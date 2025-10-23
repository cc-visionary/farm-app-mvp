import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/application/auth_providers.dart';
import '../data/location_repository.dart';
import '../domain/location_model.dart';

// Provides an instance of the LocationRepository
final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepository(ref.read(firestoreProvider));
});

// Watches the list of locations for the current farm
final locationsStreamProvider = StreamProvider<List<Location>>((ref) {
  // Watch the provider that gives us the current user's farmId.
  final farmId = ref.watch(currentFarmIdProvider);

  // If the user is not logged in or has no farmId yet, return an empty list.
  if (farmId == null) {
    return Stream.value([]);
  }
  
  return ref.watch(locationRepositoryProvider).watchLocations(farmId);
});