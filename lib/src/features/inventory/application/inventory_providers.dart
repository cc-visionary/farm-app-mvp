import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../activity/application/activity_providers.dart';
import '../data/movement_repository.dart';
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
