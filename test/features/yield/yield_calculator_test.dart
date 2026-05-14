import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:farm_app/src/features/pigs/domain/farrowing_record.dart';
import 'package:farm_app/src/features/pigs/domain/mortality_record.dart';
import 'package:farm_app/src/features/pigs/domain/pig.dart';
import 'package:farm_app/src/features/yield/yield_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('herdProductivity averages litter size and stillbirth rate', () {
    final now = DateTime(2026, 5, 14);
    final start = now.subtract(const Duration(days: 30));
    final farrowings = [
      _farr(date: now.subtract(const Duration(days: 5)), live: 10, still: 1),
      _farr(date: now.subtract(const Duration(days: 10)), live: 12, still: 0),
      _farr(date: now.subtract(const Duration(days: 15)), live: 8, still: 2),
    ];
    final result = YieldCalculator.herdProductivity(
      farrowings: farrowings,
      breedings: const [],
      activeSowCount: 5,
      periodStart: start,
      now: now,
    );
    expect(result.avgLitterSize, closeTo(10, 0.01));
    expect(result.stillbirthRate, closeTo(3 / 33, 0.01));
    expect(result.totalFarrowings, 3);
  });

  test('herdProductivity empty period returns zeros', () {
    final r = YieldCalculator.herdProductivity(
      farrowings: const [],
      breedings: const [],
      activeSowCount: 5,
      periodStart: DateTime(2026, 1, 1),
      now: DateTime(2026, 5, 14),
    );
    expect(r.avgLitterSize, 0);
  });

  test('growth computes mean ADG', () {
    final now = DateTime(2026, 5, 14);
    final pigs = [
      _pig(
        stage: PigStage.grower,
        status: PigStatus.active,
        birthDate: now.subtract(const Duration(days: 100)),
        currentWeight: 50,
        weightUpdatedAt: now,
      ),
      _pig(
        stage: PigStage.finisher,
        status: PigStatus.active,
        birthDate: now.subtract(const Duration(days: 200)),
        currentWeight: 100,
        weightUpdatedAt: now,
      ),
    ];
    final g = YieldCalculator.growth(pigs: pigs, now: now);
    // ADG: 50/100=0.5, 100/200=0.5 -> mean 0.5
    expect(g.avgDailyGainKg, closeTo(0.5, 0.01));
    expect(g.activeGrowFinishCount, 2);
  });

  test('mortality rate by area and top causes', () {
    final now = DateTime(2026, 5, 14);
    final start = now.subtract(const Duration(days: 30));
    final morts = [
      _mort(now.subtract(const Duration(days: 5)),
          pigId: 'p1', cause: 'Respiratory'),
      _mort(now.subtract(const Duration(days: 10)),
          pigId: 'p2', cause: 'Respiratory'),
      _mort(now.subtract(const Duration(days: 15)),
          pigId: 'p3', cause: 'Accident'),
    ];
    final allPigs = List.generate(
      20,
      (i) => _pig(
        birthDate: now.subtract(const Duration(days: 100)),
        stage: PigStage.grower,
        status: PigStatus.active,
        currentWeight: null,
        weightUpdatedAt: null,
      ),
    );
    final m = YieldCalculator.mortality(
      mortalities: morts,
      allPigs: allPigs,
      pigIdToAreaId: {'p1': 'a1', 'p2': 'a1', 'p3': 'a2'},
      periodStart: start,
    );
    expect(m.totalDeaths, 3);
    expect(m.overallMortalityRate, closeTo(3 / 20, 0.01));
    expect(m.byArea['a1'], 2);
    expect(m.topCauses.first.key, 'Respiratory');
  });
}

FarrowingRecord _farr({
  required DateTime date,
  required int live,
  required int still,
}) =>
    FarrowingRecord(
      id: 'x',
      farmId: 'f',
      sowId: 's',
      breedingRecordId: 'br',
      date: Timestamp.fromDate(date),
      liveBorn: live,
      stillborn: still,
      mummified: 0,
      avgBirthWeightKg: null,
      litterBatchId: null,
      notes: null,
      createdBy: 'u',
      createdAt: Timestamp.now(),
    );

Pig _pig({
  required DateTime birthDate,
  required PigStage stage,
  required PigStatus status,
  double? currentWeight,
  DateTime? weightUpdatedAt,
}) =>
    Pig(
      id: 'x',
      farmId: 'f',
      tagId: 't',
      sex: PigSex.male,
      breed: 'y',
      birthDate: Timestamp.fromDate(birthDate),
      sireId: null,
      damId: null,
      stage: stage,
      status: status,
      currentAreaId: 'a',
      currentPenId: null,
      currentBatchId: null,
      currentWeight: currentWeight,
      weightUpdatedAt:
          weightUpdatedAt == null ? null : Timestamp.fromDate(weightUpdatedAt),
      photoUrl: null,
      notes: null,
      createdBy: 'u',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.fromDate(birthDate.add(const Duration(days: 1))),
    );

MortalityRecord _mort(
  DateTime date, {
  required String pigId,
  required String cause,
}) =>
    MortalityRecord(
      id: 'm',
      farmId: 'f',
      pigId: pigId,
      date: Timestamp.fromDate(date),
      cause: cause,
      photoUrls: const [],
      notes: null,
      createdBy: 'u',
      createdAt: Timestamp.now(),
    );
