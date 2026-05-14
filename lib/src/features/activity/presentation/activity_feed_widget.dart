import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../farms/application/farm_providers.dart';
import '../application/activity_providers.dart';
import '../domain/activity_entry.dart';

/// Card-wrapped list of the most recent activity entries for the selected farm.
///
/// Intended for embedding in dashboards or summary screens. Displays up to
/// [limit] entries (latest first) with actor avatar, summary text, and a
/// relative timestamp (e.g. "just now", "5m", "2h", "3d", "Mar 14").
class ActivityFeedWidget extends ConsumerWidget {
  const ActivityFeedWidget({super.key, this.limit = 8});

  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) return const SizedBox.shrink();

    final feedAsync = ref.watch(recentActivityProvider(farmId));

    return feedAsync.when(
      data: (entries) {
        final items = entries.take(limit).toList();
        if (items.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No activity yet. Logged events will appear here.'),
            ),
          );
        }
        return Card(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    Text(
                      'Recent activity',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ...items.map((e) => _row(context, e)),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('$e'),
    );
  }

  Widget _row(BuildContext context, ActivityEntry e) {
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        child: Text(e.actorDisplayName.isEmpty ? '?' : e.actorDisplayName[0]),
      ),
      title: Text(e.summary),
      trailing: Text(
        _relative(e.timestamp.toDate()),
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      ),
    );
  }

  String _relative(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return DateFormat.MMMd().format(t);
  }
}
