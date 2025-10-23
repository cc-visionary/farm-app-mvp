import 'package:cloud_firestore/cloud_firestore.dart';

class Animal {
  final String id;
  final String animalId; // User-defined ID like 'SOW-001'
  final DateTime birthDate;
  final String locationId;
  final String farmId;

  Animal({
    required this.id,
    required this.animalId,
    required this.birthDate,
    required this.locationId,
    required this.farmId,
  });

  factory Animal.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Animal(
      id: doc.id,
      animalId: data['animalId'] ?? '',
      birthDate: (data['birthDate'] as Timestamp).toDate(),
      locationId: data['locationId'] ?? '',
      farmId: data['farmId'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'animalId': animalId,
      'birthDate': Timestamp.fromDate(birthDate),
      'locationId': locationId,
      'farmId': farmId,
    };
  }
}