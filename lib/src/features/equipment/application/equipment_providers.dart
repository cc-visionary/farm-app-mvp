import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../activity/application/activity_providers.dart';
import '../data/equipment_repository.dart';
import '../domain/equipment.dart';
import '../domain/maintenance_record.dart';

final equipmentRepositoryProvider = Provider<EquipmentRepository>(
  (ref) => EquipmentRepository(
    ref.watch(firestoreProvider),
    ref.watch(activityRepositoryProvider),
  ),
);

final equipmentStreamProvider =
    StreamProvider.family<List<Equipment>, String>((ref, farmId) {
  return ref.watch(equipmentRepositoryProvider).streamEquipment(farmId);
});

final equipmentByIdProvider = StreamProvider.family<
    Equipment?, ({String farmId, String equipmentId})>((ref, args) {
  return ref.watch(equipmentRepositoryProvider).streamEquipmentById(
        farmId: args.farmId,
        equipmentId: args.equipmentId,
      );
});

final maintenanceStreamProvider = StreamProvider.family<
    List<MaintenanceRecord>, ({String farmId, String equipmentId})>((ref, args) {
  return ref.watch(equipmentRepositoryProvider).streamMaintenance(
        farmId: args.farmId,
        equipmentId: args.equipmentId,
      );
});
