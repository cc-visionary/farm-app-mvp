import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/permissions/role.dart';

enum InvitationStatus {
  pending('pending'),
  accepted('accepted'),
  expired('expired'),
  revoked('revoked');

  const InvitationStatus(this.value);
  final String value;

  static InvitationStatus fromString(String s) =>
      InvitationStatus.values.firstWhere(
        (e) => e.value == s,
        orElse: () => InvitationStatus.pending,
      );
}

class Invitation {
  final String id;
  final String farmId;
  final String email;
  final Role role;
  final List<String> assignedAreaIds;
  final String invitedBy;
  final Timestamp createdAt;
  final Timestamp expiresAt;
  final InvitationStatus status;

  const Invitation({
    required this.id,
    required this.farmId,
    required this.email,
    required this.role,
    required this.assignedAreaIds,
    required this.invitedBy,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
  });

  String get normalizedEmail => email.trim().toLowerCase();

  factory Invitation.fromFirestore(DocumentSnapshot doc, {required String farmId}) {
    final d = doc.data() as Map<String, dynamic>;
    return Invitation(
      id: doc.id,
      farmId: farmId,
      email: d['email'] as String,
      role: Role.fromString(d['role'] as String),
      assignedAreaIds: List<String>.from(d['assignedAreaIds'] ?? const []),
      invitedBy: d['invitedBy'] as String,
      createdAt: d['createdAt'] as Timestamp,
      expiresAt: d['expiresAt'] as Timestamp,
      status: InvitationStatus.fromString(d['status'] as String? ?? 'pending'),
    );
  }

  Map<String, dynamic> toMap() => {
    'email': normalizedEmail,
    'role': role.value,
    'assignedAreaIds': assignedAreaIds,
    'invitedBy': invitedBy,
    'createdAt': createdAt,
    'expiresAt': expiresAt,
    'status': status.value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Invitation &&
          id == other.id && farmId == other.farmId &&
          email == other.email && role == other.role &&
          createdAt == other.createdAt && expiresAt == other.expiresAt &&
          status == other.status && invitedBy == other.invitedBy;

  @override
  int get hashCode => Object.hash(
    id, farmId, email, role, createdAt, expiresAt, status, invitedBy,
  );
}
