import 'package:cloud_firestore/cloud_firestore.dart';
import '../../activity/data/activity_repository.dart';
import '../domain/batch.dart';

class BatchRepository {
  BatchRepository(this._firestore, this._activity);
  final FirebaseFirestore _firestore;
  // Reserved for future activity writes (e.g., batch_closed, batch_sold).
  // ignore: unused_field
  final ActivityRepository _activity;

  CollectionReference<Map<String, dynamic>> _col(String farmId) =>
      _firestore.collection('farms').doc(farmId).collection('batches');

  /// Adds a batch create to an existing [WriteBatch] (used during farrowing
  /// so the batch + farrowing record + breeding update land atomically).
  /// Returns the new batch document ID.
  String addBatchCreateToBatch({
    required WriteBatch batch,
    required String farmId,
    required String name,
    required BatchType type,
    required List<String> originPigIds,
    required int count,
    required String currentAreaId,
    String? currentPenId,
    required String createdBy,
  }) {
    final ref = _col(farmId).doc();
    batch.set(ref, {
      'name': name,
      'type': type.value,
      'originPigIds': originPigIds,
      'pigIds': <String>[],
      'count': count,
      'currentAreaId': currentAreaId,
      if (currentPenId != null) 'currentPenId': currentPenId,
      'status': BatchStatus.active.value,
      'startDate': FieldValue.serverTimestamp(),
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Stream<List<Batch>> streamBatches(String farmId) {
    return _col(farmId).snapshots().map(
          (s) => s.docs
              .map((d) => Batch.fromFirestore(d, farmId: farmId))
              .toList(),
        );
  }
}
