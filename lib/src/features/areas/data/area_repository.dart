import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/area.dart';
import '../domain/pen.dart';

class AreaRepository {
  AreaRepository(this._firestore);
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _areas(String farmId) =>
      _firestore.collection('farms').doc(farmId).collection('areas');

  CollectionReference<Map<String, dynamic>> _pens(String farmId, String areaId) =>
      _areas(farmId).doc(areaId).collection('pens');

  Future<String> createArea({
    required String farmId,
    required String name,
    required AreaPurpose purpose,
    required String? notes,
  }) async {
    final ref = _areas(farmId).doc();
    await ref.set({
      'name': name.trim(),
      'purpose': purpose.value,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> updateArea({
    required String farmId,
    required String areaId,
    required String name,
    required AreaPurpose purpose,
    required String? notes,
  }) async {
    await _areas(farmId).doc(areaId).update({
      'name': name.trim(),
      'purpose': purpose.value,
      'notes': notes?.trim(),
    });
  }

  Future<void> deleteArea({required String farmId, required String areaId}) async {
    await _areas(farmId).doc(areaId).delete();
  }

  Stream<List<Area>> streamAreas(String farmId) {
    return _areas(farmId).snapshots().map((s) {
      final list = s.docs.map((d) => Area.fromFirestore(d, farmId: farmId)).toList();
      list.sort((a, b) {
        final cmp = a.purpose.sortOrder.compareTo(b.purpose.sortOrder);
        return cmp != 0 ? cmp : a.name.compareTo(b.name);
      });
      return list;
    });
  }

  Future<String> createPen({
    required String farmId,
    required String areaId,
    required String name,
    required int? capacity,
    required String? notes,
  }) async {
    final ref = _pens(farmId, areaId).doc();
    await ref.set({
      'name': name.trim(),
      if (capacity != null) 'capacity': capacity,
      'currentOccupancy': 0,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    });
    return ref.id;
  }

  Future<void> updatePen({
    required String farmId,
    required String areaId,
    required String penId,
    required String name,
    required int? capacity,
    required String? notes,
  }) async {
    await _pens(farmId, areaId).doc(penId).update({
      'name': name.trim(),
      'capacity': capacity,
      'notes': notes?.trim(),
    });
  }

  Future<void> deletePen({
    required String farmId, required String areaId, required String penId,
  }) async {
    await _pens(farmId, areaId).doc(penId).delete();
  }

  Stream<List<Pen>> streamPens({required String farmId, required String areaId}) {
    return _pens(farmId, areaId).snapshots().map((s) => s.docs
        .map((d) => Pen.fromFirestore(d, farmId: farmId, areaId: areaId))
        .toList()..sort((a, b) => a.name.compareTo(b.name)));
  }

  /// Streams all pens across all areas for a farm — used by Farm Layout.
  Stream<List<Pen>> streamAllPens(String farmId) {
    return _firestore.collectionGroup('pens').snapshots().map((s) {
      return s.docs
          .where((d) {
            final parts = d.reference.path.split('/');
            return parts.length >= 5 && parts[0] == 'farms' && parts[1] == farmId;
          })
          .map((d) {
            final areaId = d.reference.parent.parent!.id;
            return Pen.fromFirestore(d, farmId: farmId, areaId: areaId);
          })
          .toList();
    });
  }

  Future<void> incrementPenOccupancy({
    required String farmId, required String areaId, required String penId, required int delta,
  }) async {
    await _pens(farmId, areaId).doc(penId).update({
      'currentOccupancy': FieldValue.increment(delta),
    });
  }
}
