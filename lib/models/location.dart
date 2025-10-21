// lib/models/location.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Location {
  final String id;
  final String name;
  final String type; // e.g., "Building", "Pen"

  Location({required this.id, required this.name, required this.type});

  factory Location.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Location(
      id: doc.id,
      name: data['name'] ?? '',
      type: data['type'] ?? '',
    );
  }
}