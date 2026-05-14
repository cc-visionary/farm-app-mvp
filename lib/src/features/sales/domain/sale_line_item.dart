import 'package:cloud_firestore/cloud_firestore.dart';

class SaleLineItem {
  final String id;
  final String farmId;
  final String saleId;
  final String pigId;
  final String pigTagId;
  final double finalWeightKg;
  final double pricePerKgPhp;
  final double lineRevenuePhp;
  final Timestamp createdAt;

  const SaleLineItem({
    required this.id,
    required this.farmId,
    required this.saleId,
    required this.pigId,
    required this.pigTagId,
    required this.finalWeightKg,
    required this.pricePerKgPhp,
    required this.lineRevenuePhp,
    required this.createdAt,
  });

  factory SaleLineItem.fromFirestore(
    DocumentSnapshot doc, {
    required String farmId,
    required String saleId,
  }) {
    final d = doc.data() as Map<String, dynamic>;
    return SaleLineItem(
      id: doc.id,
      farmId: farmId,
      saleId: saleId,
      pigId: d['pigId'] as String? ?? '',
      pigTagId: d['pigTagId'] as String? ?? '',
      finalWeightKg: (d['finalWeightKg'] as num?)?.toDouble() ?? 0.0,
      pricePerKgPhp: (d['pricePerKgPhp'] as num?)?.toDouble() ?? 0.0,
      lineRevenuePhp: (d['lineRevenuePhp'] as num?)?.toDouble() ?? 0.0,
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'pigId': pigId,
        'pigTagId': pigTagId,
        'finalWeightKg': finalWeightKg,
        'pricePerKgPhp': pricePerKgPhp,
        'lineRevenuePhp': lineRevenuePhp,
        'createdAt': createdAt,
      };
}
