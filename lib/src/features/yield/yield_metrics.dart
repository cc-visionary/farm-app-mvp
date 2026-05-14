enum YieldPeriod {
  d7('7d', Duration(days: 7)),
  d30('30d', Duration(days: 30)),
  d90('90d', Duration(days: 90)),
  ytd('YTD', Duration.zero),
  all('All-time', Duration.zero);

  const YieldPeriod(this.label, this.duration);
  final String label;
  final Duration duration;

  DateTime startFrom(DateTime now) {
    switch (this) {
      case YieldPeriod.d7:
      case YieldPeriod.d30:
      case YieldPeriod.d90:
        return now.subtract(duration);
      case YieldPeriod.ytd:
        return DateTime(now.year, 1, 1);
      case YieldPeriod.all:
        return DateTime(1970);
    }
  }
}

class HerdProductivity {
  final double avgLitterSize;
  final double avgStillborns;
  final double stillbirthRate;
  final double preWeaningMortalityRate;
  final double breedingSuccessRate;
  final double psyEstimate;
  final int totalFarrowings;

  const HerdProductivity({
    required this.avgLitterSize,
    required this.avgStillborns,
    required this.stillbirthRate,
    required this.preWeaningMortalityRate,
    required this.breedingSuccessRate,
    required this.psyEstimate,
    required this.totalFarrowings,
  });

  static const empty = HerdProductivity(
    avgLitterSize: 0,
    avgStillborns: 0,
    stillbirthRate: 0,
    preWeaningMortalityRate: 0,
    breedingSuccessRate: 0,
    psyEstimate: 0,
    totalFarrowings: 0,
  );
}

class GrowthMetrics {
  final double avgDailyGainKg;
  final int activeGrowFinishCount;

  const GrowthMetrics({
    required this.avgDailyGainKg,
    required this.activeGrowFinishCount,
  });

  static const empty = GrowthMetrics(avgDailyGainKg: 0, activeGrowFinishCount: 0);
}

class MortalityMetrics {
  final double overallMortalityRate;
  final Map<String, int> byArea;
  final List<MapEntry<String, int>> topCauses;
  final int totalDeaths;

  const MortalityMetrics({
    required this.overallMortalityRate,
    required this.byArea,
    required this.topCauses,
    required this.totalDeaths,
  });

  static const empty = MortalityMetrics(
    overallMortalityRate: 0,
    byArea: {},
    topCauses: [],
    totalDeaths: 0,
  );
}

class OutputMetrics {
  final int sold;
  final int culled;

  const OutputMetrics({required this.sold, required this.culled});

  static const empty = OutputMetrics(sold: 0, culled: 0);
}
