import 'package:cloud_firestore/cloud_firestore.dart';
import 'payment_method.dart';
import 'payment_status.dart';

class Sale {
  final String id;
  final String farmId;
  final String buyerName;
  final String? buyerContact;
  final Timestamp saleDate;
  final int totalHeads;
  final double totalWeightKg;
  final double totalRevenuePhp;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final double? amountPaidPhp;
  final String? notes;
  final String createdBy;
  final Timestamp createdAt;

  const Sale({
    required this.id,
    required this.farmId,
    required this.buyerName,
    required this.buyerContact,
    required this.saleDate,
    required this.totalHeads,
    required this.totalWeightKg,
    required this.totalRevenuePhp,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.amountPaidPhp,
    required this.notes,
    required this.createdBy,
    required this.createdAt,
  });

  factory Sale.fromFirestore(DocumentSnapshot doc, {required String farmId}) {
    final d = doc.data() as Map<String, dynamic>;
    return Sale(
      id: doc.id,
      farmId: farmId,
      buyerName: d['buyerName'] as String? ?? '',
      buyerContact: d['buyerContact'] as String?,
      saleDate: d['saleDate'] as Timestamp? ?? Timestamp.now(),
      totalHeads: (d['totalHeads'] as num?)?.toInt() ?? 0,
      totalWeightKg: (d['totalWeightKg'] as num?)?.toDouble() ?? 0.0,
      totalRevenuePhp: (d['totalRevenuePhp'] as num?)?.toDouble() ?? 0.0,
      paymentMethod:
          PaymentMethod.fromString(d['paymentMethod'] as String? ?? 'cash'),
      paymentStatus:
          PaymentStatus.fromString(d['paymentStatus'] as String? ?? 'paid'),
      amountPaidPhp: (d['amountPaidPhp'] as num?)?.toDouble(),
      notes: d['notes'] as String?,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'buyerName': buyerName,
        if (buyerContact != null) 'buyerContact': buyerContact,
        'saleDate': saleDate,
        'totalHeads': totalHeads,
        'totalWeightKg': totalWeightKg,
        'totalRevenuePhp': totalRevenuePhp,
        'paymentMethod': paymentMethod.value,
        'paymentStatus': paymentStatus.value,
        if (amountPaidPhp != null) 'amountPaidPhp': amountPaidPhp,
        if (notes != null) 'notes': notes,
        'createdBy': createdBy,
        'createdAt': createdAt,
      };
}
