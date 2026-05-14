import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/features/activity/domain/activity_entry.dart';

void main() {
  test('ActivityEntry round-trips', () async {
    final f = FakeFirebaseFirestore();
    final t = Timestamp.fromMillisecondsSinceEpoch(3000);
    await f.collection('farms').doc('f1').collection('activity').doc('e1').set({
      'actorUserId': 'u1',
      'actorDisplayName': 'Juan',
      'action': 'pig_added',
      'entityType': 'pig',
      'entityId': 'p1',
      'areaId': 'a1',
      'summary': 'Juan added pig SOW-001',
      'timestamp': t,
    });
    final doc = await f.collection('farms').doc('f1').collection('activity').doc('e1').get();
    final e = ActivityEntry.fromFirestore(doc, farmId: 'f1');

    expect(e.id, 'e1');
    expect(e.actorUserId, 'u1');
    expect(e.actorDisplayName, 'Juan');
    expect(e.action, 'pig_added');
    expect(e.entityType, 'pig');
    expect(e.entityId, 'p1');
    expect(e.areaId, 'a1');
    expect(e.summary, 'Juan added pig SOW-001');
    expect(e.timestamp, t);
  });
}
