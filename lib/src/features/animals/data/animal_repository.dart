import 'package:cloud_firestore/cloud_firestore.dart';
import '../../animals/domain/animal_model.dart';

class AnimalRepository {
  final FirebaseFirestore _firestore;

  AnimalRepository(this._firestore);

  // Helper function to generate a unique ID
  String _generateAnimalId(String animalType) {
    final prefix = animalType.substring(0, 3).toUpperCase();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    return '$prefix-$timestamp';
  }

  // Watch all animals for a farm
  Stream<List<Animal>> watchAnimals(String farmId) {
    return _firestore
        .collection('farms')
        .doc(farmId)
        .collection('animals')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Animal.fromFirestore(doc)).toList());
  }

  // Add a new animal
  Future<void> addAnimal(Animal animal) {
    final newId = _generateAnimalId(animal.animalType);
    final animalWithId = animal.copyWith(animalId: newId); // Assumes you add a copyWith method

    return _firestore
        .collection('farms')
        .doc(animal.farmId)
        .collection('animals')
        .add(animalWithId.toFirestore());
  }
}