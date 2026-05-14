import 'package:cloud_firestore/cloud_firestore.dart';
import 'supply_category.dart';

class SupplyMovement {
  final String id;
  final String farmId;
  final String supplyId;
  final MovementType type;
  final num quantity; // signed: + inflow, − outflow
  final double? unitCostPhp;
  final String? relatedPurchaseId;
  final String? relatedPenId;
  final String? relatedBatchId;
  final String? relatedHealthRecordId;
  final String? notes;
  final String createdBy;
  final Timestamp createdAt;

  const SupplyMovement({
    required this.id,
    required this.farmId,
    required this.supplyId,
    required this.type,
    required this.quantity,
    required this.unitCostPhp,
    required this.relatedPurchaseId,
    required this.relatedPenId,
    required this.relatedBatchId,
    required this.relatedHealthRecordId,
    required this.notes,
    required this.createdBy,
    required this.createdAt,
  });

  factory SupplyMovement.fromFirestore(
    DocumentSnapshot doc, {
    required String farmId,
  }) {
    final d = doc.data() as Map<String, dynamic>;
    return SupplyMovement(
      id: doc.id,
      farmId: farmId,
      supplyId: d['supplyId'] as String? ?? '',
      type: MovementType.fromString(d['type'] as String? ?? 'adjustment'),
      quantity: (d['quantity'] as num?) ?? 0,
      unitCostPhp: (d['unitCostPhp'] as num?)?.toDouble(),
      relatedPurchaseId: d['relatedPurchaseId'] as String?,
      relatedPenId: d['relatedPenId'] as String?,
      relatedBatchId: d['relatedBatchId'] as String?,
      relatedHealthRecordId: d['relatedHealthRecordId'] as String?,
      notes: d['notes'] as String?,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'supplyId': supplyId,
    'type': type.value,
    'quantity': quantity,
    if (unitCostPhp != null) 'unitCostPhp': unitCostPhp,
    if (relatedPurchaseId != null) 'relatedPurchaseId': relatedPurchaseId,
    if (relatedPenId != null) 'relatedPenId': relatedPenId,
    if (relatedBatchId != null) 'relatedBatchId': relatedBatchId,
    if (relatedHealthRecordId != null)
      'relatedHealthRecordId': relatedHealthRecordId,
    if (notes != null) 'notes': notes,
    'createdBy': createdBy,
    'createdAt': createdAt,
  };
}
