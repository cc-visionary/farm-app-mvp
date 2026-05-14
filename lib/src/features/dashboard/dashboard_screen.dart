import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmId = ref.watch(selectedFarmIdProvider);
    final user = ref.watch(authStateChangesProvider).asData?.value;
    final appUser = ref.watch(currentAppUserProvider).asData?.value;

    if (farmId == null || user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final myTasks = ref.watch(
      myTasksStreamProvider((farmId: farmId, userId: user.uid)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const FarmSwitcher(),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
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
              appUser?.displayName == null
                  ? 'Hello'
                  : 'Hello, ${appUser!.displayName}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            const SnapshotCard(),
            const SizedBox(height: 16),
            myTasks.when(
              data: (tasks) => _MyTasksCard(tasks: tasks),
              loading: () => const SizedBox.shrink(),
              error: (e, _) => Text('$e'),
            ),
            const SizedBox(height: 16),
            const RosterWidget(),
            const SizedBox(height: 16),
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
    if (tasks.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No tasks assigned to you. 🎉'),
        ),
      );
    }
    final preview = tasks.take(5).toList();
    return Card(
      color: Colors.lightGreen.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your tasks today',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ...preview.map(
              (t) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.task_alt),
                title: Text(t.title),
                subtitle: Text(t.dueDate.toDate().toString().split(' ')[0]),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => GoRouter.of(context).push('/tasks'),
                child: const Text('See all tasks →'),
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
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(child: Text('Farm CRM')),
          _item(context, Icons.pets, 'Pigs', '/pigs'),
          _item(context, Icons.task_alt, 'Tasks', '/tasks'),
          _item(context, Icons.dashboard, 'Farm layout', '/layout'),
          _item(context, Icons.assessment, 'Yield reports', '/yield'),
          _item(context, Icons.history, 'Activity', '/activity'),
          const Divider(),
          _item(context, Icons.location_on, 'Areas', '/areas'),
          _item(context, Icons.build, 'Equipment', '/equipment'),
          _item(context, Icons.schedule, 'Shifts', '/shifts'),
          _item(context, Icons.people, 'Team', '/team'),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: () async {
              // Router redirect handles the post-sign-out navigation when the
              // auth state changes to null — no manual go() needed here.
              await ref.read(authRepositoryProvider).signOut();
            },
          ),
        ],
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
