import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/features/activity/data/activity_repository.dart';

void main() {
  test('addActivityToBatch writes to farms/{id}/activity/', () async {
    final f = FakeFirebaseFirestore();
    final repo = ActivityRepository(f);
    final batch = f.batch();
    repo.addActivityToBatch(
      batch: batch,
      farmId: 'f1',
      actorUserId: 'u1',
      actorDisplayName: 'Juan',
      action: 'pig_added',
      entityType: 'pig',
      entityId: 'p1',
      areaId: 'a1',
      summary: 'Juan added pig SOW-001',
    );
    await batch.commit();

    final snap = await f.collection('farms').doc('f1').collection('activity').get();
    expect(snap.docs, hasLength(1));
    final d = snap.docs.first.data();
    expect(d['actorUserId'], 'u1');
    expect(d['action'], 'pig_added');
    expect(d['summary'], 'Juan added pig SOW-001');
  });

  test('streamRecent returns entries newest-first, limited', () async {
    final f = FakeFirebaseFirestore();
    for (var i = 0; i < 3; i++) {
      await f.collection('farms').doc('f1').collection('activity').add({
        'actorUserId': 'u1', 'actorDisplayName': 'Juan',
        'action': 'pig_added', 'entityType': 'pig', 'entityId': 'p$i',
        'summary': 's$i',
        'timestamp': Timestamp.fromMillisecondsSinceEpoch(i * 1000),
      });
    }
    final repo = ActivityRepository(f);
    final entries = await repo.streamRecent('f1', limit: 2).first;
    expect(entries, hasLength(2));
    expect(entries[0].summary, 's2');
    expect(entries[1].summary, 's1');
  });
}
