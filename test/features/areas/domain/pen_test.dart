import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/features/areas/domain/pen.dart';

void main() {
  test('Pen round-trips', () async {
    final f = FakeFirebaseFirestore();
    await f.collection('farms').doc('f1').collection('areas').doc('a1').collection('pens').doc('p1').set({
      'name': 'Pen 1',
      'capacity': 12,
      'currentOccupancy': 8,
      'notes': null,
    });
    final doc = await f.collection('farms').doc('f1').collection('areas').doc('a1').collection('pens').doc('p1').get();
    final p = Pen.fromFirestore(doc, farmId: 'f1', areaId: 'a1');
    expect(p.id, 'p1');
    expect(p.areaId, 'a1');
    expect(p.capacity, 12);
    expect(p.currentOccupancy, 8);
  });
}
