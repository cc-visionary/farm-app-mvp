import 'package:cloud_firestore/cloud_firestore.dart';
import 'supply_category.dart';

class Supply {
  final String id;
  final String farmId;
  final String name;
  final SupplyCategory category;
  final SupplyUnit unit;
  final int? unitsPerPackage;
  final num? lowStockThreshold;
  final num currentStock;
  final double weightedAvgUnitCostPhp;
  final String? notes;
  final String createdBy;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  const Supply({
    required this.id,
    required this.farmId,
    required this.name,
    required this.category,
    required this.unit,
    required this.unitsPerPackage,
    required this.lowStockThreshold,
    required this.currentStock,
    required this.weightedAvgUnitCostPhp,
    required this.notes,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Supply.fromFirestore(DocumentSnapshot doc, {required String farmId}) {
    final d = doc.data() as Map<String, dynamic>;
    return Supply(
      id: doc.id,
      farmId: farmId,
      name: d['name'] as String? ?? '(unnamed)',
      category: SupplyCategory.fromString(
        d['category'] as String? ?? 'other_input',
      ),
      unit: SupplyUnit.fromString(d['unit'] as String? ?? 'unit'),
      unitsPerPackage: (d['unitsPerPackage'] as num?)?.toInt(),
      lowStockThreshold: d['lowStockThreshold'] as num?,
      currentStock: (d['currentStock'] as num?) ?? 0,
      weightedAvgUnitCostPhp:
          (d['weightedAvgUnitCostPhp'] as num?)?.toDouble() ?? 0.0,
      notes: d['notes'] as String?,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: d['updatedAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'category': category.value,
    'unit': unit.value,
    if (unitsPerPackage != null) 'unitsPerPackage': unitsPerPackage,
    if (lowStockThreshold != null) 'lowStockThreshold': lowStockThreshold,
    'currentStock': currentStock,
    'weightedAvgUnitCostPhp': weightedAvgUnitCostPhp,
    if (notes != null) 'notes': notes,
    'createdBy': createdBy,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  bool get isOutOfStock => currentStock <= 0;
  bool get isLowStock =>
      lowStockThreshold != null &&
      currentStock < lowStockThreshold! &&
      !isOutOfStock;

  Supply copyWith({
    String? name,
    SupplyCategory? category,
    SupplyUnit? unit,
    int? unitsPerPackage,
    num? lowStockThreshold,
    num? currentStock,
    double? weightedAvgUnitCostPhp,
    String? notes,
  }) => Supply(
    id: id,
    farmId: farmId,
    name: name ?? this.name,
    category: category ?? this.category,
    unit: unit ?? this.unit,
    unitsPerPackage: unitsPerPackage ?? this.unitsPerPackage,
    lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
    currentStock: currentStock ?? this.currentStock,
    weightedAvgUnitCostPhp:
        weightedAvgUnitCostPhp ?? this.weightedAvgUnitCostPhp,
    notes: notes ?? this.notes,
    createdBy: createdBy,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
