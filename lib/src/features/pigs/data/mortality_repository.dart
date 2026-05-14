import 'package:cloud_firestore/cloud_firestore.dart';
import '../../activity/data/activity_repository.dart';
import '../domain/mortality_record.dart';

/// Per-pig mortality record. There is at most ONE mortality record per pig,
/// stored at a fixed `primary` doc under `pigs/{pigId}/mortality_record/`.
///
/// `logMortality` writes the record, flips the pig's `status` to `deceased`,
/// and writes an activity entry — all in a single atomic [WriteBatch].
class MortalityRepository {
  MortalityRepository(this._firestore, this._activity);
  final FirebaseFirestore _firestore;
  final ActivityRepository _activity;

  DocumentReference<Map<String, dynamic>> _doc(String farmId, String pigId) =>
      _firestore
          .collection('farms')
          .doc(farmId)
          .collection('pigs')
          .doc(pigId)
          .collection('mortality_record')
          .doc('primary');

  Future<void> logMortality({
    required String farmId,
    required String pigId,
    required String tagId,
    required String areaId,
    required Timestamp date,
    required String? cause,
    required List<String> photoUrls,
    required String? notes,
    required String actorUserId,
    required String actorDisplayName,
  }) async {
    final batch = _firestore.batch();

    // 1. Write the mortality record.
    batch.set(_doc(farmId, pigId), {
      'date': date,
      if (cause != null) 'cause': cause,
      'photoUrls': photoUrls,
      if (notes != null) 'notes': notes,
      'createdBy': actorUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Flip the pig's status to deceased.
    batch.update(
      _firestore.collection('farms').doc(farmId).collection('pigs').doc(pigId),
      {'status': 'deceased', 'updatedAt': FieldValue.serverTimestamp()},
    );

    // 3. Activity entry (same batch — atomic).
    _activity.addActivityToBatch(
      batch: batch,
      farmId: farmId,
      actorUserId: actorUserId,
      actorDisplayName: actorDisplayName,
      action: 'mortality_logged',
      entityType: 'pig',
      entityId: pigId,
      areaId: areaId,
      summary: '$actorDisplayName logged mortality of $tagId'
          '${cause == null ? '' : ' (cause: $cause)'}',
    );

    await batch.commit();
  }

  Stream<MortalityRecord?> streamMortality({
    required String farmId,
    required String pigId,
  }) {
    return _doc(farmId, pigId).snapshots().map(
          (d) => d.exists
              ? MortalityRecord.fromFirestore(d, farmId: farmId, pigId: pigId)
              : null,
        );
  }

  /// All mortalities across a farm — for yield reports.
  /// Uses `collectionGroup` + client-side path filter for farmId
  /// (same pattern as other allXxx providers).
  Stream<List<MortalityRecord>> streamAllMortalities(String farmId) {
    return _firestore.collectionGroup('mortality_record').snapshots().map((s) {
      return s.docs.where((d) {
        final parts = d.reference.path.split('/');
        return parts.length >= 2 &&
            parts[0] == 'farms' &&
            parts[1] == farmId;
      }).map((d) {
        final pigId = d.reference.parent.parent!.id;
        return MortalityRecord.fromFirestore(d, farmId: farmId, pigId: pigId);
      }).toList();
    });
  }
}
