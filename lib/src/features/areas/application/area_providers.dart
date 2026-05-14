import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../activity/application/activity_providers.dart';
import '../data/area_repository.dart';
import '../domain/area.dart';
import '../domain/pen.dart';

final areaRepositoryProvider = Provider<AreaRepository>(
  (ref) => AreaRepository(ref.watch(firestoreProvider)),
);

final areasStreamProvider =
    StreamProvider.family<List<Area>, String>((ref, farmId) {
  return ref.watch(areaRepositoryProvider).streamAreas(farmId);
});

final pensStreamProvider =
    StreamProvider.family<List<Pen>, ({String farmId, String areaId})>((ref, args) {
  return ref.watch(areaRepositoryProvider).streamPens(
        farmId: args.farmId, areaId: args.areaId,
      );
});

final allPensStreamProvider =
    StreamProvider.family<List<Pen>, String>((ref, farmId) {
  return ref.watch(areaRepositoryProvider).streamAllPens(farmId);
});
