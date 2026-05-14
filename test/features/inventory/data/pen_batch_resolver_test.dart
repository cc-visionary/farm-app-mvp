import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/features/inventory/data/pen_batch_resolver.dart';
import 'package:farm_app/src/features/pigs/domain/pig.dart';

Pig _pig({
  required String currentPenId,
  String? currentBatchId,
  PigStatus status = PigStatus.active,
}) {
  return Pig(
    id: 'p',
    farmId: 'f',
    tagId: 't',
    sex: PigSex.female,
    breed: 'b',
    birthDate: Timestamp.now(),
    sireId: null,
    damId: null,
    stage: PigStage.grower,
    status: status,
    currentAreaId: 'a',
    currentPenId: currentPenId,
    currentBatchId: currentBatchId,
    currentWeight: null,
    weightUpdatedAt: null,
    photoUrl: null,
    notes: null,
    createdBy: 'u',
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  );
}

void main() {
  test('returns null when pen has no pigs', () {
    expect(PenBatchResolver.primaryBatchForPen(penId: 'p1', pigs: []), isNull);
  });

  test('returns the batch when all pigs share one batch', () {
    final pigs = [
      _pig(currentPenId: 'p1', currentBatchId: 'b1'),
      _pig(currentPenId: 'p1', currentBatchId: 'b1'),
      _pig(currentPenId: 'p1', currentBatchId: 'b1'),
    ];
    expect(PenBatchResolver.primaryBatchForPen(penId: 'p1', pigs: pigs), 'b1');
  });

  test('returns majority batch when mixed', () {
    final pigs = [
      _pig(currentPenId: 'p1', currentBatchId: 'b1'),
      _pig(currentPenId: 'p1', currentBatchId: 'b1'),
      _pig(currentPenId: 'p1', currentBatchId: 'b2'),
    ];
    expect(PenBatchResolver.primaryBatchForPen(penId: 'p1', pigs: pigs), 'b1');
  });

  test('returns null when no pig has a batch', () {
    final pigs = [
      _pig(currentPenId: 'p1', currentBatchId: null),
      _pig(currentPenId: 'p1', currentBatchId: null),
    ];
    expect(PenBatchResolver.primaryBatchForPen(penId: 'p1', pigs: pigs), isNull);
  });

  test('ignores pigs not in the pen', () {
    final pigs = [
      _pig(currentPenId: 'p1', currentBatchId: 'b1'),
      _pig(currentPenId: 'p2', currentBatchId: 'b2'),
      _pig(currentPenId: 'p2', currentBatchId: 'b2'),
    ];
    expect(PenBatchResolver.primaryBatchForPen(penId: 'p1', pigs: pigs), 'b1');
  });

  test('ignores deceased/sold/culled pigs', () {
    final pigs = [
      _pig(currentPenId: 'p1', currentBatchId: 'b1', status: PigStatus.deceased),
      _pig(currentPenId: 'p1', currentBatchId: 'b2'),
    ];
    expect(PenBatchResolver.primaryBatchForPen(penId: 'p1', pigs: pigs), 'b2');
  });

  test('tie broken by alphabetical batch id', () {
    final pigs = [
      _pig(currentPenId: 'p1', currentBatchId: 'b2'),
      _pig(currentPenId: 'p1', currentBatchId: 'b1'),
    ];
    expect(PenBatchResolver.primaryBatchForPen(penId: 'p1', pigs: pigs), 'b1');
  });
}
