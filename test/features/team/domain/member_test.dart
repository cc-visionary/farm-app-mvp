import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/features/team/domain/member.dart';
import 'package:farm_app/src/core/permissions/role.dart';

void main() {
  test('Member round-trips through map', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('farms').doc('f1').collection('members').doc('u1').set({
      'role': 'worker',
      'assignedAreaIds': ['a1', 'a2'],
      'joinedAt': Timestamp.fromMillisecondsSinceEpoch(1000),
      'invitedBy': 'u-owner',
    });
    final doc = await firestore.collection('farms').doc('f1').collection('members').doc('u1').get();
    final m = Member.fromFirestore(doc, farmId: 'f1');

    expect(m.userId, 'u1');
    expect(m.farmId, 'f1');
    expect(m.role, Role.worker);
    expect(m.assignedAreaIds, ['a1', 'a2']);
    expect(m.invitedBy, 'u-owner');
    expect(m.joinedAt.millisecondsSinceEpoch, 1000);

    final back = m.toMap();
    expect(back['role'], 'worker');
    expect(back['assignedAreaIds'], ['a1', 'a2']);
    expect(back['invitedBy'], 'u-owner');
  });

  test('Member equality is by field', () {
    final t = Timestamp.fromMillisecondsSinceEpoch(1000);
    final a = Member(
      userId: 'u1', farmId: 'f1', role: Role.owner,
      assignedAreaIds: const [], joinedAt: t, invitedBy: null,
    );
    final b = Member(
      userId: 'u1', farmId: 'f1', role: Role.owner,
      assignedAreaIds: const [], joinedAt: t, invitedBy: null,
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });
}
