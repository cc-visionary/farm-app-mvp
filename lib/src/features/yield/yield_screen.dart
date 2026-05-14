import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../farms/application/farm_providers.dart';
import 'yield_metrics.dart';
import 'yield_providers.dart';

class YieldScreen extends ConsumerWidget {
  const YieldScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            children: YieldPeriod.values
                .map((p) => ChoiceChip(
                      label: Text(p.label),
                      selected: period == p,
                      onSelected: (_) => ref
                          .read(selectedPeriodProvider.notifier)
                          .state = p,
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          _Card(title: 'Herd productivity', children: [
            _row('Total farrowings', hp.totalFarrowings.toString()),
            _row('Avg litter size', hp.avgLitterSize.toStringAsFixed(1)),
            _row('Avg stillborns / litter', hp.avgStillborns.toStringAsFixed(1)),
            _row('Stillbirth rate', _pct(hp.stillbirthRate)),
            _row('Breeding success rate', _pct(hp.breedingSuccessRate)),
            _row('PSY (estimate, annualized)', hp.psyEstimate.toStringAsFixed(1)),
          ]),
          _Card(title: 'Growth & finishing', children: [
            _row('Active grow/finish pigs', g.activeGrowFinishCount.toString()),
            _row('Average daily gain',
                '${g.avgDailyGainKg.toStringAsFixed(2)} kg/d'),
          ]),
          _Card(title: 'Mortality', children: [
            _row('Total deaths (period)', m.totalDeaths.toString()),
            _row('Overall mortality rate', _pct(m.overallMortalityRate)),
            if (m.topCauses.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Top causes:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ...m.topCauses.map((c) => Text('  • ${c.key}: ${c.value}')),
            ],
            if (m.byArea.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('By area:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 180, child: _AreaBarChart(byArea: m.byArea)),
            ],
          ]),
          _Card(title: 'Output', children: [
            _row('Sold (in period)', o.sold.toString()),
            _row('Culled (in period)', o.culled.toString()),
            const Text(
              'Sales revenue tracking comes in Sub-project B.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
      );

  String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const Divider(),
              ...children,
            ],
          ),
        ),
      );
}

class _AreaBarChart extends StatelessWidget {
  const _AreaBarChart({required this.byArea});
  final Map<String, int> byArea;

  @override
  Widget build(BuildContext context) {
    final entries = byArea.entries.toList();
    return BarChart(BarChartData(
      barGroups: List.generate(
        entries.length,
        (i) => BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: entries[i].value.toDouble(),
              color: Colors.red,
            ),
          ],
        ),
      ),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: true, reservedSize: 28),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            getTitlesWidget: (v, _) {
              final idx = v.toInt();
              if (idx < 0 || idx >= entries.length) {
                return const SizedBox.shrink();
              }
              final key = entries[idx].key;
              final label = key.substring(0, key.length.clamp(0, 4));
              return Text(label, style: const TextStyle(fontSize: 10));
            },
          ),
        ),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: const FlGridData(show: true),
      borderData: FlBorderData(show: false),
    ));
  }
}
