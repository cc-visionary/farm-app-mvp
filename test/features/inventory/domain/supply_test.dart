import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/features/inventory/domain/supply.dart';
import 'package:farm_app/src/features/inventory/domain/supply_category.dart';

void main() {
  test('Supply round-trips through Firestore', () async {
    final f = FakeFirebaseFirestore();
    final t = Timestamp.fromMillisecondsSinceEpoch(1700000000000);
    await f
        .collection('farms')
        .doc('f1')
        .collection('supplies')
        .doc('s1')
        .set({
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
    final doc = await f
        .collection('farms')
        .doc('f1')
        .collection('supplies')
        .doc('s1')
        .get();
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
      id: 's',
      farmId: 'f',
      name: 'X',
      category: SupplyCategory.feed,
      unit: SupplyUnit.sack,
      unitsPerPackage: null,
      lowStockThreshold: 5,
      currentStock: 3,
      weightedAvgUnitCostPhp: 100.0,
      notes: null,
      createdBy: 'u',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    );
    expect(base.isLowStock, true);
    expect(base.copyWith(currentStock: 5).isLowStock, false);
    expect(base.copyWith(currentStock: 6).isLowStock, false);
  });

  test('Supply.isOutOfStock when currentStock is 0 or negative', () {
    final base = Supply(
      id: 's',
      farmId: 'f',
      name: 'X',
      category: SupplyCategory.feed,
      unit: SupplyUnit.sack,
      unitsPerPackage: null,
      lowStockThreshold: 5,
      currentStock: 0,
      weightedAvgUnitCostPhp: 0,
      notes: null,
      createdBy: 'u',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    );
    expect(base.isOutOfStock, true);
    expect(base.copyWith(currentStock: 1).isOutOfStock, false);
  });

  test('Supply with null lowStockThreshold is never low-stock', () {
    final base = Supply(
      id: 's',
      farmId: 'f',
      name: 'X',
      category: SupplyCategory.feed,
      unit: SupplyUnit.sack,
      unitsPerPackage: null,
      lowStockThreshold: null,
      currentStock: 0,
      weightedAvgUnitCostPhp: 0,
      notes: null,
      createdBy: 'u',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    );
    expect(base.isLowStock, false);
    expect(base.isOutOfStock, true);
  });
}
