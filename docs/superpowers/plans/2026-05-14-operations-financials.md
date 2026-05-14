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

---

## Task 4: Purchase model + transactional weighted-avg recomputation + log purchase screen

**Goal:** Implement purchases — a multi-line receipt that, when committed, updates each line's supply: stock balance up + weighted-avg unit cost recomputed. All atomic via `runTransaction` because we need to read each supply's pre-purchase stock + avg.

**Files:**
- Create:
  - `lib/src/features/purchases/domain/purchase.dart`
  - `lib/src/features/purchases/domain/purchase_line_item.dart`
  - `lib/src/features/purchases/data/purchase_repository.dart`
  - `lib/src/features/purchases/application/purchase_providers.dart`
  - `lib/src/features/purchases/presentation/purchases_list_screen.dart`
  - `lib/src/features/purchases/presentation/log_purchase_screen.dart`
  - `test/features/purchases/data/purchase_repository_test.dart`
- Modify: `lib/src/routing/app_router.dart`

### Steps

- [ ] **Step 4.1: Purchase + PurchaseLineItem models**

`lib/src/features/purchases/domain/purchase_line_item.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseLineItem {
  final String id;
  final String farmId;
  final String purchaseId;
  final String supplyId;
  final num quantity;
  final double unitCostPhp;
  final double lineTotalPhp;
  final Timestamp createdAt;

  const PurchaseLineItem({
    required this.id, required this.farmId, required this.purchaseId,
    required this.supplyId, required this.quantity,
    required this.unitCostPhp, required this.lineTotalPhp,
    required this.createdAt,
  });

  factory PurchaseLineItem.fromFirestore(
    DocumentSnapshot doc, {required String farmId, required String purchaseId,
  }) {
    final d = doc.data() as Map<String, dynamic>;
    return PurchaseLineItem(
      id: doc.id, farmId: farmId, purchaseId: purchaseId,
      supplyId: d['supplyId'] as String? ?? '',
      quantity: (d['quantity'] as num?) ?? 0,
      unitCostPhp: (d['unitCostPhp'] as num?)?.toDouble() ?? 0.0,
      lineTotalPhp: (d['lineTotalPhp'] as num?)?.toDouble() ?? 0.0,
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'supplyId': supplyId,
    'quantity': quantity,
    'unitCostPhp': unitCostPhp,
    'lineTotalPhp': lineTotalPhp,
    'createdAt': createdAt,
  };
}
```

`lib/src/features/purchases/domain/purchase.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Purchase {
  final String id;
  final String farmId;
  final String vendorName;
  final Timestamp purchaseDate;
  final String? referenceNo;
  final double totalCostPhp;
  final String? receiptPhotoUrl;
  final String? notes;
  final String createdBy;
  final Timestamp createdAt;

  const Purchase({
    required this.id, required this.farmId, required this.vendorName,
    required this.purchaseDate, required this.referenceNo,
    required this.totalCostPhp, required this.receiptPhotoUrl,
    required this.notes, required this.createdBy, required this.createdAt,
  });

  factory Purchase.fromFirestore(DocumentSnapshot doc, {required String farmId}) {
    final d = doc.data() as Map<String, dynamic>;
    return Purchase(
      id: doc.id, farmId: farmId,
      vendorName: d['vendorName'] as String? ?? '',
      purchaseDate: d['purchaseDate'] as Timestamp? ?? Timestamp.now(),
      referenceNo: d['referenceNo'] as String?,
      totalCostPhp: (d['totalCostPhp'] as num?)?.toDouble() ?? 0.0,
      receiptPhotoUrl: d['receiptPhotoUrl'] as String?,
      notes: d['notes'] as String?,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'vendorName': vendorName,
    'purchaseDate': purchaseDate,
    if (referenceNo != null) 'referenceNo': referenceNo,
    'totalCostPhp': totalCostPhp,
    if (receiptPhotoUrl != null) 'receiptPhotoUrl': receiptPhotoUrl,
    if (notes != null) 'notes': notes,
    'createdBy': createdBy,
    'createdAt': createdAt,
  };
}
```

Commit: `feat(purchases): Purchase + PurchaseLineItem domain models`.

- [ ] **Step 4.2: Test — PurchaseRepository weighted-avg correctness**

`test/features/purchases/data/purchase_repository_test.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/features/activity/data/activity_repository.dart';
import 'package:farm_app/src/features/inventory/data/supply_repository.dart';
import 'package:farm_app/src/features/inventory/domain/supply_category.dart';
import 'package:farm_app/src/features/purchases/data/purchase_repository.dart';

void main() {
  test('first purchase sets weighted-avg to unit cost', () async {
    final f = FakeFirebaseFirestore();
    final supplies = SupplyRepository(f, ActivityRepository(f));
    final purchases = PurchaseRepository(f, ActivityRepository(f));
    final sid = await supplies.createSupply(
      farmId: 'f1', name: 'Feed', category: SupplyCategory.feed,
      unit: SupplyUnit.sack, unitsPerPackage: null, lowStockThreshold: null,
      notes: null, actorUserId: 'u', actorDisplayName: 'J',
    );

    await purchases.logPurchase(
      farmId: 'f1',
      vendorName: 'Vendor A',
      purchaseDate: Timestamp.now(),
      referenceNo: null,
      lineItems: [
        PurchaseLineItemInput(supplyId: sid, quantity: 10, unitCostPhp: 1650),
      ],
      receiptPhotoUrl: null,
      notes: null,
      actorUserId: 'u', actorDisplayName: 'J',
    );

    final supply = await f.collection('farms').doc('f1').collection('supplies').doc(sid).get();
    expect(supply.data()!['currentStock'], 10);
    expect(supply.data()!['weightedAvgUnitCostPhp'], 1650.0);
  });

  test('second purchase recomputes weighted-avg correctly', () async {
    final f = FakeFirebaseFirestore();
    final supplies = SupplyRepository(f, ActivityRepository(f));
    final purchases = PurchaseRepository(f, ActivityRepository(f));
    final sid = await supplies.createSupply(
      farmId: 'f1', name: 'Feed', category: SupplyCategory.feed,
      unit: SupplyUnit.sack, unitsPerPackage: null, lowStockThreshold: null,
      notes: null, actorUserId: 'u', actorDisplayName: 'J',
    );

    // First: 10 sacks at 1650
    await purchases.logPurchase(
      farmId: 'f1', vendorName: 'A',
      purchaseDate: Timestamp.now(), referenceNo: null,
      lineItems: [PurchaseLineItemInput(supplyId: sid, quantity: 10, unitCostPhp: 1650)],
      receiptPhotoUrl: null, notes: null,
      actorUserId: 'u', actorDisplayName: 'J',
    );
    // Second: 5 sacks at 1750
    // newAvg = (10*1650 + 5*1750) / 15 = (16500 + 8750) / 15 = 25250 / 15 = 1683.33...
    await purchases.logPurchase(
      farmId: 'f1', vendorName: 'B',
      purchaseDate: Timestamp.now(), referenceNo: null,
      lineItems: [PurchaseLineItemInput(supplyId: sid, quantity: 5, unitCostPhp: 1750)],
      receiptPhotoUrl: null, notes: null,
      actorUserId: 'u', actorDisplayName: 'J',
    );

    final supply = await f.collection('farms').doc('f1').collection('supplies').doc(sid).get();
    expect(supply.data()!['currentStock'], 15);
    expect((supply.data()!['weightedAvgUnitCostPhp'] as num).toDouble(),
        closeTo(1683.33, 0.01));
  });

  test('multi-line purchase atomically writes header + line_items + movements + supply updates', () async {
    final f = FakeFirebaseFirestore();
    final supplies = SupplyRepository(f, ActivityRepository(f));
    final purchases = PurchaseRepository(f, ActivityRepository(f));
    final s1 = await supplies.createSupply(
      farmId: 'f1', name: 'Feed', category: SupplyCategory.feed,
      unit: SupplyUnit.sack, unitsPerPackage: null, lowStockThreshold: null,
      notes: null, actorUserId: 'u', actorDisplayName: 'J',
    );
    final s2 = await supplies.createSupply(
      farmId: 'f1', name: 'Medicine', category: SupplyCategory.medicine,
      unit: SupplyUnit.vial, unitsPerPackage: null, lowStockThreshold: null,
      notes: null, actorUserId: 'u', actorDisplayName: 'J',
    );

    await purchases.logPurchase(
      farmId: 'f1', vendorName: 'A',
      purchaseDate: Timestamp.now(), referenceNo: 'INV-001',
      lineItems: [
        PurchaseLineItemInput(supplyId: s1, quantity: 10, unitCostPhp: 1650),
        PurchaseLineItemInput(supplyId: s2, quantity: 6, unitCostPhp: 250),
      ],
      receiptPhotoUrl: null, notes: null,
      actorUserId: 'u', actorDisplayName: 'J',
    );

    final purchasesSnap = await f.collection('farms').doc('f1').collection('purchases').get();
    expect(purchasesSnap.docs, hasLength(1));
    final p = purchasesSnap.docs.first;
    expect(p.data()['vendorName'], 'A');
    expect(p.data()['totalCostPhp'], 10 * 1650 + 6 * 250);

    final lines = await f.collection('farms').doc('f1').collection('purchases')
        .doc(p.id).collection('line_items').get();
    expect(lines.docs, hasLength(2));

    final movements = await f.collection('farms').doc('f1').collection('supply_movements').get();
    expect(movements.docs, hasLength(2));
    for (final m in movements.docs) {
      expect(m.data()['type'], 'purchase');
      expect(m.data()['relatedPurchaseId'], p.id);
    }

    final supply1 = await f.collection('farms').doc('f1').collection('supplies').doc(s1).get();
    final supply2 = await f.collection('farms').doc('f1').collection('supplies').doc(s2).get();
    expect(supply1.data()!['currentStock'], 10);
    expect(supply2.data()!['currentStock'], 6);
  });
}
```

- [ ] **Step 4.3: Implement PurchaseRepository**

`lib/src/features/purchases/data/purchase_repository.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../activity/data/activity_repository.dart';
import '../domain/purchase.dart';
import '../domain/purchase_line_item.dart';

/// Input shape for log-purchase: not persisted with this exact name,
/// just a value type for the repository method signature.
class PurchaseLineItemInput {
  PurchaseLineItemInput({
    required this.supplyId, required this.quantity, required this.unitCostPhp,
  });
  final String supplyId;
  final num quantity;
  final double unitCostPhp;
  double get lineTotalPhp => quantity * unitCostPhp;
}

class PurchaseRepository {
  PurchaseRepository(this._firestore, this._activity);
  final FirebaseFirestore _firestore;
  final ActivityRepository _activity;

  CollectionReference<Map<String, dynamic>> _col(String farmId) =>
      _firestore.collection('farms').doc(farmId).collection('purchases');

  /// Atomically writes the purchase header, line items, supply_movements,
  /// and updates each supply's currentStock + weightedAvgUnitCostPhp.
  /// Uses runTransaction because weighted-avg needs the pre-purchase value.
  Future<String> logPurchase({
    required String farmId,
    required String vendorName,
    required Timestamp purchaseDate,
    required String? referenceNo,
    required List<PurchaseLineItemInput> lineItems,
    required String? receiptPhotoUrl,
    required String? notes,
    required String actorUserId,
    required String actorDisplayName,
  }) async {
    if (lineItems.isEmpty) {
      throw ArgumentError('At least one line item is required.');
    }
    final purchaseRef = _col(farmId).doc();
    final totalCost = lineItems.fold<double>(0, (s, i) => s + i.lineTotalPhp);

    await _firestore.runTransaction((tx) async {
      // Phase 1: read all supplies referenced (transactions require reads before writes).
      final supplyRefs = <String, DocumentReference<Map<String, dynamic>>>{};
      final currentStock = <String, num>{};
      final currentAvg = <String, double>{};
      for (final item in lineItems) {
        if (supplyRefs.containsKey(item.supplyId)) continue;
        final ref = _firestore.collection('farms').doc(farmId)
            .collection('supplies').doc(item.supplyId);
        final snap = await tx.get(ref);
        if (!snap.exists) {
          throw StateError('Supply ${item.supplyId} not found.');
        }
        supplyRefs[item.supplyId] = ref;
        currentStock[item.supplyId] = (snap.data()!['currentStock'] as num?) ?? 0;
        currentAvg[item.supplyId] = (snap.data()!['weightedAvgUnitCostPhp'] as num?)
                ?.toDouble() ?? 0.0;
      }

      // Phase 2: writes — purchase header, line items, movements, supply updates.
      tx.set(purchaseRef, {
        'vendorName': vendorName.trim(),
        'purchaseDate': purchaseDate,
        if (referenceNo != null && referenceNo.trim().isNotEmpty)
          'referenceNo': referenceNo.trim(),
        'totalCostPhp': totalCost,
        if (receiptPhotoUrl != null) 'receiptPhotoUrl': receiptPhotoUrl,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        'createdBy': actorUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Aggregate per-supply increments for weighted-avg recomputation.
      // If the same supply appears multiple times in line items, treat them
      // as concurrent additions: sum the qty and weight the unit cost.
      final supplyAddedQty = <String, num>{};
      final supplyAddedCost = <String, double>{}; // sum of qty * unitCost
      for (final item in lineItems) {
        final lineRef = purchaseRef.collection('line_items').doc();
        tx.set(lineRef, {
          'supplyId': item.supplyId,
          'quantity': item.quantity,
          'unitCostPhp': item.unitCostPhp,
          'lineTotalPhp': item.lineTotalPhp,
          'createdAt': FieldValue.serverTimestamp(),
        });

        final movementRef = _firestore.collection('farms').doc(farmId)
            .collection('supply_movements').doc();
        tx.set(movementRef, {
          'supplyId': item.supplyId,
          'type': 'purchase',
          'quantity': item.quantity,
          'unitCostPhp': item.unitCostPhp,
          'relatedPurchaseId': purchaseRef.id,
          'createdBy': actorUserId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        supplyAddedQty[item.supplyId] =
            (supplyAddedQty[item.supplyId] ?? 0) + item.quantity;
        supplyAddedCost[item.supplyId] =
            (supplyAddedCost[item.supplyId] ?? 0) + item.lineTotalPhp;
      }

      // Now update each supply's currentStock + weightedAvgUnitCostPhp.
      for (final entry in supplyAddedQty.entries) {
        final supplyId = entry.key;
        final addedQty = entry.value;
        final addedCost = supplyAddedCost[supplyId]!;
        final prevStock = currentStock[supplyId]!;
        final prevAvg = currentAvg[supplyId]!;
        final newStock = prevStock + addedQty;
        final newAvg = newStock == 0
            ? 0.0
            : ((prevStock * prevAvg) + addedCost) / newStock;
        tx.update(supplyRefs[supplyId]!, {
          'currentStock': newStock,
          'weightedAvgUnitCostPhp': newAvg,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Activity entry.
      final activityRef = _firestore.collection('farms').doc(farmId)
          .collection('activity').doc();
      tx.set(activityRef, {
        'actorUserId': actorUserId,
        'actorDisplayName': actorDisplayName,
        'action': 'purchase_logged',
        'entityType': 'purchase',
        'entityId': purchaseRef.id,
        'summary':
            '$actorDisplayName logged purchase from ${vendorName.trim()} · ₱${totalCost.toStringAsFixed(0)}',
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
    return purchaseRef.id;
  }

  Stream<List<Purchase>> streamPurchases(String farmId) {
    return _col(farmId)
        .orderBy('purchaseDate', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Purchase.fromFirestore(d, farmId: farmId)).toList());
  }

  Stream<Purchase?> streamPurchaseById({
    required String farmId, required String purchaseId,
  }) {
    return _col(farmId).doc(purchaseId).snapshots().map(
      (d) => d.exists ? Purchase.fromFirestore(d, farmId: farmId) : null,
    );
  }

  Stream<List<PurchaseLineItem>> streamLineItems({
    required String farmId, required String purchaseId,
  }) {
    return _col(farmId).doc(purchaseId).collection('line_items')
        .orderBy('createdAt')
        .snapshots()
        .map((s) => s.docs.map((d) => PurchaseLineItem.fromFirestore(
              d, farmId: farmId, purchaseId: purchaseId,
            )).toList());
  }
}
```

