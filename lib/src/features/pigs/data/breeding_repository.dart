import 'package:cloud_firestore/cloud_firestore.dart';
import '../../activity/data/activity_repository.dart';
import '../../tasks/application/task_generator.dart';
import '../domain/breeding_record.dart';

class BreedingRepository {
  BreedingRepository(this._firestore, this._activity, this._gen);
  final FirebaseFirestore _firestore;
  final ActivityRepository _activity;
  final TaskGenerator _gen;

  CollectionReference<Map<String, dynamic>> _col(String farmId, String pigId) =>
      _firestore
          .collection('farms')
          .doc(farmId)
          .collection('pigs')
          .doc(pigId)
          .collection('breeding_records');

  CollectionReference<Map<String, dynamic>> _tasksCol(String farmId) =>
      _firestore.collection('farms').doc(farmId).collection('tasks');

  /// Atomic write: breeding record + 3 derived tasks (preg/prep/farr) +
  /// activity entry land together via a single WriteBatch commit.
  Future<String> logBreeding({
    required String farmId,
    required String sowId,
    required String sowTagId,
    required String? sowAreaId,
    required String boarId,
    required Timestamp? heatDate,
    required Timestamp inseminationDate,
    required BreedingMethod method,
    required String? notes,
    required String actorUserId,
    required String actorDisplayName,
  }) async {
    final expected =
        BreedingRecord.computeExpectedFarrowingDate(inseminationDate);
    final ref = _col(farmId, sowId).doc();
    final batch = _firestore.batch();
    batch.set(ref, {
      'boarId': boarId,
      if (heatDate != null) 'heatDate': heatDate,
      'inseminationDate': inseminationDate,
      'method': method.value,
      'confirmed': false,
      'expectedFarrowingDate': expected,
      'status': 'planned',
      if (notes != null) 'notes': notes,
      'createdBy': actorUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    _gen.addBreedingTasksToBatch(
      batch: batch,
      farmId: farmId,
      breedingRecordId: ref.id,
      sowId: sowId,
      sowTagId: sowTagId,
      areaId: sowAreaId,
      inseminationDate: inseminationDate,
    );
    _activity.addActivityToBatch(
      batch: batch,
      farmId: farmId,
      actorUserId: actorUserId,
      actorDisplayName: actorDisplayName,
      action: 'breeding_logged',
      entityType: 'pig',
      entityId: sowId,
      areaId: sowAreaId,
      summary: '$actorDisplayName logged breeding for $sowTagId',
    );
    await batch.commit();
    return ref.id;
  }

  /// Records the pregnancy check outcome.
  /// - confirmed=true: breeding record → 'confirmed', pregnancy_check task → completed
  /// - confirmed=false: breeding record → 'failed', preg task → completed,
  ///   farrowing_prep + farrowing_expected tasks → skipped (cancelled)
  Future<void> recordPregnancyCheck({
    required String farmId,
    required String sowId,
    required String breedingRecordId,
    required bool confirmed,
    required Timestamp checkDate,
    required String actorUserId,
    required String actorDisplayName,
    required String sowTagId,
    String? areaId,
  }) async {
    final batch = _firestore.batch();
    batch.update(_col(farmId, sowId).doc(breedingRecordId), {
      'confirmed': confirmed,
      'pregnancyCheckDate': checkDate,
      'status': confirmed ? 'confirmed' : 'failed',
    });
    if (!confirmed) {
      // Cancel downstream farrowing tasks.
      batch.update(
        _tasksCol(farmId).doc('br_${breedingRecordId}_prep'),
        {'status': 'skipped'},
      );
      batch.update(
        _tasksCol(farmId).doc('br_${breedingRecordId}_farr'),
        {'status': 'skipped'},
      );
    }
    // The pregnancy_check task itself is completed regardless of outcome.
    batch.update(_tasksCol(farmId).doc('br_${breedingRecordId}_preg'), {
      'status': 'completed',
      'completedBy': actorUserId,
      'completedAt': FieldValue.serverTimestamp(),
    });
    _activity.addActivityToBatch(
      batch: batch,
      farmId: farmId,
      actorUserId: actorUserId,
      actorDisplayName: actorDisplayName,
      action: 'pregnancy_check_logged',
      entityType: 'pig',
      entityId: sowId,
      areaId: areaId,
      summary:
          '$actorDisplayName recorded pregnancy check for $sowTagId: ${confirmed ? "confirmed" : "failed"}',
    );
    await batch.commit();
  }

  Future<void> markFarrowed({
    required String farmId,
    required String sowId,
    required String breedingRecordId,
  }) async {
    await _col(farmId, sowId).doc(breedingRecordId).update({
      'status': 'farrowed',
    });
  }

  Stream<List<BreedingRecord>> streamBreedingRecords({
    required String farmId,
    required String sowId,
  }) {
    return _col(farmId, sowId)
        .orderBy('inseminationDate', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) =>
                BreedingRecord.fromFirestore(d, farmId: farmId, sowId: sowId))
            .toList());
  }
}
