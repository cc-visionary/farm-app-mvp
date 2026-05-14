import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../activity/application/activity_providers.dart';
import '../data/task_repository.dart';
import '../domain/task.dart';
import 'task_generator.dart';

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepository(ref.watch(firestoreProvider)),
);

final taskGeneratorProvider = Provider<TaskGenerator>(
  (ref) => TaskGenerator(
    ref.watch(firestoreProvider),
    ref.watch(taskRepositoryProvider),
  ),
);

final openTasksStreamProvider =
    StreamProvider.family<List<FarmTask>, String>((ref, farmId) {
  return ref.watch(taskRepositoryProvider).streamOpenTasks(farmId);
});

final myTasksStreamProvider =
    StreamProvider.family<List<FarmTask>, ({String farmId, String userId})>(
        (ref, args) {
  return ref.watch(taskRepositoryProvider).streamTasksAssignedToUser(
        farmId: args.farmId,
        userId: args.userId,
      );
});
