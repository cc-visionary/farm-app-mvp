// lib/src/features/profitability/application/batch_cost_calculator.dart
//
// Pure-function math layer for batch-level cost attribution. Takes plain
// collections of records and produces a structured cost breakdown. No
// Firestore I/O — callers wire data in from providers.

import '../../expenses/domain/expense.dart';
import '../../expenses/domain/expense_category.dart';
import '../../inventory/domain/supply.dart';
import '../../inventory/domain/supply_category.dart';
import '../../inventory/domain/supply_movement.dart';
import '../../pigs/domain/health_record.dart';

/// Immutable breakdown of all cost categories attributed to a single batch.
class BatchCostBreakdown {
  final double feedCostPhp;
  final double medicineCostPhp;
  final double laborCostPhp;
  final double utilitiesCostPhp;
  final double equipmentCostPhp;
  final double maintenanceCostPhp;
  final double otherCostPhp;
  final double totalCostPhp;

  const BatchCostBreakdown({
    required this.feedCostPhp,
    required this.medicineCostPhp,
    required this.laborCostPhp,
    required this.utilitiesCostPhp,
    required this.equipmentCostPhp,
    required this.maintenanceCostPhp,
    required this.otherCostPhp,
    required this.totalCostPhp,
  });

  static const empty = BatchCostBreakdown(
    feedCostPhp: 0,
    medicineCostPhp: 0,
    laborCostPhp: 0,
    utilitiesCostPhp: 0,
    equipmentCostPhp: 0,
    maintenanceCostPhp: 0,
    otherCostPhp: 0,
    totalCostPhp: 0,
  );
}

class BatchCostCalculator {
  BatchCostCalculator._();

  /// Aggregates costs attributed to a given batch from:
  ///   1. Supply consumption × `supply.weightedAvgUnitCostPhp` at time of
  ///      movement (movements with `relatedBatchId == batchId`).
  ///   2. Health records `costPhp` for pigs in the batch — included ONLY if the
  ///      health record was not already paid for through an inventory movement
  ///      (double-count guard via `relatedHealthRecordId`).
  ///   3. Direct expenses tagged with `relatedBatchId`.
  static BatchCostBreakdown forBatch({
    required String batchId,
    required List<SupplyMovement> movements,
    required Map<String, Supply> suppliesById,
    required List<HealthRecord> healthRecords,
    required Set<String> batchMemberPigIds,
    required List<Expense> expenses,
  }) {
    // ---- 1. Supply consumption movements attributed to this batch ----
    double feedCost = 0;
    double medicineCost = 0;
    final consumedHealthRecordIds = <String>{};

    for (final m in movements) {
      if (m.relatedBatchId != batchId) continue;
      if (m.type != MovementType.consumption) continue;
      final supply = suppliesById[m.supplyId];
      if (supply == null) continue;

      final qty = m.quantity.abs(); // consumption is stored as negative
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
          // Other inputs fall through — they will not show in the batch view
          // since we have no obvious cost bucket for them at the batch level.
          break;
      }
    }

    // ---- 2. Health records for pigs in this batch ----
    //
    // Only add a health record's `costPhp` if its ID is NOT already in the
    // consumedHealthRecordIds set. This is the medicine double-count guard:
    // inventory-tracked consumption takes precedence; off-inventory health
    // record costs fill the gap when no movement references them.
    for (final h in healthRecords) {
      if (!batchMemberPigIds.contains(h.pigId)) continue;
      if (consumedHealthRecordIds.contains(h.id)) continue;
      medicineCost += h.costPhp ?? 0;
    }

    // ---- 3. Direct expenses tagged with this batch ----
    double laborCost = 0;
    double utilitiesCost = 0;
    double equipmentCost = 0;
    double maintenanceCost = 0;
    double otherCost = 0;

    for (final e in expenses) {
      if (e.relatedBatchId != batchId) continue;
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

    return BatchCostBreakdown(
      feedCostPhp: feedCost,
      medicineCostPhp: medicineCost,
      laborCostPhp: laborCost,
      utilitiesCostPhp: utilitiesCost,
      equipmentCostPhp: equipmentCost,
      maintenanceCostPhp: maintenanceCost,
      otherCostPhp: otherCost,
      totalCostPhp: total,
    );
  }
}
