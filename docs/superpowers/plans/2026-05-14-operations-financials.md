# Operations & Financials Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Layer financial discipline onto the Sub-project A swine CRM — inventory ledger with weighted-average cost, vendor purchases, expenses, sales (per-transaction with per-pig line items), and profitability reporting both per-period and per-batch.

**Architecture:** Sub-collections under `farms/{farmId}/...` continue the spec A pattern. New inventory model is a movement ledger + denormalized stock balance with weighted-average unit cost. Sales and purchases are atomic transactions (multi-doc reads + writes). Profitability is pure-function calculation over streamed data.

**Tech Stack:** No new packages. Reuse existing — `flutter_riverpod` 3.x, `cloud_firestore`, `firebase_storage`, `image_picker`, `fl_chart`, `fake_cloud_firestore` (dev).

**Spec reference:** `docs/superpowers/specs/2026-05-14-operations-financials-design.md`. Authoritative for data model and permissions matrix delta.

**Required pre-reading:** `CLAUDE.md` and `.impeccable.md` (design contract — every new screen honors these), plus `docs/superpowers/specs/2026-05-14-swine-crm-foundation-design.md` (spec A) for inherited patterns.

---

## Conventions (inherit from Sub-project A plan)

- **TDD**: failing test first, then minimal code to pass.
- **Tests** at `test/<mirror-of-lib-path>/<file>_test.dart`.
- **Repository tests** use `fake_cloud_firestore` — no Mockito.
- **Models** implement `==` and `hashCode` via `Object.hash` where helpful (matches spec A pattern; mostly skip for stream-only entities like movements).
- **Commits**: conventional (`feat:`, `fix:`, `test:`, `refactor:`, `docs:`, `chore:`). Small and focused.
- **Atomicity contract**: every state-changing repository method writes its source record AND the corresponding activity entry (and any derived effects) in a single `WriteBatch` or `runTransaction`.
- **Design contract**: every new screen uses theme tokens (`Theme.of(context).colorScheme.<token>`), shared widgets (`SectionHeader`, `EmptyState`, `StatTile`, `AdaptiveDatePicker`, `ConfirmDialog`), and the iconsax glyph map.
- **Verify before commit**: `flutter analyze` (must stay at 0 issues) + `flutter test` (currently 105 passing — will grow to ~135 by end of plan).

## File structure (delta to spec A)

```
lib/src/features/
├─ inventory/                    (new)
│   ├─ domain/    supply.dart, supply_movement.dart, supply_category.dart
│   ├─ data/      supply_repository.dart, movement_repository.dart
│   ├─ application/  inventory_providers.dart
│   └─ presentation/  inventory_list_screen.dart, supply_detail_screen.dart,
│                     add_edit_supply_screen.dart, log_consumption_screen.dart
├─ purchases/                    (new)
│   ├─ domain/    purchase.dart, purchase_line_item.dart
│   ├─ data/      purchase_repository.dart
│   ├─ application/  purchase_providers.dart
│   └─ presentation/  purchases_list_screen.dart, log_purchase_screen.dart
├─ expenses/                     (new)
│   ├─ domain/    expense.dart, expense_category.dart
│   ├─ data/      expense_repository.dart
│   ├─ application/  expense_providers.dart
│   └─ presentation/  expenses_list_screen.dart, log_expense_screen.dart
├─ sales/                        (new)
│   ├─ domain/    sale.dart, sale_line_item.dart, payment_method.dart, payment_status.dart
│   ├─ data/      sale_repository.dart
│   ├─ application/  sale_providers.dart
│   └─ presentation/  sales_list_screen.dart, sale_detail_screen.dart, log_sale_screen.dart
├─ profitability/                (new)
│   ├─ application/  batch_cost_calculator.dart, profitability_calculator.dart, profitability_providers.dart
│   └─ presentation/  batches_list_screen.dart, batch_profitability_screen.dart
└─ pigs/                         (modified — add currentBatchId)
```

