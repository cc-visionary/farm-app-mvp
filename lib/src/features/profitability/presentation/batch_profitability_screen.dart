// lib/src/features/profitability/presentation/batch_profitability_screen.dart
//
// Per-batch P&L: revenue (sum of sale line items for batch member pigs),
// total cost (BatchCostCalculator), gross profit, margin %, and a cost-
// breakdown pie chart sourced from theme tokens.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/section_header.dart';
import '../../expenses/application/expense_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../inventory/domain/supply.dart';
import '../../inventory/domain/supply_movement.dart';
import '../../pigs/application/pig_providers.dart';
import '../../pigs/domain/batch.dart';
import '../../pigs/domain/health_record.dart';
import '../../sales/application/sale_providers.dart';
import '../application/profitability_calculator.dart';
import '../application/profitability_providers.dart';

class BatchProfitabilityScreen extends ConsumerWidget {
  const BatchProfitabilityScreen({super.key, required this.batchId});
  final String batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    final batches =
        ref.watch(batchesStreamProvider(farmId)).asData?.value ??
            const <Batch>[];
    if (batches.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Batch')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final batch = batches.firstWhere(
      (b) => b.id == batchId,
      orElse: () => batches.first,
    );

    final sales =
        ref.watch(salesStreamProvider(farmId)).asData?.value ?? const [];
    final movements = ref.watch(allMovementsProvider(farmId)).asData?.value ??
        const <SupplyMovement>[];
    final supplies =
        ref.watch(suppliesStreamProvider(farmId)).asData?.value ??
            const <Supply>[];
    final suppliesById = {for (final s in supplies) s.id: s};
    final healthRecords =
        ref.watch(allHealthRecordsProvider(farmId)).asData?.value ??
            const <HealthRecord>[];
    final expenses = ref
            .watch(expensesForBatchProvider(
              (farmId: farmId, batchId: batchId),
            ))
            .asData
            ?.value ??
        const [];

    // Member pig IDs: from batch.pigIds (current members). Historic members
    // are best-effort — line items for sold/culled pigs that referenced the
    // batch directly are picked up via batch.pigIds when retained, otherwise
    // not counted here.
    final memberPigIds = batch.pigIds.toSet();

    // Build line items index keyed by sale ID for revenue computation.
    final lineItemsBySale =
        <String, List<({String pigId, double lineRevenuePhp})>>{};
    for (final sale in sales) {
      lineItemsBySale[sale.id] = ref
              .watch(saleLineItemsProvider(
                (farmId: farmId, saleId: sale.id),
              ))
              .asData
              ?.value
              .map((li) => (pigId: li.pigId, lineRevenuePhp: li.lineRevenuePhp))
              .toList() ??
          const [];
    }

    final p = ProfitabilityCalculator.forBatch(
      batchId: batchId,
      batchMemberPigIds: memberPigIds,
      sales: sales,
      lineItemsBySale: lineItemsBySale,
      movements: movements,
      suppliesById: suppliesById,
      healthRecords: healthRecords,
      expenses: expenses,
    );
    final profitColor = p.grossProfitPhp >= 0
        ? theme.colorScheme.primary
        : theme.colorScheme.error;

    return Scaffold(
      appBar: AppBar(title: Text(batch.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${batch.type.label} · ${batch.count} head',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const Divider(),
                  Row(
                    children: [
                      Text('Revenue', style: theme.textTheme.bodyMedium),
                      const Spacer(),
                      Text(
                        '₱${p.revenuePhp.toStringAsFixed(0)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text('Total cost', style: theme.textTheme.bodyMedium),
                      const Spacer(),
                      Text(
                        '₱${p.totalCostPhp.toStringAsFixed(0)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    children: [
                      Text('Gross profit',
                          style: theme.textTheme.titleMedium),
                      const Spacer(),
                      Text(
                        '${p.grossProfitPhp >= 0 ? "" : "−"}₱${p.grossProfitPhp.abs().toStringAsFixed(0)}',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: profitColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${p.marginPct.toStringAsFixed(1)}% margin',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: profitColor),
                  ),
                ],
              ),
            ),
          ),
          const SectionHeader(title: 'Cost breakdown'),
          SizedBox(
            height: 220,
            child: _CostPie(breakdown: p),
          ),
        ],
      ),
    );
  }
}

class _CostPie extends StatelessWidget {
  const _CostPie({required this.breakdown});
  final ProfitabilityBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sections = <PieChartSectionData>[];
    void add(String label, double v, Color c) {
      if (v <= 0) return;
      sections.add(
        PieChartSectionData(
          value: v,
          color: c,
          title: label,
          radius: 80,
          titleStyle: theme.textTheme.labelMedium?.copyWith(
            color: Colors.white,
          ),
        ),
      );
    }

    final palette = [
      theme.colorScheme.primary,
      theme.colorScheme.tertiary,
      theme.colorScheme.secondary,
      theme.colorScheme.error,
      theme.colorScheme.primaryContainer,
      theme.colorScheme.surfaceContainerHigh,
      theme.colorScheme.onSurfaceVariant,
    ];
    add('Feed', breakdown.feedCostPhp, palette[0]);
    add('Med', breakdown.medicineCostPhp, palette[1]);
    add('Labor', breakdown.laborCostPhp, palette[2]);
    add('Util', breakdown.utilitiesCostPhp, palette[3]);
    add('Eqp', breakdown.equipmentCostPhp, palette[4]);
    add('Maint', breakdown.maintenanceCostPhp, palette[5]);
    add('Other', breakdown.otherCostPhp, palette[6]);

    if (sections.isEmpty) {
      return Center(
        child: Text(
          'No costs yet',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }
    return PieChart(
      PieChartData(sections: sections, centerSpaceRadius: 32),
    );
  }
}
