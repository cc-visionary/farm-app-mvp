import 'package:farm_app/src/features/media/photo_upload_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('enqueue + all returns the queued upload', () async {
    final prefs = await SharedPreferences.getInstance();
    final q = PhotoUploadQueue(prefs);
    await q.enqueue(
      QueuedUpload(
        localPath: '/tmp/a.jpg',
        storagePath: 'farms/f/pigs/p/0.jpg',
        recordPath: 'farms/f/pigs/p',
        fieldName: 'photoUrl',
      ),
    );
    final list = await q.all();
    expect(list, hasLength(1));
    expect(list.first.localPath, '/tmp/a.jpg');
    expect(list.first.storagePath, 'farms/f/pigs/p/0.jpg');
    expect(list.first.recordPath, 'farms/f/pigs/p');
    expect(list.first.fieldName, 'photoUrl');
  });

  test('remove matches by both localPath and storagePath', () async {
    final prefs = await SharedPreferences.getInstance();
    final q = PhotoUploadQueue(prefs);
    final a = QueuedUpload(
      localPath: '/a.jpg',
      storagePath: 's/a',
      recordPath: 'r/a',
      fieldName: 'photoUrl',
    );
    final b = QueuedUpload(
      localPath: '/b.jpg',
      storagePath: 's/b',
      recordPath: 'r/b',
      fieldName: 'photoUrl',
    );
    await q.enqueue(a);
    await q.enqueue(b);
    await q.remove(a);
    final remaining = await q.all();
    expect(remaining.map((x) => x.localPath), ['/b.jpg']);
  });

  test('remove does not delete entries with same localPath but different storagePath',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final q = PhotoUploadQueue(prefs);
    final a = QueuedUpload(
      localPath: '/dup.jpg',
      storagePath: 's/a',
      recordPath: 'r/a',
      fieldName: 'photoUrl',
    );
    final b = QueuedUpload(
      localPath: '/dup.jpg',
      storagePath: 's/b',
      recordPath: 'r/b',
      fieldName: 'photoUrl',
    );
    await q.enqueue(a);
    await q.enqueue(b);
    await q.remove(a);
    final remaining = await q.all();
    expect(remaining, hasLength(1));
    expect(remaining.first.storagePath, 's/b');
  });
}
