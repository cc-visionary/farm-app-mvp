// lib/src/features/expenses/domain/expense.dart
//
// Direct-expense record. Optional attribution fields let us roll expenses up
// against a batch, equipment item, individual pig, or area for profitability.
// The v1 UI does not surface those attribution pickers, but the model already
// supports them so future screens can write them without a schema change.

import 'package:cloud_firestore/cloud_firestore.dart';

import 'expense_category.dart';

class Expense {
  final String id;
  final String farmId;
  final ExpenseCategory category;
  final String description;
  final double amountPhp;
  final Timestamp date;
  final String? relatedBatchId;
  final String? relatedEquipmentId;
  final String? relatedPigId;
  final String? relatedAreaId;
  final String? receiptPhotoUrl;
  final String? notes;
  final String createdBy;
  final Timestamp createdAt;

  const Expense({
    required this.id,
    required this.farmId,
    required this.category,
    required this.description,
    required this.amountPhp,
    required this.date,
    required this.relatedBatchId,
    required this.relatedEquipmentId,
    required this.relatedPigId,
    required this.relatedAreaId,
    required this.receiptPhotoUrl,
    required this.notes,
    required this.createdBy,
    required this.createdAt,
  });

  factory Expense.fromFirestore(
    DocumentSnapshot doc, {
    required String farmId,
  }) {
    final d = doc.data() as Map<String, dynamic>;
    return Expense(
      id: doc.id,
      farmId: farmId,
      category: ExpenseCategory.fromString(d['category'] as String? ?? 'other'),
      description: d['description'] as String? ?? '',
      amountPhp: (d['amountPhp'] as num?)?.toDouble() ?? 0.0,
      date: d['date'] as Timestamp? ?? Timestamp.now(),
      relatedBatchId: d['relatedBatchId'] as String?,
      relatedEquipmentId: d['relatedEquipmentId'] as String?,
      relatedPigId: d['relatedPigId'] as String?,
      relatedAreaId: d['relatedAreaId'] as String?,
      receiptPhotoUrl: d['receiptPhotoUrl'] as String?,
      notes: d['notes'] as String?,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'category': category.value,
    'description': description,
    'amountPhp': amountPhp,
    'date': date,
    if (relatedBatchId != null) 'relatedBatchId': relatedBatchId,
    if (relatedEquipmentId != null) 'relatedEquipmentId': relatedEquipmentId,
    if (relatedPigId != null) 'relatedPigId': relatedPigId,
    if (relatedAreaId != null) 'relatedAreaId': relatedAreaId,
    if (receiptPhotoUrl != null) 'receiptPhotoUrl': receiptPhotoUrl,
    if (notes != null) 'notes': notes,
    'createdBy': createdBy,
    'createdAt': createdAt,
  };
}
