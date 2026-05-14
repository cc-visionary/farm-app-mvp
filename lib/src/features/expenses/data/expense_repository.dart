// lib/src/features/expenses/data/expense_repository.dart
//
// Direct-expense Firestore repository. `createExpense` writes the expense doc
// and a matching activity entry atomically via a [WriteBatch] so the activity
// feed never drifts from the source-of-truth. Stream methods expose the full
// list, a date-range slice (for monthly P&L), and a per-batch filter (for
// per-batch profitability).

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../activity/data/activity_repository.dart';
import '../domain/expense.dart';
import '../domain/expense_category.dart';

class ExpenseRepository {
  ExpenseRepository(this._firestore, this._activity);

  final FirebaseFirestore _firestore;
  final ActivityRepository _activity;

  CollectionReference<Map<String, dynamic>> _col(String farmId) =>
      _firestore.collection('farms').doc(farmId).collection('expenses');

  /// Atomically writes a new expense document plus its activity entry.
  ///
  /// Throws [ArgumentError] when [amountPhp] is not positive or [description]
  /// is empty after trimming.
  Future<String> createExpense({
    required String farmId,
    required ExpenseCategory category,
    required String description,
    required double amountPhp,
    required Timestamp date,
    String? relatedBatchId,
    String? relatedEquipmentId,
    String? relatedPigId,
    String? relatedAreaId,
    String? receiptPhotoUrl,
    String? notes,
    required String actorUserId,
    required String actorDisplayName,
  }) async {
    if (amountPhp <= 0) {
      throw ArgumentError('amountPhp must be positive');
    }
    if (description.trim().isEmpty) {
      throw ArgumentError('description is required');
    }

    final ref = _col(farmId).doc();
    final batch = _firestore.batch();
    batch.set(ref, {
      'category': category.value,
      'description': description.trim(),
      'amountPhp': amountPhp,
      'date': date,
      if (relatedBatchId != null) 'relatedBatchId': relatedBatchId,
      if (relatedEquipmentId != null) 'relatedEquipmentId': relatedEquipmentId,
      if (relatedPigId != null) 'relatedPigId': relatedPigId,
      if (relatedAreaId != null) 'relatedAreaId': relatedAreaId,
      if (receiptPhotoUrl != null) 'receiptPhotoUrl': receiptPhotoUrl,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      'createdBy': actorUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    _activity.addActivityToBatch(
      batch: batch,
      farmId: farmId,
      actorUserId: actorUserId,
      actorDisplayName: actorDisplayName,
      action: 'expense_logged',
      entityType: 'expense',
      entityId: ref.id,
      areaId: relatedAreaId,
      summary:
          '$actorDisplayName logged ${category.label} expense · ₱${amountPhp.toStringAsFixed(0)}',
    );

    await batch.commit();
    return ref.id;
  }

  Stream<List<Expense>> streamExpenses(String farmId) {
    return _col(farmId)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (s) => s.docs
              .map((d) => Expense.fromFirestore(d, farmId: farmId))
              .toList(),
        );
  }

  Stream<List<Expense>> streamInRange({
    required String farmId,
    required Timestamp start,
    required Timestamp end,
  }) {
    return _col(farmId)
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThan: end)
        .snapshots()
        .map(
          (s) => s.docs
              .map((d) => Expense.fromFirestore(d, farmId: farmId))
              .toList(),
        );
  }

  Stream<List<Expense>> streamForBatch({
    required String farmId,
    required String batchId,
  }) {
    return _col(farmId)
        .where('relatedBatchId', isEqualTo: batchId)
        .snapshots()
        .map(
          (s) => s.docs
              .map((d) => Expense.fromFirestore(d, farmId: farmId))
              .toList(),
        );
  }
}
