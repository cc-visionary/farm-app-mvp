import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/permissions/role.dart';

class Member {
  final String userId;
  final String farmId;
  final Role role;
  final List<String> assignedAreaIds;
  final Timestamp joinedAt;
  final String? invitedBy;
  final Timestamp? removedAt;

  const Member({
    required this.userId,
    required this.farmId,
    required this.role,
    required this.assignedAreaIds,
    required this.joinedAt,
    required this.invitedBy,
    this.removedAt,
  });

  factory Member.fromFirestore(DocumentSnapshot doc, {required String farmId}) {
    final data = doc.data() as Map<String, dynamic>;
    return Member(
      userId: doc.id,
      farmId: farmId,
      role: Role.fromString(data['role'] as String? ?? 'worker'),
      assignedAreaIds: List<String>.from(data['assignedAreaIds'] ?? const []),
      joinedAt: data['joinedAt'] as Timestamp? ?? Timestamp.now(),
      invitedBy: data['invitedBy'] as String?,
      removedAt: data['removedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => {
    'role': role.value,
    'assignedAreaIds': assignedAreaIds,
    'joinedAt': joinedAt,
    'invitedBy': invitedBy,
    if (removedAt != null) 'removedAt': removedAt,
  };

  Member copyWith({
    Role? role,
    List<String>? assignedAreaIds,
    Timestamp? removedAt,
  }) => Member(
    userId: userId,
    farmId: farmId,
    role: role ?? this.role,
    assignedAreaIds: assignedAreaIds ?? this.assignedAreaIds,
    joinedAt: joinedAt,
    invitedBy: invitedBy,
    removedAt: removedAt ?? this.removedAt,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Member &&
          userId == other.userId &&
          farmId == other.farmId &&
          role == other.role &&
          _listEquals(assignedAreaIds, other.assignedAreaIds) &&
          joinedAt == other.joinedAt &&
          invitedBy == other.invitedBy &&
          removedAt == other.removedAt;

  @override
  int get hashCode => Object.hash(
    userId, farmId, role, Object.hashAll(assignedAreaIds),
    joinedAt, invitedBy, removedAt,
  );
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
