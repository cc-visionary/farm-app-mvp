import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/features/areas/data/area_repository.dart';
import 'package:farm_app/src/features/areas/domain/area.dart';

void main() {
  test('createArea + streamAreas', () async {
    final f = FakeFirebaseFirestore();
    final repo = AreaRepository(f);
    final id = await repo.createArea(
      farmId: 'f1', name: 'Farrowing 1',
      purpose: AreaPurpose.farrowing, notes: null,
    );
    expect(id, isNotEmpty);
    final areas = await repo.streamAreas('f1').first;
    expect(areas, hasLength(1));
    expect(areas.first.name, 'Farrowing 1');
  });

  test('updateArea changes name', () async {
    final f = FakeFirebaseFirestore();
    final repo = AreaRepository(f);
    final id = await repo.createArea(
      farmId: 'f1', name: 'Old', purpose: AreaPurpose.nursery, notes: null,
    );
    await repo.updateArea(farmId: 'f1', areaId: id, name: 'New',
        purpose: AreaPurpose.nursery, notes: 'updated');
    final areas = await repo.streamAreas('f1').first;
    expect(areas.first.name, 'New');
    expect(areas.first.notes, 'updated');
  });

  test('createPen + streamPens', () async {
    final f = FakeFirebaseFirestore();
    final repo = AreaRepository(f);
    final aId = await repo.createArea(
      farmId: 'f1', name: 'Farrowing', purpose: AreaPurpose.farrowing, notes: null,
    );
    final pId = await repo.createPen(
      farmId: 'f1', areaId: aId, name: 'Pen 1', capacity: 10, notes: null,
    );
    expect(pId, isNotEmpty);
    final pens = await repo.streamPens(farmId: 'f1', areaId: aId).first;
    expect(pens, hasLength(1));
    expect(pens.first.capacity, 10);
  });

  test('deletePen + deleteArea', () async {
    final f = FakeFirebaseFirestore();
    final repo = AreaRepository(f);
    final aId = await repo.createArea(
      farmId: 'f1', name: 'Q', purpose: AreaPurpose.quarantine, notes: null,
    );
    final pId = await repo.createPen(
      farmId: 'f1', areaId: aId, name: 'P', capacity: 5, notes: null,
    );
    await repo.deletePen(farmId: 'f1', areaId: aId, penId: pId);
    expect((await repo.streamPens(farmId: 'f1', areaId: aId).first), isEmpty);
    await repo.deleteArea(farmId: 'f1', areaId: aId);
    expect((await repo.streamAreas('f1').first), isEmpty);
  });
}
