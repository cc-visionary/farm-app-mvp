import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/application/auth_providers.dart';
import '../data/animal_repository.dart';
import '../domain/animal_model.dart';

final animalRepositoryProvider = Provider<AnimalRepository>((ref) {
  return AnimalRepository(ref.read(firestoreProvider));
});

final animalsStreamProvider = StreamProvider<List<Animal>>((ref) {
  // Watch the provider that gives us the current user's farmId.
  final farmId = ref.watch(currentFarmIdProvider);

  // If the user is not logged in or has no farmId yet, return an empty list.
  if (farmId == null) {
    return Stream.value([]);
  }

  return ref.watch(animalRepositoryProvider).watchAnimals(farmId);
});
