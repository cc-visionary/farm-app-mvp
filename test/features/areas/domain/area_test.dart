import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/features/areas/domain/area.dart';

void main() {
  test('AreaPurpose.fromString resolves all values', () {
    for (final p in AreaPurpose.values) {
      expect(AreaPurpose.fromString(p.value), p);
    }
    expect(AreaPurpose.fromString('asdf'), AreaPurpose.other);
  });

  test('Area round-trips', () async {
    final f = FakeFirebaseFirestore();
    await f.collection('farms').doc('f1').collection('areas').doc('a1').set({
      'name': 'Farrowing 1',
      'purpose': 'farrowing',
      'notes': 'south wing',
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(1000),
    });
    final doc = await f.collection('farms').doc('f1').collection('areas').doc('a1').get();
    final a = Area.fromFirestore(doc, farmId: 'f1');
    expect(a.id, 'a1');
    expect(a.name, 'Farrowing 1');
    expect(a.purpose, AreaPurpose.farrowing);
    expect(a.notes, 'south wing');
  });
}
