import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/errors/photo_upload_error.dart';
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

/// Broadcast stream of classified photo-upload errors. The [AppShell]
/// listens on this and surfaces a SnackBar (retryable vs terminal copy).
/// Emits an empty stream while [photoUploadServiceProvider] is still loading.
final photoUploadErrorStreamProvider = StreamProvider<PhotoUploadError>((ref) {
  final svc = ref.watch(photoUploadServiceProvider);
  if (svc == null) return const Stream.empty();
  return svc.errorStream;
});
