import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/features/inventory/domain/supply_category.dart';
import 'package:farm_app/src/features/inventory/domain/supply_movement.dart';

void main() {
  test('SupplyMovement round-trips', () async {
    final f = FakeFirebaseFirestore();
    final t = Timestamp.fromMillisecondsSinceEpoch(1700000000000);
    await f
        .collection('farms')
        .doc('f1')
        .collection('supply_movements')
        .doc('m1')
        .set({
          'supplyId': 's1',
          'type': 'consumption',
          'quantity': -2,
          'relatedPenId': 'pen1',
          'relatedBatchId': 'batch1',
          'notes': 'morning feed',
          'createdBy': 'u1',
          'createdAt': t,
        });
    final doc = await f
        .collection('farms')
        .doc('f1')
        .collection('supply_movements')
        .doc('m1')
        .get();
    final m = SupplyMovement.fromFirestore(doc, farmId: 'f1');

    expect(m.id, 'm1');
    expect(m.farmId, 'f1');
    expect(m.supplyId, 's1');
    expect(m.type, MovementType.consumption);
    expect(m.quantity, -2);
    expect(m.relatedPenId, 'pen1');
    expect(m.relatedBatchId, 'batch1');
  });

  test('Purchase movement carries unitCostPhp', () async {
    final f = FakeFirebaseFirestore();
    await f
        .collection('farms')
        .doc('f1')
        .collection('supply_movements')
        .doc('m2')
        .set({
          'supplyId': 's1',
          'type': 'purchase',
          'quantity': 10,
          'unitCostPhp': 1650.0,
          'relatedPurchaseId': 'p1',
          'createdBy': 'u1',
          'createdAt': Timestamp.now(),
        });
    final doc = await f
        .collection('farms')
        .doc('f1')
        .collection('supply_movements')
        .doc('m2')
        .get();
    final m = SupplyMovement.fromFirestore(doc, farmId: 'f1');

    expect(m.type, MovementType.purchase);
    expect(m.quantity, 10);
    expect(m.unitCostPhp, 1650.0);
    expect(m.relatedPurchaseId, 'p1');
  });
}
