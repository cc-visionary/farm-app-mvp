// lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- Farm Management ---

  // Create a new farm for a new user
  Future<void> createFarmForNewUser(User user, String farmName) async {
    await _db.collection('farms').doc(user.uid).set({
      'farmName': farmName,
      'ownerId': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'animalType': 'Hogs', // Default to Hogs for the MVP
    });
  }

  // --- Location Management ---

  // Get a stream of all locations for the current user's farm
  Stream<QuerySnapshot> getLocations() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not logged in");
    // The farm ID is the same as the user's ID in our simple model
    return _db.collection('farms').doc(user.uid).collection('locations').snapshots();
  }

  // Add a new location
  Future<void> addLocation(String name, String type) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not logged in");
    await _db.collection('farms').doc(user.uid).collection('locations').add({
      'name': name,
      'type': type,
    });
  }

  // --- Animal Management ---

  // Get a stream of all animals for the current user's farm
  Stream<QuerySnapshot> getAnimals() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not logged in");
    return _db.collection('farms').doc(user.uid).collection('animals').snapshots();
  }

  // Add a new animal
  Future<void> addAnimal(String tagId, DateTime birthDate, String locationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not logged in");
    await _db.collection('farms').doc(user.uid).collection('animals').add({
      'tagId': tagId,
      'birthDate': Timestamp.fromDate(birthDate),
      'locationId': locationId,
      'history': [], // Start with an empty history log
    });
  }

  // Add a history note to an animal
  Future<void> addAnimalHistoryNote(String animalId, String note) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not logged in");
    
    final noteEntry = {
      'date': Timestamp.now(),
      'note': note,
    };

    await _db
        .collection('farms')
        .doc(user.uid)
        .collection('animals')
        .doc(animalId)
        .update({
          'history': FieldValue.arrayUnion([noteEntry])
        });
  }
}