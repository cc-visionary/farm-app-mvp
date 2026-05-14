import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../pigs/application/pig_providers.dart';
import '../pigs/domain/breeding_record.dart';
import '../pigs/domain/farrowing_record.dart';
import '../pigs/domain/mortality_record.dart';
import '../pigs/domain/pig.dart';
import 'yield_calculator.dart';
import 'yield_metrics.dart';

/// Currently selected reporting period. Drives every metric provider below.
final selectedPeriodProvider =
    StateProvider<YieldPeriod>((_) => YieldPeriod.d30);

/// Herd productivity (litter size, stillbirth rate, breeding success, PSY)
/// for the selected period.
final yieldHerdProductivityProvider =
    Provider.family<HerdProductivity, String>((ref, farmId) {
  final period = ref.watch(selectedPeriodProvider);
  final now = DateTime.now();
  final pigs =
      ref.watch(pigsStreamProvider(farmId)).asData?.value ?? const <Pig>[];
  final farrowings =
      ref.watch(allFarrowingsProvider(farmId)).asData?.value ??
          const <FarrowingRecord>[];
  // No breeding-collection-group provider yet; passing empty is handled
  // gracefully by the calculator (returns 0 success rate).
  final activeSows = pigs
      .where((p) =>
          p.sex == PigSex.female &&
          p.stage == PigStage.sow &&
          p.status == PigStatus.active)
      .length;
  return YieldCalculator.herdProductivity(
    farrowings: farrowings,
    breedings: const <BreedingRecord>[],
    activeSowCount: activeSows,
    periodStart: period.startFrom(now),
    now: now,
  );
});

/// Average daily gain (ADG) across active grow/finish pigs.
final yieldGrowthProvider =
    Provider.family<GrowthMetrics, String>((ref, farmId) {
  final pigs =
      ref.watch(pigsStreamProvider(farmId)).asData?.value ?? const <Pig>[];
  return YieldCalculator.growth(pigs: pigs, now: DateTime.now());
});

/// Mortality rate, by-area breakdown, top-3 causes.
final yieldMortalityProvider =
    Provider.family<MortalityMetrics, String>((ref, farmId) {
  final period = ref.watch(selectedPeriodProvider);
  final pigs =
      ref.watch(pigsStreamProvider(farmId)).asData?.value ?? const <Pig>[];
  final morts =
      ref.watch(allMortalitiesProvider(farmId)).asData?.value ??
          const <MortalityRecord>[];
  return YieldCalculator.mortality(
    mortalities: morts,
    allPigs: pigs,
    pigIdToAreaId: {for (final p in pigs) p.id: p.currentAreaId},
    periodStart: period.startFrom(DateTime.now()),
  );
});

/// Sold/culled counts in the period.
final yieldOutputProvider =
    Provider.family<OutputMetrics, String>((ref, farmId) {
  final period = ref.watch(selectedPeriodProvider);
  final pigs =
      ref.watch(pigsStreamProvider(farmId)).asData?.value ?? const <Pig>[];
  return YieldCalculator.output(
    pigs: pigs,
    periodStart: period.startFrom(DateTime.now()),
  );
});
