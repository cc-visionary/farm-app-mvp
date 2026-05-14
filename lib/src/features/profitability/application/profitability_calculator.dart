// lib/src/features/profitability/application/profitability_calculator.dart
//
// Pure-function P&L math. Two entry points:
//   - forPeriod: revenue and costs aggregated across a [start, end) window
//   - forBatch:  revenue (via line items for batch member pigs) + batch costs
//
// No Firestore I/O — callers wire data in from providers.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../expenses/domain/expense.dart';
import '../../expenses/domain/expense_category.dart';
import '../../inventory/domain/supply.dart';
import '../../inventory/domain/supply_category.dart';
import '../../inventory/domain/supply_movement.dart';
import '../../pigs/domain/health_record.dart';
import '../../sales/domain/sale.dart';
import 'batch_cost_calculator.dart';

/// Immutable P&L breakdown for either a period or a batch.
class ProfitabilityBreakdown {
  final double revenuePhp;
  final double feedCostPhp;
  final double medicineCostPhp;
  final double laborCostPhp;
  final double utilitiesCostPhp;
  final double equipmentCostPhp;
  final double maintenanceCostPhp;
  final double otherCostPhp;
  final double totalCostPhp;
  final double grossProfitPhp;
  final double marginPct;

  const ProfitabilityBreakdown({
    required this.revenuePhp,
    required this.feedCostPhp,
    required this.medicineCostPhp,
    required this.laborCostPhp,
    required this.utilitiesCostPhp,
    required this.equipmentCostPhp,
    required this.maintenanceCostPhp,
    required this.otherCostPhp,
    required this.totalCostPhp,
    required this.grossProfitPhp,
    required this.marginPct,
  });

  static const empty = ProfitabilityBreakdown(
    revenuePhp: 0,
    feedCostPhp: 0,
    medicineCostPhp: 0,
    laborCostPhp: 0,
    utilitiesCostPhp: 0,
    equipmentCostPhp: 0,
    maintenanceCostPhp: 0,
    otherCostPhp: 0,
    totalCostPhp: 0,
    grossProfitPhp: 0,
    marginPct: 0,
  );
}

class ProfitabilityCalculator {
  ProfitabilityCalculator._();

  /// Period P&L over the half-open range `[start, end)`:
  ///   - Revenue:  sum of `Sale.totalRevenuePhp` for sales in range.
  ///   - Feed:     consumption movements × supply weighted-avg + Expense.feed.
  ///   - Medicine: consumption movements × supply weighted-avg + Expense.medicine
  ///               + health record `costPhp` (only when no movement references
  ///               that health record — double-count guard).
  ///   - Others:   each remaining ExpenseCategory bucketed directly.
  ///   - Margin:   0.0 when revenue is 0 (explicit guard against NaN).
  static ProfitabilityBreakdown forPeriod({
    required Timestamp start,
    required Timestamp end,
    required List<Sale> sales,
    required List<SupplyMovement> movements,
    required Map<String, Supply> suppliesById,
    required List<HealthRecord> healthRecords,
    required List<Expense> expenses,
  }) {
    final startDt = start.toDate();
    final endDt = end.toDate();

    // ---- Revenue from sales in range ----
    final revenue = sales
        .where((s) {
          final t = s.saleDate.toDate();
          return !t.isBefore(startDt) && t.isBefore(endDt);
        })
        .fold<double>(0, (acc, s) => acc + s.totalRevenuePhp);

    // ---- Costs from supply consumption in range ----
    double feedCost = 0;
    double medicineCost = 0;
    final consumedHealthRecordIds = <String>{};

    for (final m in movements) {
      final t = m.createdAt.toDate();
      if (t.isBefore(startDt) || !t.isBefore(endDt)) continue;
      if (m.type != MovementType.consumption) continue;
      final supply = suppliesById[m.supplyId];
      if (supply == null) continue;

      final qty = m.quantity.abs();
      final cost = qty * supply.weightedAvgUnitCostPhp;
      switch (supply.category) {
        case SupplyCategory.feed:
          feedCost += cost;
          break;
        case SupplyCategory.medicine:
          medicineCost += cost;
          if (m.relatedHealthRecordId != null) {
            consumedHealthRecordIds.add(m.relatedHealthRecordId!);
          }
          break;
        case SupplyCategory.otherInput:
          break;
      }
    }

    // ---- Off-inventory medicine cost from health records in range ----
    for (final h in healthRecords) {
      final t = h.date.toDate();
      if (t.isBefore(startDt) || !t.isBefore(endDt)) continue;
      if (consumedHealthRecordIds.contains(h.id)) continue;
      medicineCost += h.costPhp ?? 0;
    }

    // ---- Direct expenses in range, by category ----
    double laborCost = 0;
    double utilitiesCost = 0;
    double equipmentCost = 0;
    double maintenanceCost = 0;
    double otherCost = 0;

    for (final e in expenses) {
      final t = e.date.toDate();
      if (t.isBefore(startDt) || !t.isBefore(endDt)) continue;
      switch (e.category) {
        case ExpenseCategory.feed:
          feedCost += e.amountPhp;
          break;
        case ExpenseCategory.medicine:
          medicineCost += e.amountPhp;
          break;
        case ExpenseCategory.labor:
          laborCost += e.amountPhp;
          break;
        case ExpenseCategory.utilities:
          utilitiesCost += e.amountPhp;
          break;
        case ExpenseCategory.equipment:
          equipmentCost += e.amountPhp;
          break;
        case ExpenseCategory.maintenance:
          maintenanceCost += e.amountPhp;
          break;
        case ExpenseCategory.other:
          otherCost += e.amountPhp;
          break;
      }
    }

    final total = feedCost +
        medicineCost +
        laborCost +
        utilitiesCost +
        equipmentCost +
        maintenanceCost +
        otherCost;
    final profit = revenue - total;
    final margin = revenue == 0 ? 0.0 : (profit / revenue) * 100;

    return ProfitabilityBreakdown(
      revenuePhp: revenue,
      feedCostPhp: feedCost,
      medicineCostPhp: medicineCost,
      laborCostPhp: laborCost,
      utilitiesCostPhp: utilitiesCost,
      equipmentCostPhp: equipmentCost,
      maintenanceCostPhp: maintenanceCost,
      otherCostPhp: otherCost,
      totalCostPhp: total,
      grossProfitPhp: profit,
      marginPct: margin,
    );
  }

