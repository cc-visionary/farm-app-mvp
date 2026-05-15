import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/features/equipment/data/equipment_repository.dart';
import 'package:farm_app/src/features/equipment/domain/equipment.dart';
import 'package:farm_app/src/features/equipment/domain/maintenance_record.dart';
import 'package:farm_app/src/features/activity/data/activity_repository.dart';

void main() {
  test('createEquipment writes and emits activity', () async {
    final f = FakeFirebaseFirestore();
    final repo = EquipmentRepository(f, ActivityRepository(f));
    final id = await repo.createEquipment(
      farmId: 'f1',
      name: 'Fan A',
      type: EquipmentType.ventilation,
      areaId: 'a1',
      status: EquipmentStatus.inUse,
      purchaseDate: null,
      purchaseCostPhp: null,
      photoUrl: null,
      notes: null,
      actorUserId: 'u1',
      actorDisplayName: 'Juan',
    );
    final eq =
        await f.collection('farms').doc('f1').collection('equipment').doc(id).get();
    expect(eq.data()!['name'], 'Fan A');
    final activity =
        await f.collection('farms').doc('f1').collection('activity').get();
    expect(activity.docs, hasLength(1));
    expect(activity.docs.first.data()['action'], 'equipment_added');
  });

  test('quickToggleStatus cycles status', () async {
    final f = FakeFirebaseFirestore();
    final repo = EquipmentRepository(f, ActivityRepository(f));
    final id = await repo.createEquipment(
      farmId: 'f1',
      name: 'X',
      type: EquipmentType.tool,
      areaId: null,
      status: EquipmentStatus.available,
      purchaseDate: null,
      purchaseCostPhp: null,
      photoUrl: null,
      notes: null,
      actorUserId: 'u1',
      actorDisplayName: 'J',
    );
    await repo.quickToggleStatus(
      farmId: 'f1',
      equipmentId: id,
      actorUserId: 'u1',
      actorDisplayName: 'J',
    );
    final eq =
        await f.collection('farms').doc('f1').collection('equipment').doc(id).get();
    expect(eq.data()!['status'], 'needs_repair');
  });

  test('updateEquipment writes equipment_updated activity atomically',
      () async {
    final f = FakeFirebaseFirestore();
    final repo = EquipmentRepository(f, ActivityRepository(f));
    final id = await repo.createEquipment(
      farmId: 'f1',
      name: 'Fan A',
      type: EquipmentType.ventilation,
      areaId: 'a1',
      status: EquipmentStatus.inUse,
      purchaseDate: null,
      purchaseCostPhp: null,
      photoUrl: null,
      notes: null,
      actorUserId: 'u1',
      actorDisplayName: 'Juan',
    );
    final beforeActivity = (await f
            .collection('farms')
            .doc('f1')
            .collection('activity')
            .get())
        .docs
        .length;

    await repo.updateEquipment(
      farmId: 'f1',
      equipmentId: id,
      name: 'Fan A (renamed)',
      type: EquipmentType.ventilation,
      areaId: 'a1',
      status: EquipmentStatus.inUse,
      purchaseDate: null,
      purchaseCostPhp: null,
      photoUrl: null,
      notes: 'updated',
      actorUserId: 'u1',
      actorDisplayName: 'Juan',
    );

    final afterActivity = await f
        .collection('farms')
        .doc('f1')
        .collection('activity')
        .get();
    expect(afterActivity.docs.length, beforeActivity + 1);
    final last = afterActivity.docs.firstWhere(
      (d) => d.data()['action'] == 'equipment_updated',
    );
    expect(last.data()['entityId'], id);
    expect(last.data()['summary'], contains('Fan A (renamed)'));
  });

  test('logMaintenance writes record + activity', () async {
    final f = FakeFirebaseFirestore();
    final repo = EquipmentRepository(f, ActivityRepository(f));
    final id = await repo.createEquipment(
      farmId: 'f1',
      name: 'Y',
      type: EquipmentType.feeder,
      areaId: 'a1',
      status: EquipmentStatus.inUse,
      purchaseDate: null,
      purchaseCostPhp: null,
      photoUrl: null,
      notes: null,
      actorUserId: 'u1',
      actorDisplayName: 'J',
    );
    await repo.logMaintenance(
      farmId: 'f1',
      equipmentId: id,
      equipmentName: 'Y',
      type: MaintenanceType.repair,
      date: Timestamp.now(),
      performedBy: 'ACME Repairs',
      partsReplaced: 'belt',
      costPhp: 500,
      photoUrls: const [],
      notes: null,
      actorUserId: 'u1',
      actorDisplayName: 'J',
    );
    final maint = await f
        .collection('farms')
        .doc('f1')
        .collection('equipment')
        .doc(id)
        .collection('maintenance_records')
        .get();
    expect(maint.docs, hasLength(1));
    final activity =
        await f.collection('farms').doc('f1').collection('activity').get();
    expect(
      activity.docs.where((d) => d.data()['action'] == 'maintenance_logged'),
      hasLength(1),
    );
  });
}
