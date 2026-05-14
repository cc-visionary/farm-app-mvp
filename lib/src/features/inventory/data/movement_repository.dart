import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/supply_movement.dart';

class MovementRepository {
  MovementRepository(this._firestore);
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _col(String farmId) =>
      _firestore.collection('farms').doc(farmId).collection('supply_movements');

  /// Streams movements for a given supply, newest first.
  Stream<List<SupplyMovement>> streamForSupply({
    required String farmId,
    required String supplyId,
  }) {
    return _col(farmId)
        .where('supplyId', isEqualTo: supplyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (s) => s.docs
              .map((d) => SupplyMovement.fromFirestore(d, farmId: farmId))
              .toList(),
        );
  }

  /// All movements in a date range — for profitability calculator.
  Stream<List<SupplyMovement>> streamInRange({
    required String farmId,
    required Timestamp start,
    required Timestamp end,
  }) {
    return _col(farmId)
        .where('createdAt', isGreaterThanOrEqualTo: start)
        .where('createdAt', isLessThan: end)
        .snapshots()
        .map(
          (s) => s.docs
              .map((d) => SupplyMovement.fromFirestore(d, farmId: farmId))
              .toList(),
        );
  }

  /// All movements for a batch — for batch cost calculator.
  Stream<List<SupplyMovement>> streamForBatch({
    required String farmId,
    required String batchId,
  }) {
    return _col(farmId)
        .where('relatedBatchId', isEqualTo: batchId)
        .snapshots()
        .map(
          (s) => s.docs
              .map((d) => SupplyMovement.fromFirestore(d, farmId: farmId))
              .toList(),
        );
  }
}
