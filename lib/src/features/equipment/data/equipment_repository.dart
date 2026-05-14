import 'package:cloud_firestore/cloud_firestore.dart';
import '../../activity/data/activity_repository.dart';
import '../domain/equipment.dart';
import '../domain/maintenance_record.dart';

class EquipmentRepository {
  EquipmentRepository(this._firestore, this._activity);
  final FirebaseFirestore _firestore;
  final ActivityRepository _activity;

  CollectionReference<Map<String, dynamic>> _col(String farmId) =>
      _firestore.collection('farms').doc(farmId).collection('equipment');

  CollectionReference<Map<String, dynamic>> _maint(String farmId, String eqId) =>
      _col(farmId).doc(eqId).collection('maintenance_records');

  Future<String> createEquipment({
    required String farmId,
    required String name,
    required EquipmentType type,
    required String? areaId,
    required EquipmentStatus status,
    required Timestamp? purchaseDate,
    required double? purchaseCostPhp,
    required String? photoUrl,
    required String? notes,
    required String actorUserId,
    required String actorDisplayName,
  }) async {
    final ref = _col(farmId).doc();
    final batch = _firestore.batch();
    batch.set(ref, {
      'name': name.trim(),
      'type': type.value,
      if (areaId != null) 'areaId': areaId,
      'status': status.value,
      if (purchaseDate != null) 'purchaseDate': purchaseDate,
      if (purchaseCostPhp != null) 'purchaseCostPhp': purchaseCostPhp,
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
      action: 'equipment_added',
      entityType: 'equipment',
      entityId: ref.id,
      areaId: areaId,
      summary: '$actorDisplayName added equipment "${name.trim()}"',
    );
    await batch.commit();
    return ref.id;
  }

  Future<void> updateEquipment({
    required String farmId,
    required String equipmentId,
    required String name,
    required EquipmentType type,
    required String? areaId,
    required EquipmentStatus status,
    required Timestamp? purchaseDate,
    required double? purchaseCostPhp,
    required String? photoUrl,
    required String? notes,
  }) async {
    await _col(farmId).doc(equipmentId).update({
      'name': name.trim(),
      'type': type.value,
      'areaId': areaId,
      'status': status.value,
      'purchaseDate': purchaseDate,
      'purchaseCostPhp': purchaseCostPhp,
      'photoUrl': photoUrl,
      'notes': notes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteEquipment({
    required String farmId,
    required String equipmentId,
  }) async {
    await _col(farmId).doc(equipmentId).delete();
  }

  Future<void> quickToggleStatus({
    required String farmId,
    required String equipmentId,
    required String actorUserId,
    required String actorDisplayName,
  }) async {
    final doc = await _col(farmId).doc(equipmentId).get();
    final eq = Equipment.fromFirestore(doc, farmId: farmId);
    final next = eq.status.next;
    final batch = _firestore.batch();
    batch.update(_col(farmId).doc(equipmentId), {
      'status': next.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _activity.addActivityToBatch(
      batch: batch,
      farmId: farmId,
      actorUserId: actorUserId,
      actorDisplayName: actorDisplayName,
      action: 'equipment_status_changed',
      entityType: 'equipment',
      entityId: equipmentId,
      areaId: eq.areaId,
      summary: '$actorDisplayName set "${eq.name}" -> ${next.label}',
    );
    await batch.commit();
  }

  Future<void> setStatus({
    required String farmId,
    required String equipmentId,
    required EquipmentStatus status,
    required String actorUserId,
    required String actorDisplayName,
  }) async {
    final doc = await _col(farmId).doc(equipmentId).get();
    final eq = Equipment.fromFirestore(doc, farmId: farmId);
    final batch = _firestore.batch();
    batch.update(_col(farmId).doc(equipmentId), {
      'status': status.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _activity.addActivityToBatch(
      batch: batch,
      farmId: farmId,
      actorUserId: actorUserId,
      actorDisplayName: actorDisplayName,
      action: 'equipment_status_changed',
      entityType: 'equipment',
      entityId: equipmentId,
      areaId: eq.areaId,
      summary: '$actorDisplayName set "${eq.name}" -> ${status.label}',
    );
    await batch.commit();
  }

  Stream<List<Equipment>> streamEquipment(String farmId) {
    return _col(farmId).snapshots().map((s) {
      final list =
          s.docs.map((d) => Equipment.fromFirestore(d, farmId: farmId)).toList();
      list.sort((a, b) {
        final cmp = a.type.index.compareTo(b.type.index);
        return cmp != 0 ? cmp : a.name.compareTo(b.name);
      });
      return list;
    });
  }

  Stream<Equipment?> streamEquipmentById({
    required String farmId,
    required String equipmentId,
  }) {
    return _col(farmId).doc(equipmentId).snapshots().map(
          (d) => d.exists ? Equipment.fromFirestore(d, farmId: farmId) : null,
        );
  }

  Future<void> logMaintenance({
    required String farmId,
    required String equipmentId,
    required String equipmentName,
    required MaintenanceType type,
    required Timestamp date,
    required String? performedBy,
    required String? partsReplaced,
    required double? costPhp,
    required List<String> photoUrls,
    required String? notes,
    required String actorUserId,
    required String actorDisplayName,
  }) async {
    final ref = _maint(farmId, equipmentId).doc();
    final batch = _firestore.batch();
    batch.set(ref, {
      'type': type.value,
      'date': date,
      if (performedBy != null) 'performedBy': performedBy,
      if (partsReplaced != null) 'partsReplaced': partsReplaced,
      if (costPhp != null) 'costPhp': costPhp,
      'photoUrls': photoUrls,
      if (notes != null) 'notes': notes,
      'createdBy': actorUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    _activity.addActivityToBatch(
      batch: batch,
      farmId: farmId,
      actorUserId: actorUserId,
      actorDisplayName: actorDisplayName,
      action: 'maintenance_logged',
      entityType: 'equipment',
      entityId: equipmentId,
      summary: '$actorDisplayName logged ${type.label} on "$equipmentName"',
    );
    await batch.commit();
  }

  Stream<List<MaintenanceRecord>> streamMaintenance({
    required String farmId,
    required String equipmentId,
  }) {
    return _maint(farmId, equipmentId)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (s) => s.docs
              .map((d) => MaintenanceRecord.fromFirestore(
                    d,
                    farmId: farmId,
                    equipmentId: equipmentId,
                  ))
              .toList(),
        );
  }
}
