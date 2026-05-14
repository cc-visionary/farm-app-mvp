import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:farm_app/src/features/activity/data/activity_repository.dart';
import 'package:farm_app/src/features/pigs/data/breeding_repository.dart';
import 'package:farm_app/src/features/pigs/domain/breeding_record.dart';
import 'package:farm_app/src/features/tasks/application/task_generator.dart';
import 'package:farm_app/src/features/tasks/data/task_repository.dart';
import 'package:flutter_test/flutter_test.dart';

({BreedingRepository repo, FakeFirebaseFirestore firestore}) newRepo() {
  final f = FakeFirebaseFirestore();
  final activity = ActivityRepository(f);
  final gen = TaskGenerator(f, TaskRepository(f));
  return (repo: BreedingRepository(f, activity, gen), firestore: f);
}

void main() {
  test(
      'logBreeding writes breeding record + 3 derived tasks + activity entry atomically',
      () async {
    final t = newRepo();
    final ins = Timestamp.fromMillisecondsSinceEpoch(1700000000000);

    final id = await t.repo.logBreeding(
      farmId: 'f1',
      sowId: 'sow1',
      sowTagId: 'SOW-001',
      sowAreaId: 'a1',
      boarId: 'boar1',
      heatDate: null,
      inseminationDate: ins,
      method: BreedingMethod.ai,
      notes: 'first AI cycle',
      actorUserId: 'u1',
      actorDisplayName: 'Juan',
    );

    // Breeding record exists with computed expectedFarrowingDate (ins + 114d).
    final br = await t.firestore
        .collection('farms')
        .doc('f1')
        .collection('pigs')
        .doc('sow1')
        .collection('breeding_records')
        .doc(id)
        .get();
    expect(br.exists, isTrue);
    expect(br.data()!['boarId'], 'boar1');
    expect(br.data()!['method'], 'ai');
    expect(br.data()!['status'], 'planned');
    expect(br.data()!['confirmed'], isFalse);
    expect(
      (br.data()!['expectedFarrowingDate'] as Timestamp).toDate(),
      ins.toDate().add(const Duration(days: 114)),
    );

    // Three derived tasks exist with the right types + idempotent IDs.
    final tasksSnap =
        await t.firestore.collection('farms').doc('f1').collection('tasks').get();
    expect(tasksSnap.docs, hasLength(3));
    final ids = tasksSnap.docs.map((d) => d.id).toSet();
    expect(ids, {'br_${id}_preg', 'br_${id}_prep', 'br_${id}_farr'});
    final types = tasksSnap.docs.map((d) => d.data()['type']).toSet();
    expect(types, {'pregnancy_check', 'farrowing_prep', 'farrowing_expected'});

    // Activity entry recorded.
    final activity = await t.firestore
        .collection('farms')
        .doc('f1')
        .collection('activity')
        .get();
    expect(activity.docs, hasLength(1));
    expect(activity.docs.single.data()['action'], 'breeding_logged');
    expect(activity.docs.single.data()['entityId'], 'sow1');
  });

  test(
      'recordPregnancyCheck(confirmed=true) updates record + completes preg task',
      () async {
    final t = newRepo();
    final ins = Timestamp.fromMillisecondsSinceEpoch(1700000000000);
    final id = await t.repo.logBreeding(
      farmId: 'f1',
      sowId: 'sow1',
      sowTagId: 'SOW-001',
      sowAreaId: 'a1',
      boarId: 'boar1',
      heatDate: null,
      inseminationDate: ins,
      method: BreedingMethod.natural,
      notes: null,
      actorUserId: 'u1',
      actorDisplayName: 'Juan',
    );

    await t.repo.recordPregnancyCheck(
      farmId: 'f1',
      sowId: 'sow1',
      breedingRecordId: id,
      confirmed: true,
      checkDate: Timestamp.fromMillisecondsSinceEpoch(1702592000000),
      actorUserId: 'u1',
      actorDisplayName: 'Juan',
      sowTagId: 'SOW-001',
      areaId: 'a1',
    );

    final br = await t.firestore
        .collection('farms')
        .doc('f1')
        .collection('pigs')
        .doc('sow1')
        .collection('breeding_records')
        .doc(id)
        .get();
    expect(br.data()!['status'], 'confirmed');
    expect(br.data()!['confirmed'], isTrue);
    expect(br.data()!['pregnancyCheckDate'], isNotNull);

    final preg = await t.firestore
        .collection('farms')
        .doc('f1')
        .collection('tasks')
        .doc('br_${id}_preg')
        .get();
    expect(preg.data()!['status'], 'completed');
    expect(preg.data()!['completedBy'], 'u1');

    // Downstream tasks stay open when pregnancy is confirmed.
    final prep = await t.firestore
        .collection('farms')
        .doc('f1')
        .collection('tasks')
        .doc('br_${id}_prep')
        .get();
    final farr = await t.firestore
        .collection('farms')
        .doc('f1')
        .collection('tasks')
        .doc('br_${id}_farr')
        .get();
    expect(prep.data()!['status'], 'open');
    expect(farr.data()!['status'], 'open');

    // pregnancy_check_logged activity recorded.
    final activity = await t.firestore
        .collection('farms')
        .doc('f1')
        .collection('activity')
        .where('action', isEqualTo: 'pregnancy_check_logged')
        .get();
    expect(activity.docs, hasLength(1));
  });

  test(
      'recordPregnancyCheck(confirmed=false) marks preg complete + prep/farr skipped',
      () async {
    final t = newRepo();
    final ins = Timestamp.fromMillisecondsSinceEpoch(1700000000000);
    final id = await t.repo.logBreeding(
      farmId: 'f1',
      sowId: 'sow1',
      sowTagId: 'SOW-001',
      sowAreaId: 'a1',
      boarId: 'boar1',
      heatDate: null,
      inseminationDate: ins,
      method: BreedingMethod.natural,
      notes: null,
      actorUserId: 'u1',
      actorDisplayName: 'Juan',
    );

    await t.repo.recordPregnancyCheck(
      farmId: 'f1',
      sowId: 'sow1',
      breedingRecordId: id,
      confirmed: false,
      checkDate: Timestamp.fromMillisecondsSinceEpoch(1702592000000),
      actorUserId: 'u1',
      actorDisplayName: 'Juan',
      sowTagId: 'SOW-001',
      areaId: 'a1',
    );

    final br = await t.firestore
        .collection('farms')
        .doc('f1')
        .collection('pigs')
        .doc('sow1')
        .collection('breeding_records')
        .doc(id)
        .get();
    expect(br.data()!['status'], 'failed');
    expect(br.data()!['confirmed'], isFalse);

    final preg = await t.firestore
        .collection('farms')
        .doc('f1')
        .collection('tasks')
        .doc('br_${id}_preg')
        .get();
    expect(preg.data()!['status'], 'completed');

    final prep = await t.firestore
        .collection('farms')
        .doc('f1')
        .collection('tasks')
        .doc('br_${id}_prep')
        .get();
    final farr = await t.firestore
        .collection('farms')
        .doc('f1')
        .collection('tasks')
        .doc('br_${id}_farr')
        .get();
    expect(prep.data()!['status'], 'skipped');
    expect(farr.data()!['status'], 'skipped');
  });

  test('markFarrowed updates breeding record status to farrowed', () async {
    final t = newRepo();
    final ins = Timestamp.fromMillisecondsSinceEpoch(1700000000000);
    final id = await t.repo.logBreeding(
      farmId: 'f1',
      sowId: 'sow1',
      sowTagId: 'SOW-001',
      sowAreaId: 'a1',
      boarId: 'boar1',
      heatDate: null,
      inseminationDate: ins,
      method: BreedingMethod.natural,
      notes: null,
      actorUserId: 'u1',
      actorDisplayName: 'Juan',
    );

    await t.repo.markFarrowed(
      farmId: 'f1',
      sowId: 'sow1',
      breedingRecordId: id,
    );

    final br = await t.firestore
        .collection('farms')
        .doc('f1')
        .collection('pigs')
        .doc('sow1')
        .collection('breeding_records')
        .doc(id)
        .get();
    expect(br.data()!['status'], 'farrowed');
  });
}
