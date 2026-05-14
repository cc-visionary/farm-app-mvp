import 'package:cloud_firestore/cloud_firestore.dart';
import '../../activity/data/activity_repository.dart';
import '../../tasks/application/task_generator.dart';
import '../domain/health_record.dart';

/// Per-pig health records: vaccinations, treatments, checkups, deworming.
/// Writes the record + (optional) withdrawal-end task + activity entry as an
/// atomic [WriteBatch] so all three land together.
class HealthRepository {
  HealthRepository(this._firestore, this._activity, this._gen);
  final FirebaseFirestore _firestore;
  final ActivityRepository _activity;
  final TaskGenerator _gen;

  CollectionReference<Map<String, dynamic>> _col(String farmId, String pigId) =>
      _firestore
          .collection('farms')
          .doc(farmId)
          .collection('pigs')
          .doc(pigId)
          .collection('health_records');

  /// Logs a health event. If [withdrawalEndDate] is non-null, also generates a
  /// `withdrawal_end` task with ID `hr_{healthRecordId}_wd`.
  Future<String> logHealth({
    required String farmId,
    required String pigId,
    required String tagId,
    required String areaId,
    required HealthEventType type,
    required Timestamp date,
    required String? productName,
    required String? dosage,
    required HealthRoute? route,
    required String? diagnosis,
    required Timestamp? withdrawalEndDate,
    required double? costPhp,
    required List<String> photoUrls,
    required String? notes,
    required String actorUserId,
    required String actorDisplayName,
  }) async {
    final ref = _col(farmId, pigId).doc();
    final batch = _firestore.batch();
    batch.set(ref, {
      'type': type.value,
      'date': date,
      if (productName != null) 'productName': productName,
      if (dosage != null) 'dosage': dosage,
      if (route != null) 'route': route.value,
      if (diagnosis != null) 'diagnosis': diagnosis,
      if (withdrawalEndDate != null) 'withdrawalEndDate': withdrawalEndDate,
      if (costPhp != null) 'costPhp': costPhp,
      'photoUrls': photoUrls,
      if (notes != null) 'notes': notes,
      'createdBy': actorUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (withdrawalEndDate != null) {
      _gen.addWithdrawalTaskToBatch(
        batch: batch,
        farmId: farmId,
        healthRecordId: ref.id,
        pigId: pigId,
        tagId: tagId,
        areaId: areaId,
        withdrawalEndDate: withdrawalEndDate,
      );
    }
    _activity.addActivityToBatch(
      batch: batch,
      farmId: farmId,
      actorUserId: actorUserId,
      actorDisplayName: actorDisplayName,
      action: 'health_logged',
      entityType: 'pig',
      entityId: pigId,
      areaId: areaId,
      summary: '$actorDisplayName logged ${type.label} on $tagId'
          '${productName == null ? '' : ' ($productName)'}',
    );
    await batch.commit();
    return ref.id;
  }

  Stream<List<HealthRecord>> streamHealthForPig({
    required String farmId,
    required String pigId,
  }) {
    return _col(farmId, pigId)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) => HealthRecord.fromFirestore(
                  d,
                  farmId: farmId,
                  pigId: pigId,
                ),
              )
              .toList(),
        );
  }
}
