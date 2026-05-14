import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/farm_model.dart';

class FarmRepository {
  FarmRepository(this._firestore);
  final FirebaseFirestore _firestore;

  Future<String> createFarmWithOwner({
    required String name,
    required String ownerUserId,
  }) async {
    final farmRef = _firestore.collection('farms').doc();
    final memberRef = farmRef.collection('members').doc(ownerUserId);
    final batch = _firestore.batch();
    batch.set(farmRef, {
      'name': name.trim(),
      'createdBy': ownerUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(memberRef, {
      'role': 'owner',
      'assignedAreaIds': <String>[],
      'joinedAt': FieldValue.serverTimestamp(),
      'invitedBy': null,
    });
    await batch.commit();
    return farmRef.id;
  }

  Future<void> updateFarmName({required String farmId, required String newName}) async {
    await _firestore.collection('farms').doc(farmId).update({'name': newName.trim()});
  }

  Stream<Farm?> streamFarm(String farmId) {
    return _firestore.collection('farms').doc(farmId).snapshots().map(
      (d) => d.exists ? Farm.fromFirestore(d) : null,
    );
  }
}