Existing files modified:
- `lib/src/features/pigs/domain/pig.dart` — add `currentBatchId?`
- `lib/src/features/pigs/data/farrowing_repository.dart` — write `currentBatchId` if litter members are created (currently piglets aren't per-pig docs; only the batch is created — see Task 5 for the nuance)
- `lib/src/features/yield/yield_screen.dart` — add Profitability card + Batches link
- `lib/src/features/dashboard/dashboard_screen.dart` — add Revenue + Low Stock tiles
- `lib/src/features/pigs/presentation/pig_detail_screen.dart` — Sold banner + sale link
- `lib/src/routing/app_router.dart` — wire new routes
- `firestore.rules` — rules for new collections

---

## Task 1: Supply & SupplyMovement models, SupplyRepository, inventory list

**Goal:** Build the inventory foundation — the `Supply` catalog entity with denormalized `currentStock` and `weightedAvgUnitCostPhp`, the `SupplyMovement` ledger, the repository with atomic batched ops, and a sectioned inventory list screen.

**Files:**
- Create:
  - `lib/src/features/inventory/domain/supply_category.dart`
  - `lib/src/features/inventory/domain/supply.dart`
  - `lib/src/features/inventory/domain/supply_movement.dart`
  - `lib/src/features/inventory/data/supply_repository.dart`
  - `lib/src/features/inventory/data/movement_repository.dart`
  - `lib/src/features/inventory/application/inventory_providers.dart`
  - `lib/src/features/inventory/presentation/inventory_list_screen.dart`
  - `test/features/inventory/domain/supply_test.dart`
  - `test/features/inventory/domain/supply_movement_test.dart`
  - `test/features/inventory/data/supply_repository_test.dart`
- Modify: `lib/src/routing/app_router.dart`

### Steps

- [ ] **Step 1.1: SupplyCategory + SupplyUnit + MovementType enums**

`lib/src/features/inventory/domain/supply_category.dart`:

```dart
enum SupplyCategory {
  feed('feed', 'Feed'),
  medicine('medicine', 'Medicine'),
  otherInput('other_input', 'Other input');

  const SupplyCategory(this.value, this.label);
  final String value;
  final String label;

  static SupplyCategory fromString(String s) =>
      SupplyCategory.values.firstWhere(
        (e) => e.value == s,
        orElse: () => SupplyCategory.otherInput,
      );
}

enum SupplyUnit {
  kg('kg', 'kg'),
  sack('sack', 'sack'),
  bag('bag', 'bag'),
  ml('ml', 'ml'),
  dose('dose', 'dose'),
  vial('vial', 'vial'),
  unit('unit', 'unit');

  const SupplyUnit(this.value, this.label);
  final String value;
  final String label;

  static SupplyUnit fromString(String s) =>
      SupplyUnit.values.firstWhere(
        (e) => e.value == s,
        orElse: () => SupplyUnit.unit,
      );
}

enum MovementType {
  purchase('purchase', 'Purchase'),
  consumption('consumption', 'Consumption'),
  adjustment('adjustment', 'Adjustment'),
  wastage('wastage', 'Wastage');

  const MovementType(this.value, this.label);
  final String value;
  final String label;

  static MovementType fromString(String s) =>
      MovementType.values.firstWhere(
        (e) => e.value == s,
        orElse: () => MovementType.adjustment,
      );
}
```

- [ ] **Step 1.2: Test — Supply model**

`test/features/inventory/domain/supply_test.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/features/inventory/domain/supply.dart';
import 'package:farm_app/src/features/inventory/domain/supply_category.dart';

void main() {
  test('Supply round-trips through Firestore', () async {
    final f = FakeFirebaseFirestore();
    final t = Timestamp.fromMillisecondsSinceEpoch(1700000000000);
    await f.collection('farms').doc('f1').collection('supplies').doc('s1').set({
      'name': 'Pigrolac Grower',
      'category': 'feed',
      'unit': 'sack',
      'unitsPerPackage': 50,
      'lowStockThreshold': 5,
      'currentStock': 12,
      'weightedAvgUnitCostPhp': 1650.0,
      'notes': null,
      'createdBy': 'u1',
      'createdAt': t,
      'updatedAt': t,
    });
    final doc = await f.collection('farms').doc('f1').collection('supplies').doc('s1').get();
    final s = Supply.fromFirestore(doc, farmId: 'f1');

    expect(s.id, 's1');
    expect(s.farmId, 'f1');
    expect(s.name, 'Pigrolac Grower');
    expect(s.category, SupplyCategory.feed);
    expect(s.unit, SupplyUnit.sack);
    expect(s.unitsPerPackage, 50);
    expect(s.lowStockThreshold, 5);
    expect(s.currentStock, 12);
    expect(s.weightedAvgUnitCostPhp, 1650.0);
  });

  test('Supply.isLowStock returns true when current < threshold', () {
    final base = Supply(
      id: 's', farmId: 'f', name: 'X',
      category: SupplyCategory.feed, unit: SupplyUnit.sack,
      unitsPerPackage: null, lowStockThreshold: 5,
      currentStock: 3, weightedAvgUnitCostPhp: 100.0,
      notes: null, createdBy: 'u',
      createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
    );
    expect(base.isLowStock, true);
    expect(base.copyWith(currentStock: 5).isLowStock, false);
    expect(base.copyWith(currentStock: 6).isLowStock, false);
  });

  test('Supply.isOutOfStock when currentStock is 0 or negative', () {
    final base = Supply(
      id: 's', farmId: 'f', name: 'X',
      category: SupplyCategory.feed, unit: SupplyUnit.sack,
      unitsPerPackage: null, lowStockThreshold: 5,
      currentStock: 0, weightedAvgUnitCostPhp: 0,
      notes: null, createdBy: 'u',
      createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
    );
    expect(base.isOutOfStock, true);
    expect(base.copyWith(currentStock: 1).isOutOfStock, false);
  });

  test('Supply with null lowStockThreshold is never low-stock', () {
    final base = Supply(
      id: 's', farmId: 'f', name: 'X',
      category: SupplyCategory.feed, unit: SupplyUnit.sack,
      unitsPerPackage: null, lowStockThreshold: null,
      currentStock: 0, weightedAvgUnitCostPhp: 0,
      notes: null, createdBy: 'u',
      createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
    );
    expect(base.isLowStock, false);
    expect(base.isOutOfStock, true);
  });
}
```

Run: `flutter test test/features/inventory/domain/supply_test.dart` → fails (no Supply).

- [ ] **Step 1.3: Implement Supply model**

`lib/src/features/inventory/domain/supply.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'supply_category.dart';

class Supply {
  final String id;
  final String farmId;
  final String name;
  final SupplyCategory category;
  final SupplyUnit unit;
  final int? unitsPerPackage;
  final num? lowStockThreshold;
  final num currentStock;
  final double weightedAvgUnitCostPhp;
  final String? notes;
  final String createdBy;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  const Supply({
    required this.id,
    required this.farmId,
    required this.name,
    required this.category,
    required this.unit,
    required this.unitsPerPackage,
    required this.lowStockThreshold,
    required this.currentStock,
    required this.weightedAvgUnitCostPhp,
    required this.notes,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Supply.fromFirestore(DocumentSnapshot doc, {required String farmId}) {
    final d = doc.data() as Map<String, dynamic>;
    return Supply(
      id: doc.id,
      farmId: farmId,
      name: d['name'] as String? ?? '(unnamed)',
      category: SupplyCategory.fromString(d['category'] as String? ?? 'other_input'),
      unit: SupplyUnit.fromString(d['unit'] as String? ?? 'unit'),
      unitsPerPackage: (d['unitsPerPackage'] as num?)?.toInt(),
      lowStockThreshold: d['lowStockThreshold'] as num?,
      currentStock: (d['currentStock'] as num?) ?? 0,
      weightedAvgUnitCostPhp: (d['weightedAvgUnitCostPhp'] as num?)?.toDouble() ?? 0.0,
      notes: d['notes'] as String?,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: d['updatedAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'category': category.value,
    'unit': unit.value,
    if (unitsPerPackage != null) 'unitsPerPackage': unitsPerPackage,
    if (lowStockThreshold != null) 'lowStockThreshold': lowStockThreshold,
    'currentStock': currentStock,
    'weightedAvgUnitCostPhp': weightedAvgUnitCostPhp,
    if (notes != null) 'notes': notes,
    'createdBy': createdBy,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  bool get isOutOfStock => currentStock <= 0;
  bool get isLowStock =>
      lowStockThreshold != null && currentStock < lowStockThreshold! && !isOutOfStock;

  Supply copyWith({
    String? name,
    SupplyCategory? category,
    SupplyUnit? unit,
    int? unitsPerPackage,
    num? lowStockThreshold,
    num? currentStock,
    double? weightedAvgUnitCostPhp,
    String? notes,
  }) => Supply(
    id: id, farmId: farmId,
    name: name ?? this.name,
    category: category ?? this.category,
    unit: unit ?? this.unit,
    unitsPerPackage: unitsPerPackage ?? this.unitsPerPackage,
    lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
    currentStock: currentStock ?? this.currentStock,
    weightedAvgUnitCostPhp: weightedAvgUnitCostPhp ?? this.weightedAvgUnitCostPhp,
    notes: notes ?? this.notes,
    createdBy: createdBy, createdAt: createdAt, updatedAt: updatedAt,
  );
}
```

Run: `flutter test test/features/inventory/domain/supply_test.dart` → passes.

- [ ] **Step 1.4: Test + implement SupplyMovement**

`test/features/inventory/domain/supply_movement_test.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/features/inventory/domain/supply_category.dart';
import 'package:farm_app/src/features/inventory/domain/supply_movement.dart';

void main() {
  test('SupplyMovement round-trips', () async {
    final f = FakeFirebaseFirestore();
    final t = Timestamp.fromMillisecondsSinceEpoch(1700000000000);
    await f.collection('farms').doc('f1').collection('supply_movements').doc('m1').set({
      'supplyId': 's1',
      'type': 'consumption',
      'quantity': -2,
      'relatedPenId': 'pen1',
      'relatedBatchId': 'batch1',
      'notes': 'morning feed',
      'createdBy': 'u1',
      'createdAt': t,
    });
    final doc = await f.collection('farms').doc('f1').collection('supply_movements').doc('m1').get();
    final m = SupplyMovement.fromFirestore(doc, farmId: 'f1');

    expect(m.id, 'm1');
    expect(m.farmId, 'f1');
    expect(m.supplyId, 's1');
    expect(m.type, MovementType.consumption);
    expect(m.quantity, -2);
    expect(m.relatedPenId, 'pen1');
    expect(m.relatedBatchId, 'batch1');
  });

  test('Purchase movement carries unitCostPhp', () async {
    final f = FakeFirebaseFirestore();
    await f.collection('farms').doc('f1').collection('supply_movements').doc('m2').set({
      'supplyId': 's1',
      'type': 'purchase',
      'quantity': 10,
      'unitCostPhp': 1650.0,
      'relatedPurchaseId': 'p1',
      'createdBy': 'u1',
      'createdAt': Timestamp.now(),
    });
    final doc = await f.collection('farms').doc('f1').collection('supply_movements').doc('m2').get();
    final m = SupplyMovement.fromFirestore(doc, farmId: 'f1');

    expect(m.type, MovementType.purchase);
    expect(m.quantity, 10);
    expect(m.unitCostPhp, 1650.0);
    expect(m.relatedPurchaseId, 'p1');
  });
}
```

`lib/src/features/inventory/domain/supply_movement.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'supply_category.dart';

class SupplyMovement {
  final String id;
  final String farmId;
  final String supplyId;
  final MovementType type;
  final num quantity; // signed: + inflow, − outflow
  final double? unitCostPhp;
  final String? relatedPurchaseId;
  final String? relatedPenId;
  final String? relatedBatchId;
  final String? relatedHealthRecordId;
  final String? notes;
  final String createdBy;
  final Timestamp createdAt;

  const SupplyMovement({
    required this.id,
    required this.farmId,
    required this.supplyId,
    required this.type,
    required this.quantity,
    required this.unitCostPhp,
    required this.relatedPurchaseId,
    required this.relatedPenId,
    required this.relatedBatchId,
    required this.relatedHealthRecordId,
    required this.notes,
    required this.createdBy,
    required this.createdAt,
  });

  factory SupplyMovement.fromFirestore(DocumentSnapshot doc, {required String farmId}) {
    final d = doc.data() as Map<String, dynamic>;
    return SupplyMovement(
      id: doc.id,
      farmId: farmId,
      supplyId: d['supplyId'] as String? ?? '',
      type: MovementType.fromString(d['type'] as String? ?? 'adjustment'),
      quantity: (d['quantity'] as num?) ?? 0,
      unitCostPhp: (d['unitCostPhp'] as num?)?.toDouble(),
      relatedPurchaseId: d['relatedPurchaseId'] as String?,
      relatedPenId: d['relatedPenId'] as String?,
      relatedBatchId: d['relatedBatchId'] as String?,
      relatedHealthRecordId: d['relatedHealthRecordId'] as String?,
      notes: d['notes'] as String?,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'supplyId': supplyId,
    'type': type.value,
    'quantity': quantity,
    if (unitCostPhp != null) 'unitCostPhp': unitCostPhp,
    if (relatedPurchaseId != null) 'relatedPurchaseId': relatedPurchaseId,
    if (relatedPenId != null) 'relatedPenId': relatedPenId,
    if (relatedBatchId != null) 'relatedBatchId': relatedBatchId,
    if (relatedHealthRecordId != null) 'relatedHealthRecordId': relatedHealthRecordId,
    if (notes != null) 'notes': notes,
    'createdBy': createdBy,
    'createdAt': createdAt,
  };
}
```

Run tests, expect pass.

- [ ] **Step 1.5: Commit models**

```bash
git add lib/src/features/inventory/domain test/features/inventory/domain
git commit -m "feat(inventory): Supply + SupplyMovement domain models with category/unit/type enums"
```

- [ ] **Step 1.6: Test SupplyRepository**

`test/features/inventory/data/supply_repository_test.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/features/activity/data/activity_repository.dart';
import 'package:farm_app/src/features/inventory/data/supply_repository.dart';
import 'package:farm_app/src/features/inventory/domain/supply.dart';
import 'package:farm_app/src/features/inventory/domain/supply_category.dart';

void main() {
  SupplyRepository newRepo() {
    final f = FakeFirebaseFirestore();
    return SupplyRepository(f, ActivityRepository(f));
  }

  test('createSupply writes doc with currentStock=0 and emits activity', () async {
    final repo = newRepo();
    final id = await repo.createSupply(
      farmId: 'f1',
      name: 'Pigrolac Grower',
      category: SupplyCategory.feed,
      unit: SupplyUnit.sack,
      unitsPerPackage: 50,
      lowStockThreshold: 5,
      notes: null,
      actorUserId: 'u1',
      actorDisplayName: 'Juan',
    );
    expect(id, isNotEmpty);
    final supply = await repo.streamSupplyById(farmId: 'f1', supplyId: id).first;
    expect(supply!.name, 'Pigrolac Grower');
    expect(supply.currentStock, 0);
    expect(supply.weightedAvgUnitCostPhp, 0.0);
  });

  test('updateSupply changes name + threshold', () async {
    final repo = newRepo();
    final id = await repo.createSupply(
      farmId: 'f1', name: 'A',
      category: SupplyCategory.feed, unit: SupplyUnit.sack,
      unitsPerPackage: null, lowStockThreshold: null, notes: null,
      actorUserId: 'u', actorDisplayName: 'J',
    );
    await repo.updateSupply(
      farmId: 'f1', supplyId: id,
      name: 'B', category: SupplyCategory.feed, unit: SupplyUnit.sack,
      unitsPerPackage: null, lowStockThreshold: 5, notes: null,
    );
    final supply = await repo.streamSupplyById(farmId: 'f1', supplyId: id).first;
    expect(supply!.name, 'B');
    expect(supply.lowStockThreshold, 5);
  });

  test('streamSupplies returns sorted by category then name', () async {
    final repo = newRepo();
    await repo.createSupply(
      farmId: 'f1', name: 'Zinc supplement',
      category: SupplyCategory.medicine, unit: SupplyUnit.vial,
      unitsPerPackage: null, lowStockThreshold: null, notes: null,
      actorUserId: 'u', actorDisplayName: 'J',
    );
    await repo.createSupply(
      farmId: 'f1', name: 'Aloe spray',
      category: SupplyCategory.medicine, unit: SupplyUnit.ml,
      unitsPerPackage: null, lowStockThreshold: null, notes: null,
      actorUserId: 'u', actorDisplayName: 'J',
    );
    await repo.createSupply(
      farmId: 'f1', name: 'Grower feed',
      category: SupplyCategory.feed, unit: SupplyUnit.sack,
      unitsPerPackage: null, lowStockThreshold: null, notes: null,
      actorUserId: 'u', actorDisplayName: 'J',
    );
    final list = await repo.streamSupplies('f1').first;
    expect(list.length, 3);
    expect(list[0].category, SupplyCategory.feed);
    expect(list[0].name, 'Grower feed');
    expect(list[1].name, 'Aloe spray');
    expect(list[2].name, 'Zinc supplement');
  });
}
```

- [ ] **Step 1.7: Implement SupplyRepository**

`lib/src/features/inventory/data/supply_repository.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../activity/data/activity_repository.dart';
import '../domain/supply.dart';
import '../domain/supply_category.dart';

class SupplyRepository {
  SupplyRepository(this._firestore, this._activity);
  final FirebaseFirestore _firestore;
  final ActivityRepository _activity;

  CollectionReference<Map<String, dynamic>> _col(String farmId) =>
      _firestore.collection('farms').doc(farmId).collection('supplies');

  Future<String> createSupply({
    required String farmId,
    required String name,
    required SupplyCategory category,
    required SupplyUnit unit,
    required int? unitsPerPackage,
    required num? lowStockThreshold,
    required String? notes,
    required String actorUserId,
    required String actorDisplayName,
  }) async {
    final ref = _col(farmId).doc();
    final batch = _firestore.batch();
    batch.set(ref, {
      'name': name.trim(),
      'category': category.value,
      'unit': unit.value,
      if (unitsPerPackage != null) 'unitsPerPackage': unitsPerPackage,
      if (lowStockThreshold != null) 'lowStockThreshold': lowStockThreshold,
      'currentStock': 0,
      'weightedAvgUnitCostPhp': 0.0,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      'createdBy': actorUserId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _activity.addActivityToBatch(
      batch: batch, farmId: farmId,
      actorUserId: actorUserId, actorDisplayName: actorDisplayName,
      action: 'supply_added', entityType: 'supply', entityId: ref.id,
      summary: '$actorDisplayName added supply "$name"',
    );
    await batch.commit();
    return ref.id;
  }

  Future<void> updateSupply({
    required String farmId,
    required String supplyId,
    required String name,
    required SupplyCategory category,
    required SupplyUnit unit,
    required int? unitsPerPackage,
    required num? lowStockThreshold,
    required String? notes,
  }) async {
    await _col(farmId).doc(supplyId).update({
      'name': name.trim(),
      'category': category.value,
      'unit': unit.value,
      'unitsPerPackage': unitsPerPackage,
      'lowStockThreshold': lowStockThreshold,
      'notes': notes?.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteSupply({required String farmId, required String supplyId}) async {
    await _col(farmId).doc(supplyId).delete();
  }

  Stream<List<Supply>> streamSupplies(String farmId) {
    return _col(farmId).snapshots().map((s) {
      final list = s.docs.map((d) => Supply.fromFirestore(d, farmId: farmId)).toList();
      list.sort((a, b) {
        final cmp = a.category.index.compareTo(b.category.index);
        return cmp != 0 ? cmp : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return list;
    });
  }

  Stream<Supply?> streamSupplyById({required String farmId, required String supplyId}) {
    return _col(farmId).doc(supplyId).snapshots().map(
      (d) => d.exists ? Supply.fromFirestore(d, farmId: farmId) : null,
    );
  }
}
```

Run tests, expect pass.

- [ ] **Step 1.8: Implement MovementRepository**

`lib/src/features/inventory/data/movement_repository.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/supply_movement.dart';

class MovementRepository {
  MovementRepository(this._firestore);
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _col(String farmId) =>
      _firestore.collection('farms').doc(farmId).collection('supply_movements');

  /// Streams movements for a given supply, newest first.
  Stream<List<SupplyMovement>> streamForSupply({
    required String farmId, required String supplyId,
  }) {
    return _col(farmId)
        .where('supplyId', isEqualTo: supplyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) =>
            SupplyMovement.fromFirestore(d, farmId: farmId)).toList());
  }

  /// All movements in a date range — for profitability calculator.
  Stream<List<SupplyMovement>> streamInRange({
    required String farmId,
    required Timestamp start,
    required Timestamp end,
  }) {
    return _col(farmId)
        .where('createdAt', isGreaterThanOrEqualTo: start)
        .where('createdAt', isLessThan: end)
        .snapshots()
        .map((s) => s.docs.map((d) =>
            SupplyMovement.fromFirestore(d, farmId: farmId)).toList());
  }

  /// All movements for a batch — for batch cost calculator.
  Stream<List<SupplyMovement>> streamForBatch({
    required String farmId, required String batchId,
  }) {
    return _col(farmId)
        .where('relatedBatchId', isEqualTo: batchId)
        .snapshots()
        .map((s) => s.docs.map((d) =>
            SupplyMovement.fromFirestore(d, farmId: farmId)).toList());
  }
}
```

- [ ] **Step 1.9: Providers**

`lib/src/features/inventory/application/inventory_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../activity/application/activity_providers.dart';
import '../data/movement_repository.dart';
import '../data/supply_repository.dart';
import '../domain/supply.dart';
import '../domain/supply_movement.dart';

final supplyRepositoryProvider = Provider<SupplyRepository>(
  (ref) => SupplyRepository(ref.watch(firestoreProvider), ref.watch(activityRepositoryProvider)),
);

final movementRepositoryProvider = Provider<MovementRepository>(
  (ref) => MovementRepository(ref.watch(firestoreProvider)),
);

final suppliesStreamProvider =
    StreamProvider.family<List<Supply>, String>((ref, farmId) {
  return ref.watch(supplyRepositoryProvider).streamSupplies(farmId);
});

final supplyByIdProvider =
    StreamProvider.family<Supply?, ({String farmId, String supplyId})>((ref, args) {
  return ref.watch(supplyRepositoryProvider)
      .streamSupplyById(farmId: args.farmId, supplyId: args.supplyId);
});

final movementsForSupplyProvider =
    StreamProvider.family<List<SupplyMovement>, ({String farmId, String supplyId})>((ref, args) {
  return ref.watch(movementRepositoryProvider)
      .streamForSupply(farmId: args.farmId, supplyId: args.supplyId);
});
```

- [ ] **Step 1.10: Inventory list screen**

`lib/src/features/inventory/presentation/inventory_list_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../../core/permissions/permission_service.dart';
import '../../../core/permissions/role.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../../team/application/team_providers.dart';
import '../application/inventory_providers.dart';
import '../domain/supply.dart';
import '../domain/supply_category.dart';
import 'add_edit_supply_screen.dart';
import 'supply_detail_screen.dart';

enum _StockFilter { all, low, out }

class InventoryListScreen extends ConsumerStatefulWidget {
  const InventoryListScreen({super.key});
  @override
  ConsumerState<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends ConsumerState<InventoryListScreen> {
  _StockFilter _filter = _StockFilter.all;

  @override
  Widget build(BuildContext context) {
    final farmId = ref.watch(selectedFarmIdProvider);
    final user = ref.watch(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return const SizedBox.shrink();

    final role = ref.watch(memberForUserProvider(
      (farmId: farmId, userId: user.uid),
    )).asData?.value?.role ?? Role.worker;
    final canEdit = PermissionService.canEditEquipment(role); // Same gate as equipment
    final suppliesAsync = ref.watch(suppliesStreamProvider(farmId));

    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              icon: const Icon(Iconsax.add),
              label: const Text('Add supply'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddEditSupplyScreen()),
              ),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Wrap(spacing: 8, children: [
              FilterChip(
                label: const Text('All'),
                selected: _filter == _StockFilter.all,
                onSelected: (_) => setState(() => _filter = _StockFilter.all),
              ),
              FilterChip(
                label: const Text('Low stock'),
                selected: _filter == _StockFilter.low,
                onSelected: (_) => setState(() => _filter = _StockFilter.low),
              ),
              FilterChip(
                label: const Text('Out of stock'),
                selected: _filter == _StockFilter.out,
                onSelected: (_) => setState(() => _filter = _StockFilter.out),
              ),
            ]),
          ),
          Expanded(
            child: suppliesAsync.when(
              data: (supplies) {
                final filtered = supplies.where((s) {
                  switch (_filter) {
                    case _StockFilter.all: return true;
                    case _StockFilter.low: return s.isLowStock;
                    case _StockFilter.out: return s.isOutOfStock;
                  }
                }).toList();
                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Iconsax.box,
                    title: supplies.isEmpty ? 'No supplies tracked' : 'No supplies match',
                    subtitle: supplies.isEmpty
                        ? 'Tap + to track your first feed or medicine.'
                        : 'Try clearing the filter.',
                  );
                }
                final byCategory = <SupplyCategory, List<Supply>>{};
                for (final s in filtered) {
                  byCategory.putIfAbsent(s.category, () => []).add(s);
                }
                final cats = byCategory.keys.toList()
                  ..sort((a, b) => a.index.compareTo(b.index));
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: cats.length,
                  itemBuilder: (_, i) {
                    final c = cats[i];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionHeader(title: c.label.toUpperCase()),
                        ...byCategory[c]!.map((s) => _SupplyCard(supply: s)),
                      ],
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupplyCard extends StatelessWidget {
  const _SupplyCard({required this.supply});
  final Supply supply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formatter = NumberFormat.decimalPattern('en_PH');
    String pillLabel;
    Color pillFg, pillBg;
    if (supply.isOutOfStock) {
      pillLabel = 'Out';
      pillFg = scheme.onError; pillBg = scheme.error;
    } else if (supply.isLowStock) {
      pillLabel = 'Low';
      pillFg = scheme.onTertiary; pillBg = scheme.tertiary;
    } else {
      pillLabel = 'OK';
      pillFg = scheme.onPrimary; pillBg = scheme.primary;
    }

    return Card(
      child: ListTile(
        title: Text(supply.name, style: theme.textTheme.titleMedium),
        subtitle: Text(
          '${formatter.format(supply.currentStock)} ${supply.unit.label}'
          '${supply.weightedAvgUnitCostPhp > 0 ? ' · ₱${supply.weightedAvgUnitCostPhp.toStringAsFixed(0)} / ${supply.unit.label}' : ''}',
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: pillBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(pillLabel,
              style: theme.textTheme.labelMedium?.copyWith(
                color: pillFg, fontWeight: FontWeight.w700)),
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SupplyDetailScreen(supplyId: supply.id)),
        ),
      ),
    );
  }
}
```

(Note: `AddEditSupplyScreen` and `SupplyDetailScreen` are created in Task 2 — for this task they're just import targets. To compile, create empty stub classes now in their files; Task 2 will fill them out.)

- [ ] **Step 1.11: Create stub screens for Task 2 imports**

`lib/src/features/inventory/presentation/add_edit_supply_screen.dart`:

```dart
import 'package:flutter/material.dart';
import '../domain/supply.dart';

class AddEditSupplyScreen extends StatelessWidget {
  const AddEditSupplyScreen({super.key, this.existing});
  final Supply? existing;
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Add/Edit Supply — Task 2')));
}
```

`lib/src/features/inventory/presentation/supply_detail_screen.dart`:

```dart
import 'package:flutter/material.dart';

class SupplyDetailScreen extends StatelessWidget {
  const SupplyDetailScreen({super.key, required this.supplyId});
  final String supplyId;
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('Supply Detail — $supplyId — Task 2')));
}
```

- [ ] **Step 1.12: Wire route + commit**

In `lib/src/routing/app_router.dart`, add inside the `routes:` list (before the `/` route):

```dart
GoRoute(
  path: '/inventory',
  builder: (c, s) => const InventoryListScreen(),
),
```

And add the import at the top:
```dart
import '../features/inventory/presentation/inventory_list_screen.dart';
```

Run:
```bash
flutter analyze
flutter test
```
Expected: 0 issues, 105 + 7 = ~112 tests pass.

```bash
git add -A
git commit -m "feat(inventory): SupplyRepository + MovementRepository + inventory list

- Supply with denormalized currentStock and weightedAvgUnitCostPhp
- SupplyMovement ledger (purchase/consumption/adjustment/wastage)
- Inventory list grouped by category with status pills (OK/Low/Out)
- Stub supply detail and add/edit screens for Task 2 implementation
- /inventory route wired"
```

---

## Task 2: Supply detail + Add/Edit Supply + Low-stock threshold inline edit

**Goal:** Replace the Task 1 stubs with the real Supply detail screen (with stock-history tab) and Add/Edit Supply form. Implement inline threshold editing.

**Files:**
- Replace: `lib/src/features/inventory/presentation/supply_detail_screen.dart`
- Replace: `lib/src/features/inventory/presentation/add_edit_supply_screen.dart`

### Steps

- [ ] **Step 2.1: Add/Edit Supply screen**

Replace `lib/src/features/inventory/presentation/add_edit_supply_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/section_header.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../application/inventory_providers.dart';
import '../domain/supply.dart';
import '../domain/supply_category.dart';

class AddEditSupplyScreen extends ConsumerStatefulWidget {
  const AddEditSupplyScreen({super.key, this.existing});
  final Supply? existing;
  @override
  ConsumerState<AddEditSupplyScreen> createState() => _State();
}

class _State extends ConsumerState<AddEditSupplyScreen> {
  late final TextEditingController _name;
  late final TextEditingController _unitsPerPackage;
  late final TextEditingController _lowStock;
  late final TextEditingController _notes;
  late SupplyCategory _category;
  late SupplyUnit _unit;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _unitsPerPackage = TextEditingController(text: e?.unitsPerPackage?.toString() ?? '');
    _lowStock = TextEditingController(text: e?.lowStockThreshold?.toString() ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _category = e?.category ?? SupplyCategory.feed;
    _unit = e?.unit ?? SupplyUnit.sack;
  }

  @override
  void dispose() {
    _name.dispose();
    _unitsPerPackage.dispose();
    _lowStock.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final farmId = ref.read(selectedFarmIdProvider);
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required.')),
      );
      return;
    }
    setState(() => _busy = true);
    final repo = ref.read(supplyRepositoryProvider);
    final actorName = ref.read(currentAppUserProvider).asData?.value?.displayName ?? '';
    final unitsPerPackage = int.tryParse(_unitsPerPackage.text.trim());
    final lowStock = num.tryParse(_lowStock.text.trim());
    final notes = _notes.text.trim().isEmpty ? null : _notes.text.trim();
    try {
      if (widget.existing == null) {
        await repo.createSupply(
          farmId: farmId, name: name, category: _category, unit: _unit,
          unitsPerPackage: unitsPerPackage, lowStockThreshold: lowStock,
          notes: notes,
          actorUserId: user.uid, actorDisplayName: actorName,
        );
      } else {
        await repo.updateSupply(
          farmId: farmId, supplyId: widget.existing!.id,
          name: name, category: _category, unit: _unit,
          unitsPerPackage: unitsPerPackage, lowStockThreshold: lowStock,
          notes: notes,
        );
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New supply' : 'Edit supply'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(title: 'NAME', padding: EdgeInsets.only(bottom: 8)),
            TextField(controller: _name,
              decoration: const InputDecoration(hintText: 'e.g., Pigrolac Grower')),
            const SectionHeader(title: 'CATEGORY'),
            SegmentedButton<SupplyCategory>(
              segments: SupplyCategory.values
                  .map((c) => ButtonSegment(value: c, label: Text(c.label)))
                  .toList(),
              selected: {_category},
              onSelectionChanged: (s) => setState(() => _category = s.first),
            ),
            const SectionHeader(title: 'UNIT'),
            DropdownButtonFormField<SupplyUnit>(
              initialValue: _unit,
              items: SupplyUnit.values
                  .map((u) => DropdownMenuItem(value: u, child: Text(u.label)))
                  .toList(),
              onChanged: (v) => setState(() => _unit = v ?? SupplyUnit.unit),
            ),
            const SectionHeader(title: 'PACKAGE & THRESHOLDS'),
            TextField(
              controller: _unitsPerPackage,
              decoration: const InputDecoration(
                labelText: 'Units per package (optional)',
                helperText: 'e.g., 50 if a sack is 50 kg',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lowStock,
              decoration: const InputDecoration(
                labelText: 'Low-stock alert threshold (optional)',
              ),
              keyboardType: TextInputType.number,
            ),
            const SectionHeader(title: 'NOTES'),
            TextField(controller: _notes, maxLines: 3),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      height: 24, width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5))
                  : Text(widget.existing == null ? 'Add supply' : 'Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2.2: Supply detail screen with stock history**

Replace `lib/src/features/inventory/presentation/supply_detail_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../../core/permissions/permission_service.dart';
import '../../../core/permissions/role.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../../team/application/team_providers.dart';
import '../application/inventory_providers.dart';
import '../domain/supply.dart';
import '../domain/supply_category.dart';
import '../domain/supply_movement.dart';
import 'add_edit_supply_screen.dart';

class SupplyDetailScreen extends ConsumerWidget {
  const SupplyDetailScreen({super.key, required this.supplyId});
  final String supplyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmId = ref.watch(selectedFarmIdProvider);
    final user = ref.watch(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return const SizedBox.shrink();
    final role = ref.watch(memberForUserProvider(
      (farmId: farmId, userId: user.uid),
    )).asData?.value?.role ?? Role.worker;
    final canEdit = PermissionService.canEditEquipment(role);
    final supplyAsync = ref.watch(supplyByIdProvider(
      (farmId: farmId, supplyId: supplyId),
    ));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Supply'),
        actions: [
          if (canEdit)
            supplyAsync.maybeWhen(
              data: (s) => s == null
                  ? const SizedBox.shrink()
                  : IconButton(
                      icon: const Icon(Iconsax.edit),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddEditSupplyScreen(existing: s),
                        ),
                      ),
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
        ],
      ),
      body: supplyAsync.when(
        data: (s) {
          if (s == null) return const Center(child: Text('Not found'));
          return _SupplyDetailBody(supply: s);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _SupplyDetailBody extends ConsumerWidget {
  const _SupplyDetailBody({required this.supply});
  final Supply supply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final formatter = NumberFormat.decimalPattern('en_PH');
    final movementsAsync = ref.watch(movementsForSupplyProvider(
      (farmId: supply.farmId, supplyId: supply.id),
    ));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(supply.name, style: theme.textTheme.headlineSmall),
                Text('${supply.category.label} · ${supply.unit.label}',
                    style: theme.textTheme.bodyMedium),
                const Divider(height: 24),
                Text('Current stock', style: theme.textTheme.bodyMedium),
                Text(
                  '${formatter.format(supply.currentStock)} ${supply.unit.label}',
                  style: theme.textTheme.headlineLarge,
                ),
                if (supply.weightedAvgUnitCostPhp > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Weighted avg: ₱${supply.weightedAvgUnitCostPhp.toStringAsFixed(2)} / ${supply.unit.label}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
                if (supply.lowStockThreshold != null) ...[
                  const SizedBox(height: 4),
                  Text('Low-stock alert at ${formatter.format(supply.lowStockThreshold!)}',
                      style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          ),
        ),
        const SectionHeader(title: 'STOCK HISTORY'),
        movementsAsync.when(
          data: (list) {
            if (list.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: EmptyState(
                  icon: Iconsax.box,
                  title: 'No movements yet',
                  subtitle:
                      'Stock changes will appear here once you log a purchase or consumption.',
                ),
              );
            }
            return Column(
              children: list.map((m) => _MovementCard(movement: m)).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('$e'),
        ),
      ],
    );
  }
}

class _MovementCard extends StatelessWidget {
  const _MovementCard({required this.movement});
  final SupplyMovement movement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isInflow = movement.quantity > 0;
    final color = switch (movement.type) {
      MovementType.purchase => scheme.primary,
      MovementType.consumption => scheme.onSurfaceVariant,
      MovementType.adjustment => scheme.tertiary,
      MovementType.wastage => scheme.error,
    };
    final icon = switch (movement.type) {
      MovementType.purchase => Iconsax.arrow_down_3,
      MovementType.consumption => Iconsax.arrow_up_3,
      MovementType.adjustment => Iconsax.refresh,
      MovementType.wastage => Icons.delete_outline,
    };
    final formatter = NumberFormat.decimalPattern('en_PH');
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(movement.type.label),
        subtitle: Text(DateFormat.yMMMd().add_jm().format(movement.createdAt.toDate())),
        trailing: Text(
          '${isInflow ? '+' : ''}${formatter.format(movement.quantity)}',
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2.3: Run + commit**

```bash
flutter analyze && flutter test
git add -A
git commit -m "feat(inventory): Supply detail with stock history + Add/Edit form

- Stock-history list with movement-type-specific icons and colors
- Section-grouped Add/Edit form with category SegmentedButton
- Edit action gated to Manager/Owner roles"
```

---

## Task 3: Log consumption flow with pen → batch derivation

**Goal:** Allow workers (and managers/owners) to log supply consumption against a specific pen. Implement the pen → primary batch derivation algorithm. Write atomic batch (movement + supply.currentStock decrement + activity).

**Files:**
- Create:
  - `lib/src/features/inventory/data/pen_batch_resolver.dart`
  - `lib/src/features/inventory/presentation/log_consumption_screen.dart`
  - `test/features/inventory/data/pen_batch_resolver_test.dart`
- Modify:
  - `lib/src/features/inventory/data/supply_repository.dart` (add `logConsumption` method)
  - `lib/src/features/inventory/application/inventory_providers.dart` (add `penBatchResolverProvider`)
  - `lib/src/features/inventory/presentation/supply_detail_screen.dart` (add Log consumption FAB)

### Steps

- [ ] **Step 3.1: Test — pen → batch resolver (pure function)**

`test/features/inventory/data/pen_batch_resolver_test.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/features/inventory/data/pen_batch_resolver.dart';
import 'package:farm_app/src/features/pigs/domain/pig.dart';

Pig _pig({required String currentPenId, String? currentBatchId, PigStatus status = PigStatus.active}) {
  return Pig(
    id: 'p', farmId: 'f', tagId: 't', sex: PigSex.female, breed: 'b',
    birthDate: Timestamp.now(),
    sireId: null, damId: null,
    stage: PigStage.grower, status: status,
    currentAreaId: 'a', currentPenId: currentPenId,
    currentBatchId: currentBatchId,
    currentWeight: null, weightUpdatedAt: null,
    photoUrl: null, notes: null,
    createdBy: 'u', createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
  );
}

void main() {
  test('returns null when pen has no pigs', () {
    expect(PenBatchResolver.primaryBatchForPen(penId: 'p1', pigs: []), isNull);
  });

  test('returns the batch when all pigs share one batch', () {
    final pigs = [
      _pig(currentPenId: 'p1', currentBatchId: 'b1'),
      _pig(currentPenId: 'p1', currentBatchId: 'b1'),
      _pig(currentPenId: 'p1', currentBatchId: 'b1'),
    ];
    expect(PenBatchResolver.primaryBatchForPen(penId: 'p1', pigs: pigs), 'b1');
  });

  test('returns majority batch when mixed', () {
    final pigs = [
      _pig(currentPenId: 'p1', currentBatchId: 'b1'),
      _pig(currentPenId: 'p1', currentBatchId: 'b1'),
      _pig(currentPenId: 'p1', currentBatchId: 'b2'),
    ];
    expect(PenBatchResolver.primaryBatchForPen(penId: 'p1', pigs: pigs), 'b1');
  });

  test('returns null when no pig has a batch', () {
    final pigs = [
      _pig(currentPenId: 'p1', currentBatchId: null),
      _pig(currentPenId: 'p1', currentBatchId: null),
    ];
    expect(PenBatchResolver.primaryBatchForPen(penId: 'p1', pigs: pigs), isNull);
  });

  test('ignores pigs not in the pen', () {
    final pigs = [
      _pig(currentPenId: 'p1', currentBatchId: 'b1'),
      _pig(currentPenId: 'p2', currentBatchId: 'b2'),
      _pig(currentPenId: 'p2', currentBatchId: 'b2'),
    ];
    expect(PenBatchResolver.primaryBatchForPen(penId: 'p1', pigs: pigs), 'b1');
  });

  test('ignores deceased/sold/culled pigs', () {
    final pigs = [
      _pig(currentPenId: 'p1', currentBatchId: 'b1', status: PigStatus.deceased),
      _pig(currentPenId: 'p1', currentBatchId: 'b2'),
    ];
    expect(PenBatchResolver.primaryBatchForPen(penId: 'p1', pigs: pigs), 'b2');
  });

  test('tie broken by alphabetical batch id', () {
    final pigs = [
      _pig(currentPenId: 'p1', currentBatchId: 'b2'),
      _pig(currentPenId: 'p1', currentBatchId: 'b1'),
    ];
    expect(PenBatchResolver.primaryBatchForPen(penId: 'p1', pigs: pigs), 'b1');
  });
}
```

Note: `Pig.currentBatchId` does not exist yet — Task 5 adds it. **For this test to compile,** add the field to `Pig` early. We'll do this as Step 3.2.

- [ ] **Step 3.2: Add `currentBatchId?` field to Pig (pre-Task-5 partial migration)**

This is necessary to make the resolver work. The full Task 5 will wire `farrowing` to populate it; here we just add the field.

In `lib/src/features/pigs/domain/pig.dart`:

- Add `currentBatchId` to the field list:
```dart
final String? currentBatchId;
```

- Add to constructor:
```dart
const Pig({
  // ... existing fields ...
  required this.currentBatchId,
  // ...
});
```

- Add to `fromFirestore`:
```dart
currentBatchId: d['currentBatchId'] as String?,
```

- Add to `toMap`:
```dart
if (currentBatchId != null) 'currentBatchId': currentBatchId,
```

The Pig model is now ready. Search for any `Pig(...)` call sites in tests and production code that may fail to compile due to the new required parameter. Fix them by adding `currentBatchId: null`.

```bash
grep -rln "Pig(" lib/ test/ | xargs grep -l "id: '"
```

Expected files with `Pig(...)` constructor calls:
- `test/features/pigs/domain/pig_test.dart`
- `test/features/pigs/data/pig_repository_test.dart`
- `test/features/yield/yield_calculator_test.dart`
- (possibly others — fix as compilation errors surface)

In each, add `currentBatchId: null,` to the Pig constructor calls.

Also fix `PigRepository.createPig` and `updatePig` in `lib/src/features/pigs/data/pig_repository.dart` to pass `currentBatchId: null` when constructing (they don't construct Pig objects; they just write maps — actually no fix needed there).

Run `flutter analyze` after the field is added. Expect compile errors at constructor sites; fix them.

- [ ] **Step 3.3: Run test for resolver — it should fail (resolver doesn't exist)**

```bash
flutter test test/features/inventory/data/pen_batch_resolver_test.dart
```

Expected: fails ("PenBatchResolver not defined").

- [ ] **Step 3.4: Implement PenBatchResolver**

`lib/src/features/inventory/data/pen_batch_resolver.dart`:

```dart
import '../../pigs/domain/pig.dart';

class PenBatchResolver {
  PenBatchResolver._();

  /// Given a pen ID and the full list of pigs in the farm, returns the
  /// "primary batch" for that pen — the batch with the most active pigs
  /// currently in the pen. Returns null if no pig in the pen has a batch.
  ///
  /// Ties are broken by alphabetical batch ID for deterministic output.
  static String? primaryBatchForPen({
    required String penId,
    required List<Pig> pigs,
  }) {
    final counts = <String, int>{};
    for (final p in pigs) {
      if (p.currentPenId != penId) continue;
      if (p.status != PigStatus.active) continue;
      if (p.currentBatchId == null) continue;
      counts[p.currentBatchId!] = (counts[p.currentBatchId!] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    final entries = counts.entries.toList()
      ..sort((a, b) {
        final cmp = b.value.compareTo(a.value);
        return cmp != 0 ? cmp : a.key.compareTo(b.key);
      });
    return entries.first.key;
  }
}
```

Run tests, expect pass.

- [ ] **Step 3.5: Add penBatchResolverProvider to inventory_providers.dart**

Append:

```dart
import '../data/pen_batch_resolver.dart';
import '../../pigs/application/pig_providers.dart';

/// Resolves the primary batch for a pen by streaming current pigs.
/// Returns null if no pigs in the pen have a batch.
final primaryBatchForPenProvider =
    Provider.family<String?, ({String farmId, String penId})>((ref, args) {
  final pigs = ref.watch(pigsStreamProvider(args.farmId)).asData?.value ?? const [];
  return PenBatchResolver.primaryBatchForPen(penId: args.penId, pigs: pigs);
});
```

- [ ] **Step 3.6: Add `logConsumption` method to SupplyRepository**

In `lib/src/features/inventory/data/supply_repository.dart`, append the method (before the closing `}` of the class):

```dart
/// Logs supply consumption tied to a pen. Derives primary batch at write time.
/// Atomic: writes a movement, decrements supply.currentStock, writes activity.
/// Throws if currentStock - quantity would go negative.
Future<void> logConsumption({
  required String farmId,
  required String supplyId,
  required String supplyName,
  required num quantity, // positive value; will be stored as negative
  required String? penId,
  required String? derivedBatchId,
  required String? healthRecordId,
  required String? notes,
  required String actorUserId,
  required String actorDisplayName,
}) async {
  if (quantity <= 0) {
    throw ArgumentError('quantity must be positive');
  }
  await _firestore.runTransaction((tx) async {
    final supplyRef = _col(farmId).doc(supplyId);
    final snap = await tx.get(supplyRef);
    if (!snap.exists) throw StateError('Supply not found.');
    final current = (snap.data()!['currentStock'] as num?) ?? 0;
    if (current - quantity < 0) {
      throw StateError('Insufficient stock — only $current available.');
    }
    final movementRef = _firestore.collection('farms').doc(farmId)
        .collection('supply_movements').doc();
    tx.set(movementRef, {
      'supplyId': supplyId,
      'type': 'consumption',
      'quantity': -quantity,
      if (penId != null) 'relatedPenId': penId,
      if (derivedBatchId != null) 'relatedBatchId': derivedBatchId,
      if (healthRecordId != null) 'relatedHealthRecordId': healthRecordId,
      if (notes != null) 'notes': notes,
      'createdBy': actorUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    tx.update(supplyRef, {
      'currentStock': FieldValue.increment(-quantity),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final activityRef = _firestore.collection('farms').doc(farmId)
        .collection('activity').doc();
    tx.set(activityRef, {
      'actorUserId': actorUserId,
      'actorDisplayName': actorDisplayName,
      'action': 'supply_consumed',
      'entityType': 'supply',
      'entityId': supplyId,
      'summary': '$actorDisplayName used $quantity of "$supplyName"',
      'timestamp': FieldValue.serverTimestamp(),
    });
  });
}
```

Note: this method uses `runTransaction` rather than `WriteBatch` because of the read-before-write requirement (current stock check). The activity entry is written directly inside the transaction rather than through `ActivityRepository.addActivityToBatch` because that helper only supports WriteBatch.

- [ ] **Step 3.7: Test logConsumption**

Add to `test/features/inventory/data/supply_repository_test.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

// ... existing imports ...

void main() {
  // ... existing tests ...

  group('logConsumption', () {
    test('writes movement, decrements stock, writes activity (atomic)', () async {
      final f = FakeFirebaseFirestore();
      final repo = SupplyRepository(f, ActivityRepository(f));
      final id = await repo.createSupply(
        farmId: 'f1', name: 'Feed', category: SupplyCategory.feed,
        unit: SupplyUnit.sack, unitsPerPackage: 50, lowStockThreshold: null,
        notes: null, actorUserId: 'u', actorDisplayName: 'J',
      );
      // Seed stock manually (the model allows this since createSupply starts at 0)
      await f.collection('farms').doc('f1').collection('supplies').doc(id).update({
        'currentStock': 10,
      });

      await repo.logConsumption(
        farmId: 'f1', supplyId: id, supplyName: 'Feed', quantity: 3,
        penId: 'pen1', derivedBatchId: 'batch1',
        healthRecordId: null, notes: null,
        actorUserId: 'u', actorDisplayName: 'J',
      );

      final supply = await f.collection('farms').doc('f1').collection('supplies').doc(id).get();
      expect(supply.data()!['currentStock'], 7);

      final movements = await f.collection('farms').doc('f1')
          .collection('supply_movements').get();
      expect(movements.docs, hasLength(1));
      expect(movements.docs.first.data()['quantity'], -3);
      expect(movements.docs.first.data()['type'], 'consumption');
      expect(movements.docs.first.data()['relatedPenId'], 'pen1');
      expect(movements.docs.first.data()['relatedBatchId'], 'batch1');

      final activity = await f.collection('farms').doc('f1').collection('activity').get();
      final logEntry = activity.docs.where(
        (d) => d.data()['action'] == 'supply_consumed',
      );
      expect(logEntry, hasLength(1));
    });

    test('rejects consumption exceeding currentStock', () async {
      final f = FakeFirebaseFirestore();
      final repo = SupplyRepository(f, ActivityRepository(f));
      final id = await repo.createSupply(
        farmId: 'f1', name: 'Feed', category: SupplyCategory.feed,
        unit: SupplyUnit.sack, unitsPerPackage: null, lowStockThreshold: null,
        notes: null, actorUserId: 'u', actorDisplayName: 'J',
      );
      await f.collection('farms').doc('f1').collection('supplies').doc(id).update({
        'currentStock': 2,
      });
      expect(
        () => repo.logConsumption(
          farmId: 'f1', supplyId: id, supplyName: 'Feed', quantity: 5,
          penId: null, derivedBatchId: null, healthRecordId: null, notes: null,
          actorUserId: 'u', actorDisplayName: 'J',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects negative or zero quantity', () async {
      final f = FakeFirebaseFirestore();
      final repo = SupplyRepository(f, ActivityRepository(f));
      final id = await repo.createSupply(
        farmId: 'f1', name: 'F', category: SupplyCategory.feed,
        unit: SupplyUnit.sack, unitsPerPackage: null, lowStockThreshold: null,
        notes: null, actorUserId: 'u', actorDisplayName: 'J',
      );
      expect(
        () => repo.logConsumption(
          farmId: 'f1', supplyId: id, supplyName: 'F', quantity: 0,
          penId: null, derivedBatchId: null, healthRecordId: null, notes: null,
          actorUserId: 'u', actorDisplayName: 'J',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
```

Run: tests pass.

- [ ] **Step 3.8: Log Consumption screen**

`lib/src/features/inventory/presentation/log_consumption_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/permissions/permission_service.dart';
import '../../../core/widgets/section_header.dart';
import '../../areas/application/area_providers.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../../team/application/team_providers.dart';
import '../application/inventory_providers.dart';
import '../domain/supply.dart';

class LogConsumptionScreen extends ConsumerStatefulWidget {
  const LogConsumptionScreen({super.key, this.initialSupplyId});
  final String? initialSupplyId;
  @override
  ConsumerState<LogConsumptionScreen> createState() => _State();
}

class _State extends ConsumerState<LogConsumptionScreen> {
  String? _supplyId;
  String? _penId;
  bool _showAllPens = false;
  final _quantity = TextEditingController();
  final _notes = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _supplyId = widget.initialSupplyId;
  }

  @override
  void dispose() {
    _quantity.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final farmId = ref.read(selectedFarmIdProvider);
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return;
    if (_supplyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a supply.')),
      );
      return;
    }
    final qty = num.tryParse(_quantity.text.trim());
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantity must be a positive number.')),
      );
      return;
    }
    setState(() => _busy = true);
    final actorName = ref.read(currentAppUserProvider).asData?.value?.displayName ?? '';
    final supply = await ref.read(supplyByIdProvider(
      (farmId: farmId, supplyId: _supplyId!),
    ).future);
    if (supply == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Supply not found.')),
        );
        setState(() => _busy = false);
      }
      return;
    }
    String? derivedBatchId;
    if (_penId != null) {
      derivedBatchId = ref.read(primaryBatchForPenProvider(
        (farmId: farmId, penId: _penId!),
      ));
    }
    try {
      await ref.read(supplyRepositoryProvider).logConsumption(
        farmId: farmId,
        supplyId: _supplyId!,
        supplyName: supply.name,
        quantity: qty,
        penId: _penId,
        derivedBatchId: derivedBatchId,
        healthRecordId: null,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        actorUserId: user.uid,
        actorDisplayName: actorName,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) return const SizedBox.shrink();
    final user = ref.watch(authStateChangesProvider).asData?.value;
    final supplies = ref.watch(suppliesStreamProvider(farmId)).asData?.value ?? const <Supply>[];
    final pens = ref.watch(allPensStreamProvider(farmId)).asData?.value ?? const [];
    final member = user == null
        ? null
        : ref.watch(memberForUserProvider(
            (farmId: farmId, userId: user.uid),
          )).asData?.value;
    final assignedAreas = member?.assignedAreaIds ?? const <String>[];
    final visiblePens = (assignedAreas.isEmpty || _showAllPens)
        ? pens
        : pens.where((p) => assignedAreas.contains(p.areaId)).toList();

    final selectedSupply = _supplyId == null
        ? null
        : supplies.firstWhere(
            (s) => s.id == _supplyId,
            orElse: () => supplies.first,
          );

    return Scaffold(
      appBar: AppBar(title: const Text('Log consumption')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(title: 'SUPPLY', padding: EdgeInsets.only(bottom: 8)),
            DropdownButtonFormField<String>(
              initialValue: _supplyId,
              decoration: const InputDecoration(hintText: 'Pick a supply'),
              items: supplies
                  .map((s) => DropdownMenuItem(value: s.id,
                      child: Text('${s.name} (${s.currentStock} ${s.unit.label})')))
                  .toList(),
              onChanged: (v) => setState(() => _supplyId = v),
            ),
            const SectionHeader(title: 'QUANTITY'),
            TextField(
              controller: _quantity,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'How much',
                suffixText: selectedSupply?.unit.label,
              ),
            ),
            const SectionHeader(title: 'PEN'),
            DropdownButtonFormField<String?>(
              initialValue: _penId,
              decoration: const InputDecoration(hintText: 'Pick a pen (optional)'),
              items: [
                const DropdownMenuItem(value: null, child: Text('— Unattributed —')),
                ...visiblePens.map((p) =>
                    DropdownMenuItem(value: p.id, child: Text('${p.name} · ${p.currentOccupancy} pigs'))),
              ],
              onChanged: (v) => setState(() => _penId = v),
            ),
            if (assignedAreas.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SwitchListTile(
                  title: const Text('Show all pens'),
                  subtitle: const Text('Includes pens outside your assigned areas'),
                  value: _showAllPens,
                  onChanged: (v) => setState(() {
                    _showAllPens = v;
                    _penId = null;
                  }),
                ),
              ),
            const SectionHeader(title: 'NOTES'),
            TextField(controller: _notes, maxLines: 3),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      height: 24, width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Text('Save consumption'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3.9: Wire FAB on supply detail**

Edit `lib/src/features/inventory/presentation/supply_detail_screen.dart`, modifying the Scaffold to add a `floatingActionButton`:

```dart
import 'log_consumption_screen.dart';

// In Scaffold(...):
floatingActionButton: FloatingActionButton.extended(
  icon: const Icon(Iconsax.arrow_up_3),
  label: const Text('Log consumption'),
  onPressed: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => LogConsumptionScreen(initialSupplyId: supplyId)),
  ),
),
```

- [ ] **Step 3.10: Run + commit**

```bash
flutter analyze && flutter test
git add -A
git commit -m "feat(inventory): log consumption with pen → primary-batch derivation

- PenBatchResolver: majority-batch logic with tie-break by batch ID
- SupplyRepository.logConsumption: transactional with stock-check guard
- Log consumption screen with pen picker scoped to worker's areas
- Pig.currentBatchId field added (full population in Task 5)"
```

---

_(Tasks 4-13 continue. Each follows the same TDD + commit cadence. Remaining tasks cover Purchase (with weighted-avg in a transaction), Expenses, Sales (multi-pig atomic flip), Pig Detail integration, Profitability calculators, Yield Reports extension, Dashboard tiles, and Firestore Security Rules.)_
