import 'package:cloud_firestore/cloud_firestore.dart';

enum EquipmentType {
  ventilation('ventilation', 'Ventilation'),
  feeder('feeder', 'Feeder'),
  waterPump('water_pump', 'Water Pump'),
  generator('generator', 'Generator'),
  scale('scale', 'Scale'),
  vehicle('vehicle', 'Vehicle'),
  structure('structure', 'Structure'),
  tool('tool', 'Tool'),
  other('other', 'Other');

  const EquipmentType(this.value, this.label);
  final String value;
  final String label;

  static EquipmentType fromString(String s) => EquipmentType.values
      .firstWhere((e) => e.value == s, orElse: () => EquipmentType.other);
}

enum EquipmentStatus {
  inUse('in_use', 'In use'),
  available('available', 'Available'),
  needsRepair('needs_repair', 'Needs repair'),
  retired('retired', 'Retired');

  const EquipmentStatus(this.value, this.label);
  final String value;
  final String label;

  static EquipmentStatus fromString(String s) => EquipmentStatus.values
      .firstWhere((e) => e.value == s, orElse: () => EquipmentStatus.available);

  /// Used by the one-tap status cycle (excluding retired which is a manual choice).
  EquipmentStatus get next {
    switch (this) {
      case EquipmentStatus.inUse:
        return EquipmentStatus.available;
      case EquipmentStatus.available:
        return EquipmentStatus.needsRepair;
      case EquipmentStatus.needsRepair:
        return EquipmentStatus.inUse;
      case EquipmentStatus.retired:
        return EquipmentStatus.retired;
    }
  }
}

class Equipment {
  final String id;
  final String farmId;
  final String name;
  final EquipmentType type;
  final String? areaId;
  final EquipmentStatus status;
  final Timestamp? purchaseDate;
  final double? purchaseCostPhp;
  final String? photoUrl;
  final String? notes;
  final String createdBy;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  const Equipment({
    required this.id,
    required this.farmId,
    required this.name,
    required this.type,
    required this.areaId,
    required this.status,
    required this.purchaseDate,
    required this.purchaseCostPhp,
    required this.photoUrl,
    required this.notes,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Equipment.fromFirestore(DocumentSnapshot doc, {required String farmId}) {
    final d = doc.data() as Map<String, dynamic>;
    return Equipment(
      id: doc.id,
      farmId: farmId,
      name: d['name'] as String? ?? '(unnamed)',
      type: EquipmentType.fromString(d['type'] as String? ?? 'other'),
      areaId: d['areaId'] as String?,
      status: EquipmentStatus.fromString(d['status'] as String? ?? 'available'),
      purchaseDate: d['purchaseDate'] as Timestamp?,
      purchaseCostPhp: (d['purchaseCostPhp'] as num?)?.toDouble(),
      photoUrl: d['photoUrl'] as String?,
      notes: d['notes'] as String?,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: d['updatedAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'type': type.value,
        if (areaId != null) 'areaId': areaId,
        'status': status.value,
        if (purchaseDate != null) 'purchaseDate': purchaseDate,
        if (purchaseCostPhp != null) 'purchaseCostPhp': purchaseCostPhp,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (notes != null) 'notes': notes,
        'createdBy': createdBy,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };
}