  /// Per-batch P&L. `batchMemberPigIds` is the set of pigs that belong to the
  /// batch (current OR historic — typically `batch.pigIds` plus any
  /// sold/culled/deceased pigs that were members during their lifetime).
  ///
  /// Revenue is the sum of sale line items whose `pigId` is in the member set.
  /// Costs are delegated to `BatchCostCalculator.forBatch`.
  ///
  /// `lineItemsBySale` is keyed by sale ID; the calculator does not currently
  /// use the key, but the shape keeps the caller's lookup natural. `sales` is
  /// accepted (and ignored here) for symmetry with `forPeriod` and to leave
  /// room for future revenue-source rules.
  static ProfitabilityBreakdown forBatch({
    required String batchId,
    required Set<String> batchMemberPigIds,
    required List<Sale> sales,
    required Map<String, List<({String pigId, double lineRevenuePhp})>>
        lineItemsBySale,
    required List<SupplyMovement> movements,
    required Map<String, Supply> suppliesById,
    required List<HealthRecord> healthRecords,
    required List<Expense> expenses,
  }) {
    // Revenue: sum of line items whose pigId is in batchMemberPigIds.
    double revenue = 0;
    for (final entry in lineItemsBySale.entries) {
      for (final li in entry.value) {
        if (batchMemberPigIds.contains(li.pigId)) {
          revenue += li.lineRevenuePhp;
        }
      }
    }

    final cost = BatchCostCalculator.forBatch(
      batchId: batchId,
      movements: movements,
      suppliesById: suppliesById,
      healthRecords: healthRecords,
      batchMemberPigIds: batchMemberPigIds,
      expenses: expenses,
    );

    final profit = revenue - cost.totalCostPhp;
    final margin = revenue == 0 ? 0.0 : (profit / revenue) * 100;

    return ProfitabilityBreakdown(
      revenuePhp: revenue,
      feedCostPhp: cost.feedCostPhp,
      medicineCostPhp: cost.medicineCostPhp,
      laborCostPhp: cost.laborCostPhp,
      utilitiesCostPhp: cost.utilitiesCostPhp,
      equipmentCostPhp: cost.equipmentCostPhp,
      maintenanceCostPhp: cost.maintenanceCostPhp,
      otherCostPhp: cost.otherCostPhp,
      totalCostPhp: cost.totalCostPhp,
      grossProfitPhp: profit,
      marginPct: margin,
    );
  }
}
