import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../activity/application/activity_providers.dart';
import '../../pigs/application/pig_providers.dart';
import '../data/movement_repository.dart';
import '../data/pen_batch_resolver.dart';
import '../data/supply_repository.dart';
import '../domain/supply.dart';
import '../domain/supply_movement.dart';

final supplyRepositoryProvider = Provider<SupplyRepository>(
  (ref) => SupplyRepository(
    ref.watch(firestoreProvider),
    ref.watch(activityRepositoryProvider),
  ),
);

final movementRepositoryProvider = Provider<MovementRepository>(
  (ref) => MovementRepository(ref.watch(firestoreProvider)),
);

final suppliesStreamProvider =
    StreamProvider.family<List<Supply>, String>((ref, farmId) {
  return ref.watch(supplyRepositoryProvider).streamSupplies(farmId);
});

final supplyByIdProvider = StreamProvider.family<
    Supply?,
    ({String farmId, String supplyId})>((ref, args) {
  return ref
      .watch(supplyRepositoryProvider)
      .streamSupplyById(farmId: args.farmId, supplyId: args.supplyId);
});

final movementsForSupplyProvider = StreamProvider.family<
    List<SupplyMovement>,
    ({String farmId, String supplyId})>((ref, args) {
  return ref
      .watch(movementRepositoryProvider)
      .streamForSupply(farmId: args.farmId, supplyId: args.supplyId);
});

/// Resolves the primary batch for a pen by streaming current pigs.
/// Returns null if no pigs in the pen have a batch.
final primaryBatchForPenProvider =
    Provider.family<String?, ({String farmId, String penId})>((ref, args) {
  final pigs =
      ref.watch(pigsStreamProvider(args.farmId)).asData?.value ?? const [];
  return PenBatchResolver.primaryBatchForPen(penId: args.penId, pigs: pigs);
});
