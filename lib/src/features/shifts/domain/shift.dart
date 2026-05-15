import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../l10n/generated/app_localizations.dart';

enum ShiftPattern {
  daily('daily', 'Daily'),
  weekly('weekly', 'Weekly');

  const ShiftPattern(this.value, this.label);
  final String value;
  final String label;

  static ShiftPattern fromString(String s) => ShiftPattern.values.firstWhere(
        (p) => p.value == s,
        orElse: () => ShiftPattern.daily,
      );
}

class Shift {
  final String id;
  final String farmId;
  final String name;
  final ShiftPattern pattern;

  /// 0=Sun, 1=Mon, ..., 6=Sat. Empty for daily pattern.
  final List<int> daysOfWeek;

  /// 'HH:mm' 24h format.
  final String startTime;
  final String endTime;
  final String assignedAreaId;
  final List<String> assignedUserIds;
  final String? notes;
  final String createdBy;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  const Shift({
    required this.id,
    required this.farmId,
    required this.name,
    required this.pattern,
    required this.daysOfWeek,
    required this.startTime,
    required this.endTime,
    required this.assignedAreaId,
    required this.assignedUserIds,
    required this.notes,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Shift.fromFirestore(DocumentSnapshot doc, {required String farmId}) {
    final d = doc.data() as Map<String, dynamic>;
    return Shift(
      id: doc.id,
      farmId: farmId,
      name: d['name'] as String,
      pattern: ShiftPattern.fromString(d['pattern'] as String? ?? 'daily'),
      daysOfWeek: List<int>.from(d['daysOfWeek'] ?? const []),
      startTime: d['startTime'] as String,
      endTime: d['endTime'] as String,
      assignedAreaId: d['assignedAreaId'] as String,
      assignedUserIds: List<String>.from(d['assignedUserIds'] ?? const []),
      notes: d['notes'] as String?,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: d['updatedAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'pattern': pattern.value,
        'daysOfWeek': daysOfWeek,
        'startTime': startTime,
        'endTime': endTime,
        'assignedAreaId': assignedAreaId,
        'assignedUserIds': assignedUserIds,
        if (notes != null) 'notes': notes,
        'createdBy': createdBy,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  /// Returns true if this shift is active on the given date.
  bool isActiveOn(DateTime date) {
    if (pattern == ShiftPattern.daily) return true;
    // DateTime weekday: 1=Mon..7=Sun. Map to 0=Sun..6=Sat.
    final dow = date.weekday == 7 ? 0 : date.weekday;
    return daysOfWeek.contains(dow);
  }
}

String localizedShiftPattern(AppLocalizations l, ShiftPattern p) {
  switch (p) {
    case ShiftPattern.daily:
      return l.shift_pattern_daily;
    case ShiftPattern.weekly:
      return l.shift_pattern_weekly;
  }
}

/// Single-letter day-of-week labels for the current locale, in S/M/T/W/T/F/S
/// order (index 0 = Sunday … 6 = Saturday).
List<String> shiftDowLabels(AppLocalizations l) => [
      l.shift_dow_sun,
      l.shift_dow_mon,
      l.shift_dow_tue,
      l.shift_dow_wed,
      l.shift_dow_thu,
      l.shift_dow_fri,
      l.shift_dow_sat,
    ];
