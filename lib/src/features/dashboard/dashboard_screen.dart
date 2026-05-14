import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/section_header.dart';
import '../activity/presentation/activity_feed_widget.dart';
import '../authentication/application/auth_providers.dart';
import '../farms/application/farm_providers.dart';
import '../farms/presentation/farm_switcher.dart';
import '../shifts/presentation/roster_widget.dart';
import '../tasks/application/task_providers.dart';
import '../tasks/domain/task.dart';
import 'snapshot_card.dart';

/// Authenticated home screen. Aggregates the most important at-a-glance
/// widgets so a worker landing in the app can see what to do today without
/// hunting through menus.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _greeting(DateTime now) {
    final h = now.hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmId = ref.watch(selectedFarmIdProvider);
    final user = ref.watch(authStateChangesProvider).asData?.value;
    final appUser = ref.watch(currentAppUserProvider).asData?.value;
    final theme = Theme.of(context);

    if (farmId == null || user == null) {
      return const Scaffold(
        body: Center(
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    final myTasks = ref.watch(
      myTasksStreamProvider((farmId: farmId, userId: user.uid)),
    );

    final now = DateTime.now();
    final displayName = appUser?.displayName;
    final greetingText = displayName == null || displayName.isEmpty
        ? _greeting(now)
        : '${_greeting(now)}, $displayName';

    return Scaffold(
      appBar: AppBar(
        title: const FarmSwitcher(),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Iconsax.element_3),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: theme.colorScheme.outline),
                ),
                child: Text(
                  DateFormat.MMMd().format(now),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: const _NavDrawer(),
      body: RefreshIndicator(
        onRefresh: () async {
          // Streams auto-refresh; this pull-to-refresh is a UX affordance.
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              greetingText,
              style: theme.textTheme.headlineLarge,
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat.yMMMMEEEEd().format(now),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            const SnapshotCard(),
            myTasks.when(
              data: (tasks) => _MyTasksCard(tasks: tasks),
              loading: () => const SizedBox.shrink(),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '$e',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ),
            const RosterWidget(),
            const ActivityFeedWidget(limit: 6),
          ],
        ),
      ),
    );
  }
}

class _MyTasksCard extends StatelessWidget {
  const _MyTasksCard({required this.tasks});

  final List<FarmTask> tasks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (tasks.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                title: 'Your tasks today',
                padding: EdgeInsets.only(bottom: 8),
              ),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Iconsax.task_square,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No tasks assigned to you.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    final preview = tasks.take(5).toList();
    final now = DateTime.now();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Your tasks today',
              padding: EdgeInsets.only(bottom: 8),
            ),
            const Divider(height: 1),
            const SizedBox(height: 4),
            ...preview.map(
              (t) {
                final due = t.dueDate.toDate();
                final overdue = due.isBefore(DateTime(now.year, now.month, now.day));
                final color = overdue
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Iconsax.task_square,
                        size: 20,
                        color: color,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.title,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: overdue
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              DateFormat.yMMMd().format(due),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => GoRouter.of(context).push('/tasks'),
                child: const Text('See all tasks'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavDrawer extends ConsumerWidget {
  const _NavDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Text(
                'Farm CRM',
                style: theme.textTheme.headlineSmall,
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _item(context, Iconsax.pet, 'Pigs', '/pigs'),
                  _item(context, Iconsax.task_square, 'Tasks', '/tasks'),
                  _item(context, Iconsax.element_3, 'Farm layout', '/layout'),
                  _item(context, Iconsax.chart_2, 'Yield reports', '/yield'),
                  _item(context, Iconsax.activity, 'Activity', '/activity'),
                  const Divider(),
                  _item(context, Iconsax.location, 'Areas', '/areas'),
                  _item(context, Iconsax.setting_4, 'Equipment', '/equipment'),
                  _item(context, Iconsax.calendar, 'Shifts', '/shifts'),
                  _item(context, Iconsax.people, 'Team', '/team'),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Iconsax.logout),
                    title: const Text('Sign out'),
                    onTap: () async {
                      // Router redirect handles post-sign-out navigation when
                      // the auth state changes to null — no manual go() needed.
                      await ref.read(authRepositoryProvider).signOut();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context,
    IconData icon,
    String label,
    String path,
  ) =>
      ListTile(
        leading: Icon(icon),
        title: Text(label),
        onTap: () {
          Navigator.pop(context);
          GoRouter.of(context).push(path);
        },
      );
}
