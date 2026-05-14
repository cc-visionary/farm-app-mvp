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
  }) async {
    await _col(farmId).doc(supplyId).update({
      'name': name.trim(),
      'category': category.value,
      'unit': unit.value,
      'unitsPerPackage': unitsPerPackage,
      'lowStockThreshold': lowStockThreshold,
      'notes': notes?.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
}
