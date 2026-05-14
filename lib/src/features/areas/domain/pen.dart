import 'package:cloud_firestore/cloud_firestore.dart';

class Pen {
  final String id;
  final String farmId;
  final String areaId;
  final String name;
  final int? capacity;
  final int currentOccupancy;
  final String? notes;

  const Pen({
    required this.id,
    required this.farmId,
    required this.areaId,
    required this.name,
    required this.capacity,
    required this.currentOccupancy,
    required this.notes,
  });

  factory Pen.fromFirestore(DocumentSnapshot doc, {required String farmId, required String areaId}) {
    final d = doc.data() as Map<String, dynamic>;
    return Pen(
      id: doc.id,
      farmId: farmId,
      areaId: areaId,
      name: d['name'] as String,
      capacity: d['capacity'] as int?,
      currentOccupancy: (d['currentOccupancy'] as int?) ?? 0,
      notes: d['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    if (capacity != null) 'capacity': capacity,
    'currentOccupancy': currentOccupancy,
    if (notes != null) 'notes': notes,
  };

  double get occupancyRatio {
    if (capacity == null || capacity == 0) return 0;
    return currentOccupancy / capacity!;
  }
}
