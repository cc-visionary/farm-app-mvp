import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/features/activity/data/activity_repository.dart';
import 'package:farm_app/src/features/pigs/data/pig_repository.dart';
import 'package:farm_app/src/features/pigs/domain/pig.dart';

void main() {
  ({PigRepository repo, FakeFirebaseFirestore firestore}) newRepo() {
    final f = FakeFirebaseFirestore();
    return (repo: PigRepository(f, ActivityRepository(f)), firestore: f);
  }

  test('createPig writes pig + activity entry', () async {
    final t = newRepo();
    final id = await t.repo.createPig(
      farmId: 'f1',
      tagId: 'SOW-001',
      sex: PigSex.female,
      breed: 'Yorkshire',
      birthDate: Timestamp.fromMillisecondsSinceEpoch(1700000000000),
      sireId: null,
      damId: null,
      stage: PigStage.sow,
      currentAreaId: 'a1',
      currentPenId: null,
      currentWeight: null,
      photoUrl: null,
      notes: null,
      actorUserId: 'u1',
      actorDisplayName: 'Juan',
    );
    expect(id, isNotEmpty);

    final doc =
        await t.firestore.collection('farms').doc('f1').collection('pigs').doc(id).get();
    expect(doc.exists, isTrue);
    final data = doc.data()!;
    expect(data['tagId'], 'SOW-001');
    expect(data['sex'], 'female');
    expect(data['stage'], 'sow');
    expect(data['status'], 'active');

    final activity = await t.firestore
        .collection('farms')
        .doc('f1')
        .collection('activity')
        .get();
    expect(activity.docs, hasLength(1));
    expect(activity.docs.first.data()['action'], 'pig_added');
    expect(activity.docs.first.data()['entityId'], id);
  });

  test('updatePig changes stage', () async {
    final t = newRepo();
    final id = await t.repo.createPig(
      farmId: 'f1',
      tagId: 'P1',
      sex: PigSex.female,
      breed: 'X',
      birthDate: Timestamp.now(),
      sireId: null,
      damId: null,
      stage: PigStage.gilt,
      currentAreaId: 'a1',
      currentPenId: null,
      currentWeight: null,
      photoUrl: null,
      notes: null,
      actorUserId: 'u',
      actorDisplayName: 'J',
    );
    await t.repo.updatePig(
      farmId: 'f1',
      pigId: id,
      tagId: 'P1',
      sex: PigSex.female,
      breed: 'X',
      birthDate: Timestamp.now(),
      sireId: null,
      damId: null,
      stage: PigStage.sow,
      currentAreaId: 'a1',
      currentPenId: null,
      currentWeight: null,
      photoUrl: null,
      notes: null,
    );
    final pig = await t.repo.streamPigById(farmId: 'f1', pigId: id).first;
    expect(pig!.stage, PigStage.sow);
  });

  test('movePig updates area + pen + writes activity', () async {
    final t = newRepo();
    final id = await t.repo.createPig(
      farmId: 'f1',
      tagId: 'P1',
      sex: PigSex.male,
      breed: 'X',
      birthDate: Timestamp.now(),
      sireId: null,
      damId: null,
      stage: PigStage.grower,
      currentAreaId: 'a1',
      currentPenId: 'pen1',
      currentWeight: null,
      photoUrl: null,
      notes: null,
      actorUserId: 'u',
      actorDisplayName: 'J',
    );
    await t.repo.movePig(
      farmId: 'f1',
      pigId: id,
      tagId: 'P1',
      newAreaId: 'a2',
      newPenId: 'pen2',
      actorUserId: 'u',
      actorDisplayName: 'J',
    );
    final pig = await t.repo.streamPigById(farmId: 'f1', pigId: id).first;
    expect(pig!.currentAreaId, 'a2');
    expect(pig.currentPenId, 'pen2');

    final activity = await t.firestore
        .collection('farms')
        .doc('f1')
        .collection('activity')
        .where('action', isEqualTo: 'pig_moved')
        .get();
    expect(activity.docs, hasLength(1));
  });

  test('logWeight updates currentWeight + activity', () async {
    final t = newRepo();
    final id = await t.repo.createPig(
      farmId: 'f1',
      tagId: 'X',
      sex: PigSex.male,
      breed: 'X',
      birthDate: Timestamp.now(),
      sireId: null,
      damId: null,
      stage: PigStage.grower,
      currentAreaId: 'a',
      currentPenId: null,
      currentWeight: null,
      photoUrl: null,
      notes: null,
      actorUserId: 'u',
      actorDisplayName: 'J',
    );
    await t.repo.logWeight(
      farmId: 'f1',
      pigId: id,
      tagId: 'X',
      weight: 45.5,
      actorUserId: 'u',
      actorDisplayName: 'J',
    );
    final pig = await t.repo.streamPigById(farmId: 'f1', pigId: id).first;
    expect(pig!.currentWeight, 45.5);

    final activity = await t.firestore
        .collection('farms')
        .doc('f1')
        .collection('activity')
        .where('action', isEqualTo: 'weight_logged')
        .get();
    expect(activity.docs, hasLength(1));
  });

  test('setStatus changes status and writes activity', () async {
    final t = newRepo();
    final id = await t.repo.createPig(
      farmId: 'f1',
      tagId: 'B',
      sex: PigSex.female,
      breed: 'X',
      birthDate: Timestamp.now(),
      sireId: null,
      damId: null,
      stage: PigStage.sow,
      currentAreaId: 'a',
      currentPenId: null,
      currentWeight: null,
      photoUrl: null,
      notes: null,
      actorUserId: 'u',
      actorDisplayName: 'J',
    );
    await t.repo.setStatus(
      farmId: 'f1',
      pigId: id,
      tagId: 'B',
      status: PigStatus.sold,
      actorUserId: 'u',
      actorDisplayName: 'J',
    );
    final pig = await t.repo.streamPigById(farmId: 'f1', pigId: id).first;
    expect(pig!.status, PigStatus.sold);
  });

  test('setBatch updates pig.currentBatchId and writes activity', () async {
    final t = newRepo();
    final id = await t.repo.createPig(
      farmId: 'f1',
      tagId: 'P',
      sex: PigSex.female,
      breed: 'X',
      birthDate: Timestamp.now(),
      sireId: null,
      damId: null,
      stage: PigStage.sow,
      currentAreaId: 'a1',
      currentPenId: null,
      currentWeight: null,
      photoUrl: null,
      notes: null,
      actorUserId: 'u',
      actorDisplayName: 'J',
    );
    await t.repo.setBatch(
      farmId: 'f1',
      pigId: id,
      batchId: 'b1',
      actorUserId: 'u',
      actorDisplayName: 'J',
    );
    final pig = await t.repo.streamPigById(farmId: 'f1', pigId: id).first;
    expect(pig!.currentBatchId, 'b1');

    final activity = await t.firestore
        .collection('farms')
        .doc('f1')
        .collection('activity')
        .where('action', isEqualTo: 'pig_batch_changed')
        .get();
    expect(activity.docs, hasLength(1));
    expect(activity.docs.first.data()['entityId'], id);
  });

  test('streamPigs returns all pigs (active and inactive)', () async {
    final t = newRepo();
    await t.repo.createPig(
      farmId: 'f1',
      tagId: 'A',
      sex: PigSex.male,
      breed: 'X',
      birthDate: Timestamp.now(),
      sireId: null,
      damId: null,
      stage: PigStage.grower,
      currentAreaId: 'a',
      currentPenId: null,
      currentWeight: null,
      photoUrl: null,
      notes: null,
      actorUserId: 'u',
      actorDisplayName: 'J',
    );
    final id = await t.repo.createPig(
      farmId: 'f1',
      tagId: 'B',
      sex: PigSex.female,
      breed: 'X',
      birthDate: Timestamp.now(),
      sireId: null,
      damId: null,
      stage: PigStage.sow,
      currentAreaId: 'a',
      currentPenId: null,
      currentWeight: null,
      photoUrl: null,
      notes: null,
      actorUserId: 'u',
      actorDisplayName: 'J',
    );
    await t.repo.setStatus(
      farmId: 'f1',
      pigId: id,
      tagId: 'B',
      status: PigStatus.sold,
      actorUserId: 'u',
      actorDisplayName: 'J',
    );
    final list = await t.repo.streamPigs('f1').first;
    expect(list.length, 2);
    final activeOnly = list.where((p) => p.status == PigStatus.active).toList();
    expect(activeOnly, hasLength(1));
  });
}
