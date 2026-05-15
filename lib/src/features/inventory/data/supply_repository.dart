import 'package:cloud_firestore/cloud_firestore.dart';
import '../../activity/data/activity_repository.dart';
import '../domain/supply.dart';
import '../domain/supply_category.dart';

class SupplyRepository {
  SupplyRepository(this._firestore, this._activity);
  final FirebaseFirestore _firestore;
  final ActivityRepository _activity;

  CollectionReference<Map<String, dynamic>> _col(String farmId) =>
      _firestore.collection('farms').doc(farmId).collection('supplies');

  Future<String> createSupply({
    required String farmId,
    required String name,
    required SupplyCategory category,
    required SupplyUnit unit,
    required int? unitsPerPackage,
    required num? lowStockThreshold,
    required String? notes,
    required String actorUserId,
    required String actorDisplayName,
  }) async {
    final ref = _col(farmId).doc();
    final batch = _firestore.batch();
    batch.set(ref, {
      'name': name.trim(),
      'category': category.value,
      'unit': unit.value,
      if (unitsPerPackage != null) 'unitsPerPackage': unitsPerPackage,
      if (lowStockThreshold != null) 'lowStockThreshold': lowStockThreshold,
      'currentStock': 0,
      'weightedAvgUnitCostPhp': 0.0,
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
      action: 'supply_added',
      entityType: 'supply',
      entityId: ref.id,
      summary: '$actorDisplayName added supply "$name"',
    );
    await batch.commit();
    return ref.id;
  }

  Future<void> updateSupply({
    required String farmId,
    required String supplyId,
    required String name,
    required SupplyCategory category,
    required SupplyUnit unit,
    required int? unitsPerPackage,
    required num? lowStockThreshold,
    required String? notes,
    required String actorUserId,
    required String actorDisplayName,
  }) async {
    final trimmedName = name.trim();
    final batch = _firestore.batch();
    batch.update(_col(farmId).doc(supplyId), {
      'name': trimmedName,
      'category': category.value,
      'unit': unit.value,
      'unitsPerPackage': unitsPerPackage,
      'lowStockThreshold': lowStockThreshold,
      'notes': notes?.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _activity.addActivityToBatch(
      batch: batch,
      farmId: farmId,
      actorUserId: actorUserId,
      actorDisplayName: actorDisplayName,
      action: 'supply_updated',
      entityType: 'supply',
      entityId: supplyId,
      summary: '$actorDisplayName updated supply "$trimmedName"',
    );
    await batch.commit();
  }

  Future<void> deleteSupply({
    required String farmId,
    required String supplyId,
  }) async {
    await _col(farmId).doc(supplyId).delete();
  }

  Stream<List<Supply>> streamSupplies(String farmId) {
    return _col(farmId).snapshots().map((s) {
      final list = s.docs
          .map((d) => Supply.fromFirestore(d, farmId: farmId))
          .toList();
      list.sort((a, b) {
        final cmp = a.category.index.compareTo(b.category.index);
        return cmp != 0
            ? cmp
            : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return list;
    });
  }

  Stream<Supply?> streamSupplyById({
    required String farmId,
    required String supplyId,
  }) {
    return _col(farmId)
        .doc(supplyId)
        .snapshots()
        .map((d) => d.exists ? Supply.fromFirestore(d, farmId: farmId) : null);
  }

  /// Logs supply consumption tied to a pen. Derives primary batch at write time.
  /// Atomic: writes a movement, decrements supply.currentStock, writes activity.
  /// Throws [ArgumentError] if quantity is not positive.
  /// Throws [StateError] if currentStock - quantity would go negative.
  Future<void> logConsumption({
    required String farmId,
    required String supplyId,
    required String supplyName,
    required num quantity, // positive value; will be stored as negative
    required String? penId,
    required String? derivedBatchId,
    required String? healthRecordId,
    required String? notes,
    required String actorUserId,
    required String actorDisplayName,
  }) async {
    if (quantity <= 0) {
      throw ArgumentError('quantity must be positive');
    }
    await _firestore.runTransaction((tx) async {
      final supplyRef = _col(farmId).doc(supplyId);
      final snap = await tx.get(supplyRef);
      if (!snap.exists) throw StateError('Supply not found.');
      final current = (snap.data()!['currentStock'] as num?) ?? 0;
      if (current - quantity < 0) {
        throw StateError('Insufficient stock — only $current available.');
      }
      final movementRef = _firestore
          .collection('farms')
          .doc(farmId)
          .collection('supply_movements')
          .doc();
      tx.set(movementRef, {
        'supplyId': supplyId,
        'type': 'consumption',
        'quantity': -quantity,
        if (penId != null) 'relatedPenId': penId,
        if (derivedBatchId != null) 'relatedBatchId': derivedBatchId,
        if (healthRecordId != null) 'relatedHealthRecordId': healthRecordId,
        if (notes != null) 'notes': notes,
        'createdBy': actorUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.update(supplyRef, {
        'currentStock': FieldValue.increment(-quantity),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final activityRef = _firestore
          .collection('farms')
          .doc(farmId)
          .collection('activity')
          .doc();
      tx.set(activityRef, {
        'actorUserId': actorUserId,
        'actorDisplayName': actorDisplayName,
        'action': 'supply_consumed',
        'entityType': 'supply',
        'entityId': supplyId,
        'summary': '$actorDisplayName used $quantity of "$supplyName"',
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }
}
