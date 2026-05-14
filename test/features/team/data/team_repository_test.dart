import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/core/permissions/role.dart';
import 'package:farm_app/src/features/team/data/team_repository.dart';

void main() {
  test('addMember writes to members subcollection', () async {
    final f = FakeFirebaseFirestore();
    final repo = TeamRepository(f);
    await repo.addMember(
      farmId: 'f1', userId: 'u1', role: Role.owner,
      assignedAreaIds: const [], invitedBy: null,
    );
    final doc = await f.collection('farms').doc('f1').collection('members').doc('u1').get();
    expect(doc.exists, true);
    expect(doc.data()!['role'], 'owner');
  });

  test('streamMembers returns all non-removed', () async {
    final f = FakeFirebaseFirestore();
    final repo = TeamRepository(f);
    await repo.addMember(farmId: 'f1', userId: 'u1', role: Role.owner, assignedAreaIds: const [], invitedBy: null);
    await repo.addMember(farmId: 'f1', userId: 'u2', role: Role.worker, assignedAreaIds: const ['a1'], invitedBy: 'u1');
    final members = await repo.streamMembers('f1').first;
    expect(members, hasLength(2));
  });

  test('updateMemberRole changes role', () async {
    final f = FakeFirebaseFirestore();
    final repo = TeamRepository(f);
    await repo.addMember(farmId: 'f1', userId: 'u2', role: Role.worker, assignedAreaIds: const [], invitedBy: 'u1');
    await repo.updateMemberRole(farmId: 'f1', userId: 'u2', newRole: Role.manager);
    final doc = await f.collection('farms').doc('f1').collection('members').doc('u2').get();
    expect(doc.data()!['role'], 'manager');
  });

  test('createInvitation sets normalized email + pending status', () async {
    final f = FakeFirebaseFirestore();
    final repo = TeamRepository(f);
    final id = await repo.createInvitation(
      farmId: 'f1', email: 'NEW@Example.COM', role: Role.worker,
      assignedAreaIds: const ['a1'], invitedBy: 'u1',
    );
    final doc = await f.collection('farms').doc('f1').collection('invitations').doc(id).get();
    expect(doc.data()!['email'], 'new@example.com');
    expect(doc.data()!['status'], 'pending');
  });

  test('findPendingInvitationsForEmail returns matches across farms', () async {
    final f = FakeFirebaseFirestore();
    final repo = TeamRepository(f);
    await repo.createInvitation(farmId: 'f1', email: 'me@x.com', role: Role.worker, assignedAreaIds: const [], invitedBy: 'u1');
    await repo.createInvitation(farmId: 'f2', email: 'me@x.com', role: Role.vet, assignedAreaIds: const [], invitedBy: 'u1');
    final results = await repo.findPendingInvitationsForEmail('me@x.com');
    expect(results, hasLength(2));
  });

  test('acceptInvitation creates member and marks invitation accepted', () async {
    final f = FakeFirebaseFirestore();
    final repo = TeamRepository(f);
    final invId = await repo.createInvitation(
      farmId: 'f1', email: 'me@x.com', role: Role.worker, assignedAreaIds: const ['a1'], invitedBy: 'u1',
    );
    await repo.acceptInvitation(farmId: 'f1', invitationId: invId, userId: 'u-new');
    final memberDoc = await f.collection('farms').doc('f1').collection('members').doc('u-new').get();
    expect(memberDoc.exists, true);
    expect(memberDoc.data()!['role'], 'worker');
    final invDoc = await f.collection('farms').doc('f1').collection('invitations').doc(invId).get();
    expect(invDoc.data()!['status'], 'accepted');
  });

  test('streamUserMemberships returns user farms via collection-group', () async {
    final f = FakeFirebaseFirestore();
    final repo = TeamRepository(f);
    await repo.addMember(farmId: 'f1', userId: 'u-me', role: Role.owner, assignedAreaIds: const [], invitedBy: null);
    await repo.addMember(farmId: 'f2', userId: 'u-me', role: Role.vet, assignedAreaIds: const [], invitedBy: 'u1');
    await repo.addMember(farmId: 'f1', userId: 'u-other', role: Role.worker, assignedAreaIds: const [], invitedBy: null);
    final result = await repo.streamUserMemberships('u-me').first;
    expect(result.map((m) => m.farmId).toSet(), {'f1', 'f2'});
  });
}