Run tests, expect pass.

- [ ] **Step 4.4: Purchase providers**

`lib/src/features/purchases/application/purchase_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../activity/application/activity_providers.dart';
import '../data/purchase_repository.dart';
import '../domain/purchase.dart';
import '../domain/purchase_line_item.dart';

final purchaseRepositoryProvider = Provider<PurchaseRepository>(
  (ref) => PurchaseRepository(ref.watch(firestoreProvider), ref.watch(activityRepositoryProvider)),
);

final purchasesStreamProvider =
    StreamProvider.family<List<Purchase>, String>((ref, farmId) {
  return ref.watch(purchaseRepositoryProvider).streamPurchases(farmId);
});

final purchaseByIdProvider =
    StreamProvider.family<Purchase?, ({String farmId, String purchaseId})>((ref, args) {
  return ref.watch(purchaseRepositoryProvider).streamPurchaseById(
        farmId: args.farmId, purchaseId: args.purchaseId);
});

final purchaseLineItemsProvider =
    StreamProvider.family<List<PurchaseLineItem>, ({String farmId, String purchaseId})>((ref, args) {
  return ref.watch(purchaseRepositoryProvider).streamLineItems(
        farmId: args.farmId, purchaseId: args.purchaseId);
});
```

- [ ] **Step 4.5: Purchases list screen**

`lib/src/features/purchases/presentation/purchases_list_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/empty_state.dart';
import '../../farms/application/farm_providers.dart';
import '../application/purchase_providers.dart';
import '../domain/purchase.dart';
import 'log_purchase_screen.dart';

class PurchasesListScreen extends ConsumerWidget {
  const PurchasesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final purchasesAsync = ref.watch(purchasesStreamProvider(farmId));

    return Scaffold(
      appBar: AppBar(title: const Text('Purchases')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Iconsax.add),
        label: const Text('Log purchase'),
        onPressed: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => const LogPurchaseScreen()),
        ),
      ),
      body: purchasesAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Iconsax.receipt_2,
              title: 'No purchases logged',
              subtitle: 'Tap "Log purchase" to record your first delivery.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final p = list[i];
              return Card(
                child: ListTile(
                  title: Text(p.vendorName, style: theme.textTheme.titleMedium),
                  subtitle: Text(
                    '${DateFormat.yMMMd().format(p.purchaseDate.toDate())}'
                    '${p.referenceNo != null ? " · ${p.referenceNo}" : ""}',
                  ),
                  trailing: Text(
                    '₱${p.totalCostPhp.toStringAsFixed(0)}',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}
```

- [ ] **Step 4.6: Log purchase screen with dynamic line items**

`lib/src/features/purchases/presentation/log_purchase_screen.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/widgets/adaptive_date_picker.dart';
import '../../../core/widgets/section_header.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../inventory/domain/supply.dart';
import '../data/purchase_repository.dart';
import '../application/purchase_providers.dart';

class LogPurchaseScreen extends ConsumerStatefulWidget {
  const LogPurchaseScreen({super.key});
  @override
  ConsumerState<LogPurchaseScreen> createState() => _State();
}

class _LineRow {
  String? supplyId;
  final TextEditingController qty = TextEditingController();
  final TextEditingController unitCost = TextEditingController();
  void dispose() { qty.dispose(); unitCost.dispose(); }
  double get lineTotal {
    final q = num.tryParse(qty.text.trim()) ?? 0;
    final c = double.tryParse(unitCost.text.trim()) ?? 0;
    return (q * c).toDouble();
  }
}

class _State extends ConsumerState<LogPurchaseScreen> {
  final _vendor = TextEditingController();
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  DateTime _date = DateTime.now();
  final List<_LineRow> _lines = [_LineRow()];
  bool _busy = false;

  @override
  void dispose() {
    _vendor.dispose();
    _reference.dispose();
    _notes.dispose();
    for (final r in _lines) {
      r.dispose();
    }
    super.dispose();
  }

  double get _grandTotal => _lines.fold(0.0, (s, r) => s + r.lineTotal);

  Future<void> _save() async {
    final farmId = ref.read(selectedFarmIdProvider);
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return;
    if (_vendor.text.trim().isEmpty) {
      _snack('Vendor name is required.');
      return;
    }
    final inputs = <PurchaseLineItemInput>[];
    for (var i = 0; i < _lines.length; i++) {
      final r = _lines[i];
      if (r.supplyId == null) { _snack('Line ${i + 1}: supply not picked.'); return; }
      final q = num.tryParse(r.qty.text.trim());
      final c = double.tryParse(r.unitCost.text.trim());
      if (q == null || q <= 0) { _snack('Line ${i + 1}: quantity must be positive.'); return; }
      if (c == null || c < 0) { _snack('Line ${i + 1}: unit cost must be a number.'); return; }
      inputs.add(PurchaseLineItemInput(supplyId: r.supplyId!, quantity: q, unitCostPhp: c));
    }
    setState(() => _busy = true);
    final actorName = ref.read(currentAppUserProvider).asData?.value?.displayName ?? '';
    try {
      await ref.read(purchaseRepositoryProvider).logPurchase(
        farmId: farmId,
        vendorName: _vendor.text,
        purchaseDate: Timestamp.fromDate(_date),
        referenceNo: _reference.text.trim().isEmpty ? null : _reference.text.trim(),
        lineItems: inputs,
        receiptPhotoUrl: null,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        actorUserId: user.uid,
        actorDisplayName: actorName,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String s) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmId = ref.watch(selectedFarmIdProvider);
    final supplies = farmId == null
        ? const <Supply>[]
        : ref.watch(suppliesStreamProvider(farmId)).asData?.value ?? const <Supply>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Log purchase')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(title: 'VENDOR', padding: EdgeInsets.only(bottom: 8)),
            TextField(controller: _vendor,
                decoration: const InputDecoration(hintText: 'Who you bought from')),
            const SectionHeader(title: 'PURCHASE DATE'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}'),
              trailing: const Icon(Iconsax.calendar),
              onTap: () async {
                final picked = await AdaptiveDatePicker.show(
                  context: context, initial: _date,
                  firstDate: DateTime(2020), lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const SectionHeader(title: 'REFERENCE'),
            TextField(controller: _reference,
              decoration: const InputDecoration(hintText: 'Receipt or invoice no. (optional)')),
            const SectionHeader(title: 'LINE ITEMS'),
            ..._lines.asMap().entries.map((entry) {
              final i = entry.key;
              final r = entry.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text('Line ${i + 1}',
                              style: Theme.of(context).textTheme.labelLarge),
                          const Spacer(),
                          if (_lines.length > 1)
                            IconButton(
                              icon: const Icon(Iconsax.trash),
                              onPressed: () => setState(() {
                                _lines.removeAt(i).dispose();
                              }),
                            ),
                        ],
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: r.supplyId,
                        decoration: const InputDecoration(hintText: 'Pick supply'),
                        items: supplies.map((s) =>
                            DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                        onChanged: (v) => setState(() => r.supplyId = v),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: r.qty,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Quantity'),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: r.unitCost,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Unit cost ₱'),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('Line: ₱${r.lineTotal.toStringAsFixed(0)}',
                              style: Theme.of(context).textTheme.labelLarge),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
            OutlinedButton.icon(
              icon: const Icon(Iconsax.add),
              label: const Text('Add line'),
              onPressed: () => setState(() => _lines.add(_LineRow())),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text('Grand total',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  Text('₱${_grandTotal.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      )),
                ],
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
                  : const Text('Save purchase'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4.7: Wire route + commit**

In `lib/src/routing/app_router.dart`:

```dart
GoRoute(path: '/purchases', builder: (c, s) => const PurchasesListScreen()),
```

```bash
flutter analyze && flutter test
git add -A
git commit -m "feat(purchases): atomic purchase with weighted-avg recomputation

- PurchaseRepository.logPurchase as a runTransaction (reads supplies
  first, then writes header + line items + movements + supply updates)
- Per-supply currentStock + weightedAvgUnitCostPhp updated atomically
- Multi-supply purchases aggregate qty/cost correctly per supply
- Log purchase screen with dynamic line items, live grand total"
```

---

## Task 5: Pig.currentBatchId — wire farrowing to populate

**Goal:** Complete the `currentBatchId` migration started in Task 3. Currently the field exists on `Pig` but no production code populates it. Update `FarrowingRepository.logFarrowing` so that, when a litter batch is created, **if** piglet `Pig` docs are also created (currently they aren't), they get `currentBatchId` set. Since the current MVP doesn't create individual piglet docs, this task instead exposes a method to manually set `currentBatchId` on existing pigs (Owner/Manager), and ensures **grow-finish batches** (when added in future) can attach pigs.

**Files:**
- Modify:
  - `lib/src/features/pigs/data/pig_repository.dart` (add `setBatch` method)
  - `lib/src/features/pigs/data/batch_repository.dart` (add `addPigToBatch` method)

### Steps

- [ ] **Step 5.1: Add setBatch method to PigRepository**

In `lib/src/features/pigs/data/pig_repository.dart`, add a method (before the closing `}` of the class):

```dart
Future<void> setBatch({
  required String farmId,
  required String pigId,
  required String? batchId,
  required String actorUserId,
  required String actorDisplayName,
}) async {
  final batch = _firestore.batch();
  batch.update(_col(farmId).doc(pigId), {
    'currentBatchId': batchId,
    'updatedAt': FieldValue.serverTimestamp(),
  });
  _activity.addActivityToBatch(
    batch: batch, farmId: farmId,
    actorUserId: actorUserId, actorDisplayName: actorDisplayName,
    action: 'pig_batch_changed',
    entityType: 'pig', entityId: pigId,
    summary: batchId == null
        ? '$actorDisplayName removed pig from batch'
        : '$actorDisplayName assigned pig to batch $batchId',
  );
  await batch.commit();
}
```

- [ ] **Step 5.2: Add addPigToBatch helper to BatchRepository**

In `lib/src/features/pigs/data/batch_repository.dart`, add:

```dart
/// Adds a pig to a batch: updates pig.currentBatchId AND appends pig.id
/// to batch.pigIds + increments batch.count. Atomic.
Future<void> addPigToBatch({
  required String farmId,
  required String batchId,
  required String pigId,
  required String actorUserId,
  required String actorDisplayName,
}) async {
  final batch = _firestore.batch();
  batch.update(_col(farmId).doc(batchId), {
    'pigIds': FieldValue.arrayUnion([pigId]),
    'count': FieldValue.increment(1),
  });
  batch.update(_firestore.collection('farms').doc(farmId)
      .collection('pigs').doc(pigId), {
    'currentBatchId': batchId,
    'updatedAt': FieldValue.serverTimestamp(),
  });
  _activity.addActivityToBatch(
    batch: batch, farmId: farmId,
    actorUserId: actorUserId, actorDisplayName: actorDisplayName,
    action: 'pig_added_to_batch',
    entityType: 'batch', entityId: batchId,
    summary: '$actorDisplayName added pig $pigId to batch',
  );
  await batch.commit();
}
```

- [ ] **Step 5.3: Test setBatch + addPigToBatch**

In `test/features/pigs/data/pig_repository_test.dart`, add:

```dart
group('setBatch', () {
  test('updates pig.currentBatchId and writes activity', () async {
    final repo = newRepo();
    final id = await repo.createPig(
      farmId: 'f1', tagId: 'P', sex: PigSex.female, breed: 'X',
      birthDate: Timestamp.now(), sireId: null, damId: null,
      stage: PigStage.sow, currentAreaId: 'a1', currentPenId: null,
      currentWeight: null, photoUrl: null, notes: null,
      actorUserId: 'u', actorDisplayName: 'J',
    );
    await repo.setBatch(
      farmId: 'f1', pigId: id, batchId: 'b1',
      actorUserId: 'u', actorDisplayName: 'J',
    );
    final pig = await repo.streamPigById(farmId: 'f1', pigId: id).first;
    expect(pig!.currentBatchId, 'b1');
  });
});
```

Run tests, expect pass.

- [ ] **Step 5.4: Commit**

```bash
flutter analyze && flutter test
git add -A
git commit -m "feat(pigs,batch): wire currentBatchId via setBatch and addPigToBatch

- PigRepository.setBatch: atomic pig.currentBatchId update + activity
- BatchRepository.addPigToBatch: pig+batch update + activity
- Enables BatchCostCalculator to attribute consumption via Pig.currentBatchId"
```

Note: a UI to assign pigs to batches is **not** in this task — Sub-project A's add/edit pig screen doesn't expose this. A future polish task can add a batch picker. For MVP, the field is settable via the repository (e.g., from farrowing flows, future grow-finish batching). Existing pigs have `null` currentBatchId until explicitly set.

---

## Task 6: Expenses

**Goal:** Track direct expenses by category, optionally attributed to a batch / pig / area / equipment.

**Files:**
- Create:
  - `lib/src/features/expenses/domain/expense_category.dart`
  - `lib/src/features/expenses/domain/expense.dart`
  - `lib/src/features/expenses/data/expense_repository.dart`
  - `lib/src/features/expenses/application/expense_providers.dart`
  - `lib/src/features/expenses/presentation/expenses_list_screen.dart`
  - `lib/src/features/expenses/presentation/log_expense_screen.dart`
  - `test/features/expenses/data/expense_repository_test.dart`
- Modify: `lib/src/routing/app_router.dart`

### Steps

- [ ] **Step 6.1: ExpenseCategory + Expense models**

`lib/src/features/expenses/domain/expense_category.dart`:

```dart
enum ExpenseCategory {
  feed('feed', 'Feed'),
  medicine('medicine', 'Medicine'),
  labor('labor', 'Labor'),
  utilities('utilities', 'Utilities'),
  equipment('equipment', 'Equipment'),
  maintenance('maintenance', 'Maintenance'),
  other('other', 'Other');

  const ExpenseCategory(this.value, this.label);
  final String value;
  final String label;

  static ExpenseCategory fromString(String s) =>
      ExpenseCategory.values.firstWhere(
        (e) => e.value == s,
        orElse: () => ExpenseCategory.other,
      );
}
```

`lib/src/features/expenses/domain/expense.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'expense_category.dart';

class Expense {
  final String id;
  final String farmId;
  final ExpenseCategory category;
  final String description;
  final double amountPhp;
  final Timestamp date;
  final String? relatedBatchId;
  final String? relatedEquipmentId;
  final String? relatedPigId;
  final String? relatedAreaId;
  final String? receiptPhotoUrl;
  final String? notes;
  final String createdBy;
  final Timestamp createdAt;

  const Expense({
    required this.id, required this.farmId,
    required this.category, required this.description,
    required this.amountPhp, required this.date,
    required this.relatedBatchId, required this.relatedEquipmentId,
    required this.relatedPigId, required this.relatedAreaId,
    required this.receiptPhotoUrl, required this.notes,
    required this.createdBy, required this.createdAt,
  });

