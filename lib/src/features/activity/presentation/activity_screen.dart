import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../farms/application/farm_providers.dart';
import '../application/activity_providers.dart';
import '../domain/activity_entry.dart';

/// Full-page activity log for the currently selected farm.
///
/// Groups entries by day with the labels Today / Yesterday / formatted date
/// (yMMMMd) for older entries. Each entry renders as a card with actor avatar,
/// summary text, and a `jm` formatted timestamp.
class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) return const SizedBox.shrink();

    final feedAsync = ref.watch(recentActivityProvider(farmId));

    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: feedAsync.when(
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(child: Text('No activity yet.'));
          }
          final groups = _groupByDay(entries);
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groups.length,
            itemBuilder: (_, i) {
              final g = groups[i];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      g.label,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ...g.entries.map(
                    (e) => Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            e.actorDisplayName.isEmpty
                                ? '?'
                                : e.actorDisplayName[0],
                          ),
                        ),
                        title: Text(e.summary),
                        subtitle: Text(
                          DateFormat.jm().format(e.timestamp.toDate()),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }

  List<_DayGroup> _groupByDay(List<ActivityEntry> entries) {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    final groups = <String, List<ActivityEntry>>{};
    for (final e in entries) {
      final t = e.timestamp.toDate();
      String label;
      if (sameDay(t, today)) {
        label = 'Today';
      } else if (sameDay(t, yesterday)) {
        label = 'Yesterday';
      } else {
        label = DateFormat.yMMMMd().format(t);
      }
      groups.putIfAbsent(label, () => []).add(e);
    }
    return groups.entries
        .map((e) => _DayGroup(label: e.key, entries: e.value))
        .toList();
  }
}

class _DayGroup {
  _DayGroup({required this.label, required this.entries});
  final String label;
  final List<ActivityEntry> entries;
}
