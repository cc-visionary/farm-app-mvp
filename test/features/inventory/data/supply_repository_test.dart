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
    );
    final supply = await repo.streamSupplyById(farmId: 'f1', supplyId: id).first;
    expect(supply!.name, 'B');
    expect(supply.lowStockThreshold, 5);
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
}
