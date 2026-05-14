import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../activity/application/activity_providers.dart';
import 'photo_upload_queue.dart';
import 'photo_upload_service.dart';

final firebaseStorageProvider =
    Provider<FirebaseStorage>((_) => FirebaseStorage.instance);

final sharedPreferencesProvider = FutureProvider<SharedPreferences>(
  (_) => SharedPreferences.getInstance(),
);

/// `null` while [sharedPreferencesProvider] is still loading.
final photoUploadQueueProvider = Provider<PhotoUploadQueue?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).asData?.value;
  return prefs == null ? null : PhotoUploadQueue(prefs);
});

/// `null` while [sharedPreferencesProvider] is still loading.
final photoUploadServiceProvider = Provider<PhotoUploadService?>((ref) {
  final queue = ref.watch(photoUploadQueueProvider);
  if (queue == null) return null;
  return PhotoUploadService(
    ref.watch(firebaseStorageProvider),
    ref.watch(firestoreProvider),
    queue,
  );
});
