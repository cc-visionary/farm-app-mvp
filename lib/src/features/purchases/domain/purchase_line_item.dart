import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseLineItem {
  final String id;
  final String farmId;
  final String purchaseId;
  final String supplyId;
  final num quantity;
  final double unitCostPhp;
  final double lineTotalPhp;
  final Timestamp createdAt;

  const PurchaseLineItem({
    required this.id,
    required this.farmId,
    required this.purchaseId,
    required this.supplyId,
    required this.quantity,
    required this.unitCostPhp,
    required this.lineTotalPhp,
    required this.createdAt,
  });

  factory PurchaseLineItem.fromFirestore(
    DocumentSnapshot doc, {
    required String farmId,
    required String purchaseId,
  }) {
    final d = doc.data() as Map<String, dynamic>;
    return PurchaseLineItem(
      id: doc.id,
      farmId: farmId,
      purchaseId: purchaseId,
      supplyId: d['supplyId'] as String? ?? '',
      quantity: (d['quantity'] as num?) ?? 0,
      unitCostPhp: (d['unitCostPhp'] as num?)?.toDouble() ?? 0.0,
      lineTotalPhp: (d['lineTotalPhp'] as num?)?.toDouble() ?? 0.0,
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'supplyId': supplyId,
    'quantity': quantity,
    'unitCostPhp': unitCostPhp,
    'lineTotalPhp': lineTotalPhp,
    'createdAt': createdAt,
  };
}
