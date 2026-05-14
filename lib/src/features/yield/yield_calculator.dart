import '../pigs/domain/breeding_record.dart';
import '../pigs/domain/farrowing_record.dart';
import '../pigs/domain/mortality_record.dart';
import '../pigs/domain/pig.dart';
import 'yield_metrics.dart';

/// Pure-function calculator for yield-related metrics.
///
/// All methods are side-effect free and operate exclusively on the data
/// passed in, so they can be unit tested without any framework setup.
class YieldCalculator {
  YieldCalculator._();

  /// Computes breeding/farrowing-related productivity for the period.
  ///
  /// Returns [HerdProductivity.empty] when no farrowings fall in the period.
  static HerdProductivity herdProductivity({
    required List<FarrowingRecord> farrowings,
    required List<BreedingRecord> breedings,
    required int activeSowCount,
    required DateTime periodStart,
    required DateTime now,
  }) {
    final inPeriod = farrowings.where((f) {
      final d = f.date.toDate();
      return d.isAfter(periodStart) || d.isAtSameMomentAs(periodStart);
    }).toList();
    if (inPeriod.isEmpty) return HerdProductivity.empty;

    final totalLive = inPeriod.fold<int>(0, (s, f) => s + f.liveBorn);
    final totalStill = inPeriod.fold<int>(0, (s, f) => s + f.stillborn);
    final avgLitter = totalLive / inPeriod.length;
    final avgStill = totalStill / inPeriod.length;
    final stillRate = (totalLive + totalStill) == 0
        ? 0.0
        : totalStill / (totalLive + totalStill);
    // Pre-weaning mortality rate is not tracked separately yet; placeholder 0.
    const preWean = 0.0;

    final breedingsInPeriod = breedings
        .where((b) => b.inseminationDate.toDate().isAfter(periodStart))
        .toList();
    final confirmed = breedingsInPeriod.where((b) => b.confirmed).length;
    final successRate = breedingsInPeriod.isEmpty
        ? 0.0
        : confirmed / breedingsInPeriod.length;

    // PSY estimate: (live born in period) extrapolated to a year / active sow count.
    final daysInPeriod = now.difference(periodStart).inDays.clamp(1, 365);
    final yearlyExtrapolation = (totalLive / daysInPeriod) * 365;
    final psy =
        activeSowCount == 0 ? 0.0 : yearlyExtrapolation / activeSowCount;

    return HerdProductivity(
      avgLitterSize: avgLitter,
      avgStillborns: avgStill,
      stillbirthRate: stillRate,
      preWeaningMortalityRate: preWean,
      breedingSuccessRate: successRate,
      psyEstimate: psy,
      totalFarrowings: inPeriod.length,
    );
  }

  /// Average daily gain (kg/day) across active grower/finisher pigs that
  /// have both a current weight and a weight-update timestamp.
  static GrowthMetrics growth({
    required List<Pig> pigs,
    required DateTime now,
  }) {
    final growers = pigs
        .where((p) =>
            (p.stage == PigStage.grower || p.stage == PigStage.finisher) &&
            p.status == PigStatus.active)
        .toList();
    final adgs = <double>[];
    for (final p in growers) {
      if (p.currentWeight == null || p.weightUpdatedAt == null) continue;
      final birthDate = p.birthDate.toDate();
      final lastWeighDate = p.weightUpdatedAt!.toDate();
      final days = lastWeighDate.difference(birthDate).inDays;
      if (days <= 0) continue;
      adgs.add(p.currentWeight! / days);
    }
    final avgAdg =
        adgs.isEmpty ? 0.0 : adgs.reduce((a, b) => a + b) / adgs.length;
    return GrowthMetrics(
      avgDailyGainKg: avgAdg,
      activeGrowFinishCount: growers.length,
    );
  }

  /// Mortality rate and breakdowns. `pigIdToAreaId` is consulted at call time
  /// to attribute each death to the pig's current area at the time the
  /// caller built the map.
  static MortalityMetrics mortality({
    required List<MortalityRecord> mortalities,
    required List<Pig> allPigs,
    required Map<String, String> pigIdToAreaId,
    required DateTime periodStart,
  }) {
    final inPeriod = mortalities
        .where((m) => m.date.toDate().isAfter(periodStart))
        .toList();
    final herdAtStart = allPigs.length;
    final rate = herdAtStart == 0 ? 0.0 : inPeriod.length / herdAtStart;
    final byArea = <String, int>{};
    final causeCounts = <String, int>{};
    for (final m in inPeriod) {
      final area = pigIdToAreaId[m.pigId] ?? 'unknown';
      byArea[area] = (byArea[area] ?? 0) + 1;
      final c = m.cause ?? 'Unknown';
      causeCounts[c] = (causeCounts[c] ?? 0) + 1;
    }
    final topCauses = causeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return MortalityMetrics(
      overallMortalityRate: rate,
      byArea: byArea,
      topCauses: topCauses.take(3).toList(),
      totalDeaths: inPeriod.length,
    );
  }

  /// Sold/culled pig counts in the period. Uses [Pig.updatedAt] as a proxy
  /// for sale/cull date until those events get their own timestamps.
  static OutputMetrics output({
    required List<Pig> pigs,
    required DateTime periodStart,
  }) {
    final inPeriod =
        pigs.where((p) => p.updatedAt.toDate().isAfter(periodStart)).toList();
    final sold = inPeriod.where((p) => p.status == PigStatus.sold).length;
    final culled = inPeriod.where((p) => p.status == PigStatus.culled).length;
    return OutputMetrics(sold: sold, culled: culled);
  }
}
