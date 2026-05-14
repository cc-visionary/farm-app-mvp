import 'package:cloud_firestore/cloud_firestore.dart';
import '../../activity/data/activity_repository.dart';
import '../domain/batch.dart';
import '../domain/farrowing_record.dart';
import 'batch_repository.dart';

class FarrowingRepository {
  FarrowingRepository(this._firestore, this._activity, this._batches);
  final FirebaseFirestore _firestore;
  final ActivityRepository _activity;
  final BatchRepository _batches;

  CollectionReference<Map<String, dynamic>> _col(String farmId, String sowId) =>
      _firestore
          .collection('farms')
          .doc(farmId)
          .collection('pigs')
          .doc(sowId)
          .collection('farrowing_records');

  /// Atomic write: farrowing record + optional litter batch + breeding record
  /// closure + farrowing_expected task completion + activity entry.
  Future<String> logFarrowing({
    required String farmId,
    required String sowId,
    required String sowTagId,
    required String sowAreaId,
    required String? sowPenId,
    required String breedingRecordId,
    required Timestamp date,
    required int liveBorn,
    required int stillborn,
    required int mummified,
    required double? avgBirthWeightKg,
    required bool createLitterBatch,
    required String? notes,
    required String actorUserId,
    required String actorDisplayName,
  }) async {
    final farrRef = _col(farmId, sowId).doc();
    final batch = _firestore.batch();

    String? litterBatchId;
    if (createLitterBatch && liveBorn > 0) {
      final dateStr = date.toDate().toIso8601String().split('T')[0];
      litterBatchId = _batches.addBatchCreateToBatch(
        batch: batch,
        farmId: farmId,
        name: 'Litter $dateStr · $sowTagId',
        type: BatchType.litter,
        originPigIds: [sowId],
        count: liveBorn,
        currentAreaId: sowAreaId,
        currentPenId: sowPenId,
        createdBy: actorUserId,
      );
    }

    batch.set(farrRef, {
      'breedingRecordId': breedingRecordId,
      'date': date,
      'liveBorn': liveBorn,
      'stillborn': stillborn,
      'mummified': mummified,
      if (avgBirthWeightKg != null) 'avgBirthWeightKg': avgBirthWeightKg,
      if (litterBatchId != null) 'litterBatchId': litterBatchId,
      if (notes != null) 'notes': notes,
      'createdBy': actorUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Close the breeding record.
    batch.update(
      _firestore
          .collection('farms')
          .doc(farmId)
          .collection('pigs')
          .doc(sowId)
          .collection('breeding_records')
          .doc(breedingRecordId),
      {'status': 'farrowed'},
    );

    // Mark farrowing_expected task complete.
    batch.update(
      _firestore
          .collection('farms')
          .doc(farmId)
          .collection('tasks')
          .doc('br_${breedingRecordId}_farr'),
      {
        'status': 'completed',
        'completedBy': actorUserId,
        'completedAt': FieldValue.serverTimestamp(),
      },
    );

    _activity.addActivityToBatch(
      batch: batch,
      farmId: farmId,
      actorUserId: actorUserId,
      actorDisplayName: actorDisplayName,
      action: 'farrowing_logged',
      entityType: 'pig',
      entityId: sowId,
      areaId: sowAreaId,
      summary: '$actorDisplayName logged farrowing on $sowTagId — '
          '$liveBorn live, $stillborn stillborn',
    );

    await batch.commit();
    return farrRef.id;
  }

  Stream<List<FarrowingRecord>> streamFarrowings({
    required String farmId,
    required String sowId,
  }) {
    return _col(farmId, sowId)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) => FarrowingRecord.fromFirestore(
                  d,
                  farmId: farmId,
                  sowId: sowId,
                ),
              )
              .toList(),
        );
  }

  /// Collection-group across all sows for a farm — used by Yield Reports.
  Stream<List<FarrowingRecord>> streamAllFarrowings(String farmId) {
    return _firestore.collectionGroup('farrowing_records').snapshots().map((s) {
      return s.docs.where((d) {
        final parts = d.reference.path.split('/');
        return parts.length >= 2 && parts[0] == 'farms' && parts[1] == farmId;
      }).map((d) {
        final sowId = d.reference.parent.parent!.id;
        return FarrowingRecord.fromFirestore(d, farmId: farmId, sowId: sowId);
      }).toList();
    });
  }
}
