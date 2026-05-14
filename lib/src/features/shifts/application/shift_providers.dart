import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../activity/application/activity_providers.dart';
import '../data/shift_repository.dart';
import '../domain/shift.dart';

final shiftRepositoryProvider = Provider<ShiftRepository>(
  (ref) => ShiftRepository(
    ref.watch(firestoreProvider),
    ref.watch(activityRepositoryProvider),
  ),
);

final shiftsStreamProvider = StreamProvider.family<List<Shift>, String>(
  (ref, farmId) => ref.watch(shiftRepositoryProvider).streamShifts(farmId),
);

/// Active shifts for the given date, sorted by start time.
final shiftsForDateProvider =
    Provider.family<List<Shift>, ({String farmId, DateTime date})>((ref, args) {
  final all =
      ref.watch(shiftsStreamProvider(args.farmId)).asData?.value ?? const <Shift>[];
  return all.where((s) => s.isActiveOn(args.date)).toList();
});
