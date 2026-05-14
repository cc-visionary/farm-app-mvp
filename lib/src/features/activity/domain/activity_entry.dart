import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityEntry {
  final String id;
  final String farmId;
  final String actorUserId;
  final String actorDisplayName;
  final String action;
  final String entityType;
  final String entityId;
  final String? areaId;
  final String summary;
  final Timestamp timestamp;

  const ActivityEntry({
    required this.id,
    required this.farmId,
    required this.actorUserId,
    required this.actorDisplayName,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.areaId,
    required this.summary,
    required this.timestamp,
  });

  factory ActivityEntry.fromFirestore(DocumentSnapshot doc, {required String farmId}) {
    final d = doc.data() as Map<String, dynamic>;
    return ActivityEntry(
      id: doc.id,
      farmId: farmId,
      actorUserId: d['actorUserId'] as String,
      actorDisplayName: d['actorDisplayName'] as String,
      action: d['action'] as String,
      entityType: d['entityType'] as String,
      entityId: d['entityId'] as String,
      areaId: d['areaId'] as String?,
      summary: d['summary'] as String,
      timestamp: d['timestamp'] as Timestamp,
    );
  }

  Map<String, dynamic> toMap() => {
    'actorUserId': actorUserId,
    'actorDisplayName': actorDisplayName,
    'action': action,
    'entityType': entityType,
    'entityId': entityId,
    if (areaId != null) 'areaId': areaId,
    'summary': summary,
    'timestamp': timestamp,
  };
}