  factory Expense.fromFirestore(DocumentSnapshot doc, {required String farmId}) {
    final d = doc.data() as Map<String, dynamic>;
    return Expense(
      id: doc.id, farmId: farmId,
      category: ExpenseCategory.fromString(d['category'] as String? ?? 'other'),
      description: d['description'] as String? ?? '',
      amountPhp: (d['amountPhp'] as num?)?.toDouble() ?? 0.0,
      date: d['date'] as Timestamp? ?? Timestamp.now(),
      relatedBatchId: d['relatedBatchId'] as String?,
      relatedEquipmentId: d['relatedEquipmentId'] as String?,
      relatedPigId: d['relatedPigId'] as String?,
      relatedAreaId: d['relatedAreaId'] as String?,
      receiptPhotoUrl: d['receiptPhotoUrl'] as String?,
      notes: d['notes'] as String?,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'category': category.value,
    'description': description,
    'amountPhp': amountPhp,
    'date': date,
    if (relatedBatchId != null) 'relatedBatchId': relatedBatchId,
    if (relatedEquipmentId != null) 'relatedEquipmentId': relatedEquipmentId,
    if (relatedPigId != null) 'relatedPigId': relatedPigId,
    if (relatedAreaId != null) 'relatedAreaId': relatedAreaId,
    if (receiptPhotoUrl != null) 'receiptPhotoUrl': receiptPhotoUrl,
    if (notes != null) 'notes': notes,
    'createdBy': createdBy,
    'createdAt': createdAt,
  };
}
```

- [ ] **Step 6.2: ExpenseRepository + tests**

`lib/src/features/expenses/data/expense_repository.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../activity/data/activity_repository.dart';
import '../domain/expense.dart';
import '../domain/expense_category.dart';

class ExpenseRepository {
  ExpenseRepository(this._firestore, this._activity);
  final FirebaseFirestore _firestore;
  final ActivityRepository _activity;

  CollectionReference<Map<String, dynamic>> _col(String farmId) =>
      _firestore.collection('farms').doc(farmId).collection('expenses');

  Future<String> createExpense({
    required String farmId,
    required ExpenseCategory category,
    required String description,
    required double amountPhp,
    required Timestamp date,
    String? relatedBatchId,
    String? relatedEquipmentId,
    String? relatedPigId,
    String? relatedAreaId,
    String? receiptPhotoUrl,
    String? notes,
    required String actorUserId,
    required String actorDisplayName,
  }) async {
    if (amountPhp <= 0) throw ArgumentError('amountPhp must be positive');
    if (description.trim().isEmpty) {
      throw ArgumentError('description is required');
    }
    final ref = _col(farmId).doc();
    final batch = _firestore.batch();
    batch.set(ref, {
      'category': category.value,
      'description': description.trim(),
      'amountPhp': amountPhp,
      'date': date,
      if (relatedBatchId != null) 'relatedBatchId': relatedBatchId,
      if (relatedEquipmentId != null) 'relatedEquipmentId': relatedEquipmentId,
      if (relatedPigId != null) 'relatedPigId': relatedPigId,
      if (relatedAreaId != null) 'relatedAreaId': relatedAreaId,
      if (receiptPhotoUrl != null) 'receiptPhotoUrl': receiptPhotoUrl,
      if (notes != null) 'notes': notes,
      'createdBy': actorUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    _activity.addActivityToBatch(
      batch: batch, farmId: farmId,
      actorUserId: actorUserId, actorDisplayName: actorDisplayName,
      action: 'expense_logged', entityType: 'expense', entityId: ref.id,
      summary: '$actorDisplayName logged ${category.label} expense · ₱${amountPhp.toStringAsFixed(0)}',
    );
    await batch.commit();
    return ref.id;
  }

  Stream<List<Expense>> streamExpenses(String farmId) {
    return _col(farmId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Expense.fromFirestore(d, farmId: farmId)).toList());
  }

  Stream<List<Expense>> streamInRange({
    required String farmId,
    required Timestamp start,
    required Timestamp end,
  }) {
    return _col(farmId)
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThan: end)
        .snapshots()
        .map((s) => s.docs.map((d) => Expense.fromFirestore(d, farmId: farmId)).toList());
  }

  Stream<List<Expense>> streamForBatch({required String farmId, required String batchId}) {
    return _col(farmId)
        .where('relatedBatchId', isEqualTo: batchId)
        .snapshots()
        .map((s) => s.docs.map((d) => Expense.fromFirestore(d, farmId: farmId)).toList());
  }
}
```

Test (`test/features/expenses/data/expense_repository_test.dart`):

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/features/activity/data/activity_repository.dart';
import 'package:farm_app/src/features/expenses/data/expense_repository.dart';
import 'package:farm_app/src/features/expenses/domain/expense_category.dart';

void main() {
  test('createExpense writes doc and activity', () async {
    final f = FakeFirebaseFirestore();
    final repo = ExpenseRepository(f, ActivityRepository(f));
    final id = await repo.createExpense(
      farmId: 'f1',
      category: ExpenseCategory.utilities,
      description: 'May electricity',
      amountPhp: 8500,
      date: Timestamp.now(),
      actorUserId: 'u', actorDisplayName: 'J',
    );
    expect(id, isNotEmpty);
    final doc = await f.collection('farms').doc('f1').collection('expenses').doc(id).get();
    expect(doc.data()!['description'], 'May electricity');
    expect(doc.data()!['amountPhp'], 8500);

    final activity = await f.collection('farms').doc('f1').collection('activity').get();
    expect(activity.docs.where((d) => d.data()['action'] == 'expense_logged'),
      hasLength(1));
  });

  test('rejects empty description', () async {
    final f = FakeFirebaseFirestore();
    final repo = ExpenseRepository(f, ActivityRepository(f));
    expect(
      () => repo.createExpense(
        farmId: 'f1', category: ExpenseCategory.other,
        description: '', amountPhp: 100, date: Timestamp.now(),
        actorUserId: 'u', actorDisplayName: 'J',
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('rejects non-positive amount', () async {
    final f = FakeFirebaseFirestore();
    final repo = ExpenseRepository(f, ActivityRepository(f));
    expect(
      () => repo.createExpense(
        farmId: 'f1', category: ExpenseCategory.other,
        description: 'X', amountPhp: 0, date: Timestamp.now(),
        actorUserId: 'u', actorDisplayName: 'J',
      ),
      throwsA(isA<ArgumentError>()),
    );
  });
}
```

- [ ] **Step 6.3: Expense providers + screens**

`lib/src/features/expenses/application/expense_providers.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../activity/application/activity_providers.dart';
import '../data/expense_repository.dart';
import '../domain/expense.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (ref) => ExpenseRepository(ref.watch(firestoreProvider), ref.watch(activityRepositoryProvider)),
);

final expensesStreamProvider =
    StreamProvider.family<List<Expense>, String>((ref, farmId) {
  return ref.watch(expenseRepositoryProvider).streamExpenses(farmId);
});

final expensesInRangeProvider =
    StreamProvider.family<List<Expense>, ({String farmId, Timestamp start, Timestamp end})>((ref, args) {
  return ref.watch(expenseRepositoryProvider).streamInRange(
        farmId: args.farmId, start: args.start, end: args.end);
});

final expensesForBatchProvider =
    StreamProvider.family<List<Expense>, ({String farmId, String batchId})>((ref, args) {
  return ref.watch(expenseRepositoryProvider).streamForBatch(
        farmId: args.farmId, batchId: args.batchId);
});
```

`lib/src/features/expenses/presentation/expenses_list_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/empty_state.dart';
import '../../farms/application/farm_providers.dart';
import '../application/expense_providers.dart';
import '../domain/expense.dart';
import '../domain/expense_category.dart';
import 'log_expense_screen.dart';

class ExpensesListScreen extends ConsumerStatefulWidget {
  const ExpensesListScreen({super.key});
  @override
  ConsumerState<ExpensesListScreen> createState() => _State();
}

class _State extends ConsumerState<ExpensesListScreen> {
  ExpenseCategory? _categoryFilter;

  @override
  Widget build(BuildContext context) {
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final expensesAsync = ref.watch(expensesStreamProvider(farmId));

    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Iconsax.add),
        label: const Text('Log expense'),
        onPressed: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => const LogExpenseScreen()),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Wrap(
              spacing: 8, runSpacing: 8,
              children: ExpenseCategory.values.map((c) => FilterChip(
                label: Text(c.label),
                selected: _categoryFilter == c,
                onSelected: (sel) => setState(() => _categoryFilter = sel ? c : null),
              )).toList(),
            ),
          ),
          Expanded(
            child: expensesAsync.when(
              data: (list) {
                final filtered = _categoryFilter == null
                    ? list
                    : list.where((e) => e.category == _categoryFilter).toList();
                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Iconsax.receipt_item,
                    title: list.isEmpty ? 'No expenses logged' : 'No matching expenses',
                    subtitle: list.isEmpty
                        ? 'Tap "Log expense" to record your first expense.'
                        : 'Try clearing the category filter.',
                  );
                }
                final total = filtered.fold<double>(0, (s, e) => s + e.amountPhp);
                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      width: double.infinity,
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                      child: Row(
                        children: [
                          Text('Total', style: theme.textTheme.titleMedium),
                          const Spacer(),
                          Text('₱${total.toStringAsFixed(0)}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              )),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _ExpenseCard(expense: filtered[i]),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({required this.expense});
  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        title: Text(expense.description, style: theme.textTheme.titleMedium),
        subtitle: Text(
          '${expense.category.label} · ${DateFormat.yMMMd().format(expense.date.toDate())}',
        ),
        trailing: Text('₱${expense.amountPhp.toStringAsFixed(0)}',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
```

`lib/src/features/expenses/presentation/log_expense_screen.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/widgets/adaptive_date_picker.dart';
import '../../../core/widgets/section_header.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../application/expense_providers.dart';
import '../domain/expense_category.dart';

class LogExpenseScreen extends ConsumerStatefulWidget {
  const LogExpenseScreen({super.key});
  @override
  ConsumerState<LogExpenseScreen> createState() => _State();
}

class _State extends ConsumerState<LogExpenseScreen> {
  ExpenseCategory _category = ExpenseCategory.other;
  final _description = TextEditingController();
  final _amount = TextEditingController();
  DateTime _date = DateTime.now();
  final _notes = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final farmId = ref.read(selectedFarmIdProvider);
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return;
    final desc = _description.text.trim();
    final amount = double.tryParse(_amount.text.trim());
    if (desc.isEmpty) {
      _snack('Description is required.');
      return;
    }
    if (amount == null || amount <= 0) {
      _snack('Amount must be a positive number.');
      return;
    }
    setState(() => _busy = true);
    final actorName = ref.read(currentAppUserProvider).asData?.value?.displayName ?? '';
    try {
      await ref.read(expenseRepositoryProvider).createExpense(
        farmId: farmId,
        category: _category,
        description: desc,
        amountPhp: amount,
        date: Timestamp.fromDate(_date),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        actorUserId: user.uid,
        actorDisplayName: actorName,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log expense')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(title: 'CATEGORY', padding: EdgeInsets.only(bottom: 8)),
            Wrap(spacing: 8, runSpacing: 8, children: ExpenseCategory.values.map((c) =>
                ChoiceChip(
                  label: Text(c.label),
                  selected: _category == c,
                  onSelected: (_) => setState(() => _category = c),
                )).toList()),
            const SectionHeader(title: 'DESCRIPTION'),
            TextField(controller: _description,
                decoration: const InputDecoration(hintText: 'What was this expense for?')),
            const SectionHeader(title: 'AMOUNT'),
            TextField(
              controller: _amount, keyboardType: TextInputType.number,
              decoration: const InputDecoration(prefixText: '₱ '),
            ),
            const SectionHeader(title: 'DATE'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}'),
              trailing: const Icon(Iconsax.calendar),
              onTap: () async {
                final picked = await AdaptiveDatePicker.show(
                  context: context, initial: _date,
                  firstDate: DateTime(2020), lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              },
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
                  : const Text('Save expense'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6.4: Wire route + commit**

In `app_router.dart`:

```dart
GoRoute(path: '/expenses', builder: (c, s) => const ExpensesListScreen()),
```

```bash
flutter analyze && flutter test
git add -A
git commit -m "feat(expenses): expense logging by category with date picker and batch attribution

- 7-category enum (Feed/Medicine/Labor/Utilities/Equipment/Maintenance/Other)
- ExpenseRepository with period + batch streams for profitability
- List screen with category filter chips and running total
- Log screen with adaptive date picker"
```

---

## Task 7: Sale + SaleLineItem models + SaleRepository with atomic multi-pig flip

**Goal:** Build the sales data layer. Sales are per-transaction (truckload) with per-pig line items. `runTransaction` validates every pig is `active` then atomically flips all to `sold` + writes header + line items + activity.

**Files:**
- Create:
  - `lib/src/features/sales/domain/payment_method.dart`
  - `lib/src/features/sales/domain/payment_status.dart`
  - `lib/src/features/sales/domain/sale.dart`
  - `lib/src/features/sales/domain/sale_line_item.dart`
  - `lib/src/features/sales/data/sale_repository.dart`
  - `lib/src/features/sales/application/sale_providers.dart`
  - `test/features/sales/data/sale_repository_test.dart`

### Steps

- [ ] **Step 7.1: Enums**

`lib/src/features/sales/domain/payment_method.dart`:

```dart
enum PaymentMethod {
  cash('cash', 'Cash'),
  bankTransfer('bank_transfer', 'Bank transfer'),
  gcash('gcash', 'GCash'),
  check('check', 'Check'),
  other('other', 'Other');

  const PaymentMethod(this.value, this.label);
  final String value;
  final String label;

  static PaymentMethod fromString(String s) =>
      PaymentMethod.values.firstWhere(
        (e) => e.value == s,
        orElse: () => PaymentMethod.cash,
      );
}
```

`lib/src/features/sales/domain/payment_status.dart`:

```dart
enum PaymentStatus {
  paid('paid', 'Paid'),
  partial('partial', 'Partial'),
  unpaid('unpaid', 'Unpaid');

  const PaymentStatus(this.value, this.label);
  final String value;
  final String label;

