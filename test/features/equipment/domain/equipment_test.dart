import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/features/equipment/domain/equipment.dart';

void main() {
  test('EquipmentType.fromString resolves all', () {
    for (final t in EquipmentType.values) {
      expect(EquipmentType.fromString(t.value), t);
    }
    expect(EquipmentType.fromString('foo'), EquipmentType.other);
  });

  test('EquipmentStatus.fromString resolves all', () {
    for (final s in EquipmentStatus.values) {
      expect(EquipmentStatus.fromString(s.value), s);
    }
    expect(EquipmentStatus.fromString('asdf'), EquipmentStatus.available);
  });

  test('EquipmentStatus.next cycles through in_use -> available -> needs_repair', () {
    expect(EquipmentStatus.inUse.next, EquipmentStatus.available);
    expect(EquipmentStatus.available.next, EquipmentStatus.needsRepair);
    expect(EquipmentStatus.needsRepair.next, EquipmentStatus.inUse);
    expect(EquipmentStatus.retired.next, EquipmentStatus.retired);
  });

  test('Equipment round-trips', () async {
    final f = FakeFirebaseFirestore();
    final t = Timestamp.fromMillisecondsSinceEpoch(1000);
    await f.collection('farms').doc('f1').collection('equipment').doc('e1').set({
      'name': 'Tunnel Fan A',
      'type': 'ventilation',
      'areaId': 'a1',
      'status': 'in_use',
      'purchaseDate': t,
      'purchaseCostPhp': 25000.0,
      'photoUrl': null,
      'notes': 'south wall',
      'createdBy': 'u1',
      'createdAt': t,
      'updatedAt': t,
    });
    final doc =
        await f.collection('farms').doc('f1').collection('equipment').doc('e1').get();
    final eq = Equipment.fromFirestore(doc, farmId: 'f1');
    expect(eq.id, 'e1');
    expect(eq.type, EquipmentType.ventilation);
    expect(eq.status, EquipmentStatus.inUse);
    expect(eq.purchaseCostPhp, 25000.0);
  });
}
