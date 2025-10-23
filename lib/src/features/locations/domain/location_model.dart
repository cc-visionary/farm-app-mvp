import 'package:cloud_firestore/cloud_firestore.dart';

enum LocationType { building, pen, pasture }

class Location {
  final String id;
  final String name;
  final LocationType type;
  final String farmId;

  Location({
    required this.id,
    required this.name,
    required this.type,
    required this.farmId,
  });

  factory Location.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Location(
      id: doc.id,
      name: data['name'] ?? '',
      type: LocationType.values.firstWhere(
        (e) => e.toString() == data['type'],
        orElse: () => LocationType.pen,
      ),
      farmId: data['farmId'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'type': type.toString(),
      'farmId': farmId,
    };
  }
}