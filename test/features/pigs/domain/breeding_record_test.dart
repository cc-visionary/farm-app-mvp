import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:farm_app/src/features/pigs/domain/breeding_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BreedingMethod.fromString', () {
    test('resolves natural and ai', () {
      expect(BreedingMethod.fromString('natural'), BreedingMethod.natural);
      expect(BreedingMethod.fromString('ai'), BreedingMethod.ai);
    });
    test('defaults to natural on unknown', () {
      expect(BreedingMethod.fromString('???'), BreedingMethod.natural);
    });
  });

  group('BreedingStatus.fromString', () {
    test('resolves all', () {
      expect(BreedingStatus.fromString('planned'), BreedingStatus.planned);
      expect(BreedingStatus.fromString('confirmed'), BreedingStatus.confirmed);
      expect(BreedingStatus.fromString('farrowed'), BreedingStatus.farrowed);
      expect(BreedingStatus.fromString('failed'), BreedingStatus.failed);
      expect(BreedingStatus.fromString('aborted'), BreedingStatus.aborted);
    });
    test('defaults to planned on unknown', () {
      expect(BreedingStatus.fromString('???'), BreedingStatus.planned);
    });
  });

  test('gestationDays constant is 114', () {
    expect(gestationDays, 114);
  });

  test('computeExpectedFarrowingDate returns insemination + 114 days', () {
    final ins = Timestamp.fromMillisecondsSinceEpoch(1700000000000);
    final expected = BreedingRecord.computeExpectedFarrowingDate(ins);
    expect(
      expected.toDate(),
      ins.toDate().add(const Duration(days: 114)),
    );
  });

  test('BreedingRecord round-trips through Firestore', () async {
    final f = FakeFirebaseFirestore();
    final ins = Timestamp.fromMillisecondsSinceEpoch(1700000000000);
    final heat = Timestamp.fromMillisecondsSinceEpoch(1699000000000);
    final expected = BreedingRecord.computeExpectedFarrowingDate(ins);
    final createdAt = Timestamp.fromMillisecondsSinceEpoch(1698000000000);

    final record = BreedingRecord(
      id: 'br1',
      farmId: 'f1',
      sowId: 'sow1',
      boarId: 'boar1',
      heatDate: heat,
      inseminationDate: ins,
      method: BreedingMethod.ai,
      pregnancyCheckDate: null,
      confirmed: false,
      expectedFarrowingDate: expected,
      status: BreedingStatus.planned,
      notes: 'first AI cycle',
      createdBy: 'u1',
      createdAt: createdAt,
    );

    await f
        .collection('farms')
        .doc('f1')
        .collection('pigs')
        .doc('sow1')
        .collection('breeding_records')
        .doc('br1')
        .set(record.toMap());

    final doc = await f
        .collection('farms')
        .doc('f1')
        .collection('pigs')
        .doc('sow1')
        .collection('breeding_records')
        .doc('br1')
        .get();
    final hydrated =
        BreedingRecord.fromFirestore(doc, farmId: 'f1', sowId: 'sow1');

    expect(hydrated.id, 'br1');
    expect(hydrated.farmId, 'f1');
    expect(hydrated.sowId, 'sow1');
    expect(hydrated.boarId, 'boar1');
    expect(hydrated.heatDate, heat);
    expect(hydrated.inseminationDate, ins);
    expect(hydrated.method, BreedingMethod.ai);
    expect(hydrated.pregnancyCheckDate, isNull);
    expect(hydrated.confirmed, isFalse);
    expect(hydrated.expectedFarrowingDate, expected);
    expect(hydrated.status, BreedingStatus.planned);
    expect(hydrated.notes, 'first AI cycle');
    expect(hydrated.createdBy, 'u1');
    expect(hydrated.createdAt, createdAt);
  });
}
