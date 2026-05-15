// lib/src/features/profitability/presentation/batch_profitability_screen.dart
//
// Per-batch P&L: revenue (sum of sale line items for batch member pigs),
// total cost (BatchCostCalculator), gross profit, margin %, and a cost-
// breakdown pie chart sourced from theme tokens.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/intl_helpers.dart';
import '../../../core/widgets/section_header.dart';
import '../../../l10n/generated/app_localizations.dart';
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
    final l = AppLocalizations.of(context);
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    final batches =
        ref.watch(batchesStreamProvider(farmId)).asData?.value ??
            const <Batch>[];
    if (batches.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l.batches_list_title)),
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

    final sign = p.grossProfitPhp >= 0 ? '' : '−';

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
                    l.batch_card_subtitle(
                      localizedBatchType(l, batch.type),
                      batch.count,
                    ),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const Divider(),
                  Row(
                    children: [
                      Text(
                        l.batch_profit_revenue,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const Spacer(),
                      Text(
                        formatCurrencyPhp(context, p.revenuePhp),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        l.batch_profit_total_cost,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const Spacer(),
                      Text(
                        formatCurrencyPhp(context, p.totalCostPhp),
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
                      Text(
                        l.batch_profit_gross_profit,
                        style: theme.textTheme.titleMedium,
                      ),
                      const Spacer(),
                      Text(
                        '$sign${formatCurrencyPhp(context, p.grossProfitPhp.abs())}',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: profitColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.yield_profitability_margin(
                      p.marginPct.toStringAsFixed(1),
                    ),
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: profitColor),
                  ),
                ],
              ),
            ),
          ),
          SectionHeader(title: l.batch_profit_cost_breakdown),
          _CostPie(breakdown: p),
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
    final l = AppLocalizations.of(context);

    // Build (label, value, color) tuples.
    final palette = [
      theme.colorScheme.primary,
      theme.colorScheme.tertiary,
      theme.colorScheme.secondary,
      theme.colorScheme.error,
      theme.colorScheme.primaryContainer,
      theme.colorScheme.surfaceContainerHigh,
      theme.colorScheme.onSurfaceVariant,
    ];
    final entries = <({String label, double value, Color color})>[
      (
        label: l.yield_profitability_feed,
        value: breakdown.feedCostPhp,
        color: palette[0],
      ),
      (
        label: l.yield_profitability_medicine,
        value: breakdown.medicineCostPhp,
        color: palette[1],
      ),
      (
        label: l.yield_profitability_labor,
        value: breakdown.laborCostPhp,
        color: palette[2],
      ),
      (
        label: l.yield_profitability_utilities,
        value: breakdown.utilitiesCostPhp,
        color: palette[3],
      ),
      (
        label: l.yield_profitability_equipment,
        value: breakdown.equipmentCostPhp,
        color: palette[4],
      ),
      (
        label: l.yield_profitability_maintenance,
        value: breakdown.maintenanceCostPhp,
        color: palette[5],
      ),
      (
        label: l.yield_profitability_other,
        value: breakdown.otherCostPhp,
        color: palette[6],
      ),
    ].where((e) => e.value > 0).toList();

    if (entries.isEmpty) {
      return Center(
        child: Text(
          l.batch_profit_cost_no_costs,
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    final total = entries.fold<double>(0, (s, e) => s + e.value);
    final sections = entries.map((e) {
      final pct = e.value / total * 100;
      return PieChartSectionData(
        value: e.value,
        color: e.color,
        radius: 80,
        // Only show percentage labels on slices >= 8% to avoid cramped text.
        title: pct >= 8 ? '${pct.toStringAsFixed(0)}%' : '',
        titleStyle: theme.textTheme.labelMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      );
    }).toList();

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(sections: sections, centerSpaceRadius: 32),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: entries
              .map(
                (e) => _LegendRow(
                  color: e.color,
                  label: e.label,
                  value: e.value,
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
  });
  final Color color;
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: theme.textTheme.bodyMedium),
        const SizedBox(width: 4),
        Text(
          formatCurrencyPhp(context, value),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
