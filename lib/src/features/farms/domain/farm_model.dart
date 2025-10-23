// lib/src/features/farms/domain/farm_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Farm {
  final String id;
  final String name;
  final String ownerId;
  final Timestamp createdAt;
  final List<String> enabledModules;

  Farm({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.createdAt,
    this.enabledModules = const [],
  });

  factory Farm.fromMap(Map<String, dynamic> data, String documentId) {
    return Farm(
      id: documentId,
      name: data['name'],
      ownerId: data['ownerId'],
      createdAt: data['createdAt'],
      enabledModules: List<String>.from(data['enabledModules'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'ownerId': ownerId,
      'createdAt': createdAt,
      'enabledModules': enabledModules,
    };
  }
}
