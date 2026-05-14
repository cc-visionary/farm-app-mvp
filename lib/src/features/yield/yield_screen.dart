import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/stat_tile.dart';
import '../farms/application/farm_providers.dart';
import 'yield_metrics.dart';
import 'yield_providers.dart';

class YieldScreen extends ConsumerWidget {
  const YieldScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    return Scaffold(
      appBar: AppBar(title: const Text('Yield reports')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const SectionHeader(title: 'Period'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: YieldPeriod.values
                .map(
                  (p) => ChoiceChip(
                    label: Text(p.label),
                    selected: period == p,
                    onSelected: (_) =>
                        ref.read(selectedPeriodProvider.notifier).state = p,
                  ),
                )
                .toList(),
          ),
          const SectionHeader(title: 'Herd productivity'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StatTile(
                    label: 'Total farrowings',
                    value: hp.totalFarrowings.toString(),
                  ),
                  StatTile(
                    label: 'Avg litter size',
                    value: hp.avgLitterSize.toStringAsFixed(1),
                  ),
                  StatTile(
                    label: 'Avg stillborns / litter',
                    value: hp.avgStillborns.toStringAsFixed(1),
                  ),
                  StatTile(
                    label: 'Stillbirth rate',
                    value: _pct(hp.stillbirthRate),
                  ),
                  StatTile(
                    label: 'Breeding success rate',
                    value: _pct(hp.breedingSuccessRate),
                  ),
                  StatTile(
                    label: 'PSY (annualized)',
                    value: hp.psyEstimate.toStringAsFixed(1),
                  ),
                ],
              ),
            ),
          ),
          const SectionHeader(title: 'Growth & finishing'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StatTile(
                    label: 'Active grow/finish pigs',
                    value: g.activeGrowFinishCount.toString(),
                  ),
                  StatTile(
                    label: 'Average daily gain',
                    value: '${g.avgDailyGainKg.toStringAsFixed(2)} kg/d',
                  ),
                ],
              ),
            ),
          ),
          const SectionHeader(title: 'Mortality'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatTile(
                    label: 'Total deaths (period)',
                    value: m.totalDeaths.toString(),
                  ),
                  StatTile(
                    label: 'Overall mortality rate',
                    value: _pct(m.overallMortalityRate),
                  ),
                  if (m.topCauses.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'TOP CAUSES',
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
                      'BY AREA',
                      style: textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 180,
                      child: _AreaBarChart(byArea: m.byArea),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SectionHeader(title: 'Output'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StatTile(label: 'Sold', value: o.sold.toString()),
                  StatTile(label: 'Culled', value: o.culled.toString()),
                  const SizedBox(height: 12),
                  Text(
                    'Sales revenue tracking comes in Sub-project B.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
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
