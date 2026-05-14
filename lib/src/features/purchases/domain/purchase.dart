import 'package:cloud_firestore/cloud_firestore.dart';

class Purchase {
  final String id;
  final String farmId;
  final String vendorName;
  final Timestamp purchaseDate;
  final String? referenceNo;
  final double totalCostPhp;
  final String? receiptPhotoUrl;
  final String? notes;
  final String createdBy;
  final Timestamp createdAt;

  const Purchase({
    required this.id,
    required this.farmId,
    required this.vendorName,
    required this.purchaseDate,
    required this.referenceNo,
    required this.totalCostPhp,
    required this.receiptPhotoUrl,
    required this.notes,
    required this.createdBy,
    required this.createdAt,
  });

  factory Purchase.fromFirestore(
    DocumentSnapshot doc, {
    required String farmId,
  }) {
    final d = doc.data() as Map<String, dynamic>;
    return Purchase(
      id: doc.id,
      farmId: farmId,
      vendorName: d['vendorName'] as String? ?? '',
      purchaseDate: d['purchaseDate'] as Timestamp? ?? Timestamp.now(),
      referenceNo: d['referenceNo'] as String?,
      totalCostPhp: (d['totalCostPhp'] as num?)?.toDouble() ?? 0.0,
      receiptPhotoUrl: d['receiptPhotoUrl'] as String?,
      notes: d['notes'] as String?,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'vendorName': vendorName,
    'purchaseDate': purchaseDate,
    if (referenceNo != null) 'referenceNo': referenceNo,
    'totalCostPhp': totalCostPhp,
    if (receiptPhotoUrl != null) 'receiptPhotoUrl': receiptPhotoUrl,
    if (notes != null) 'notes': notes,
    'createdBy': createdBy,
    'createdAt': createdAt,
  };
}
