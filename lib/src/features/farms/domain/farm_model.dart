import 'package:cloud_firestore/cloud_firestore.dart';

class Farm {
  final String id;
  final String name;
  final String createdBy;
  final Timestamp createdAt;

  const Farm({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.createdAt,
  });

  factory Farm.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Farm(
      id: doc.id,
      name: d['name'] as String,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'createdBy': createdBy,
    'createdAt': createdAt,
  };
}
