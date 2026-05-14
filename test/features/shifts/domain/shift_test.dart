import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/features/shifts/domain/shift.dart';

void main() {
  Shift mk(ShiftPattern p, List<int> days) => Shift(
        id: 'x',
        farmId: 'f',
        name: 'n',
        pattern: p,
        daysOfWeek: days,
        startTime: '06:00',
        endTime: '14:00',
        assignedAreaId: 'a',
        assignedUserIds: const [],
        notes: null,
        createdBy: 'u',
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );

  test('daily is always active', () {
    expect(mk(ShiftPattern.daily, []).isActiveOn(DateTime(2026, 5, 14)), true);
  });

  test('weekly active only on listed days', () {
    // 2026-05-14 is a Thursday → weekday=4 → dow=4
    expect(mk(ShiftPattern.weekly, [4]).isActiveOn(DateTime(2026, 5, 14)), true);
    expect(mk(ShiftPattern.weekly, [1, 3]).isActiveOn(DateTime(2026, 5, 14)), false);
  });

  test('Sunday maps to 0', () {
    // 2026-05-17 is Sunday → weekday=7 → dow=0
    expect(mk(ShiftPattern.weekly, [0]).isActiveOn(DateTime(2026, 5, 17)), true);
  });
}
