import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/features/activity/data/activity_repository.dart';
import 'package:farm_app/src/features/inventory/data/supply_repository.dart';
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
      farmId: 'f1',
      name: 'A',
      category: SupplyCategory.feed,
      unit: SupplyUnit.sack,
      unitsPerPackage: null,
      lowStockThreshold: null,
      notes: null,
      actorUserId: 'u',
      actorDisplayName: 'J',
    );
    await repo.updateSupply(
      farmId: 'f1',
      supplyId: id,
      name: 'B',
      category: SupplyCategory.feed,
      unit: SupplyUnit.sack,
      unitsPerPackage: null,
      lowStockThreshold: 5,
      notes: null,
      actorUserId: 'u',
      actorDisplayName: 'J',
    );
    final supply = await repo.streamSupplyById(farmId: 'f1', supplyId: id).first;
    expect(supply!.name, 'B');
    expect(supply.lowStockThreshold, 5);
  });

  test('updateSupply writes supply_updated activity atomically', () async {
    final f = FakeFirebaseFirestore();
    final repo = SupplyRepository(f, ActivityRepository(f));
    final id = await repo.createSupply(
      farmId: 'f1',
      name: 'A',
      category: SupplyCategory.feed,
      unit: SupplyUnit.sack,
      unitsPerPackage: null,
      lowStockThreshold: null,
      notes: null,
      actorUserId: 'u',
      actorDisplayName: 'Juan',
    );
    final beforeActivity = (await f
            .collection('farms')
            .doc('f1')
            .collection('activity')
            .get())
        .docs
        .length;

    await repo.updateSupply(
      farmId: 'f1',
      supplyId: id,
      name: 'B',
      category: SupplyCategory.feed,
      unit: SupplyUnit.sack,
      unitsPerPackage: null,
      lowStockThreshold: 5,
      notes: 'updated',
      actorUserId: 'u',
      actorDisplayName: 'Juan',
    );

    final after = await f
        .collection('farms')
        .doc('f1')
        .collection('activity')
        .get();
    expect(after.docs.length, beforeActivity + 1);
    final entry = after.docs.firstWhere(
      (d) => d.data()['action'] == 'supply_updated',
    );
    expect(entry.data()['entityId'], id);
    expect(entry.data()['summary'], contains('B'));
  });

  test('streamSupplies returns sorted by category then name', () async {
    final repo = newRepo();
    await repo.createSupply(
      farmId: 'f1',
      name: 'Zinc supplement',
      category: SupplyCategory.medicine,
      unit: SupplyUnit.vial,
      unitsPerPackage: null,
      lowStockThreshold: null,
      notes: null,
      actorUserId: 'u',
      actorDisplayName: 'J',
    );
    await repo.createSupply(
      farmId: 'f1',
      name: 'Aloe spray',
      category: SupplyCategory.medicine,
      unit: SupplyUnit.ml,
      unitsPerPackage: null,
      lowStockThreshold: null,
      notes: null,
      actorUserId: 'u',
      actorDisplayName: 'J',
    );
    await repo.createSupply(
      farmId: 'f1',
      name: 'Grower feed',
      category: SupplyCategory.feed,
      unit: SupplyUnit.sack,
      unitsPerPackage: null,
      lowStockThreshold: null,
      notes: null,
      actorUserId: 'u',
      actorDisplayName: 'J',
    );
    final list = await repo.streamSupplies('f1').first;
    expect(list.length, 3);
    expect(list[0].category, SupplyCategory.feed);
    expect(list[0].name, 'Grower feed');
    expect(list[1].name, 'Aloe spray');
    expect(list[2].name, 'Zinc supplement');
  });

  group('logConsumption', () {
    test('writes movement, decrements stock, writes activity (atomic)', () async {
      final f = FakeFirebaseFirestore();
      final repo = SupplyRepository(f, ActivityRepository(f));
      final id = await repo.createSupply(
        farmId: 'f1',
        name: 'Feed',
        category: SupplyCategory.feed,
        unit: SupplyUnit.sack,
        unitsPerPackage: 50,
        lowStockThreshold: null,
        notes: null,
        actorUserId: 'u',
        actorDisplayName: 'J',
      );
      // Seed stock manually (createSupply starts at 0).
      await f
          .collection('farms')
          .doc('f1')
          .collection('supplies')
          .doc(id)
          .update({'currentStock': 10});

      await repo.logConsumption(
        farmId: 'f1',
        supplyId: id,
        supplyName: 'Feed',
        quantity: 3,
        penId: 'pen1',
        derivedBatchId: 'batch1',
        healthRecordId: null,
        notes: null,
        actorUserId: 'u',
        actorDisplayName: 'J',
      );

      final supply = await f
          .collection('farms')
          .doc('f1')
          .collection('supplies')
          .doc(id)
          .get();
      expect(supply.data()!['currentStock'], 7);

      final movements = await f
          .collection('farms')
          .doc('f1')
          .collection('supply_movements')
          .get();
      expect(movements.docs, hasLength(1));
      expect(movements.docs.first.data()['quantity'], -3);
      expect(movements.docs.first.data()['type'], 'consumption');
      expect(movements.docs.first.data()['relatedPenId'], 'pen1');
      expect(movements.docs.first.data()['relatedBatchId'], 'batch1');

      final activity = await f
          .collection('farms')
          .doc('f1')
          .collection('activity')
          .get();
      final logEntry = activity.docs.where(
        (d) => d.data()['action'] == 'supply_consumed',
      );
      expect(logEntry, hasLength(1));
    });

    test('rejects consumption exceeding currentStock', () async {
      final f = FakeFirebaseFirestore();
      final repo = SupplyRepository(f, ActivityRepository(f));
      final id = await repo.createSupply(
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
      await f
          .collection('farms')
          .doc('f1')
          .collection('supplies')
          .doc(id)
          .update({'currentStock': 2});
      expect(
        () => repo.logConsumption(
          farmId: 'f1',
          supplyId: id,
          supplyName: 'Feed',
          quantity: 5,
          penId: null,
          derivedBatchId: null,
          healthRecordId: null,
          notes: null,
          actorUserId: 'u',
          actorDisplayName: 'J',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects negative or zero quantity', () async {
      final f = FakeFirebaseFirestore();
      final repo = SupplyRepository(f, ActivityRepository(f));
      final id = await repo.createSupply(
        farmId: 'f1',
        name: 'F',
        category: SupplyCategory.feed,
        unit: SupplyUnit.sack,
        unitsPerPackage: null,
        lowStockThreshold: null,
        notes: null,
        actorUserId: 'u',
        actorDisplayName: 'J',
      );
      expect(
        () => repo.logConsumption(
          farmId: 'f1',
          supplyId: id,
          supplyName: 'F',
          quantity: 0,
          penId: null,
          derivedBatchId: null,
          healthRecordId: null,
          notes: null,
          actorUserId: 'u',
          actorDisplayName: 'J',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
