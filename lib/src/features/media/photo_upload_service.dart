import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'photo_upload_queue.dart';

/// Uploads photos to Firebase Storage and attaches the resulting URL onto the
/// owning Firestore record. On failure, the upload is enqueued for retry.
class PhotoUploadService {
  PhotoUploadService(this._storage, this._firestore, this._queue);

  final FirebaseStorage _storage;
  final FirebaseFirestore _firestore;
  final PhotoUploadQueue _queue;

  /// Uploads [file] to [storagePath], then writes the public URL onto the
  /// Firestore doc at [recordPath] under [fieldName]. Returns the URL on
  /// success. On any failure, the upload is enqueued and the method returns
  /// `null`.
  Future<String?> uploadAndAttach({
    required File file,
    required String storagePath,
    required String recordPath,
    required String fieldName,
  }) async {
    try {
      final ref = _storage.ref(storagePath);
      final task = await ref.putFile(file);
      final url = await task.ref.getDownloadURL();
      await _attachUrlToRecord(
        recordPath: recordPath,
        fieldName: fieldName,
        url: url,
      );
      return url;
    } catch (_) {
      await _queue.enqueue(
        QueuedUpload(
          localPath: file.path,
          storagePath: storagePath,
          recordPath: recordPath,
          fieldName: fieldName,
        ),
      );
      return null;
    }
  }

  Future<void> _attachUrlToRecord({
    required String recordPath,
    required String fieldName,
    required String url,
  }) async {
    final ref = _firestore.doc(recordPath);
    if (fieldName.endsWith('s')) {
      // Multi-photo field — append.
      await ref.update({
        fieldName: FieldValue.arrayUnion([url]),
      });
    } else {
      // Single-photo field — overwrite.
      await ref.update({fieldName: url});
    }
  }

  /// Re-attempts all queued uploads. Successful entries are removed from the
  /// queue; failures stay queued for the next attempt. Call this on
  /// connectivity restore.
  Future<void> flushQueue() async {
    final list = await _queue.all();
    for (final q in list) {
      try {
        final file = File(q.localPath);
        if (!file.existsSync()) {
          // Source file is gone — drop the entry rather than retry forever.
          await _queue.remove(q);
          continue;
        }
        final ref = _storage.ref(q.storagePath);
        final task = await ref.putFile(file);
        final url = await task.ref.getDownloadURL();
        await _attachUrlToRecord(
          recordPath: q.recordPath,
          fieldName: q.fieldName,
          url: url,
        );
        await _queue.remove(q);
      } catch (_) {
        // Keep in queue for next attempt.
      }
    }
  }
}
