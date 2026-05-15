import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/i18n/intl_helpers.dart';
import '../../core/permissions/permission_service.dart';
import '../../core/permissions/role.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/stat_tile.dart';
import '../../l10n/generated/app_localizations.dart';
import '../authentication/application/auth_providers.dart';
import '../farms/application/farm_providers.dart';
import '../profitability/application/profitability_providers.dart';
import '../profitability/presentation/batches_list_screen.dart';
import '../team/application/team_providers.dart';
import 'yield_metrics.dart';
import 'yield_providers.dart';

/// Localized label for a [YieldPeriod] choice chip.
String _periodLabel(AppLocalizations l, YieldPeriod p) {
  switch (p) {
    case YieldPeriod.d7:
      return l.yield_period_7d;
    case YieldPeriod.d30:
      return l.yield_period_30d;
    case YieldPeriod.d90:
      return l.yield_period_90d;
    case YieldPeriod.ytd:
      return l.yield_period_ytd;
    case YieldPeriod.all:
      return l.yield_period_all;
  }
}

class YieldScreen extends ConsumerWidget {
  const YieldScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) return const SizedBox.shrink();
    final period = ref.watch(selectedPeriodProvider);
    final hp = ref.watch(yieldHerdProductivityProvider(farmId));
    final g = ref.watch(yieldGrowthProvider(farmId));
    final m = ref.watch(yieldMortalityProvider(farmId));
    final o = ref.watch(yieldOutputProvider(farmId));

    final user = ref.watch(authStateChangesProvider).asData?.value;
    final role = user != null
        ? (ref
                .watch(memberForUserProvider(
                  (farmId: farmId, userId: user.uid),
                ))
                .asData
                ?.value
                ?.role ??
            Role.worker)
        : Role.worker;
    final canSeeProfit = PermissionService.canEditEquipment(role);

    return Scaffold(
      appBar: AppBar(title: Text(l.yield_title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          SectionHeader(title: l.yield_section_period),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: YieldPeriod.values
                .map(
                  (p) => ChoiceChip(
                    label: Text(_periodLabel(l, p)),
                    selected: period == p,
                    onSelected: (_) =>
                        ref.read(selectedPeriodProvider.notifier).state = p,
                  ),
                )
                .toList(),
          ),
          SectionHeader(title: l.yield_card_herd),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StatTile(
                    label: l.yield_card_herd_total_farrowings,
                    value: hp.totalFarrowings.toString(),
                  ),
                  StatTile(
                    label: l.yield_card_herd_avg_litter,
                    value: hp.avgLitterSize.toStringAsFixed(1),
                  ),
                  StatTile(
                    label: l.yield_card_herd_avg_stillborns,
                    value: hp.avgStillborns.toStringAsFixed(1),
                  ),
                  StatTile(
                    label: l.yield_card_herd_stillbirth_rate,
                    value: _pct(hp.stillbirthRate),
                  ),
                  StatTile(
                    label: l.yield_card_herd_breeding_success,
                    value: _pct(hp.breedingSuccessRate),
                  ),
                  StatTile(
                    label: l.yield_card_herd_psy,
                    value: hp.psyEstimate.toStringAsFixed(1),
                  ),
                ],
              ),
            ),
          ),
          SectionHeader(title: l.yield_card_growth),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StatTile(
                    label: l.yield_card_growth_active_gf,
                    value: g.activeGrowFinishCount.toString(),
                  ),
                  StatTile(
                    label: l.yield_card_growth_adg,
                    value: l.yield_card_growth_adg_value(
                      g.avgDailyGainKg.toStringAsFixed(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SectionHeader(title: l.yield_card_mortality),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatTile(
                    label: l.yield_card_mortality_total,
                    value: m.totalDeaths.toString(),
                  ),
                  StatTile(
                    label: l.yield_card_mortality_rate,
                    value: _pct(m.overallMortalityRate),
                  ),
                  if (m.topCauses.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      l.yield_card_mortality_top_causes,
                      style: textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...m.topCauses.map(
                      (c) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(c.key, style: textTheme.bodyMedium),
                            ),
                            Text(
                              c.value.toString(),
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (m.byArea.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      l.yield_card_mortality_by_area,
                      style: textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // RepaintBoundary so chart isolates raster work from
                    // surrounding card content.
                    SizedBox(
                      height: 180,
                      child: RepaintBoundary(
                        child: _AreaBarChart(byArea: m.byArea),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SectionHeader(title: l.yield_card_output),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StatTile(
                    label: l.yield_card_output_sold,
                    value: o.sold.toString(),
                  ),
                  StatTile(
                    label: l.yield_card_output_culled,
                    value: o.culled.toString(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l.yield_card_output_b_note,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (canSeeProfit) SectionHeader(title: l.yield_profitability_title),
          if (canSeeProfit) _ProfitabilityCard(farmId: farmId),
          if (canSeeProfit) const SizedBox(height: 12),
          if (canSeeProfit)
            OutlinedButton.icon(
              icon: const Icon(Iconsax.box),
              label: Text(l.yield_view_per_batch_button),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const BatchesListScreen(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';
}

class _AreaBarChart extends StatelessWidget {
  const _AreaBarChart({required this.byArea});
  final Map<String, int> byArea;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final entries = byArea.entries.toList();
    return BarChart(
      BarChartData(
        barGroups: List.generate(
          entries.length,
          (i) => BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: entries[i].value.toDouble(),
                color: colorScheme.error,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, _) => Text(
                v.toInt().toString(),
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (v, _) {
                final idx = v.toInt();
                if (idx < 0 || idx >= entries.length) {
                  return const SizedBox.shrink();
                }
                final key = entries[idx].key;
                final label = key.substring(0, key.length.clamp(0, 4));
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    label,
                    style: textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: colorScheme.outlineVariant,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}

class _ProfitabilityCard extends ConsumerWidget {
  const _ProfitabilityCard({required this.farmId});
  final String farmId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final r = ref.watch(profitabilityForPeriodProvider(farmId));
    final profitColor = r.grossProfitPhp >= 0
        ? theme.colorScheme.primary
        : theme.colorScheme.error;
    final sign = r.grossProfitPhp >= 0 ? '' : '−';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.yield_profitability_title,
              style: theme.textTheme.headlineSmall,
            ),
            const Divider(),
            _line(context, theme, l.yield_profitability_revenue, r.revenuePhp),
            const SizedBox(height: 4),
            _line(context, theme, l.yield_profitability_feed, r.feedCostPhp,
                expense: true),
            _line(context, theme, l.yield_profitability_medicine,
                r.medicineCostPhp,
                expense: true),
            _line(context, theme, l.yield_profitability_labor, r.laborCostPhp,
                expense: true),
            _line(context, theme, l.yield_profitability_utilities,
                r.utilitiesCostPhp,
                expense: true),
            _line(context, theme, l.yield_profitability_equipment,
                r.equipmentCostPhp,
                expense: true),
            _line(context, theme, l.yield_profitability_maintenance,
                r.maintenanceCostPhp,
                expense: true),
            _line(context, theme, l.yield_profitability_other, r.otherCostPhp,
                expense: true),
            const Divider(),
            Row(
              children: [
                Text(
                  l.yield_profitability_gross_profit,
                  style: theme.textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  '$sign${formatCurrencyPhp(context, r.grossProfitPhp.abs())}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: profitColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: profitColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l.yield_profitability_margin(r.marginPct.toStringAsFixed(1)),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: profitColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(
    BuildContext context,
    ThemeData theme,
    String label,
    double value, {
    bool expense = false,
  }) {
    final sign = expense ? '−' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          const Spacer(),
          Text(
            '$sign${formatCurrencyPhp(context, value)}',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: expense ? theme.colorScheme.onSurfaceVariant : null,
            ),
          ),
        ],
      ),
    );
  }
}
