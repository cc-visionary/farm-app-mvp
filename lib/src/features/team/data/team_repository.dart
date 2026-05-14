import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/permissions/role.dart';
import '../domain/member.dart';
import '../domain/invitation.dart';

class TeamRepository {
  TeamRepository(this._firestore);
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _members(String farmId) =>
      _firestore.collection('farms').doc(farmId).collection('members');

  CollectionReference<Map<String, dynamic>> _invitations(String farmId) =>
      _firestore.collection('farms').doc(farmId).collection('invitations');

  Future<void> addMember({
    required String farmId,
    required String userId,
    required Role role,
    required List<String> assignedAreaIds,
    required String? invitedBy,
  }) async {
    await _members(farmId).doc(userId).set({
      'role': role.value,
      'assignedAreaIds': assignedAreaIds,
      'joinedAt': FieldValue.serverTimestamp(),
      'invitedBy': invitedBy,
    });
  }

  Stream<List<Member>> streamMembers(String farmId) {
    return _members(farmId).snapshots().map((s) => s.docs
        .map((d) => Member.fromFirestore(d, farmId: farmId))
        .where((m) => m.removedAt == null)
        .toList());
  }

  Stream<Member?> streamMember({required String farmId, required String userId}) {
    return _members(farmId).doc(userId).snapshots().map(
      (d) => d.exists ? Member.fromFirestore(d, farmId: farmId) : null,
    );
  }

  Future<void> updateMemberRole({
    required String farmId,
    required String userId,
    required Role newRole,
  }) async {
    await _members(farmId).doc(userId).update({'role': newRole.value});
  }

  Future<void> updateMemberAreaAssignments({
    required String farmId,
    required String userId,
    required List<String> assignedAreaIds,
  }) async {
    await _members(farmId).doc(userId).update({'assignedAreaIds': assignedAreaIds});
  }

  Future<void> removeMember({required String farmId, required String userId}) async {
    await _members(farmId).doc(userId).update({'removedAt': FieldValue.serverTimestamp()});
  }

  Future<String> createInvitation({
    required String farmId,
    required String email,
    required Role role,
    required List<String> assignedAreaIds,
    required String invitedBy,
  }) async {
    final normalized = email.trim().toLowerCase();
    final doc = _invitations(farmId).doc();
    final now = Timestamp.now();
    final expires = Timestamp.fromDate(now.toDate().add(const Duration(days: 14)));
    await doc.set({
      'email': normalized,
      'role': role.value,
      'assignedAreaIds': assignedAreaIds,
      'invitedBy': invitedBy,
      'createdAt': now,
      'expiresAt': expires,
      'status': 'pending',
    });
    return doc.id;
  }

  Stream<List<Invitation>> streamInvitations(String farmId) {
    return _invitations(farmId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Invitation.fromFirestore(d, farmId: farmId)).toList());
  }

  Future<void> revokeInvitation({required String farmId, required String invitationId}) async {
    await _invitations(farmId).doc(invitationId).update({'status': 'revoked'});
  }

  /// Collection-group query on `invitations` to find all pending invites for an email
  /// across every farm.
  Future<List<Invitation>> findPendingInvitationsForEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    final snap = await _firestore
        .collectionGroup('invitations')
        .where('email', isEqualTo: normalized)
        .where('status', isEqualTo: 'pending')
        .get();
    return snap.docs.map((d) {
      final farmId = d.reference.parent.parent!.id;
      return Invitation.fromFirestore(d, farmId: farmId);
    }).toList();
  }

  Future<void> acceptInvitation({
    required String farmId,
    required String invitationId,
    required String userId,
  }) async {
    final invRef = _invitations(farmId).doc(invitationId);
    final memberRef = _members(farmId).doc(userId);
    final inv = await invRef.get();
    final d = inv.data()!;
    final batch = _firestore.batch();
    batch.set(memberRef, {
      'role': d['role'],
      'assignedAreaIds': d['assignedAreaIds'] ?? const [],
      'joinedAt': FieldValue.serverTimestamp(),
      'invitedBy': d['invitedBy'],
    });
    batch.update(invRef, {'status': 'accepted'});
    await batch.commit();
  }

  /// Collection-group query on `members` to list all farms a user belongs to.
  Stream<List<Member>> streamUserMemberships(String userId) {
    return _firestore
        .collectionGroup('members')
        .where(FieldPath.documentId, isEqualTo: userId)
        .snapshots()
        .map((s) {
          return s.docs.map((d) {
            final farmId = d.reference.parent.parent!.id;
            return Member.fromFirestore(d, farmId: farmId);
          }).where((m) => m.removedAt == null).toList();
        });
  }
}
