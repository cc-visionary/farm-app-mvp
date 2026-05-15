import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../l10n/generated/app_localizations.dart';

enum MaintenanceType {
  preventive('preventive', 'Preventive'),
  repair('repair', 'Repair'),
  inspection('inspection', 'Inspection');

  const MaintenanceType(this.value, this.label);
  final String value;
  final String label;

  static MaintenanceType fromString(String s) => MaintenanceType.values
      .firstWhere((e) => e.value == s, orElse: () => MaintenanceType.repair);
}

class MaintenanceRecord {
  final String id;
  final String farmId;
  final String equipmentId;
  final MaintenanceType type;
  final Timestamp date;
  final String? performedBy;
  final String? partsReplaced;
  final double? costPhp;
  final List<String> photoUrls;
  final String? notes;
  final String createdBy;
  final Timestamp createdAt;

  const MaintenanceRecord({
    required this.id,
    required this.farmId,
    required this.equipmentId,
    required this.type,
    required this.date,
    required this.performedBy,
    required this.partsReplaced,
    required this.costPhp,
    required this.photoUrls,
    required this.notes,
    required this.createdBy,
    required this.createdAt,
  });

  factory MaintenanceRecord.fromFirestore(
    DocumentSnapshot doc, {
    required String farmId,
    required String equipmentId,
  }) {
    final d = doc.data() as Map<String, dynamic>;
    return MaintenanceRecord(
      id: doc.id,
      farmId: farmId,
      equipmentId: equipmentId,
      type: MaintenanceType.fromString(d['type'] as String? ?? 'repair'),
      date: d['date'] as Timestamp? ?? Timestamp.now(),
      performedBy: d['performedBy'] as String?,
      partsReplaced: d['partsReplaced'] as String?,
      costPhp: (d['costPhp'] as num?)?.toDouble(),
      photoUrls: List<String>.from(d['photoUrls'] ?? const []),
      notes: d['notes'] as String?,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type.value,
        'date': date,
        if (performedBy != null) 'performedBy': performedBy,
        if (partsReplaced != null) 'partsReplaced': partsReplaced,
        if (costPhp != null) 'costPhp': costPhp,
        'photoUrls': photoUrls,
        if (notes != null) 'notes': notes,
        'createdBy': createdBy,
        'createdAt': createdAt,
      };
}

String localizedMaintenanceType(AppLocalizations l, MaintenanceType t) {
  switch (t) {
    case MaintenanceType.preventive:
      return l.maintenance_type_preventive;
    case MaintenanceType.repair:
      return l.maintenance_type_repair;
    case MaintenanceType.inspection:
      return l.maintenance_type_inspection;
  }
}
