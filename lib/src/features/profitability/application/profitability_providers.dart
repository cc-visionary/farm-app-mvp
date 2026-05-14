// lib/src/features/profitability/application/profitability_providers.dart
//
// Riverpod wiring for the profitability calculator. The Period P&L provider
// composes streams of sales, supply movements, supplies, health records, and
// expenses, then delegates to the pure-function calculator.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../activity/application/activity_providers.dart';
import '../../expenses/application/expense_providers.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../inventory/domain/supply.dart';
import '../../inventory/domain/supply_movement.dart';
import '../../pigs/domain/health_record.dart';
import '../../sales/application/sale_providers.dart';
import '../../yield/yield_providers.dart';
import 'profitability_calculator.dart';

/// Period P&L using the same period selector as Yield Reports.
final profitabilityForPeriodProvider =
    Provider.family<ProfitabilityBreakdown, String>((ref, farmId) {
  final period = ref.watch(selectedPeriodProvider);
  final now = DateTime.now();
  final start = Timestamp.fromDate(period.startFrom(now));
  final end = Timestamp.fromDate(now.add(const Duration(days: 1)));

  final sales =
      ref.watch(salesStreamProvider(farmId)).asData?.value ?? const [];
  final movements = ref.watch(allMovementsProvider(farmId)).asData?.value ??
      const <SupplyMovement>[];
  final supplies =
      ref.watch(suppliesStreamProvider(farmId)).asData?.value ?? const <Supply>[];
  final suppliesById = {for (final s in supplies) s.id: s};
  final healthRecords =
      ref.watch(allHealthRecordsProvider(farmId)).asData?.value ??
          const <HealthRecord>[];
  final expenses =
      ref.watch(expensesStreamProvider(farmId)).asData?.value ?? const [];

  return ProfitabilityCalculator.forPeriod(
    start: start,
    end: end,
    sales: sales,
    movements: movements,
    suppliesById: suppliesById,
    healthRecords: healthRecords,
    expenses: expenses,
  );
});

/// Streams ALL movements for the farm. The calculator filters by exact range,
/// so we lean on Firestore's range filter to bound the result set. Use a
/// far-back start so YTD/all-time periods stay correct.
final allMovementsProvider =
    StreamProvider.family<List<SupplyMovement>, String>((ref, farmId) {
  return ref.watch(movementRepositoryProvider).streamInRange(
        farmId: farmId,
        start: Timestamp.fromMillisecondsSinceEpoch(0),
        end: Timestamp.fromDate(DateTime.now().add(const Duration(days: 1))),
      );
});

/// Streams ALL health records for the farm via a collection-group query.
/// Each `health_records` document lives under `farms/{farmId}/pigs/{pigId}`;
/// we filter by the path prefix to scope to one farm.
final allHealthRecordsProvider =
    StreamProvider.family<List<HealthRecord>, String>((ref, farmId) {
  return ref
      .watch(firestoreProvider)
      .collectionGroup('health_records')
      .snapshots()
      .map((s) {
    return s.docs.where((d) {
      final parts = d.reference.path.split('/');
      return parts.length >= 4 && parts[0] == 'farms' && parts[1] == farmId;
    }).map((d) {
      final pigId = d.reference.parent.parent!.id;
      return HealthRecord.fromFirestore(d, farmId: farmId, pigId: pigId);
    }).toList();
  });
});
