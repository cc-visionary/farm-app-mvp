import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/farm_model.dart';

class FarmRepository {
  final FirebaseFirestore _firestore;
  FarmRepository(this._firestore);

  // Method to get a stream of a single farm document
  Stream<Farm?> watchFarm(String farmId) {
    final docRef = _firestore.collection('farms').doc(farmId);
    return docRef.snapshots().map((snapshot) {
      if (snapshot.exists) {
        return Farm.fromMap(snapshot.data()!, snapshot.id);
      }
      return null;
    });
  }
}