import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: unused_import
import 'package:farm_app/src/core/permissions/role.dart';
import 'package:farm_app/src/features/farms/data/farm_repository.dart';

void main() {
  test('createFarmWithOwner creates farm + owner member atomically', () async {
    final f = FakeFirebaseFirestore();
    final repo = FarmRepository(f);
    final farmId = await repo.createFarmWithOwner(name: 'My Piggery', ownerUserId: 'u1');

    final farmDoc = await f.collection('farms').doc(farmId).get();
    expect(farmDoc.exists, true);
    expect(farmDoc.data()!['name'], 'My Piggery');
    expect(farmDoc.data()!['createdBy'], 'u1');

    final memberDoc = await f.collection('farms').doc(farmId).collection('members').doc('u1').get();
    expect(memberDoc.exists, true);
    expect(memberDoc.data()!['role'], 'owner');
  });

  test('updateFarmName updates name', () async {
    final f = FakeFirebaseFirestore();
    final repo = FarmRepository(f);
    final id = await repo.createFarmWithOwner(name: 'A', ownerUserId: 'u1');
    await repo.updateFarmName(farmId: id, newName: 'B');
    final farmDoc = await f.collection('farms').doc(id).get();
    expect(farmDoc.data()!['name'], 'B');
  });

  test('streamFarm emits the farm doc', () async {
    final f = FakeFirebaseFirestore();
    final repo = FarmRepository(f);
    final id = await repo.createFarmWithOwner(name: 'X', ownerUserId: 'u1');
    final farm = await repo.streamFarm(id).first;
    expect(farm?.name, 'X');
    expect(farm?.id, id);
  });
}
