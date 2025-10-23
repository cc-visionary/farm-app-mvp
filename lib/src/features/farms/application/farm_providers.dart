import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/data/farm_repository.dart';
import '../../farms/domain/farm_model.dart';

// Provides an instance of FarmRepository
final farmRepositoryProvider = Provider<FarmRepository>((ref) {
  return FarmRepository(ref.read(firestoreProvider));
});

// Provides the full Farm object for the currently logged-in user
final currentFarmProvider = StreamProvider<Farm?>((ref) {
  final farmId = ref.watch(currentFarmIdProvider);
  if (farmId == null) {
    return Stream.value(null);
  }
  return ref.watch(farmRepositoryProvider).watchFarm(farmId);
});