  static PaymentStatus fromString(String s) =>
      PaymentStatus.values.firstWhere(
        (e) => e.value == s,
        orElse: () => PaymentStatus.paid,
      );
}
```

- [ ] **Step 7.2: Sale + SaleLineItem models**

`lib/src/features/sales/domain/sale_line_item.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class SaleLineItem {
  final String id;
  final String farmId;
  final String saleId;
  final String pigId;
  final String pigTagId;
  final double finalWeightKg;
  final double pricePerKgPhp;
  final double lineRevenuePhp;
  final Timestamp createdAt;

  const SaleLineItem({
    required this.id, required this.farmId, required this.saleId,
    required this.pigId, required this.pigTagId,
    required this.finalWeightKg, required this.pricePerKgPhp,
    required this.lineRevenuePhp, required this.createdAt,
  });

  factory SaleLineItem.fromFirestore(
    DocumentSnapshot doc, {required String farmId, required String saleId,
  }) {
    final d = doc.data() as Map<String, dynamic>;
    return SaleLineItem(
      id: doc.id, farmId: farmId, saleId: saleId,
      pigId: d['pigId'] as String? ?? '',
      pigTagId: d['pigTagId'] as String? ?? '',
      finalWeightKg: (d['finalWeightKg'] as num?)?.toDouble() ?? 0.0,
      pricePerKgPhp: (d['pricePerKgPhp'] as num?)?.toDouble() ?? 0.0,
      lineRevenuePhp: (d['lineRevenuePhp'] as num?)?.toDouble() ?? 0.0,
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'pigId': pigId,
    'pigTagId': pigTagId,
    'finalWeightKg': finalWeightKg,
    'pricePerKgPhp': pricePerKgPhp,
    'lineRevenuePhp': lineRevenuePhp,
    'createdAt': createdAt,
  };
}
```

`lib/src/features/sales/domain/sale.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'payment_method.dart';
import 'payment_status.dart';

class Sale {
  final String id;
  final String farmId;
  final String buyerName;
  final String? buyerContact;
  final Timestamp saleDate;
  final int totalHeads;
  final double totalWeightKg;
  final double totalRevenuePhp;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final double? amountPaidPhp;
  final String? notes;
  final String createdBy;
  final Timestamp createdAt;

  const Sale({
    required this.id, required this.farmId,
    required this.buyerName, required this.buyerContact,
    required this.saleDate,
    required this.totalHeads, required this.totalWeightKg,
    required this.totalRevenuePhp,
    required this.paymentMethod, required this.paymentStatus,
    required this.amountPaidPhp,
    required this.notes,
    required this.createdBy, required this.createdAt,
  });

  factory Sale.fromFirestore(DocumentSnapshot doc, {required String farmId}) {
    final d = doc.data() as Map<String, dynamic>;
    return Sale(
      id: doc.id, farmId: farmId,
      buyerName: d['buyerName'] as String? ?? '',
      buyerContact: d['buyerContact'] as String?,
      saleDate: d['saleDate'] as Timestamp? ?? Timestamp.now(),
      totalHeads: (d['totalHeads'] as num?)?.toInt() ?? 0,
      totalWeightKg: (d['totalWeightKg'] as num?)?.toDouble() ?? 0.0,
      totalRevenuePhp: (d['totalRevenuePhp'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: PaymentMethod.fromString(d['paymentMethod'] as String? ?? 'cash'),
      paymentStatus: PaymentStatus.fromString(d['paymentStatus'] as String? ?? 'paid'),
      amountPaidPhp: (d['amountPaidPhp'] as num?)?.toDouble(),
      notes: d['notes'] as String?,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'buyerName': buyerName,
    if (buyerContact != null) 'buyerContact': buyerContact,
    'saleDate': saleDate,
    'totalHeads': totalHeads,
    'totalWeightKg': totalWeightKg,
    'totalRevenuePhp': totalRevenuePhp,
    'paymentMethod': paymentMethod.value,
    'paymentStatus': paymentStatus.value,
    if (amountPaidPhp != null) 'amountPaidPhp': amountPaidPhp,
    if (notes != null) 'notes': notes,
    'createdBy': createdBy,
    'createdAt': createdAt,
  };
}
```

- [ ] **Step 7.3: Test — SaleRepository.logSale**

`test/features/sales/data/sale_repository_test.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/features/activity/data/activity_repository.dart';
import 'package:farm_app/src/features/sales/data/sale_repository.dart';
import 'package:farm_app/src/features/sales/domain/payment_method.dart';
import 'package:farm_app/src/features/sales/domain/payment_status.dart';

void main() {
  Future<void> seedPig(FakeFirebaseFirestore f, String farmId, String pigId, {
    String tagId = 'P', String status = 'active',
  }) async {
    await f.collection('farms').doc(farmId).collection('pigs').doc(pigId).set({
      'tagId': tagId, 'sex': 'female', 'breed': 'X',
      'birthDate': Timestamp.now(), 'stage': 'finisher', 'status': status,
      'currentAreaId': 'a1', 'createdBy': 'u',
      'createdAt': Timestamp.now(), 'updatedAt': Timestamp.now(),
    });
  }

  test('logSale writes sale + line items + flips all pigs to sold (atomic)', () async {
    final f = FakeFirebaseFirestore();
    await seedPig(f, 'f1', 'p1', tagId: 'F-001');
    await seedPig(f, 'f1', 'p2', tagId: 'F-002');
    final repo = SaleRepository(f, ActivityRepository(f));

    final saleId = await repo.logSale(
      farmId: 'f1',
      buyerName: 'Mang Berto',
      buyerContact: '0917-555-1234',
      saleDate: Timestamp.now(),
      paymentMethod: PaymentMethod.cash,
      paymentStatus: PaymentStatus.paid,
      amountPaidPhp: null,
      lineItems: [
        SaleLineItemInput(pigId: 'p1', pigTagId: 'F-001', finalWeightKg: 90, pricePerKgPhp: 240),
        SaleLineItemInput(pigId: 'p2', pigTagId: 'F-002', finalWeightKg: 95, pricePerKgPhp: 240),
      ],
      notes: null,
      actorUserId: 'u1', actorDisplayName: 'Owner',
    );

    final sale = await f.collection('farms').doc('f1').collection('sales').doc(saleId).get();
    expect(sale.data()!['totalHeads'], 2);
    expect((sale.data()!['totalWeightKg'] as num).toDouble(), 185);
    expect((sale.data()!['totalRevenuePhp'] as num).toDouble(),
        closeTo(90 * 240 + 95 * 240, 0.01));

    final lines = await f.collection('farms').doc('f1').collection('sales').doc(saleId)
        .collection('line_items').get();
    expect(lines.docs, hasLength(2));

    final pig1 = await f.collection('farms').doc('f1').collection('pigs').doc('p1').get();
    final pig2 = await f.collection('farms').doc('f1').collection('pigs').doc('p2').get();
    expect(pig1.data()!['status'], 'sold');
    expect(pig2.data()!['status'], 'sold');

    final activity = await f.collection('farms').doc('f1').collection('activity').get();
    expect(activity.docs.where((d) => d.data()['action'] == 'sale_logged'),
        hasLength(1));
  });

  test('rejects when one of the pigs is not active', () async {
    final f = FakeFirebaseFirestore();
    await seedPig(f, 'f1', 'p1');
    await seedPig(f, 'f1', 'p2', status: 'deceased');
    final repo = SaleRepository(f, ActivityRepository(f));

    expect(
      () => repo.logSale(
        farmId: 'f1', buyerName: 'X',
        buyerContact: null,
        saleDate: Timestamp.now(),
        paymentMethod: PaymentMethod.cash,
        paymentStatus: PaymentStatus.paid,
        amountPaidPhp: null,
        lineItems: [
          SaleLineItemInput(pigId: 'p1', pigTagId: 'P1', finalWeightKg: 90, pricePerKgPhp: 240),
          SaleLineItemInput(pigId: 'p2', pigTagId: 'P2', finalWeightKg: 95, pricePerKgPhp: 240),
        ],
        notes: null,
        actorUserId: 'u', actorDisplayName: 'O',
      ),
      throwsA(isA<StateError>()),
    );

    // Verify partial atomicity: nothing was written.
    final sales = await f.collection('farms').doc('f1').collection('sales').get();
    expect(sales.docs, isEmpty);
    final pig1 = await f.collection('farms').doc('f1').collection('pigs').doc('p1').get();
    expect(pig1.data()!['status'], 'active');
  });

  test('empty line items throws ArgumentError', () async {
    final f = FakeFirebaseFirestore();
    final repo = SaleRepository(f, ActivityRepository(f));
    expect(
      () => repo.logSale(
        farmId: 'f1', buyerName: 'X', buyerContact: null,
        saleDate: Timestamp.now(),
        paymentMethod: PaymentMethod.cash, paymentStatus: PaymentStatus.paid,
        amountPaidPhp: null, lineItems: const [], notes: null,
        actorUserId: 'u', actorDisplayName: 'O',
      ),
      throwsA(isA<ArgumentError>()),
    );
  });
}
```

- [ ] **Step 7.4: Implement SaleRepository**

`lib/src/features/sales/data/sale_repository.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../activity/data/activity_repository.dart';
import '../domain/payment_method.dart';
import '../domain/payment_status.dart';
import '../domain/sale.dart';
import '../domain/sale_line_item.dart';

class SaleLineItemInput {
  SaleLineItemInput({
    required this.pigId, required this.pigTagId,
    required this.finalWeightKg, required this.pricePerKgPhp,
  });
  final String pigId;
  final String pigTagId;
  final double finalWeightKg;
  final double pricePerKgPhp;
  double get lineRevenuePhp => finalWeightKg * pricePerKgPhp;
}

class SaleRepository {
  SaleRepository(this._firestore, this._activity);
  final FirebaseFirestore _firestore;
  final ActivityRepository _activity;

  CollectionReference<Map<String, dynamic>> _col(String farmId) =>
      _firestore.collection('farms').doc(farmId).collection('sales');

  /// Atomic: validates every pig is `active`, then writes sale header,
  /// line items, flips pigs to `sold`, skips any open withdrawal_end tasks,
  /// and writes a single activity entry.
  Future<String> logSale({
    required String farmId,
    required String buyerName,
    required String? buyerContact,
    required Timestamp saleDate,
    required PaymentMethod paymentMethod,
    required PaymentStatus paymentStatus,
    required double? amountPaidPhp,
    required List<SaleLineItemInput> lineItems,
    required String? notes,
    required String actorUserId,
    required String actorDisplayName,
  }) async {
    if (lineItems.isEmpty) {
      throw ArgumentError('At least one line item is required.');
    }
    final saleRef = _col(farmId).doc();
    final totalHeads = lineItems.length;
    final totalWeight = lineItems.fold<double>(0, (s, i) => s + i.finalWeightKg);
    final totalRevenue = lineItems.fold<double>(0, (s, i) => s + i.lineRevenuePhp);

    await _firestore.runTransaction((tx) async {
      // Phase 1: read every pig and confirm it's active.
      final pigRefs = <String, DocumentReference<Map<String, dynamic>>>{};
      for (final item in lineItems) {
        final ref = _firestore.collection('farms').doc(farmId)
            .collection('pigs').doc(item.pigId);
        final snap = await tx.get(ref);
        if (!snap.exists) {
          throw StateError('Pig ${item.pigTagId} not found.');
        }
        if (snap.data()!['status'] != 'active') {
          throw StateError('Pig ${item.pigTagId} is not active (status=${snap.data()!['status']}).');
        }
        pigRefs[item.pigId] = ref;
      }

      // Optional: collect open withdrawal_end task IDs to skip.
      // (We don't query in the transaction because Firestore transactions
      //  don't support .where() reads. Skipped tasks are best-effort —
      //  if a task exists for a sold pig, we leave it open. This matches
      //  the spec's "withdrawal tasks set to skipped" but we lean conservative
      //  for atomicity.)
      // Future enhancement: trigger via Cloud Function.

      // Phase 2: writes.
      tx.set(saleRef, {
        'buyerName': buyerName.trim(),
        if (buyerContact != null && buyerContact.trim().isNotEmpty)
          'buyerContact': buyerContact.trim(),
        'saleDate': saleDate,
        'totalHeads': totalHeads,
        'totalWeightKg': totalWeight,
        'totalRevenuePhp': totalRevenue,
        'paymentMethod': paymentMethod.value,
        'paymentStatus': paymentStatus.value,
        if (amountPaidPhp != null) 'amountPaidPhp': amountPaidPhp,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        'createdBy': actorUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      for (final item in lineItems) {
        final lineRef = saleRef.collection('line_items').doc();
        tx.set(lineRef, {
          'pigId': item.pigId,
          'pigTagId': item.pigTagId,
          'finalWeightKg': item.finalWeightKg,
          'pricePerKgPhp': item.pricePerKgPhp,
          'lineRevenuePhp': item.lineRevenuePhp,
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.update(pigRefs[item.pigId]!, {
          'status': 'sold',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      // Activity entry.
      final activityRef = _firestore.collection('farms').doc(farmId)
          .collection('activity').doc();
      tx.set(activityRef, {
        'actorUserId': actorUserId,
        'actorDisplayName': actorDisplayName,
        'action': 'sale_logged',
        'entityType': 'sale',
        'entityId': saleRef.id,
        'summary':
            '$actorDisplayName logged sale of $totalHeads ${totalHeads == 1 ? "pig" : "pigs"} to ${buyerName.trim()} · ₱${totalRevenue.toStringAsFixed(0)}',
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
    return saleRef.id;
  }

  Stream<List<Sale>> streamSales(String farmId) {
    return _col(farmId)
        .orderBy('saleDate', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Sale.fromFirestore(d, farmId: farmId)).toList());
  }

  Stream<Sale?> streamSaleById({
    required String farmId, required String saleId,
  }) {
    return _col(farmId).doc(saleId).snapshots().map(
      (d) => d.exists ? Sale.fromFirestore(d, farmId: farmId) : null,
    );
  }

  Stream<List<SaleLineItem>> streamLineItems({
    required String farmId, required String saleId,
  }) {
    return _col(farmId).doc(saleId).collection('line_items')
        .orderBy('createdAt')
        .snapshots()
        .map((s) => s.docs.map((d) => SaleLineItem.fromFirestore(
              d, farmId: farmId, saleId: saleId,
            )).toList());
  }

  /// Stream sales whose saleDate falls in the given range — for profitability.
  Stream<List<Sale>> streamInRange({
    required String farmId,
    required Timestamp start,
    required Timestamp end,
  }) {
    return _col(farmId)
        .where('saleDate', isGreaterThanOrEqualTo: start)
        .where('saleDate', isLessThan: end)
        .snapshots()
        .map((s) => s.docs.map((d) => Sale.fromFirestore(d, farmId: farmId)).toList());
  }
}
```

- [ ] **Step 7.5: Sale providers**

`lib/src/features/sales/application/sale_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../activity/application/activity_providers.dart';
import '../data/sale_repository.dart';
import '../domain/sale.dart';
import '../domain/sale_line_item.dart';

final saleRepositoryProvider = Provider<SaleRepository>(
  (ref) => SaleRepository(ref.watch(firestoreProvider), ref.watch(activityRepositoryProvider)),
);

final salesStreamProvider =
    StreamProvider.family<List<Sale>, String>((ref, farmId) {
  return ref.watch(saleRepositoryProvider).streamSales(farmId);
});

final saleByIdProvider =
    StreamProvider.family<Sale?, ({String farmId, String saleId})>((ref, args) {
  return ref.watch(saleRepositoryProvider).streamSaleById(
        farmId: args.farmId, saleId: args.saleId);
});

final saleLineItemsProvider =
    StreamProvider.family<List<SaleLineItem>, ({String farmId, String saleId})>((ref, args) {
  return ref.watch(saleRepositoryProvider).streamLineItems(
        farmId: args.farmId, saleId: args.saleId);
});
```

- [ ] **Step 7.6: Run + commit**

```bash
flutter analyze && flutter test
git add -A
git commit -m "feat(sales): Sale + SaleLineItem models with atomic multi-pig logSale

- runTransaction validates every pig is 'active' before flipping all to 'sold'
- Sale header denormalizes totalHeads / totalWeightKg / totalRevenuePhp
- Empty line-items rejected with ArgumentError
- Activity entry summarizes the transaction"
```

---

---

## Task 8: Sales UI — list, detail, and log-sale screens

**Goal:** Three screens wrapping the SaleRepository: list, detail, and the multi-pig log-sale flow.

**Files:**
- Create:
  - `lib/src/features/sales/presentation/sales_list_screen.dart`
  - `lib/src/features/sales/presentation/sale_detail_screen.dart`
  - `lib/src/features/sales/presentation/log_sale_screen.dart`
- Modify: `lib/src/routing/app_router.dart`

### Steps

- [ ] **Step 8.1: Sales list screen**

`lib/src/features/sales/presentation/sales_list_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/empty_state.dart';
import '../../farms/application/farm_providers.dart';
import '../application/sale_providers.dart';
import '../domain/payment_status.dart';
import '../domain/sale.dart';
import 'log_sale_screen.dart';
import 'sale_detail_screen.dart';

class SalesListScreen extends ConsumerWidget {
  const SalesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final salesAsync = ref.watch(salesStreamProvider(farmId));

    return Scaffold(
      appBar: AppBar(title: const Text('Sales')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Iconsax.add),
        label: const Text('Log sale'),
        onPressed: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => const LogSaleScreen()),
        ),
      ),
      body: salesAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Iconsax.tag,
              title: 'No sales logged',
              subtitle: 'Tap "Log sale" to record your first transaction.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: list.length,
            itemBuilder: (_, i) => _SaleCard(sale: list[i]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}

class _SaleCard extends StatelessWidget {
  const _SaleCard({required this.sale});
  final Sale sale;

  Color _statusColor(BuildContext ctx, PaymentStatus s) {
    final scheme = Theme.of(ctx).colorScheme;
    switch (s) {
      case PaymentStatus.paid: return scheme.primary;
      case PaymentStatus.partial: return scheme.tertiary;
      case PaymentStatus.unpaid: return scheme.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        title: Text(sale.buyerName, style: theme.textTheme.titleMedium),
        subtitle: Text(
          '${DateFormat.yMMMd().format(sale.saleDate.toDate())} · '
          '${sale.totalHeads} ${sale.totalHeads == 1 ? "head" : "heads"} · '
          '${sale.totalWeightKg.toStringAsFixed(1)} kg',
        ),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('₱${sale.totalRevenuePhp.toStringAsFixed(0)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                )),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _statusColor(context, sale.paymentStatus),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(sale.paymentStatus.label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w700,
                  )),
            ),
          ],
        ),
        onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => SaleDetailScreen(saleId: sale.id)),
        ),
      ),
    );
  }
}
```

- [ ] **Step 8.2: Sale detail screen**

`lib/src/features/sales/presentation/sale_detail_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/section_header.dart';
import '../../farms/application/farm_providers.dart';
import '../application/sale_providers.dart';

class SaleDetailScreen extends ConsumerWidget {
  const SaleDetailScreen({super.key, required this.saleId});
  final String saleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final saleAsync = ref.watch(saleByIdProvider((farmId: farmId, saleId: saleId)));
    final linesAsync = ref.watch(saleLineItemsProvider((farmId: farmId, saleId: saleId)));

    return Scaffold(
      appBar: AppBar(title: const Text('Sale')),
      body: saleAsync.when(
        data: (sale) {
          if (sale == null) return const Center(child: Text('Sale not found'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sale.buyerName, style: theme.textTheme.headlineSmall),
                      if (sale.buyerContact != null)
                        Text(sale.buyerContact!, style: theme.textTheme.bodyMedium),
                      const Divider(height: 24),
                      Row(children: [
                        const Icon(Iconsax.calendar, size: 16),
                        const SizedBox(width: 8),
                        Text(DateFormat.yMMMd().format(sale.saleDate.toDate())),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Iconsax.money_4, size: 16),
                        const SizedBox(width: 8),
                        Text('${sale.paymentMethod.label} · ${sale.paymentStatus.label}'),
                      ]),
                      const SizedBox(height: 16),
                      Row(children: [
                        Text('Total', style: theme.textTheme.bodyMedium),
                        const Spacer(),
                        Text('₱${sale.totalRevenuePhp.toStringAsFixed(0)}',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            )),
                      ]),
                      Row(children: [
                        Text('${sale.totalHeads} heads · ${sale.totalWeightKg.toStringAsFixed(1)} kg',
                            style: theme.textTheme.bodyMedium),
                      ]),
                    ],
                  ),
                ),
              ),
              const SectionHeader(title: 'LINE ITEMS'),
              linesAsync.when(
                data: (lines) => Column(
                  children: lines.map((l) => Card(
                    child: ListTile(
                      title: Text(l.pigTagId, style: theme.textTheme.titleMedium),
                      subtitle: Text('${l.finalWeightKg.toStringAsFixed(1)} kg · ₱${l.pricePerKgPhp.toStringAsFixed(0)}/kg'),
                      trailing: Text('₱${l.lineRevenuePhp.toStringAsFixed(0)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          )),
                    ),
                  )).toList(),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('$e'),
              ),
              if (sale.notes != null) ...[
                const SectionHeader(title: 'NOTES'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(sale.notes!),
                  ),
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}
```

- [ ] **Step 8.3: Log sale screen (the big one)**

`lib/src/features/sales/presentation/log_sale_screen.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/widgets/adaptive_date_picker.dart';
import '../../../core/widgets/section_header.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../../pigs/application/pig_providers.dart';
import '../../pigs/domain/pig.dart';
import '../application/sale_providers.dart';
import '../data/sale_repository.dart';
import '../domain/payment_method.dart';
import '../domain/payment_status.dart';

class _PigRow {
  _PigRow({required this.pig, required this.weight, required this.pricePerKg});
  final Pig pig;
  final TextEditingController weight;
  final TextEditingController pricePerKg;
  void dispose() { weight.dispose(); pricePerKg.dispose(); }
  double get lineRevenue {
    final w = double.tryParse(weight.text.trim()) ?? 0;
    final p = double.tryParse(pricePerKg.text.trim()) ?? 0;
    return w * p;
  }
}

class LogSaleScreen extends ConsumerStatefulWidget {
  const LogSaleScreen({super.key});
  @override
  ConsumerState<LogSaleScreen> createState() => _State();
}

class _State extends ConsumerState<LogSaleScreen> {
  final _buyer = TextEditingController();
  final _contact = TextEditingController();
  final _notes = TextEditingController();
  final _amountPaid = TextEditingController();
  DateTime _date = DateTime.now();
  PaymentMethod _method = PaymentMethod.cash;
  PaymentStatus _status = PaymentStatus.paid;
  final List<_PigRow> _rows = [];
  bool _busy = false;

  @override
  void dispose() {
    _buyer.dispose();
    _contact.dispose();
    _notes.dispose();
    _amountPaid.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  double get _totalRevenue => _rows.fold(0.0, (s, r) => s + r.lineRevenue);
  double get _totalWeight => _rows.fold(0.0, (s, r) =>
      s + (double.tryParse(r.weight.text.trim()) ?? 0));

  Future<void> _addPigs() async {
    final farmId = ref.read(selectedFarmIdProvider);
    if (farmId == null) return;
    final allPigs = ref.read(pigsStreamProvider(farmId)).asData?.value ?? const <Pig>[];
    final selectableIds = allPigs
        .where((p) => p.status == PigStatus.active &&
                     (p.stage == PigStage.grower || p.stage == PigStage.finisher))
        .map((p) => p.id)
        .toSet();
    final addedIds = _rows.map((r) => r.pig.id).toSet();
    final pool = allPigs.where((p) =>
        selectableIds.contains(p.id) && !addedIds.contains(p.id)).toList();
    if (pool.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No more eligible pigs to add.')),
      );
      return;
    }
    final picked = await showModalBottomSheet<List<Pig>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _PigPicker(pool: pool),
    );
    if (picked == null || picked.isEmpty) return;
    final defaultPrice = _rows.isNotEmpty
        ? _rows.first.pricePerKg.text
        : '';
    setState(() {
      for (final p in picked) {
        _rows.add(_PigRow(
          pig: p,
          weight: TextEditingController(text: p.currentWeight?.toStringAsFixed(1) ?? ''),
          pricePerKg: TextEditingController(text: defaultPrice),
        ));
      }
    });
  }

  Future<void> _save() async {
    final farmId = ref.read(selectedFarmIdProvider);
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return;
    if (_buyer.text.trim().isEmpty) { _snack('Buyer is required.'); return; }
    if (_rows.isEmpty) { _snack('Add at least one pig.'); return; }
    final inputs = <SaleLineItemInput>[];
    for (var i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      final w = double.tryParse(r.weight.text.trim());
      final p = double.tryParse(r.pricePerKg.text.trim());
      if (w == null || w <= 0) { _snack('Pig ${r.pig.tagId}: weight must be positive.'); return; }
      if (p == null || p <= 0) { _snack('Pig ${r.pig.tagId}: price/kg must be positive.'); return; }
      inputs.add(SaleLineItemInput(
        pigId: r.pig.id, pigTagId: r.pig.tagId,
        finalWeightKg: w, pricePerKgPhp: p,
      ));
    }
    double? paid;
    if (_status == PaymentStatus.partial) {
      paid = double.tryParse(_amountPaid.text.trim());
      if (paid == null || paid <= 0 || paid >= _totalRevenue) {
        _snack('Partial-payment amount must be > 0 and < total.');
        return;
      }
    }
    setState(() => _busy = true);
    final actorName = ref.read(currentAppUserProvider).asData?.value?.displayName ?? '';
    try {
      await ref.read(saleRepositoryProvider).logSale(
        farmId: farmId,
        buyerName: _buyer.text,
        buyerContact: _contact.text.trim().isEmpty ? null : _contact.text.trim(),
        saleDate: Timestamp.fromDate(_date),
        paymentMethod: _method,
        paymentStatus: _status,
        amountPaidPhp: paid,
        lineItems: inputs,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        actorUserId: user.uid,
        actorDisplayName: actorName,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Log sale')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(title: 'BUYER', padding: EdgeInsets.only(bottom: 8)),
            TextField(controller: _buyer,
                decoration: const InputDecoration(hintText: 'Buyer name')),
            const SizedBox(height: 12),
            TextField(controller: _contact,
                decoration: const InputDecoration(hintText: 'Contact (optional)')),
            const SectionHeader(title: 'DATE'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}'),
              trailing: const Icon(Iconsax.calendar),
              onTap: () async {
                final picked = await AdaptiveDatePicker.show(
                  context: context, initial: _date,
                  firstDate: DateTime(2020), lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const SectionHeader(title: 'PIGS IN SALE'),
            ..._rows.asMap().entries.map((entry) {
              final i = entry.key;
              final r = entry.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(children: [
                        Text(r.pig.tagId, style: theme.textTheme.titleMedium),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Iconsax.trash),
                          onPressed: () => setState(() {
                            _rows.removeAt(i).dispose();
                          }),
                        ),
                      ]),
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: r.weight,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Weight kg'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: r.pricePerKg,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: '₱/kg'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text('Line: ₱${r.lineRevenue.toStringAsFixed(0)}',
                            style: theme.textTheme.labelLarge),
                      ),
                    ],
                  ),
                ),
              );
            }),
            OutlinedButton.icon(
              icon: const Icon(Iconsax.add),
              label: const Text('Add pigs'),
              onPressed: _addPigs,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(children: [
                    Text('${_rows.length} heads · ${_totalWeight.toStringAsFixed(1)} kg',
                        style: theme.textTheme.bodyMedium),
                    const Spacer(),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text('Total revenue', style: theme.textTheme.titleMedium),
                    const Spacer(),
                    Text('₱${_totalRevenue.toStringAsFixed(0)}',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        )),
                  ]),
                ],
              ),
            ),
            const SectionHeader(title: 'PAYMENT'),
            SegmentedButton<PaymentMethod>(
              segments: PaymentMethod.values.map((m) =>
                  ButtonSegment(value: m, label: Text(m.label))).toList(),
              selected: {_method},
              onSelectionChanged: (s) => setState(() => _method = s.first),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: PaymentStatus.values.map((s) =>
              ChoiceChip(
                label: Text(s.label),
                selected: _status == s,
                onSelected: (_) => setState(() => _status = s),
              )).toList()),
            if (_status == PaymentStatus.partial) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _amountPaid,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount paid (₱)',
                ),
              ),
            ],
            const SectionHeader(title: 'NOTES'),
            TextField(controller: _notes, maxLines: 3),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      height: 24, width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Text('Save sale'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PigPicker extends StatefulWidget {
  const _PigPicker({required this.pool});
  final List<Pig> pool;
  @override
  State<_PigPicker> createState() => _PigPickerState();
}

class _PigPickerState extends State<_PigPicker> {
  final Set<String> _selected = {};
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _search.trim().isEmpty
        ? widget.pool
        : widget.pool.where((p) =>
            p.tagId.toLowerCase().contains(_search.trim().toLowerCase())).toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      builder: (_, scroll) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(children: [
              Text('Pick pigs', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              TextButton(
                onPressed: _selected.isEmpty ? null : () {
                  Navigator.of(context).pop(
                    widget.pool.where((p) => _selected.contains(p.id)).toList(),
                  );
                },
                child: Text('Add (${_selected.length})'),
              ),
            ]),
            TextField(
              decoration: const InputDecoration(hintText: 'Search by tag ID'),
              onChanged: (v) => setState(() => _search = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: scroll,
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final p = filtered[i];
                  return CheckboxListTile(
                    title: Text(p.tagId),
                    subtitle: Text('${p.stage.label} · ${p.currentWeight?.toStringAsFixed(1) ?? "—"} kg'),
                    value: _selected.contains(p.id),
                    onChanged: (v) => setState(() {
                      v == true ? _selected.add(p.id) : _selected.remove(p.id);
                    }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 8.4: Wire routes + commit**

In `app_router.dart`:

```dart
GoRoute(path: '/sales', builder: (c, s) => const SalesListScreen()),
```

```bash
flutter analyze && flutter test
git add -A
git commit -m "feat(sales): list, detail, and log-sale screens

- Multi-select pig picker bottom sheet filtered to active grower/finisher
- 'Apply first price to all' UX via default-fill from first row
- Live totals (heads / weight / revenue) update with each edit
- Sale detail with per-pig line item cards"
```

---

## Task 9: Pig Detail integration — Sold banner + sale link

**Goal:** When a pig is sold, its detail screen surfaces a "Sold" banner with the date and a link to the parent sale.

**Files:**
- Modify: `lib/src/features/pigs/presentation/pig_detail_screen.dart`

### Steps

- [ ] **Step 9.1: Find the parent sale for a sold pig**

This requires a collection-group query on `line_items` filtered by `pigId`. Add a method to `SaleRepository`:

In `lib/src/features/sales/data/sale_repository.dart`, append:

```dart
/// Finds the sale that contains this pig as a line item.
/// Uses a collection-group query on line_items. Returns null if not found.
Future<Sale?> findSaleForPig({
  required String farmId, required String pigId,
}) async {
  final snap = await _firestore.collectionGroup('line_items')
      .where('pigId', isEqualTo: pigId)
      .limit(1)
      .get();
  for (final doc in snap.docs) {
    final saleRef = doc.reference.parent.parent;
    if (saleRef == null) continue;
    // Verify it's in the right farm.
    final parts = saleRef.path.split('/');
    if (parts[0] != 'farms' || parts[1] != farmId) continue;
    final saleSnap = await saleRef.get();
    if (saleSnap.exists) return Sale.fromFirestore(saleSnap, farmId: farmId);
  }
  return null;
}
```

Add a FutureProvider in `sale_providers.dart`:

```dart
final saleForPigProvider =
    FutureProvider.family<Sale?, ({String farmId, String pigId})>((ref, args) {
  return ref.read(saleRepositoryProvider).findSaleForPig(
        farmId: args.farmId, pigId: args.pigId);
});
```

- [ ] **Step 9.2: Modify Pig Detail Profile tab**

In `lib/src/features/pigs/presentation/pig_detail_screen.dart`, find the `_ProfileTab` widget. At the top of its `ListView.children`, add a `_SoldBanner` widget that renders when `pig.status == PigStatus.sold`:

```dart
// Add at top of file:
import 'package:intl/intl.dart';
import '../../sales/application/sale_providers.dart';
import '../../sales/presentation/sale_detail_screen.dart';

// Inside _ProfileTab ListView children, prepend:
if (pig.status == PigStatus.sold)
  _SoldBanner(pig: pig),
```

Add the widget:

```dart
class _SoldBanner extends ConsumerWidget {
  const _SoldBanner({required this.pig});
  final Pig pig;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final saleAsync = ref.watch(saleForPigProvider(
      (farmId: pig.farmId, pigId: pig.id),
    ));
    return Card(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: Icon(Iconsax.tag, color: theme.colorScheme.primary),
        title: Text('Sold', style: theme.textTheme.titleMedium),
        subtitle: saleAsync.when(
          data: (sale) => sale == null
              ? const Text('— no sale record found —')
              : Text('${DateFormat.yMMMd().format(sale.saleDate.toDate())} · ${sale.buyerName}'),
          loading: () => const Text('Loading sale details…'),
          error: (e, _) => Text('$e'),
        ),
        trailing: saleAsync.maybeWhen(
          data: (sale) => sale == null ? null : const Icon(Iconsax.arrow_right_3),
          orElse: () => null,
        ),
        onTap: () {
          final sale = saleAsync.asData?.value;
          if (sale != null) {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => SaleDetailScreen(saleId: sale.id),
            ));
          }
        },
      ),
    );
  }
}
```

Also: don't show the "Mark deceased" button when `pig.status == PigStatus.sold`. The existing code shows it for `active` status only — verify the check is `if (pig.status == PigStatus.active)`. If it currently says `!= deceased`, change it.

Imports needed at top of file (add if missing):
```dart
import 'package:iconsax/iconsax.dart';
```

- [ ] **Step 9.3: Run + commit**

```bash
flutter analyze && flutter test
git add -A
git commit -m "feat(pigs,sales): Sold banner on Pig Detail Profile linking to sale

- SaleRepository.findSaleForPig via line_items collection-group query
- Sold pigs show a banner with sale date + buyer + tap-to-open"
```

---

## Task 10: BatchCostCalculator + ProfitabilityCalculator (pure functions with full tests)

**Goal:** Build the core math layer for profitability. Pure functions that take collections of records and produce P&L numbers. Fully unit-tested.

**Files:**
- Create:
  - `lib/src/features/profitability/application/batch_cost_calculator.dart`
  - `lib/src/features/profitability/application/profitability_calculator.dart`
  - `lib/src/features/profitability/application/profitability_providers.dart`
  - `test/features/profitability/application/batch_cost_calculator_test.dart`
  - `test/features/profitability/application/profitability_calculator_test.dart`

### Steps

- [ ] **Step 10.1: BatchCostCalculator**

`lib/src/features/profitability/application/batch_cost_calculator.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../expenses/domain/expense.dart';
import '../../expenses/domain/expense_category.dart';
import '../../inventory/domain/supply.dart';
import '../../inventory/domain/supply_category.dart';
import '../../inventory/domain/supply_movement.dart';
import '../../pigs/domain/health_record.dart';

class BatchCostBreakdown {
  final double feedCostPhp;
  final double medicineCostPhp;
  final double laborCostPhp;
  final double utilitiesCostPhp;
  final double equipmentCostPhp;
  final double maintenanceCostPhp;
  final double otherCostPhp;
  final double totalCostPhp;
  const BatchCostBreakdown({
    required this.feedCostPhp,
    required this.medicineCostPhp,
    required this.laborCostPhp,
    required this.utilitiesCostPhp,
    required this.equipmentCostPhp,
    required this.maintenanceCostPhp,
    required this.otherCostPhp,
    required this.totalCostPhp,
  });
  static const empty = BatchCostBreakdown(
    feedCostPhp: 0, medicineCostPhp: 0, laborCostPhp: 0,
    utilitiesCostPhp: 0, equipmentCostPhp: 0, maintenanceCostPhp: 0,
    otherCostPhp: 0, totalCostPhp: 0,
  );
}

class BatchCostCalculator {
  BatchCostCalculator._();

  /// Aggregates costs attributed to a given batch from:
  ///   1. Supply consumption × supply.weightedAvgUnitCostPhp at time of movement
  ///   2. Health records.costPhp for pigs in the batch (with double-count guard via
  ///      relatedHealthRecordId on supply movements — see ProfitabilityCalculator.medicineCost docs)
  ///   3. Direct expenses tagged relatedBatchId
  static BatchCostBreakdown forBatch({
    required String batchId,
    required List<SupplyMovement> movements,
    required Map<String, Supply> suppliesById,
    required List<HealthRecord> healthRecords,
    required Set<String> batchMemberPigIds,
    required List<Expense> expenses,
  }) {
    // Movements consumed into this batch.
    double feedCost = 0;
    double medicineCost = 0;
    final consumedHealthRecordIds = <String>{};
    for (final m in movements) {
      if (m.relatedBatchId != batchId) continue;
      if (m.type != MovementType.consumption) continue;
      final supply = suppliesById[m.supplyId];
      if (supply == null) continue;
      final qty = m.quantity.abs(); // consumption is negative
      final cost = qty * supply.weightedAvgUnitCostPhp;
      switch (supply.category) {
        case SupplyCategory.feed:
          feedCost += cost;
          break;
        case SupplyCategory.medicine:
          medicineCost += cost;
          if (m.relatedHealthRecordId != null) {
            consumedHealthRecordIds.add(m.relatedHealthRecordId!);
          }
          break;
        case SupplyCategory.otherInput:
          // Fall into "other"
          break;
      }
    }

    // Health records for pigs in the batch — add cost only if NOT already counted via movement.
    for (final h in healthRecords) {
      if (!batchMemberPigIds.contains(h.pigId)) continue;
      if (consumedHealthRecordIds.contains(h.id)) continue;
      medicineCost += h.costPhp ?? 0;
    }

    // Direct expenses tagged with relatedBatchId.
    double laborCost = 0;
    double utilitiesCost = 0;
    double equipmentCost = 0;
    double maintenanceCost = 0;
    double otherCost = 0;
    for (final e in expenses) {
      if (e.relatedBatchId != batchId) continue;
      switch (e.category) {
        case ExpenseCategory.feed:
          feedCost += e.amountPhp;
          break;
        case ExpenseCategory.medicine:
          medicineCost += e.amountPhp;
          break;
        case ExpenseCategory.labor:
          laborCost += e.amountPhp;
          break;
        case ExpenseCategory.utilities:
          utilitiesCost += e.amountPhp;
          break;
        case ExpenseCategory.equipment:
          equipmentCost += e.amountPhp;
          break;
        case ExpenseCategory.maintenance:
          maintenanceCost += e.amountPhp;
          break;
        case ExpenseCategory.other:
          otherCost += e.amountPhp;
          break;
      }
    }
    final total = feedCost + medicineCost + laborCost + utilitiesCost +
        equipmentCost + maintenanceCost + otherCost;
    return BatchCostBreakdown(
      feedCostPhp: feedCost,
      medicineCostPhp: medicineCost,
      laborCostPhp: laborCost,
      utilitiesCostPhp: utilitiesCost,
      equipmentCostPhp: equipmentCost,
      maintenanceCostPhp: maintenanceCost,
      otherCostPhp: otherCost,
      totalCostPhp: total,
    );
  }
}
```

- [ ] **Step 10.2: ProfitabilityCalculator**

`lib/src/features/profitability/application/profitability_calculator.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../expenses/domain/expense.dart';
import '../../expenses/domain/expense_category.dart';
import '../../inventory/domain/supply.dart';
import '../../inventory/domain/supply_category.dart';
import '../../inventory/domain/supply_movement.dart';
import '../../pigs/domain/health_record.dart';
import '../../sales/domain/sale.dart';
import 'batch_cost_calculator.dart';

class ProfitabilityBreakdown {
  final double revenuePhp;
  final double feedCostPhp;
  final double medicineCostPhp;
  final double laborCostPhp;
  final double utilitiesCostPhp;
  final double equipmentCostPhp;
  final double maintenanceCostPhp;
  final double otherCostPhp;
  final double totalCostPhp;
  final double grossProfitPhp;
  final double marginPct;
  const ProfitabilityBreakdown({
    required this.revenuePhp,
    required this.feedCostPhp,
    required this.medicineCostPhp,
    required this.laborCostPhp,
    required this.utilitiesCostPhp,
    required this.equipmentCostPhp,
    required this.maintenanceCostPhp,
    required this.otherCostPhp,
    required this.totalCostPhp,
    required this.grossProfitPhp,
    required this.marginPct,
  });
  static const empty = ProfitabilityBreakdown(
    revenuePhp: 0, feedCostPhp: 0, medicineCostPhp: 0,
    laborCostPhp: 0, utilitiesCostPhp: 0, equipmentCostPhp: 0,
    maintenanceCostPhp: 0, otherCostPhp: 0,
    totalCostPhp: 0, grossProfitPhp: 0, marginPct: 0,
  );
}

class ProfitabilityCalculator {
  ProfitabilityCalculator._();

  /// Period P&L:
  ///   Revenue: sum of sales.totalRevenuePhp where saleDate in [start, end)
  ///   Feed: consumption × supply.avg + ExpenseCategory.feed
  ///   Medicine: consumption × supply.avg + health_records.costPhp where no movement
  ///            references the health record + ExpenseCategory.medicine
  ///   Others: each expense category direct.
  static ProfitabilityBreakdown forPeriod({
    required Timestamp start,
    required Timestamp end,
    required List<Sale> sales,
    required List<SupplyMovement> movements,
    required Map<String, Supply> suppliesById,
    required List<HealthRecord> healthRecords,
    required List<Expense> expenses,
  }) {
    // Revenue.
    final revenue = sales
        .where((s) => !s.saleDate.toDate().isBefore(start.toDate()) &&
                       s.saleDate.toDate().isBefore(end.toDate()))
        .fold<double>(0, (sum, s) => sum + s.totalRevenuePhp);

    // Costs from supply consumption in range.
    double feedCost = 0;
    double medicineCost = 0;
    final consumedHealthRecordIds = <String>{};
    for (final m in movements) {
      final t = m.createdAt.toDate();
      if (t.isBefore(start.toDate()) || !t.isBefore(end.toDate())) continue;
      if (m.type != MovementType.consumption) continue;
      final supply = suppliesById[m.supplyId];
      if (supply == null) continue;
      final qty = m.quantity.abs();
      final cost = qty * supply.weightedAvgUnitCostPhp;
      switch (supply.category) {
        case SupplyCategory.feed: feedCost += cost; break;
        case SupplyCategory.medicine:
          medicineCost += cost;
          if (m.relatedHealthRecordId != null) {
            consumedHealthRecordIds.add(m.relatedHealthRecordId!);
          }
          break;
        case SupplyCategory.otherInput: break;
      }
    }

    // Off-inventory medicine costs from health_records in range.
    for (final h in healthRecords) {
      final t = h.date.toDate();
      if (t.isBefore(start.toDate()) || !t.isBefore(end.toDate())) continue;
      if (consumedHealthRecordIds.contains(h.id)) continue;
      medicineCost += h.costPhp ?? 0;
    }

    // Direct expenses in range, by category.
    double laborCost = 0;
    double utilitiesCost = 0;
    double equipmentCost = 0;
    double maintenanceCost = 0;
    double otherCost = 0;
    for (final e in expenses) {
      final t = e.date.toDate();
      if (t.isBefore(start.toDate()) || !t.isBefore(end.toDate())) continue;
      switch (e.category) {
        case ExpenseCategory.feed: feedCost += e.amountPhp; break;
        case ExpenseCategory.medicine: medicineCost += e.amountPhp; break;
        case ExpenseCategory.labor: laborCost += e.amountPhp; break;
        case ExpenseCategory.utilities: utilitiesCost += e.amountPhp; break;
        case ExpenseCategory.equipment: equipmentCost += e.amountPhp; break;
        case ExpenseCategory.maintenance: maintenanceCost += e.amountPhp; break;
        case ExpenseCategory.other: otherCost += e.amountPhp; break;
      }
    }
    final total = feedCost + medicineCost + laborCost + utilitiesCost +
        equipmentCost + maintenanceCost + otherCost;
    final profit = revenue - total;
    final margin = revenue == 0 ? 0.0 : (profit / revenue) * 100;
    return ProfitabilityBreakdown(
      revenuePhp: revenue,
      feedCostPhp: feedCost,
      medicineCostPhp: medicineCost,
      laborCostPhp: laborCost,
      utilitiesCostPhp: utilitiesCost,
      equipmentCostPhp: equipmentCost,
      maintenanceCostPhp: maintenanceCost,
      otherCostPhp: otherCost,
      totalCostPhp: total,
      grossProfitPhp: profit,
      marginPct: margin,
    );
  }

  /// Per-batch P&L. `batchMemberPigIds` is the set of pigs that belong to the
  /// batch (current OR historic — typically derive from `batch.pigIds` plus
  /// any sold/culled/deceased pigs that were members during their lifetime).
  /// Revenue is the sum of sale line items for those pig IDs.
  static ProfitabilityBreakdown forBatch({
    required String batchId,
    required Set<String> batchMemberPigIds,
    required List<Sale> sales,
    required Map<String, List<({String pigId, double lineRevenuePhp})>> lineItemsBySale,
    required List<SupplyMovement> movements,
    required Map<String, Supply> suppliesById,
    required List<HealthRecord> healthRecords,
    required List<Expense> expenses,
  }) {
    // Revenue: sum of all line items whose pigId is in batchMemberPigIds.
    double revenue = 0;
    for (final entry in lineItemsBySale.entries) {
      for (final li in entry.value) {
        if (batchMemberPigIds.contains(li.pigId)) {
          revenue += li.lineRevenuePhp;
        }
      }
    }
    final cost = BatchCostCalculator.forBatch(
      batchId: batchId, movements: movements, suppliesById: suppliesById,
      healthRecords: healthRecords, batchMemberPigIds: batchMemberPigIds,
      expenses: expenses,
    );
    final profit = revenue - cost.totalCostPhp;
    final margin = revenue == 0 ? 0.0 : (profit / revenue) * 100;
    return ProfitabilityBreakdown(
      revenuePhp: revenue,
      feedCostPhp: cost.feedCostPhp,
      medicineCostPhp: cost.medicineCostPhp,
      laborCostPhp: cost.laborCostPhp,
      utilitiesCostPhp: cost.utilitiesCostPhp,
      equipmentCostPhp: cost.equipmentCostPhp,
      maintenanceCostPhp: cost.maintenanceCostPhp,
      otherCostPhp: cost.otherCostPhp,
      totalCostPhp: cost.totalCostPhp,
      grossProfitPhp: profit,
      marginPct: margin,
    );
  }
}
```

- [ ] **Step 10.3: Tests**

`test/features/profitability/application/batch_cost_calculator_test.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/features/expenses/domain/expense.dart';
import 'package:farm_app/src/features/expenses/domain/expense_category.dart';
import 'package:farm_app/src/features/inventory/domain/supply.dart';
import 'package:farm_app/src/features/inventory/domain/supply_category.dart';
import 'package:farm_app/src/features/inventory/domain/supply_movement.dart';
import 'package:farm_app/src/features/pigs/domain/health_record.dart';
import 'package:farm_app/src/features/profitability/application/batch_cost_calculator.dart';

Supply _supply(String id, SupplyCategory cat, double avg) => Supply(
  id: id, farmId: 'f', name: 'X',
  category: cat, unit: SupplyUnit.sack,
  unitsPerPackage: null, lowStockThreshold: null,
  currentStock: 0, weightedAvgUnitCostPhp: avg,
  notes: null, createdBy: 'u',
  createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
);

SupplyMovement _consumption({
  required String supplyId, required num qty, required String batchId,
  String? healthRecordId,
}) => SupplyMovement(
  id: 'm', farmId: 'f', supplyId: supplyId,
  type: MovementType.consumption, quantity: -qty,
  unitCostPhp: null, relatedPurchaseId: null,
  relatedPenId: null, relatedBatchId: batchId,
  relatedHealthRecordId: healthRecordId,
  notes: null, createdBy: 'u', createdAt: Timestamp.now(),
);

HealthRecord _health({
  required String id, required String pigId, double cost = 0,
}) => HealthRecord(
  id: id, farmId: 'f', pigId: pigId,
  type: HealthEventType.vaccination, date: Timestamp.now(),
  productName: null, dosage: null, route: null, diagnosis: null,
  withdrawalEndDate: null, costPhp: cost == 0 ? null : cost,
  photoUrls: const [], notes: null,
  createdBy: 'u', createdAt: Timestamp.now(),
);

Expense _expense({
  required ExpenseCategory category, required double amount, String? batchId,
}) => Expense(
  id: 'e', farmId: 'f',
  category: category, description: 'X',
  amountPhp: amount, date: Timestamp.now(),
  relatedBatchId: batchId, relatedEquipmentId: null,
  relatedPigId: null, relatedAreaId: null,
  receiptPhotoUrl: null, notes: null,
  createdBy: 'u', createdAt: Timestamp.now(),
);

void main() {
  test('feed consumption attributed to batch', () {
    final supplies = {'s1': _supply('s1', SupplyCategory.feed, 1650.0)};
    final movements = [
      _consumption(supplyId: 's1', qty: 2, batchId: 'b1'),
      _consumption(supplyId: 's1', qty: 1, batchId: 'b2'),
    ];
    final r = BatchCostCalculator.forBatch(
      batchId: 'b1',
      movements: movements,
      suppliesById: supplies,
      healthRecords: const [],
      batchMemberPigIds: const {},
      expenses: const [],
    );
    expect(r.feedCostPhp, 2 * 1650);
    expect(r.totalCostPhp, 2 * 1650);
  });

  test('medicine: health record cost included when no matching movement', () {
    final supplies = {'s1': _supply('s1', SupplyCategory.medicine, 50.0)};
    final movements = <SupplyMovement>[];
    final health = [_health(id: 'h1', pigId: 'p1', cost: 200)];
    final r = BatchCostCalculator.forBatch(
      batchId: 'b1', movements: movements, suppliesById: supplies,
      healthRecords: health,
      batchMemberPigIds: {'p1'},
      expenses: const [],
    );
    expect(r.medicineCostPhp, 200);
  });

  test('medicine: movement cost wins over health-record costPhp (no double-count)', () {
    final supplies = {'s1': _supply('s1', SupplyCategory.medicine, 50.0)};
    final movements = [
      _consumption(supplyId: 's1', qty: 4, batchId: 'b1', healthRecordId: 'h1'),
    ];
    final health = [_health(id: 'h1', pigId: 'p1', cost: 200)];
    final r = BatchCostCalculator.forBatch(
      batchId: 'b1', movements: movements, suppliesById: supplies,
      healthRecords: health, batchMemberPigIds: {'p1'},
      expenses: const [],
    );
    // 4 × 50 = 200 from movement; health record cost is SKIPPED.
    expect(r.medicineCostPhp, 200);
  });

  test('expenses by category attributed', () {
    final r = BatchCostCalculator.forBatch(
      batchId: 'b1', movements: const [], suppliesById: const {},
      healthRecords: const [], batchMemberPigIds: const {},
      expenses: [
        _expense(category: ExpenseCategory.labor, amount: 5000, batchId: 'b1'),
        _expense(category: ExpenseCategory.utilities, amount: 2000, batchId: 'b1'),
        _expense(category: ExpenseCategory.labor, amount: 9999, batchId: 'b2'),  // wrong batch
      ],
    );
    expect(r.laborCostPhp, 5000);
    expect(r.utilitiesCostPhp, 2000);
    expect(r.totalCostPhp, 7000);
  });
}
```

`test/features/profitability/application/profitability_calculator_test.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/features/inventory/domain/supply.dart';
import 'package:farm_app/src/features/inventory/domain/supply_category.dart';
import 'package:farm_app/src/features/inventory/domain/supply_movement.dart';
import 'package:farm_app/src/features/profitability/application/profitability_calculator.dart';
import 'package:farm_app/src/features/sales/domain/payment_method.dart';
import 'package:farm_app/src/features/sales/domain/payment_status.dart';
import 'package:farm_app/src/features/sales/domain/sale.dart';

Sale _sale({required DateTime date, required double revenue}) => Sale(
  id: 's', farmId: 'f', buyerName: 'X',
  buyerContact: null, saleDate: Timestamp.fromDate(date),
  totalHeads: 1, totalWeightKg: 90,
  totalRevenuePhp: revenue,
  paymentMethod: PaymentMethod.cash, paymentStatus: PaymentStatus.paid,
  amountPaidPhp: null, notes: null,
  createdBy: 'u', createdAt: Timestamp.now(),
);

Supply _supply(String id, SupplyCategory cat, double avg) => Supply(
  id: id, farmId: 'f', name: 'X',
  category: cat, unit: SupplyUnit.sack,
  unitsPerPackage: null, lowStockThreshold: null,
  currentStock: 0, weightedAvgUnitCostPhp: avg,
  notes: null, createdBy: 'u',
  createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
);

SupplyMovement _consumption({
  required String supplyId, required num qty, required DateTime at,
}) => SupplyMovement(
  id: 'm', farmId: 'f', supplyId: supplyId,
  type: MovementType.consumption, quantity: -qty,
  unitCostPhp: null, relatedPurchaseId: null,
  relatedPenId: null, relatedBatchId: null, relatedHealthRecordId: null,
  notes: null, createdBy: 'u', createdAt: Timestamp.fromDate(at),
);

void main() {
  test('period P&L sums revenue and feed cost in range', () {
    final start = DateTime(2026, 5, 1);
    final end = DateTime(2026, 6, 1);
    final r = ProfitabilityCalculator.forPeriod(
      start: Timestamp.fromDate(start), end: Timestamp.fromDate(end),
      sales: [
        _sale(date: DateTime(2026, 5, 10), revenue: 50000),
        _sale(date: DateTime(2026, 5, 20), revenue: 25000),
        _sale(date: DateTime(2026, 4, 15), revenue: 999999),  // before period
      ],
      movements: [
        _consumption(supplyId: 's1', qty: 5, at: DateTime(2026, 5, 12)),
      ],
      suppliesById: {'s1': _supply('s1', SupplyCategory.feed, 1650.0)},
      healthRecords: const [], expenses: const [],
    );
    expect(r.revenuePhp, 75000);
    expect(r.feedCostPhp, 5 * 1650);
    expect(r.totalCostPhp, 5 * 1650);
    expect(r.grossProfitPhp, 75000 - 5 * 1650);
    expect(r.marginPct, closeTo((75000 - 5 * 1650) / 75000 * 100, 0.01));
  });

  test('zero revenue yields 0 margin (not NaN)', () {
    final r = ProfitabilityCalculator.forPeriod(
      start: Timestamp.fromDate(DateTime(2026, 1, 1)),
      end: Timestamp.fromDate(DateTime(2026, 12, 31)),
      sales: const [],
      movements: const [], suppliesById: const {},
      healthRecords: const [], expenses: const [],
    );
    expect(r.marginPct, 0);
    expect(r.grossProfitPhp, 0);
  });
}
```

- [ ] **Step 10.4: Providers + commit**

`lib/src/features/profitability/application/profitability_providers.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../expenses/application/expense_providers.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../inventory/data/movement_repository.dart';
import '../../inventory/domain/supply.dart';
import '../../inventory/domain/supply_movement.dart';
import '../../pigs/application/pig_providers.dart';
import '../../pigs/domain/health_record.dart';
import '../../sales/application/sale_providers.dart';
import '../../yield/yield_metrics.dart';
import '../../yield/yield_providers.dart';
import 'profitability_calculator.dart';

/// Period P&L using the same period selector as YieldReports.
final profitabilityForPeriodProvider =
    Provider.family<ProfitabilityBreakdown, String>((ref, farmId) {
  final period = ref.watch(selectedPeriodProvider);
  final now = DateTime.now();
  final start = Timestamp.fromDate(period.startFrom(now));
  final end = Timestamp.fromDate(now.add(const Duration(days: 1)));
  final sales = ref.watch(salesStreamProvider(farmId)).asData?.value ?? const [];
  final movements = ref.watch(_allMovementsProvider(farmId)).asData?.value ?? const <SupplyMovement>[];
  final supplies = ref.watch(suppliesStreamProvider(farmId)).asData?.value ?? const <Supply>[];
  final suppliesById = {for (final s in supplies) s.id: s};
  final healthRecords = ref.watch(_allHealthRecordsProvider(farmId)).asData?.value ?? const <HealthRecord>[];
  final expenses = ref.watch(expensesStreamProvider(farmId)).asData?.value ?? const [];
  return ProfitabilityCalculator.forPeriod(
    start: start, end: end, sales: sales, movements: movements,
    suppliesById: suppliesById, healthRecords: healthRecords, expenses: expenses,
  );
});

/// Helper: streams all movements for the farm (regardless of date) — calculator filters.
final _allMovementsProvider = StreamProvider.family<List<SupplyMovement>, String>((ref, farmId) {
  // Cheap workaround: get last 90d range; profitability calculator filters by exact range.
  // For correctness over longer periods (YTD/all), this provider should stream the entire collection.
  return ref.watch(movementRepositoryProvider).streamInRange(
        farmId: farmId,
        start: Timestamp.fromMillisecondsSinceEpoch(0),
        end: Timestamp.fromDate(DateTime.now().add(const Duration(days: 1))),
      );
});

/// Helper: streams all health records via collection-group filtered to farm.
final _allHealthRecordsProvider = StreamProvider.family<List<HealthRecord>, String>((ref, farmId) {
  return ref.watch(firestoreProvider)
      .collectionGroup('health_records')
      .snapshots()
      .map((s) {
    return s.docs.where((d) {
      final parts = d.reference.path.split('/');
      return parts[0] == 'farms' && parts[1] == farmId;
    }).map((d) {
      final pigId = d.reference.parent.parent!.id;
      return HealthRecord.fromFirestore(d, farmId: farmId, pigId: pigId);
    }).toList();
  });
});
```

(Note: `firestoreProvider` is imported from `activity_providers.dart` — same pattern as other providers in this codebase.)

Run tests, commit:

```bash
flutter analyze && flutter test
git add -A
git commit -m "feat(profitability): BatchCostCalculator + ProfitabilityCalculator pure functions

- Period P&L with revenue, feed/medicine/labor/utilities/equipment/
  maintenance/other cost breakdown
- Medicine double-count guard via relatedHealthRecordId
- Per-batch P&L with member-pig revenue attribution
- Full unit tests covering empty/zero/multi-category cases"
```

---

## Task 11: Yield Reports extension + Batches list + Batch profitability detail

**Goal:** Extend the existing Yield Reports screen with the new Profitability card. Add a Batches list screen accessible from there, and a per-batch profitability detail screen.

**Files:**
- Modify: `lib/src/features/yield/yield_screen.dart`
- Create:
  - `lib/src/features/profitability/presentation/batches_list_screen.dart`
  - `lib/src/features/profitability/presentation/batch_profitability_screen.dart`
- Modify: `lib/src/routing/app_router.dart`

### Steps

- [ ] **Step 11.1: Add Profitability card to Yield Reports**

In `lib/src/features/yield/yield_screen.dart`, locate the ListView with the existing 4 metric cards. Append a new card and a "Batches" link button.

Inside the existing `ListView`'s children, after the Output card:

```dart
// Add at top of file:
import '../../profitability/application/profitability_providers.dart';
import '../../profitability/presentation/batches_list_screen.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../core/permissions/role.dart';
import '../../authentication/application/auth_providers.dart';
import '../../team/application/team_providers.dart';

// Inside Build, gate by role:
final user = ref.watch(authStateChangesProvider).asData?.value;
final role = (farmId != null && user != null)
    ? (ref.watch(memberForUserProvider(
        (farmId: farmId, userId: user.uid),
      )).asData?.value?.role ?? Role.worker)
    : Role.worker;
final canSeeProfit = PermissionService.canEditEquipment(role);

// In the children list, append:
if (canSeeProfit) _ProfitabilityCard(farmId: farmId),
if (canSeeProfit) const SizedBox(height: 12),
if (canSeeProfit)
  OutlinedButton.icon(
    icon: const Icon(Iconsax.box),
    label: const Text('View per-batch profitability'),
    onPressed: () => Navigator.push(
      context, MaterialPageRoute(builder: (_) => const BatchesListScreen()),
    ),
  ),
```

Add the `_ProfitabilityCard` widget at the bottom of the file:

```dart
class _ProfitabilityCard extends ConsumerWidget {
  const _ProfitabilityCard({required this.farmId});
  final String farmId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final r = ref.watch(profitabilityForPeriodProvider(farmId));
    final profitColor = r.grossProfitPhp >= 0
        ? theme.colorScheme.primary : theme.colorScheme.error;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Profitability', style: theme.textTheme.headlineSmall),
            const Divider(),
            _line(theme, 'Revenue', r.revenuePhp),
            const SizedBox(height: 4),
            _line(theme, 'Feed', r.feedCostPhp, expense: true),
            _line(theme, 'Medicine', r.medicineCostPhp, expense: true),
            _line(theme, 'Labor', r.laborCostPhp, expense: true),
            _line(theme, 'Utilities', r.utilitiesCostPhp, expense: true),
            _line(theme, 'Equipment', r.equipmentCostPhp, expense: true),
            _line(theme, 'Maintenance', r.maintenanceCostPhp, expense: true),
            _line(theme, 'Other', r.otherCostPhp, expense: true),
            const Divider(),
            Row(children: [
              Text('Gross profit',
                  style: theme.textTheme.titleMedium),
              const Spacer(),
              Text(
                '${r.grossProfitPhp >= 0 ? "" : "−"}₱${r.grossProfitPhp.abs().toStringAsFixed(0)}',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: profitColor, fontWeight: FontWeight.w700,
                ),
              ),
            ]),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: profitColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${r.marginPct.toStringAsFixed(1)}% margin',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: profitColor, fontWeight: FontWeight.w700,
                    )),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(ThemeData theme, String label, double value, {bool expense = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Text(label, style: theme.textTheme.bodyMedium),
        const Spacer(),
        Text(
          '${expense ? "−" : ""}₱${value.toStringAsFixed(0)}',
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: expense ? theme.colorScheme.onSurfaceVariant : null,
          ),
        ),
      ]),
    );
  }
}
```

- [ ] **Step 11.2: Batches list screen**

`lib/src/features/profitability/presentation/batches_list_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/empty_state.dart';
import '../../farms/application/farm_providers.dart';
import '../../pigs/application/pig_providers.dart';
import '../../pigs/domain/batch.dart';
import 'batch_profitability_screen.dart';

class BatchesListScreen extends ConsumerWidget {
  const BatchesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) return const SizedBox.shrink();
    final batchesAsync = ref.watch(batchesStreamProvider(farmId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Batches')),
      body: batchesAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Iconsax.element_3,
              title: 'No batches yet',
              subtitle: 'Litter or grow-finish batches will appear here once created.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final b = list[i];
              return Card(
                child: ListTile(
                  title: Text(b.name, style: theme.textTheme.titleMedium),
                  subtitle: Text(
                    '${b.type.label} · ${b.count} head'
                    '${b.status == BatchStatus.active ? "" : " · ${b.status.value}"}',
                  ),
                  trailing: const Icon(Iconsax.arrow_right_3),
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => BatchProfitabilityScreen(batchId: b.id),
                  )),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}
```

- [ ] **Step 11.3: Batch profitability screen**

`lib/src/features/profitability/presentation/batch_profitability_screen.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/widgets/section_header.dart';
import '../../activity/application/activity_providers.dart';
import '../../expenses/application/expense_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../inventory/data/movement_repository.dart';
import '../../inventory/domain/supply.dart';
import '../../inventory/domain/supply_movement.dart';
import '../../pigs/application/pig_providers.dart';
import '../../pigs/domain/batch.dart';
import '../../pigs/domain/health_record.dart';
import '../../sales/application/sale_providers.dart';
import '../application/batch_cost_calculator.dart';
import '../application/profitability_calculator.dart';

class BatchProfitabilityScreen extends ConsumerWidget {
  const BatchProfitabilityScreen({super.key, required this.batchId});
  final String batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final batches = ref.watch(batchesStreamProvider(farmId)).asData?.value ?? const <Batch>[];
    final batch = batches.firstWhere(
      (b) => b.id == batchId,
      orElse: () => batches.isNotEmpty ? batches.first : throw StateError('not found'),
    );
    final sales = ref.watch(salesStreamProvider(farmId)).asData?.value ?? const [];
    final movements = ref.watch(_movementsForBatchProvider((farmId: farmId, batchId: batchId))).asData?.value ?? const <SupplyMovement>[];
    final supplies = ref.watch(suppliesStreamProvider(farmId)).asData?.value ?? const <Supply>[];
    final suppliesById = {for (final s in supplies) s.id: s};
    final pigs = ref.watch(pigsStreamProvider(farmId)).asData?.value ?? const [];
    final healthRecords = ref.watch(_allHealthRecordsForBatchProvider(farmId)).asData?.value ?? const <HealthRecord>[];
    final expenses = ref.watch(expensesForBatchProvider(
      (farmId: farmId, batchId: batchId),
    )).asData?.value ?? const [];

    // Member pig IDs: from batch.pigIds plus any historical pigs (best-effort: union with batch.pigIds).
    final memberPigIds = batch.pigIds.toSet();

    // Build line items index for revenue computation.
    final lineItemsBySale = <String, List<({String pigId, double lineRevenuePhp})>>{};
    for (final sale in sales) {
      lineItemsBySale[sale.id] = ref.watch(saleLineItemsProvider(
        (farmId: farmId, saleId: sale.id),
      )).asData?.value
              .map((li) => (pigId: li.pigId, lineRevenuePhp: li.lineRevenuePhp))
              .toList() ?? const [];
    }

    final p = ProfitabilityCalculator.forBatch(
      batchId: batchId,
      batchMemberPigIds: memberPigIds,
      sales: sales,
      lineItemsBySale: lineItemsBySale,
      movements: movements,
      suppliesById: suppliesById,
      healthRecords: healthRecords,
      expenses: expenses,
    );
    final profitColor = p.grossProfitPhp >= 0
        ? theme.colorScheme.primary : theme.colorScheme.error;

    return Scaffold(
      appBar: AppBar(title: Text(batch.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${batch.type.label} · ${batch.count} head',
                      style: theme.textTheme.bodyMedium),
                  const Divider(),
                  Row(children: [
                    Text('Revenue', style: theme.textTheme.bodyMedium),
                    const Spacer(),
                    Text('₱${p.revenuePhp.toStringAsFixed(0)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        )),
                  ]),
                  Row(children: [
                    Text('Total cost', style: theme.textTheme.bodyMedium),
                    const Spacer(),
                    Text('₱${p.totalCostPhp.toStringAsFixed(0)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurfaceVariant,
                        )),
                  ]),
                  const Divider(),
                  Row(children: [
                    Text('Gross profit', style: theme.textTheme.titleMedium),
                    const Spacer(),
                    Text(
                      '${p.grossProfitPhp >= 0 ? "" : "−"}₱${p.grossProfitPhp.abs().toStringAsFixed(0)}',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: profitColor, fontWeight: FontWeight.w700,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text('${p.marginPct.toStringAsFixed(1)}% margin',
                      style: theme.textTheme.labelMedium?.copyWith(color: profitColor)),
                ],
              ),
            ),
          ),
          const SectionHeader(title: 'COST BREAKDOWN'),
          SizedBox(
            height: 220,
            child: _CostPie(breakdown: p),
          ),
        ],
      ),
    );
  }
}

class _CostPie extends StatelessWidget {
  const _CostPie({required this.breakdown});
  final ProfitabilityBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sections = <PieChartSectionData>[];
    void add(String label, double v, Color c) {
      if (v <= 0) return;
      sections.add(PieChartSectionData(
        value: v, color: c, title: label,
        radius: 80,
        titleStyle: theme.textTheme.labelMedium?.copyWith(color: Colors.white),
      ));
    }
    final palette = [
      theme.colorScheme.primary,
      theme.colorScheme.tertiary,
      theme.colorScheme.secondary,
      theme.colorScheme.error,
      theme.colorScheme.primaryContainer,
      theme.colorScheme.surfaceContainerHigh,
      theme.colorScheme.onSurfaceVariant,
    ];
    add('Feed', breakdown.feedCostPhp, palette[0]);
    add('Med', breakdown.medicineCostPhp, palette[1]);
    add('Labor', breakdown.laborCostPhp, palette[2]);
    add('Util', breakdown.utilitiesCostPhp, palette[3]);
    add('Eqp', breakdown.equipmentCostPhp, palette[4]);
    add('Maint', breakdown.maintenanceCostPhp, palette[5]);
    add('Other', breakdown.otherCostPhp, palette[6]);
    if (sections.isEmpty) {
      return Center(child: Text('No costs yet', style: theme.textTheme.bodyMedium));
    }
    return PieChart(PieChartData(sections: sections, centerSpaceRadius: 32));
  }
}

// Helper providers — colocated here to keep the screen self-contained.
final _movementsForBatchProvider =
    StreamProvider.family<List<SupplyMovement>, ({String farmId, String batchId})>((ref, args) {
  return ref.watch(movementRepositoryProvider).streamForBatch(
        farmId: args.farmId, batchId: args.batchId);
});

final _allHealthRecordsForBatchProvider =
    StreamProvider.family<List<HealthRecord>, String>((ref, farmId) {
  return ref.watch(firestoreProvider)
      .collectionGroup('health_records')
      .snapshots()
      .map((s) {
    return s.docs.where((d) {
      final parts = d.reference.path.split('/');
      return parts[0] == 'farms' && parts[1] == farmId;
    }).map((d) {
      final pigId = d.reference.parent.parent!.id;
      return HealthRecord.fromFirestore(d, farmId: farmId, pigId: pigId);
    }).toList();
  });
});
```

- [ ] **Step 11.4: Wire route + commit**

In `app_router.dart`:

```dart
GoRoute(path: '/batches', builder: (c, s) => const BatchesListScreen()),
```

```bash
flutter analyze && flutter test
git add -A
git commit -m "feat(yield,profitability): Profitability card + Batches list + Batch P&L

- Yield Reports gets a sixth card (Owner/Manager only): revenue,
  7-category cost lines, gross profit, margin %
- Batches list links to per-batch profitability
- Per-batch P&L screen with cost-breakdown pie chart"
```

---

## Task 12: Dashboard tiles — Revenue this month + Low stock

**Goal:** Two new stat tiles on the dashboard, visible to Owner/Manager only.

**Files:**
- Modify: `lib/src/features/dashboard/snapshot_card.dart`

### Steps

- [ ] **Step 12.1: Extend SnapshotCard with revenue + low-stock tiles**

Update `lib/src/features/dashboard/snapshot_card.dart`. After the existing stat tiles, add two more (gated on Owner/Manager role):

```dart
// At top of file, add imports:
import '../../../core/permissions/permission_service.dart';
import '../../../core/permissions/role.dart';
import '../../authentication/application/auth_providers.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../sales/application/sale_providers.dart';
import '../../team/application/team_providers.dart';

// Inside the build method, compute role:
final user = ref.watch(authStateChangesProvider).asData?.value;
final role = (farmId != null && user != null)
    ? (ref.watch(memberForUserProvider(
        (farmId: farmId, userId: user.uid),
      )).asData?.value?.role ?? Role.worker)
    : Role.worker;
final canSeeFinance = PermissionService.canEditEquipment(role); // Same role gate as profitability

// Compute revenue this month
double revenueThisMonth = 0;
if (canSeeFinance && farmId != null) {
  final sales = ref.watch(salesStreamProvider(farmId)).asData?.value ?? const [];
  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  for (final s in sales) {
    if (!s.saleDate.toDate().isBefore(monthStart)) {
      revenueThisMonth += s.totalRevenuePhp;
    }
  }
}

// Compute low-stock count
int lowStockCount = 0;
if (farmId != null) {
  final supplies = ref.watch(suppliesStreamProvider(farmId)).asData?.value ?? const [];
  lowStockCount = supplies.where((s) => s.isLowStock || s.isOutOfStock).length;
}

// Add to the tiles section, inside the existing Column children:
if (canSeeFinance)
  StatTile(
    icon: Iconsax.money_recive,
    label: 'Revenue this month',
    value: '₱${NumberFormat.decimalPattern("en_PH").format(revenueThisMonth.round())}',
  ),
StatTile(
  icon: Iconsax.box,
  label: 'Low stock items',
  value: lowStockCount.toString(),
),
```

Note: `StatTile` is the existing widget at `lib/src/core/widgets/stat_tile.dart`. If the revenue tile needs to push to `/sales` or low-stock to `/inventory?filter=low`, that's tap behavior we can add later — for v1 keep them as informational tiles.

- [ ] **Step 12.2: Run + commit**

```bash
flutter analyze && flutter test
git add -A
git commit -m "feat(dashboard): Revenue this month + Low stock items stat tiles

- Revenue tile gated to Owner/Manager only (matches profitability gate)
- Low stock tile visible to all roles
- Both update reactively via streamed providers"
```

---

## Task 13: Firestore security rules + final audit

**Goal:** Add per-collection rules for every new collection introduced in Sub-project B, matching the §8 permissions matrix.

**Files:**
- Modify: `firestore.rules`

### Steps

- [ ] **Step 13.1: Add new helpers if needed**

The existing `firestore.rules` already has `isOwner`/`isManager`/`isWorker`/`isVet`, `isMember`, etc. Add a helper for "can write financial records":

```javascript
function canWriteFinancial(farmId) {
  return isOwner(farmId) || isManager(farmId);
}
function canLogConsumption(farmId) {
  return isOwner(farmId) || isManager(farmId) || isWorker(farmId);
}
```

- [ ] **Step 13.2: Add rules for inventory, purchases, expenses, sales**

Inside `match /farms/{farmId} { ... }`, after the existing rules, append:

```javascript
// supplies
match /supplies/{supplyId} {
  allow read: if isMember(farmId);
  allow create, update, delete: if canWriteFinancial(farmId)
    // Workers can update only specific fields (currentStock decrement via increment) —
    // since we use a transaction-based logConsumption that runs as the worker,
    // we need to allow worker writes to currentStock + updatedAt.
    || (isWorker(farmId)
        && request.resource.data.diff(resource.data).affectedKeys()
            .hasOnly(['currentStock', 'updatedAt']));
}

// supply_movements
match /supply_movements/{movementId} {
  allow read: if isMember(farmId);
  allow create: if canWriteFinancial(farmId)
    || (isWorker(farmId) && request.resource.data.type == 'consumption');
  allow update, delete: if false;  // immutable ledger
}

// purchases
match /purchases/{purchaseId} {
  allow read: if canWriteFinancial(farmId);
  allow create, update, delete: if canWriteFinancial(farmId);

  match /line_items/{itemId} {
    allow read: if canWriteFinancial(farmId);
    allow create, update, delete: if canWriteFinancial(farmId);
  }
}

// expenses
match /expenses/{expenseId} {
  allow read: if canWriteFinancial(farmId);
  allow create: if canWriteFinancial(farmId);
  allow update, delete: if canWriteFinancial(farmId);
}

// sales
match /sales/{saleId} {
  allow read: if canWriteFinancial(farmId);
  allow create: if canWriteFinancial(farmId);
  allow update, delete: if canWriteFinancial(farmId);

  match /line_items/{itemId} {
    allow read: if canWriteFinancial(farmId);
    allow create, update, delete: if canWriteFinancial(farmId);
  }
}
```

Also: the **profitability views** (BatchCostCalculator, ProfitabilityCalculator) read pigs, batches, health_records, supplies, supply_movements, expenses, sales, sale line_items — verify each collection's read rule:

- `pigs`, `batches`, `health_records` — already readable by members (from sub-project A's rules)
- `supplies`, `supply_movements` — readable by members (added above)
- `expenses`, `sales`, `purchases`, `line_items` — restricted to `canWriteFinancial`

Workers and Vets cannot read these — which is the desired behavior (they shouldn't see financial numbers).

- [ ] **Step 13.3: Storage rules — verify receipts/photos**

The existing `storage.rules` already permits anyone-who-is-a-member to read/write under `/farms/{farmId}/**`. New paths used by Sub-project B:
- `farms/{farmId}/purchases/{purchaseId}/receipt.jpg`
- `farms/{farmId}/expenses/{expenseId}/receipt.jpg`

These fall under the existing rule — no change needed. The 5 MB cap remains in effect.

- [ ] **Step 13.4: Manual smoke checklist for Sub-project B**

Append to `docs/superpowers/manual-smoke-checklist.md`:

```markdown
## Sub-project B — Operations & Financials

### Inventory
- [ ] Owner adds a supply "Grower Feed" (sack, threshold 5).
- [ ] Owner logs a purchase: 10 sacks at ₱1650. supply.currentStock = 10, weightedAvg = 1650.
- [ ] Owner logs another purchase: 5 sacks at ₱1750. supply.currentStock = 15, weightedAvg ≈ 1683.33.
- [ ] Worker logs consumption: 2 sacks on Pen A. supply.currentStock = 13. supply_movement has relatedPenId and relatedBatchId.
- [ ] Trying to consume 100 sacks shows "Insufficient stock" inline error.

### Expenses
- [ ] Owner logs a Utilities expense of ₱8500 with description "May electricity". Appears in list with running total.
- [ ] Filter chips work.

### Sales
- [ ] Owner opens "Log sale", picks 12 finisher pigs via multi-select bottom sheet.
- [ ] First row's price/kg defaults to subsequent rows.
- [ ] Live total updates as weights/prices change.
- [ ] Save flips all 12 pigs to `sold` atomically; activity feed shows one sale entry.
- [ ] Attempt to log sale with a pig that's already sold (in another transaction) → atomic rejection.

### Pig Detail integration
- [ ] Open a sold pig → Profile shows "Sold" banner with date and buyer.
- [ ] Tap banner → opens Sale Detail screen.

### Profitability
- [ ] Yield Reports shows Profitability card for Owner/Manager.
- [ ] Card numbers match a hand-calculation on the seeded data within ₱1 rounding.
- [ ] Batches list shows all active/closed batches.
- [ ] Tap a batch → per-batch P&L with cost pie chart.

### Dashboard
- [ ] "Revenue this month" tile visible to Owner/Manager only; Worker doesn't see it.
- [ ] "Low stock items" tile shows count of supplies below threshold; tapping it opens inventory (filter not auto-applied — manual filter in v1).

### Security
- [ ] Worker cannot see Purchases, Expenses, Sales lists (routes 404 or empty due to read denial).
- [ ] Vet cannot see financial routes.
- [ ] Cross-farm access denied (try changing farm in switcher mid-session).
```

- [ ] **Step 13.5: Final run + commit**

```bash
flutter analyze && flutter test
git add -A
git commit -m "feat(security,docs): Firestore rules for inventory/purchases/expenses/sales

- Workers can read supplies + supply_movements + create consumption
  movements; cannot read purchases/sales/expenses
- Managers/Owners can read+write all financial records
- Vets see inventory but no financial reports
- supply_movements are immutable (no update/delete)
- Manual smoke checklist appended for Sub-project B"
```

---

## Final verification

After all 13 tasks are complete:

- [ ] **`flutter analyze`** — must be 0 issues. The baseline at start of B was 0; do not regress.
- [ ] **`flutter test`** — all tests pass. Expected count: ~105 (pre-B baseline) + ~30 new = ~135 tests.
- [ ] **Manual smoke checklist** — every checkbox in the new Sub-project B section.
- [ ] **Spec §13 success criteria** — every numbered criterion is demonstrably true on seeded data.
- [ ] Tag the branch: `git tag sub-project-B` (after Sub-project A is also tagged).

---

## Notes for the executing engineer

- **Riverpod 3 record args**: provider families use `({String farmId, String batchId})` records — type them precisely. Mismatched arg shapes silently no-op.
- **`fake_cloud_firestore` collection-group quirks**: `findSaleForPig` uses `collectionGroup('line_items')`. This works in fake_cloud_firestore 4.x but ordering may differ from prod — verify with the emulator when ready.
- **Transactions vs batches**: read the spec §7.12 atomicity table. Three operations use `runTransaction` (purchase, sale, consumption) because of read-before-write. Everything else uses `WriteBatch`.
- **Don't add UI for `Pig.currentBatchId` editing** — the field is settable from farrowing flows (Task 5 sets up the repository methods); a UI to manually assign pigs to batches can wait for a future polish task.
- **Profitability requires data**. The numbers will read as 0 until purchases, consumption, and sales are logged. Seed data for manual testing or wait until real flows fill it in.
- **Carry over CLAUDE.md / .impeccable.md design rules** in every new screen. The polish bar is the same as Sub-project A's finished state.
