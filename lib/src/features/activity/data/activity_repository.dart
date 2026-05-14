import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/activity_entry.dart';

class ActivityRepository {
  ActivityRepository(this._firestore);
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _col(String farmId) =>
      _firestore.collection('farms').doc(farmId).collection('activity');

  /// Adds an activity write to an existing batch so the source-record write
  /// and the activity entry land atomically.
  void addActivityToBatch({
    required WriteBatch batch,
    required String farmId,
    required String actorUserId,
    required String actorDisplayName,
    required String action,
    required String entityType,
    required String entityId,
    String? areaId,
    required String summary,
  }) {
    final doc = _col(farmId).doc();
    batch.set(doc, {
      'actorUserId': actorUserId,
      'actorDisplayName': actorDisplayName,
      'action': action,
      'entityType': entityType,
      'entityId': entityId,
      if (areaId != null) 'areaId': areaId,
      'summary': summary,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<ActivityEntry>> streamRecent(String farmId, {int limit = 50}) {
    return _col(farmId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs
            .map((d) => ActivityEntry.fromFirestore(d, farmId: farmId))
            .toList());
  }

  Stream<List<ActivityEntry>> streamFiltered(
    String farmId, {
    int limit = 50,
    List<String>? actorIds,
    List<String>? actions,
    List<String>? areaIds,
  }) {
    Query<Map<String, dynamic>> q = _col(farmId).orderBy('timestamp', descending: true);
    if (actorIds != null && actorIds.isNotEmpty) {
      q = q.where('actorUserId', whereIn: actorIds);
    }
    if (actions != null && actions.isNotEmpty) {
      q = q.where('action', whereIn: actions);
    }
    if (areaIds != null && areaIds.isNotEmpty) {
      q = q.where('areaId', whereIn: areaIds);
    }
    q = q.limit(limit);
    return q.snapshots().map((s) =>
        s.docs.map((d) => ActivityEntry.fromFirestore(d, farmId: farmId)).toList());
  }
}
