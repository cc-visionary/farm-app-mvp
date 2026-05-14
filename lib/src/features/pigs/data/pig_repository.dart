import 'package:cloud_firestore/cloud_firestore.dart';
import '../../activity/data/activity_repository.dart';
import '../domain/pig.dart';

class PigRepository {
  PigRepository(this._firestore, this._activity);
  final FirebaseFirestore _firestore;
  final ActivityRepository _activity;

  CollectionReference<Map<String, dynamic>> _col(String farmId) =>
      _firestore.collection('farms').doc(farmId).collection('pigs');

  Future<String> createPig({
    required String farmId,
    required String tagId,
    required PigSex sex,
    required String breed,
    required Timestamp birthDate,
    required String? sireId,
    required String? damId,
    required PigStage stage,
    required String currentAreaId,
    required String? currentPenId,
    required double? currentWeight,
    required String? photoUrl,
    required String? notes,
    required String actorUserId,
    required String actorDisplayName,
  }) async {
    final ref = _col(farmId).doc();
    final batch = _firestore.batch();
    batch.set(ref, {
      'tagId': tagId.trim(),
      'sex': sex.value,
      'breed': breed.trim(),
      'birthDate': birthDate,
      if (sireId != null) 'sireId': sireId,
      if (damId != null) 'damId': damId,
      'stage': stage.value,
      'status': 'active',
      'currentAreaId': currentAreaId,
      if (currentPenId != null) 'currentPenId': currentPenId,
      if (currentWeight != null) 'currentWeight': currentWeight,
      if (currentWeight != null) 'weightUpdatedAt': FieldValue.serverTimestamp(),
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      'createdBy': actorUserId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _activity.addActivityToBatch(
      batch: batch,
      farmId: farmId,
      actorUserId: actorUserId,
      actorDisplayName: actorDisplayName,
      action: 'pig_added',
      entityType: 'pig',
      entityId: ref.id,
      areaId: currentAreaId,
      summary: '$actorDisplayName added pig ${tagId.trim()}',
    );
    await batch.commit();
    return ref.id;
  }

  Future<void> updatePig({
    required String farmId,
    required String pigId,
    required String tagId,
    required PigSex sex,
    required String breed,
    required Timestamp birthDate,
    required String? sireId,
    required String? damId,
    required PigStage stage,
    required String currentAreaId,
    required String? currentPenId,
    required double? currentWeight,
    required String? photoUrl,
    required String? notes,
  }) async {
    await _col(farmId).doc(pigId).update({
      'tagId': tagId.trim(),
      'sex': sex.value,
      'breed': breed.trim(),
      'birthDate': birthDate,
      'sireId': sireId,
      'damId': damId,
      'stage': stage.value,
      'currentAreaId': currentAreaId,
      'currentPenId': currentPenId,
      if (currentWeight != null) 'currentWeight': currentWeight,
      'photoUrl': photoUrl,
      'notes': notes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> movePig({
    required String farmId,
    required String pigId,
    required String tagId,
    required String newAreaId,
    required String? newPenId,
    required String actorUserId,
    required String actorDisplayName,
  }) async {
    final batch = _firestore.batch();
    batch.update(_col(farmId).doc(pigId), {
      'currentAreaId': newAreaId,
      'currentPenId': newPenId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _activity.addActivityToBatch(
      batch: batch,
      farmId: farmId,
      actorUserId: actorUserId,
      actorDisplayName: actorDisplayName,
      action: 'pig_moved',
      entityType: 'pig',
      entityId: pigId,
      areaId: newAreaId,
      summary: '$actorDisplayName moved pig $tagId to area $newAreaId',
    );
    await batch.commit();
  }

  Future<void> logWeight({
    required String farmId,
    required String pigId,
    required String tagId,
    required double weight,
    required String actorUserId,
    required String actorDisplayName,
  }) async {
    final batch = _firestore.batch();
    batch.update(_col(farmId).doc(pigId), {
      'currentWeight': weight,
      'weightUpdatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _activity.addActivityToBatch(
      batch: batch,
      farmId: farmId,
      actorUserId: actorUserId,
      actorDisplayName: actorDisplayName,
      action: 'weight_logged',
      entityType: 'pig',
      entityId: pigId,
      summary: '$actorDisplayName logged weight $weight kg for $tagId',
    );
    await batch.commit();
  }

  Future<void> setStatus({
    required String farmId,
    required String pigId,
    required String tagId,
    required PigStatus status,
    required String actorUserId,
    required String actorDisplayName,
  }) async {
    final batch = _firestore.batch();
    batch.update(_col(farmId).doc(pigId), {
      'status': status.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _activity.addActivityToBatch(
      batch: batch,
      farmId: farmId,
      actorUserId: actorUserId,
      actorDisplayName: actorDisplayName,
      action: 'pig_status_changed',
      entityType: 'pig',
      entityId: pigId,
      summary: '$actorDisplayName marked $tagId as ${status.label}',
    );
    await batch.commit();
  }

  Stream<List<Pig>> streamPigs(String farmId) {
    return _col(farmId).snapshots().map((s) =>
        s.docs.map((d) => Pig.fromFirestore(d, farmId: farmId)).toList());
  }

  Stream<Pig?> streamPigById({
    required String farmId,
    required String pigId,
  }) {
    return _col(farmId).doc(pigId).snapshots().map(
          (d) => d.exists ? Pig.fromFirestore(d, farmId: farmId) : null,
        );
  }
}
