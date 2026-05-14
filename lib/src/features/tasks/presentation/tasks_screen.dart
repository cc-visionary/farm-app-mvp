import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../core/permissions/role.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../../team/application/team_providers.dart';
import '../application/task_providers.dart';
import '../domain/task.dart';
import 'create_task_screen.dart';

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmId = ref.watch(selectedFarmIdProvider);
    final user = ref.watch(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return const SizedBox.shrink();
    final role = ref
            .watch(memberForUserProvider((farmId: farmId, userId: user.uid)))
            .asData
            ?.value
            ?.role ??
        Role.worker;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tasks'),
          bottom: const TabBar(tabs: [
            Tab(text: 'My Tasks'),
            Tab(text: 'All Open'),
          ]),
        ),
        floatingActionButton: PermissionService.canCreateOrAssignTasks(role)
            ? FloatingActionButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateTaskScreen(),
                  ),
                ),
                child: const Icon(Icons.add),
              )
            : null,
        body: TabBarView(children: [
          _TaskList(farmId: farmId, userId: user.uid, onlyMine: true),
          _TaskList(farmId: farmId, userId: user.uid, onlyMine: false),
        ]),
      ),
    );
  }
}

class _TaskList extends ConsumerWidget {
  const _TaskList({
    required this.farmId,
    required this.userId,
    required this.onlyMine,
  });
  final String farmId;
  final String userId;
  final bool onlyMine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = onlyMine
        ? ref.watch(myTasksStreamProvider((farmId: farmId, userId: userId)))
        : ref.watch(openTasksStreamProvider(farmId));
    return tasksAsync.when(
      data: (tasks) {
        if (tasks.isEmpty) {
          return Center(
            child: Text(
              onlyMine ? 'No tasks assigned to you.' : 'No open tasks.',
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: tasks.map((t) => _TaskCard(task: t)).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }
}

class _TaskCard extends ConsumerWidget {
  const _TaskCard({required this.task});
  final FarmTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final due = task.dueDate.toDate();
    final overdue = due.isBefore(now);
    return Card(
      child: ListTile(
        leading: Icon(
          _icon(task.type),
          color: overdue ? Colors.red : Theme.of(context).primaryColor,
        ),
        title: Text(task.title),
        subtitle: Text(
          'Due ${DateFormat.yMMMd().format(due)}'
          '${task.assignedTo == null ? "" : " · assigned to ${task.assignedTo!.kind}:${task.assignedTo!.id}"}',
          style: TextStyle(color: overdue ? Colors.red : Colors.grey),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.check_circle_outline),
          tooltip: 'Mark complete',
          onPressed: () async {
            final user = ref.read(authStateChangesProvider).asData?.value;
            if (user == null) return;
            await ref.read(taskRepositoryProvider).completeTask(
                  farmId: task.farmId,
                  taskId: task.id,
                  userId: user.uid,
                );
          },
        ),
      ),
    );
  }

  IconData _icon(TaskType t) {
    switch (t) {
      case TaskType.pregnancyCheck:
        return Icons.fact_check;
      case TaskType.farrowingPrep:
        return Icons.event_available;
      case TaskType.farrowingExpected:
        return Icons.child_friendly;
      case TaskType.vaccinationDue:
        return Icons.medical_services;
      case TaskType.withdrawalEnd:
        return Icons.timer;
      case TaskType.manual:
        return Icons.task_alt;
    }
  }
}
