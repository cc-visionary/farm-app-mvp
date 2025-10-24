import 'package:cloud_firestore/cloud_firestore.dart';
// We will create this model in Slice 4
import './animal_event_model.dart';

// Enum to define the type of animal entry
enum AnimalCategory { individual, flock }

class Animal {
  final String id;
  final String farmId;
  final AnimalCategory category; // Is it a single animal or a group?

  // Common Fields
  final String animalId; // e.g., 'SOW-001' or 'FLOCK-C02'
  final String animalType; // e.g., 'Pig' or 'Chicken'
  final String breed;
  final DateTime birthDate;
  final String locationId;

  // Fields for Individuals (like pigs)
  final String? stage; // e.g., 'Gestating'
  final double? weight;

  // Fields for Flocks (like chickens)
  final int? quantity;

  // For Slice 4
  final List<AnimalEvent> eventHistory;

  Animal({
    required this.id,
    required this.farmId,
    required this.category,
    required this.animalId,
    required this.animalType,
    required this.breed,
    required this.birthDate,
    required this.locationId,
    this.stage,
    this.weight,
    this.quantity,
    this.eventHistory = const [],
  });

  // Helper to calculate age
  String get age {
    final now = DateTime.now();
    final difference = now.difference(birthDate);
    final years = difference.inDays ~/ 365;
    final months = (difference.inDays % 365) ~/ 30;
    final weeks = (difference.inDays % 365) ~/ 7;

    if (years > 0) return '$years yr, $months mos';
    if (months > 0) return '$months mos';
    return '$weeks wks';
  }

  factory Animal.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data()! as Map<String, dynamic>;
    return Animal(
      id: doc.id,
      farmId: data['farmId'],
      category: AnimalCategory.values.byName(data['category'] ?? 'individual'),
      animalId: data['animalId'],
      animalType: data['animalType'],
      breed: data['breed'],
      birthDate: (data['birthDate'] as Timestamp).toDate(),
      locationId: data['locationId'],
      stage: data['stage'],
      weight: data['weight'],
      quantity: data['quantity'],
      eventHistory: (data['eventHistory'] as List<dynamic>? ?? [])
          .map((eventData) => AnimalEvent.fromMap(eventData))
          .toList(),
    );
  }

  Animal copyWith({
    String? id,
    String? farmId,
    AnimalCategory? category,
    String? animalId,
    String? animalType,
    String? breed,
    DateTime? birthDate,
    String? locationId,
    String? stage,
    double? weight,
    int? quantity,
    List<AnimalEvent>? eventHistory,
  }) {
    return Animal(
      id: id ?? this.id,
      farmId: farmId ?? this.farmId,
      category: category ?? this.category,
      animalId: animalId ?? this.animalId,
      animalType: animalType ?? this.animalType,
      breed: breed ?? this.breed,
      birthDate: birthDate ?? this.birthDate,
      locationId: locationId ?? this.locationId,
      stage: stage ?? this.stage,
      weight: weight ?? this.weight,
      quantity: quantity ?? this.quantity,
      eventHistory: eventHistory ?? this.eventHistory,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'farmId': farmId,
      'category': category.name,
      'animalId': animalId,
      'animalType': animalType,
      'breed': breed,
      'birthDate': Timestamp.fromDate(birthDate),
      'locationId': locationId,
      'stage': stage,
      'weight': weight,
      'quantity': quantity,
      'eventHistory': eventHistory.map((e) => e.toMap()).toList(),
    };
  }
}
