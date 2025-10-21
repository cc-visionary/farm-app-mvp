// lib/models/animal.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Animal {
  final String id; // Document ID from Firestore
  final String tagId; // The unique ID you give the animal
  final DateTime birthDate;
  final String locationId;
  final List<Map<String, dynamic>> history; // List of history notes

  Animal({
    required this.id,
    required this.tagId,
    required this.birthDate,
    required this.locationId,
    required this.history,
  });

  // Factory constructor to create an Animal from a Firestore document
  factory Animal.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Animal(
      id: doc.id,
      tagId: data['tagId'] ?? '',
      birthDate: (data['birthDate'] as Timestamp).toDate(),
      locationId: data['locationId'] ?? '',
      // Ensure history is always a list
      history: List<Map<String, dynamic>>.from(data['history'] ?? []),
    );
  }
}