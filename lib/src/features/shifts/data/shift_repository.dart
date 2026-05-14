import 'package:cloud_firestore/cloud_firestore.dart';
import '../../activity/data/activity_repository.dart';
import '../domain/shift.dart';

class ShiftRepository {
  ShiftRepository(this._firestore, this._activity);
  final FirebaseFirestore _firestore;
  final ActivityRepository _activity;

  CollectionReference<Map<String, dynamic>> _col(String farmId) =>
      _firestore.collection('farms').doc(farmId).collection('shifts');

  Future<String> createShift({
    required String farmId,
    required String name,
    required ShiftPattern pattern,
    required List<int> daysOfWeek,
    required String startTime,
    required String endTime,
    required String assignedAreaId,
    required List<String> assignedUserIds,
    String? notes,
    required String actorUserId,
    required String actorDisplayName,
  }) async {
    final ref = _col(farmId).doc();
    final batch = _firestore.batch();
    batch.set(ref, {
      'name': name,
      'pattern': pattern.value,
      'daysOfWeek': daysOfWeek,
      'startTime': startTime,
      'endTime': endTime,
      'assignedAreaId': assignedAreaId,
      'assignedUserIds': assignedUserIds,
      if (notes != null) 'notes': notes,
      'createdBy': actorUserId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _activity.addActivityToBatch(
      batch: batch,
      farmId: farmId,
      actorUserId: actorUserId,
      actorDisplayName: actorDisplayName,
      action: 'shift_assigned',
      entityType: 'shift',
      entityId: ref.id,
      areaId: assignedAreaId,
      summary: '$actorDisplayName created shift "$name"',
    );
    await batch.commit();
    return ref.id;
  }

  Future<void> updateShift({
    required String farmId,
    required String shiftId,
    required String name,
    required ShiftPattern pattern,
    required List<int> daysOfWeek,
    required String startTime,
    required String endTime,
    required String assignedAreaId,
    required List<String> assignedUserIds,
    String? notes,
  }) async {
    await _col(farmId).doc(shiftId).update({
      'name': name,
      'pattern': pattern.value,
      'daysOfWeek': daysOfWeek,
      'startTime': startTime,
      'endTime': endTime,
      'assignedAreaId': assignedAreaId,
      'assignedUserIds': assignedUserIds,
      'notes': notes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteShift({
    required String farmId,
    required String shiftId,
  }) async {
    await _col(farmId).doc(shiftId).delete();
  }

  Stream<List<Shift>> streamShifts(String farmId) {
    return _col(farmId).snapshots().map(
          (s) => s.docs
              .map((d) => Shift.fromFirestore(d, farmId: farmId))
              .toList()
            ..sort((a, b) => a.startTime.compareTo(b.startTime)),
        );
  }
}
