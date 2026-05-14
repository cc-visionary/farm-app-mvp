import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../activity/application/activity_providers.dart';
import '../../tasks/application/task_providers.dart';
import '../data/breeding_repository.dart';
import '../data/pig_repository.dart';
import '../domain/breeding_record.dart';
import '../domain/pig.dart';

final pigRepositoryProvider = Provider<PigRepository>(
  (ref) => PigRepository(
    ref.watch(firestoreProvider),
    ref.watch(activityRepositoryProvider),
  ),
);

final pigsStreamProvider =
    StreamProvider.family<List<Pig>, String>((ref, farmId) {
  return ref.watch(pigRepositoryProvider).streamPigs(farmId);
});

final pigByIdProvider =
    StreamProvider.family<Pig?, ({String farmId, String pigId})>((ref, args) {
  return ref.watch(pigRepositoryProvider).streamPigById(
        farmId: args.farmId,
        pigId: args.pigId,
      );
});

final breedingRepositoryProvider = Provider<BreedingRepository>(
  (ref) => BreedingRepository(
    ref.watch(firestoreProvider),
    ref.watch(activityRepositoryProvider),
    ref.watch(taskGeneratorProvider),
  ),
);

final breedingStreamProvider = StreamProvider.family<List<BreedingRecord>,
    ({String farmId, String sowId})>((ref, args) {
  return ref.watch(breedingRepositoryProvider).streamBreedingRecords(
        farmId: args.farmId,
        sowId: args.sowId,
      );
});
