import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/location_model.dart';

class LocationRepository {
  final FirebaseFirestore _firestore;

  LocationRepository(this._firestore);

  // Get a stream of locations for a specific farm
  Stream<List<Location>> watchLocations(String farmId) {
    return _firestore
        .collection('farms')
        .doc(farmId)
        .collection('locations')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Location.fromFirestore(doc)).toList();
    });
  }

  // Add a new location
  Future<void> addLocation(Location location) {
    return _firestore
        .collection('farms')
        .doc(location.farmId)
        .collection('locations')
        .add(location.toFirestore());
  }

  // Update an existing location
  Future<void> updateLocation(Location location) {
    return _firestore
        .collection('farms')
        .doc(location.farmId)
        .collection('locations')
        .doc(location.id)
        .update(location.toFirestore());
  }

  // Delete a location
  Future<void> deleteLocation({required String farmId, required String locationId}) {
    return _firestore
        .collection('farms')
        .doc(farmId)
        .collection('locations')
        .doc(locationId)
        .delete();
  }
}