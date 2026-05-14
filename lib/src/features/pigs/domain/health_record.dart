import 'package:cloud_firestore/cloud_firestore.dart';

enum HealthEventType {
  vaccination('vaccination', 'Vaccination'),
  treatment('treatment', 'Treatment'),
  checkup('checkup', 'Checkup'),
  deworming('deworming', 'Deworming');

  const HealthEventType(this.value, this.label);
  final String value;
  final String label;

  static HealthEventType fromString(String s) =>
      HealthEventType.values.firstWhere(
        (e) => e.value == s,
        orElse: () => HealthEventType.checkup,
      );
}

enum HealthRoute {
  oral('oral', 'Oral'),
  im('im', 'IM (intramuscular)'),
  sc('sc', 'SC (subcutaneous)'),
  topical('topical', 'Topical');

  const HealthRoute(this.value, this.label);
  final String value;
  final String label;

  static HealthRoute fromString(String s) =>
      HealthRoute.values.firstWhere(
        (r) => r.value == s,
        orElse: () => HealthRoute.oral,
      );
}

class HealthRecord {
  final String id;
  final String farmId;
  final String pigId;
  final HealthEventType type;
  final Timestamp date;
  final String? productName;
  final String? dosage;
  final HealthRoute? route;
  final String? diagnosis;
  final Timestamp? withdrawalEndDate;
  final double? costPhp;
  final List<String> photoUrls;
  final String? notes;
  final String createdBy;
  final Timestamp createdAt;

  const HealthRecord({
    required this.id,
    required this.farmId,
    required this.pigId,
    required this.type,
    required this.date,
    required this.productName,
    required this.dosage,
    required this.route,
    required this.diagnosis,
    required this.withdrawalEndDate,
    required this.costPhp,
    required this.photoUrls,
    required this.notes,
    required this.createdBy,
    required this.createdAt,
  });

  factory HealthRecord.fromFirestore(
    DocumentSnapshot doc, {
    required String farmId,
    required String pigId,
  }) {
    final d = doc.data() as Map<String, dynamic>;
    return HealthRecord(
      id: doc.id,
      farmId: farmId,
      pigId: pigId,
      type: HealthEventType.fromString(d['type'] as String? ?? 'checkup'),
      date: d['date'] as Timestamp? ?? Timestamp.now(),
      productName: d['productName'] as String?,
      dosage: d['dosage'] as String?,
      route: d['route'] != null
          ? HealthRoute.fromString(d['route'] as String)
          : null,
      diagnosis: d['diagnosis'] as String?,
      withdrawalEndDate: d['withdrawalEndDate'] as Timestamp?,
      costPhp: (d['costPhp'] as num?)?.toDouble(),
      photoUrls: List<String>.from(d['photoUrls'] as List? ?? const []),
      notes: d['notes'] as String?,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type.value,
        'date': date,
        if (productName != null) 'productName': productName,
        if (dosage != null) 'dosage': dosage,
        if (route != null) 'route': route!.value,
        if (diagnosis != null) 'diagnosis': diagnosis,
        if (withdrawalEndDate != null) 'withdrawalEndDate': withdrawalEndDate,
        if (costPhp != null) 'costPhp': costPhp,
        'photoUrls': photoUrls,
        if (notes != null) 'notes': notes,
        'createdBy': createdBy,
        'createdAt': createdAt,
      };
}
