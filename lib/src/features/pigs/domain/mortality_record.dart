import 'package:cloud_firestore/cloud_firestore.dart';

/// Cause-of-death record for a pig. Single doc per pig at:
/// `farms/{farmId}/pigs/{pigId}/mortality_record/primary`
class MortalityRecord {
  final String id;
  final String farmId;
  final String pigId;
  final Timestamp date;
  final String? cause;
  final List<String> photoUrls;
  final String? notes;
  final String createdBy;
  final Timestamp createdAt;

  const MortalityRecord({
    required this.id,
    required this.farmId,
    required this.pigId,
    required this.date,
    required this.cause,
    required this.photoUrls,
    required this.notes,
    required this.createdBy,
    required this.createdAt,
  });

  factory MortalityRecord.fromFirestore(
    DocumentSnapshot doc, {
    required String farmId,
    required String pigId,
  }) {
    final d = doc.data() as Map<String, dynamic>? ?? const {};
    return MortalityRecord(
      id: doc.id,
      farmId: farmId,
      pigId: pigId,
      date: d['date'] as Timestamp? ?? Timestamp.now(),
      cause: d['cause'] as String?,
      photoUrls: List<String>.from(d['photoUrls'] as List? ?? const []),
      notes: d['notes'] as String?,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'date': date,
        if (cause != null) 'cause': cause,
        'photoUrls': photoUrls,
        if (notes != null) 'notes': notes,
        'createdBy': createdBy,
        'createdAt': createdAt,
      };
}
