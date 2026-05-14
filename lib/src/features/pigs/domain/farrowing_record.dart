import 'package:cloud_firestore/cloud_firestore.dart';

class FarrowingRecord {
  final String id;
  final String farmId;
  final String sowId;
  final String breedingRecordId;
  final Timestamp date;
  final int liveBorn;
  final int stillborn;
  final int mummified;
  final double? avgBirthWeightKg;
  final String? litterBatchId;
  final String? notes;
  final String createdBy;
  final Timestamp createdAt;

  const FarrowingRecord({
    required this.id,
    required this.farmId,
    required this.sowId,
    required this.breedingRecordId,
    required this.date,
    required this.liveBorn,
    required this.stillborn,
    required this.mummified,
    required this.avgBirthWeightKg,
    required this.litterBatchId,
    required this.notes,
    required this.createdBy,
    required this.createdAt,
  });

  factory FarrowingRecord.fromFirestore(
    DocumentSnapshot doc, {
    required String farmId,
    required String sowId,
  }) {
    final d = doc.data() as Map<String, dynamic>;
    return FarrowingRecord(
      id: doc.id,
      farmId: farmId,
      sowId: sowId,
      breedingRecordId: d['breedingRecordId'] as String? ?? '',
      date: d['date'] as Timestamp? ?? Timestamp.now(),
      liveBorn: d['liveBorn'] as int? ?? 0,
      stillborn: d['stillborn'] as int? ?? 0,
      mummified: d['mummified'] as int? ?? 0,
      avgBirthWeightKg: (d['avgBirthWeightKg'] as num?)?.toDouble(),
      litterBatchId: d['litterBatchId'] as String?,
      notes: d['notes'] as String?,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'breedingRecordId': breedingRecordId,
        'date': date,
        'liveBorn': liveBorn,
        'stillborn': stillborn,
        'mummified': mummified,
        if (avgBirthWeightKg != null) 'avgBirthWeightKg': avgBirthWeightKg,
        if (litterBatchId != null) 'litterBatchId': litterBatchId,
        if (notes != null) 'notes': notes,
        'createdBy': createdBy,
        'createdAt': createdAt,
      };

  int get totalBorn => liveBorn + stillborn + mummified;
}
