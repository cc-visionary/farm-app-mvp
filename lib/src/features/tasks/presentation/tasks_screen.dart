import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../core/permissions/role.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/user_display.dart';
import '../../../l10n/generated/app_localizations.dart';
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
    final l = AppLocalizations.of(context);
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
          title: Text(l.tasks_screen_title),
          bottom: TabBar(
            tabs: [
              Tab(text: l.tasks_tab_my),
              Tab(text: l.tasks_tab_all),
            ],
          ),
        ),
        floatingActionButton: PermissionService.canCreateOrAssignTasks(role)
            ? FloatingActionButton.extended(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateTaskScreen(),
                  ),
                ),
                icon: const Icon(Iconsax.add),
                label: Text(l.task_create_title),
              )
            : null,
        body: TabBarView(
          children: [
            _TaskList(farmId: farmId, userId: user.uid, onlyMine: true),
            _TaskList(farmId: farmId, userId: user.uid, onlyMine: false),
          ],
        ),
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
    final l = AppLocalizations.of(context);
    final tasksAsync = onlyMine
        ? ref.watch(myTasksStreamProvider((farmId: farmId, userId: userId)))
        : ref.watch(openTasksStreamProvider(farmId));
    return tasksAsync.when(
      data: (tasks) {
        if (tasks.isEmpty) {
          return EmptyState(
            icon: Iconsax.task_square,
            title: onlyMine ? l.tasks_empty_my : l.tasks_empty_all,
            subtitle: onlyMine
                ? "When something needs your attention, it'll show up here."
                : 'All caught up. New tasks will appear here.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          itemCount: tasks.length,
          itemBuilder: (_, i) => _TaskCard(task: tasks[i]),
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
    final l = AppLocalizations.of(context);
    final localeCode = Localizations.localeOf(context).toString();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final now = DateTime.now();
    final due = task.dueDate.toDate();
    final overdue = due.isBefore(now);
    final iconColor = overdue ? colorScheme.error : colorScheme.primary;
    final iconBg =
        overdue ? colorScheme.errorContainer : colorScheme.primaryContainer;
    final dueText = l.task_card_due(DateFormat.MMMd(localeCode).format(due));
    final assigned = task.assignedTo;
    final subtitleStyle = textTheme.bodyMedium?.copyWith(
      color: overdue ? colorScheme.error : colorScheme.onSurfaceVariant,
      fontWeight: overdue ? FontWeight.w600 : FontWeight.w400,
    );

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 4,
        ),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconBg,
            shape: BoxShape.circle,
          ),
          child: Icon(_icon(task.type), size: 20, color: iconColor),
        ),
        title: Text(task.title, style: textTheme.titleMedium),
        subtitle: DefaultTextStyle.merge(
          style: subtitleStyle,
          child: Row(
            children: [
              Flexible(child: Text(dueText, overflow: TextOverflow.ellipsis)),
              if (assigned != null) ...[
                const Text(' · '),
                if (assigned.kind == 'user')
                  Flexible(
                    child: UserDisplay(
                      userId: assigned.id,
                      style: subtitleStyle,
                      maxLines: 1,
                    ),
                  )
                else
                  Flexible(
                    child: Text(
                      l.task_card_assigned_to(assigned.kind, assigned.id),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ],
          ),
        ),
        trailing: IconButton(
          icon: Icon(Iconsax.tick_circle, color: colorScheme.primary),
          tooltip: l.task_card_mark_complete,
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
        return Iconsax.health;
      case TaskType.farrowingPrep:
        return Iconsax.calendar_tick;
      case TaskType.farrowingExpected:
        return Icons.child_friendly;
      case TaskType.vaccinationDue:
        return Iconsax.health;
      case TaskType.withdrawalEnd:
        return Iconsax.timer_1;
      case TaskType.manual:
        return Iconsax.task_square;
    }
  }
}
