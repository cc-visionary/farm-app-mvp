import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../../l10n/generated/app_localizations.dart';
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
    final l = AppLocalizations.of(context);
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) return const SizedBox.shrink();

    final feedAsync = ref.watch(recentActivityProvider(farmId));
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();

    return Scaffold(
      appBar: AppBar(title: Text(l.activity_screen_title)),
      body: feedAsync.when(
        data: (entries) {
          if (entries.isEmpty) {
            return EmptyState(
              icon: Iconsax.activity,
              title: l.activity_feed_empty_title,
              subtitle: l.activity_feed_empty_subtitle,
            );
          }
          final groups = _groupByDay(context, l, entries);
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            itemCount: groups.length,
            itemBuilder: (_, i) {
              final g = groups[i];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(title: g.label),
                  ...g.entries.map(
                    (e) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                              foregroundColor:
                                  theme.colorScheme.onPrimaryContainer,
                              child: Text(
                                (e.actorDisplayName.isEmpty
                                        ? '?'
                                        : e.actorDisplayName[0])
                                    .toUpperCase(),
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color:
                                      theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.summary,
                                    style: theme.textTheme.bodyLarge,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat.jm(locale)
                                        .format(e.timestamp.toDate()),
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
        loading: () => const Center(
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }

  List<_DayGroup> _groupByDay(
    BuildContext context,
    AppLocalizations l,
    List<ActivityEntry> entries,
  ) {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final locale = Localizations.localeOf(context).toString();
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    final groups = <String, List<ActivityEntry>>{};
    for (final e in entries) {
      final t = e.timestamp.toDate();
      String label;
      if (sameDay(t, today)) {
        label = l.activity_screen_today;
      } else if (sameDay(t, yesterday)) {
        label = l.activity_screen_yesterday;
      } else {
        label = DateFormat.yMMMMd(locale).format(t);
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
