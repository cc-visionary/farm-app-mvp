import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:farm_app/src/features/activity/data/activity_repository.dart';
import 'package:farm_app/src/features/pigs/data/mortality_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('logMortality sets pig deceased + writes mortality record + activity',
      () async {
    final f = FakeFirebaseFirestore();
    await f.collection('farms').doc('f1').collection('pigs').doc('p1').set({
      'tagId': 'P-001',
      'sex': 'female',
      'breed': 'Landrace',
      'birthDate': Timestamp.now(),
      'stage': 'sow',
      'status': 'active',
      'currentAreaId': 'a1',
      'createdBy': 'u1',
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });

    final repo = MortalityRepository(f, ActivityRepository(f));
    await repo.logMortality(
      farmId: 'f1',
      pigId: 'p1',
      tagId: 'P-001',
      areaId: 'a1',
      date: Timestamp.now(),
      cause: 'respiratory',
      photoUrls: const [],
      notes: null,
      actorUserId: 'u1',
      actorDisplayName: 'Juan',
    );

    // Pig is flipped to deceased.
    final pig =
        await f.collection('farms').doc('f1').collection('pigs').doc('p1').get();
    expect(pig.data()!['status'], 'deceased');

    // Mortality record stored at fixed 'primary' doc.
    final mort = await f
        .collection('farms')
        .doc('f1')
        .collection('pigs')
        .doc('p1')
        .collection('mortality_record')
        .doc('primary')
        .get();
    expect(mort.exists, isTrue);
    expect(mort.data()!['cause'], 'respiratory');

    // Activity entry written atomically.
    final activity =
        await f.collection('farms').doc('f1').collection('activity').get();
    expect(
      activity.docs.where((d) => d.data()['action'] == 'mortality_logged'),
      hasLength(1),
    );
  });
}
