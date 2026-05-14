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
      farmId: 'f1',
      name: 'Feed',
      category: SupplyCategory.feed,
      unit: SupplyUnit.sack,
      unitsPerPackage: null,
      lowStockThreshold: null,
      notes: null,
      actorUserId: 'u',
      actorDisplayName: 'J',
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
      actorUserId: 'u',
      actorDisplayName: 'J',
    );

    final supply = await f
        .collection('farms')
        .doc('f1')
        .collection('supplies')
        .doc(sid)
        .get();
    expect(supply.data()!['currentStock'], 10);
    expect(supply.data()!['weightedAvgUnitCostPhp'], 1650.0);
  });

  test('second purchase recomputes weighted-avg correctly', () async {
    final f = FakeFirebaseFirestore();
    final supplies = SupplyRepository(f, ActivityRepository(f));
    final purchases = PurchaseRepository(f, ActivityRepository(f));
    final sid = await supplies.createSupply(
      farmId: 'f1',
      name: 'Feed',
      category: SupplyCategory.feed,
      unit: SupplyUnit.sack,
      unitsPerPackage: null,
      lowStockThreshold: null,
      notes: null,
      actorUserId: 'u',
      actorDisplayName: 'J',
    );

    // First: 10 sacks at 1650.
    await purchases.logPurchase(
      farmId: 'f1',
      vendorName: 'A',
      purchaseDate: Timestamp.now(),
      referenceNo: null,
      lineItems: [
        PurchaseLineItemInput(supplyId: sid, quantity: 10, unitCostPhp: 1650),
      ],
      receiptPhotoUrl: null,
      notes: null,
      actorUserId: 'u',
      actorDisplayName: 'J',
    );
    // Second: 5 sacks at 1750.
    // newAvg = (10*1650 + 5*1750) / 15 = (16500 + 8750) / 15 = 25250 / 15 = 1683.33...
    await purchases.logPurchase(
      farmId: 'f1',
      vendorName: 'B',
      purchaseDate: Timestamp.now(),
      referenceNo: null,
      lineItems: [
        PurchaseLineItemInput(supplyId: sid, quantity: 5, unitCostPhp: 1750),
      ],
      receiptPhotoUrl: null,
      notes: null,
      actorUserId: 'u',
      actorDisplayName: 'J',
    );

    final supply = await f
        .collection('farms')
        .doc('f1')
        .collection('supplies')
        .doc(sid)
        .get();
    expect(supply.data()!['currentStock'], 15);
    expect(
      (supply.data()!['weightedAvgUnitCostPhp'] as num).toDouble(),
      closeTo(1683.33, 0.01),
    );
  });

  test(
    'multi-line purchase atomically writes header + line_items + movements + supply updates',
    () async {
      final f = FakeFirebaseFirestore();
      final supplies = SupplyRepository(f, ActivityRepository(f));
      final purchases = PurchaseRepository(f, ActivityRepository(f));
      final s1 = await supplies.createSupply(
        farmId: 'f1',
        name: 'Feed',
        category: SupplyCategory.feed,
        unit: SupplyUnit.sack,
        unitsPerPackage: null,
        lowStockThreshold: null,
        notes: null,
        actorUserId: 'u',
        actorDisplayName: 'J',
      );
      final s2 = await supplies.createSupply(
        farmId: 'f1',
        name: 'Medicine',
        category: SupplyCategory.medicine,
        unit: SupplyUnit.vial,
        unitsPerPackage: null,
        lowStockThreshold: null,
        notes: null,
        actorUserId: 'u',
        actorDisplayName: 'J',
      );

      await purchases.logPurchase(
        farmId: 'f1',
        vendorName: 'A',
        purchaseDate: Timestamp.now(),
        referenceNo: 'INV-001',
        lineItems: [
          PurchaseLineItemInput(supplyId: s1, quantity: 10, unitCostPhp: 1650),
          PurchaseLineItemInput(supplyId: s2, quantity: 6, unitCostPhp: 250),
        ],
        receiptPhotoUrl: null,
        notes: null,
        actorUserId: 'u',
        actorDisplayName: 'J',
      );

      final purchasesSnap = await f
          .collection('farms')
          .doc('f1')
          .collection('purchases')
          .get();
      expect(purchasesSnap.docs, hasLength(1));
      final p = purchasesSnap.docs.first;
      expect(p.data()['vendorName'], 'A');
      expect(p.data()['totalCostPhp'], 10 * 1650 + 6 * 250);

      final lines = await f
          .collection('farms')
          .doc('f1')
          .collection('purchases')
          .doc(p.id)
          .collection('line_items')
          .get();
      expect(lines.docs, hasLength(2));

      final movements = await f
          .collection('farms')
          .doc('f1')
          .collection('supply_movements')
          .get();
      expect(movements.docs, hasLength(2));
      for (final m in movements.docs) {
        expect(m.data()['type'], 'purchase');
        expect(m.data()['relatedPurchaseId'], p.id);
      }

      final supply1 = await f
          .collection('farms')
          .doc('f1')
          .collection('supplies')
          .doc(s1)
          .get();
      final supply2 = await f
          .collection('farms')
          .doc('f1')
          .collection('supplies')
          .doc(s2)
          .get();
      expect(supply1.data()!['currentStock'], 10);
      expect(supply2.data()!['currentStock'], 6);
    },
  );
}
