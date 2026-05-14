import 'package:cloud_firestore/cloud_firestore.dart';

enum BreedingMethod {
  natural('natural', 'Natural'),
  ai('ai', 'AI');

  const BreedingMethod(this.value, this.label);
  final String value;
  final String label;
  static BreedingMethod fromString(String s) => BreedingMethod.values
      .firstWhere((m) => m.value == s, orElse: () => BreedingMethod.natural);
}

enum BreedingStatus {
  planned('planned', 'Planned'),
  confirmed('confirmed', 'Confirmed pregnant'),
  farrowed('farrowed', 'Farrowed'),
  failed('failed', 'Failed'),
  aborted('aborted', 'Aborted');

  const BreedingStatus(this.value, this.label);
  final String value;
  final String label;
  static BreedingStatus fromString(String s) => BreedingStatus.values
      .firstWhere((b) => b.value == s, orElse: () => BreedingStatus.planned);
}

/// Gestation length in pigs (industry standard ~114 days,
/// "3 months, 3 weeks, 3 days").
const int gestationDays = 114;

class BreedingRecord {
  final String id;
  final String farmId;
  final String sowId;
  final String boarId;
  final Timestamp? heatDate;
  final Timestamp inseminationDate;
  final BreedingMethod method;
  final Timestamp? pregnancyCheckDate;
  final bool confirmed;
  final Timestamp expectedFarrowingDate;
  final BreedingStatus status;
  final String? notes;
  final String createdBy;
  final Timestamp createdAt;

  const BreedingRecord({
    required this.id,
    required this.farmId,
    required this.sowId,
    required this.boarId,
    required this.heatDate,
    required this.inseminationDate,
    required this.method,
    required this.pregnancyCheckDate,
    required this.confirmed,
    required this.expectedFarrowingDate,
    required this.status,
    required this.notes,
    required this.createdBy,
    required this.createdAt,
  });

  factory BreedingRecord.fromFirestore(
    DocumentSnapshot doc, {
    required String farmId,
    required String sowId,
  }) {
    final d = doc.data() as Map<String, dynamic>;
    return BreedingRecord(
      id: doc.id,
      farmId: farmId,
      sowId: sowId,
      boarId: d['boarId'] as String? ?? '',
      heatDate: d['heatDate'] as Timestamp?,
      inseminationDate: d['inseminationDate'] as Timestamp? ?? Timestamp.now(),
      method: BreedingMethod.fromString(d['method'] as String? ?? 'natural'),
      pregnancyCheckDate: d['pregnancyCheckDate'] as Timestamp?,
      confirmed: d['confirmed'] as bool? ?? false,
      expectedFarrowingDate:
          d['expectedFarrowingDate'] as Timestamp? ?? Timestamp.now(),
      status: BreedingStatus.fromString(d['status'] as String? ?? 'planned'),
      notes: d['notes'] as String?,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'boarId': boarId,
        if (heatDate != null) 'heatDate': heatDate,
        'inseminationDate': inseminationDate,
        'method': method.value,
        if (pregnancyCheckDate != null) 'pregnancyCheckDate': pregnancyCheckDate,
        'confirmed': confirmed,
        'expectedFarrowingDate': expectedFarrowingDate,
        'status': status.value,
        if (notes != null) 'notes': notes,
        'createdBy': createdBy,
        'createdAt': createdAt,
      };

  static Timestamp computeExpectedFarrowingDate(Timestamp inseminationDate) =>
      Timestamp.fromDate(
        inseminationDate.toDate().add(const Duration(days: gestationDays)),
      );
}
