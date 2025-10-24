import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single event in an animal's history, like a vaccination or a health check.
class AnimalEvent {
  /// The specific status tag associated with this event (e.g., "Vaccinated", "Moved Pen").
  final String tag;

  /// Optional detailed notes about the event.
  final String? notes;

  /// The exact time the event occurred.
  final DateTime timestamp;

  /// The ID of the user who logged the event.
  final String createdBy;

  AnimalEvent({
    required this.tag,
    this.notes,
    required this.timestamp,
    required this.createdBy,
  });

  /// Creates an [AnimalEvent] instance from a Firestore map.
  /// This is used when reading data from the database.
  factory AnimalEvent.fromMap(Map<String, dynamic> map) {
    return AnimalEvent(
      tag: map['tag'] as String,
      notes: map['notes'] as String?,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      createdBy: map['createdBy'] as String,
    );
  }

  /// Converts the [AnimalEvent] instance into a map for Firestore.
  /// This is used when writing data to the database.
  Map<String, dynamic> toMap() {
    return {
      'tag': tag,
      'notes': notes,
      'timestamp': Timestamp.fromDate(timestamp),
      'createdBy': createdBy,
    };
  }
}
