import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/features/pigs/domain/pig.dart';

void main() {
  test('PigSex.fromString', () {
    expect(PigSex.fromString('male'), PigSex.male);
    expect(PigSex.fromString('female'), PigSex.female);
    expect(PigSex.fromString('x'), PigSex.female); // default
  });

  test('PigStage.fromString resolves all', () {
    for (final s in PigStage.values) {
      expect(PigStage.fromString(s.value), s);
    }
  });

  test('PigStage.fromString defaults to grower', () {
    expect(PigStage.fromString('unknown'), PigStage.grower);
  });

  test('PigStatus.fromString resolves all', () {
    for (final s in PigStatus.values) {
      expect(PigStatus.fromString(s.value), s);
    }
  });

  test('PigStatus.fromString defaults to active', () {
    expect(PigStatus.fromString('unknown'), PigStatus.active);
  });

  test('Pig round-trips through Firestore', () async {
    final f = FakeFirebaseFirestore();
    final birth = Timestamp.fromMillisecondsSinceEpoch(1700000000000);
    final created = Timestamp.fromMillisecondsSinceEpoch(1700100000000);
    await f.collection('farms').doc('f1').collection('pigs').doc('p1').set({
      'tagId': 'SOW-001',
      'sex': 'female',
      'breed': 'Yorkshire',
      'birthDate': birth,
      'sireId': 'BOAR-1',
      'damId': 'SOW-PARENT-1',
      'stage': 'sow',
      'status': 'active',
      'currentAreaId': 'a1',
      'currentPenId': 'pen-1',
      'currentWeight': 220.5,
      'photoUrl': 'https://x/p.jpg',
      'notes': null,
      'createdBy': 'u1',
      'createdAt': created,
      'updatedAt': created,
    });
    final doc =
        await f.collection('farms').doc('f1').collection('pigs').doc('p1').get();
    final pig = Pig.fromFirestore(doc, farmId: 'f1');
    expect(pig.tagId, 'SOW-001');
    expect(pig.sex, PigSex.female);
    expect(pig.stage, PigStage.sow);
    expect(pig.status, PigStatus.active);
    expect(pig.currentWeight, 220.5);
    expect(pig.sireId, 'BOAR-1');
    expect(pig.damId, 'SOW-PARENT-1');
    expect(pig.currentAreaId, 'a1');
    expect(pig.currentPenId, 'pen-1');
    expect(pig.photoUrl, 'https://x/p.jpg');
    expect(pig.breed, 'Yorkshire');
  });

  test('Pig age helper produces sensible buckets', () {
    final now = DateTime(2026, 6, 1);
    final p1 = _pig(birthDate: DateTime(2025, 6, 1)); // 12 months
    final p2 = _pig(birthDate: DateTime(2026, 5, 1)); // ~30 days
    final p3 = _pig(birthDate: DateTime(2026, 5, 25)); // ~7 days
    final p4 = _pig(birthDate: DateTime(2026, 5, 30)); // 2 days

    expect(p1.ageString(now), '1 yr');
    expect(p2.ageString(now), '1 mo');
    expect(p3.ageString(now), '1 wk');
    expect(p4.ageString(now), '2 d');
  });

  test('Pig.isBreeder true for sow/gilt/boar', () {
    expect(_pig(stage: PigStage.sow).isBreeder, isTrue);
    expect(_pig(stage: PigStage.gilt).isBreeder, isTrue);
    expect(_pig(stage: PigStage.boar).isBreeder, isTrue);
    expect(_pig(stage: PigStage.grower).isBreeder, isFalse);
    expect(_pig(stage: PigStage.weaner).isBreeder, isFalse);
    expect(_pig(stage: PigStage.finisher).isBreeder, isFalse);
    expect(_pig(stage: PigStage.suckling).isBreeder, isFalse);
  });
}

Pig _pig({
  DateTime? birthDate,
  PigStage stage = PigStage.sow,
}) =>
    Pig(
      id: 'x',
      farmId: 'f',
      tagId: 't',
      sex: PigSex.female,
      breed: 'Y',
      birthDate: Timestamp.fromDate(birthDate ?? DateTime(2025, 1, 1)),
      sireId: null,
      damId: null,
      stage: stage,
      status: PigStatus.active,
      currentAreaId: 'a',
      currentPenId: null,
      currentWeight: null,
      weightUpdatedAt: null,
      photoUrl: null,
      notes: null,
      createdBy: 'u',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    );
