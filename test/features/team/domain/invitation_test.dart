import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/features/team/domain/invitation.dart';
import 'package:farm_app/src/core/permissions/role.dart';

void main() {
  test('Invitation round-trips', () async {
    final f = FakeFirebaseFirestore();
    final t = Timestamp.fromMillisecondsSinceEpoch(2000);
    await f.collection('farms').doc('f1').collection('invitations').doc('i1').set({
      'email': 'juan@example.com',
      'role': 'worker',
      'assignedAreaIds': ['a1'],
      'invitedBy': 'u-owner',
      'createdAt': t,
      'expiresAt': Timestamp.fromMillisecondsSinceEpoch(99999999),
      'status': 'pending',
    });
    final doc = await f.collection('farms').doc('f1').collection('invitations').doc('i1').get();
    final inv = Invitation.fromFirestore(doc, farmId: 'f1');

    expect(inv.id, 'i1');
    expect(inv.farmId, 'f1');
    expect(inv.email, 'juan@example.com');
    expect(inv.role, Role.worker);
    expect(inv.assignedAreaIds, ['a1']);
    expect(inv.status, InvitationStatus.pending);
  });

  test('Email is normalized to lowercase', () {
    final inv = Invitation(
      id: 'x', farmId: 'f', email: 'JOSE@Example.COM',
      role: Role.worker, assignedAreaIds: const [], invitedBy: 'u',
      createdAt: Timestamp.now(), expiresAt: Timestamp.now(),
      status: InvitationStatus.pending,
    );
    expect(inv.normalizedEmail, 'jose@example.com');
  });
}
