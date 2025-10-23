import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/animal_model.dart';

class AnimalRepository {
  final FirebaseFirestore _firestore;

  AnimalRepository(this._firestore);

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
    return _firestore
        .collection('farms')
        .doc(animal.farmId)
        .collection('animals')
        .add(animal.toFirestore());
  }
}