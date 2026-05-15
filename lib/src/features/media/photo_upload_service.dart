import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../core/errors/photo_upload_error.dart';
import 'photo_upload_queue.dart';

/// Uploads photos to Firebase Storage and attaches the resulting URL onto the
/// owning Firestore record.
///
/// Errors are classified via [PhotoUploadError.classify]:
/// - **Retryable** failures (network, server unavailable, unknown) are
///   enqueued for a future flush.
/// - **Terminal** failures (auth, permission, quota, invalid argument) are
///   NOT enqueued — looping on a permanently-broken upload would never
///   succeed and would silently consume battery.
///
/// Either way, the classified error is pushed onto [errorStream] so the UI
/// layer can surface a SnackBar / banner appropriate to the kind.
class PhotoUploadService {
  PhotoUploadService(this._storage, this._firestore, this._queue);

  final FirebaseStorage _storage;
  final FirebaseFirestore _firestore;
  final PhotoUploadQueue _queue;

  final _errorController = StreamController<PhotoUploadError>.broadcast();

  /// Broadcast stream of classified upload errors. The UI listens on this via
  /// `photoUploadErrorStreamProvider` to show user-facing messages.
  Stream<PhotoUploadError> get errorStream => _errorController.stream;

  /// Uploads [file] to [storagePath], then writes the public URL onto the
  /// Firestore doc at [recordPath] under [fieldName]. Returns the URL on
  /// success. On any failure, the error is classified, the upload is
  /// enqueued only if retryable, and `null` is returned.
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
    } catch (e) {
      final classified = PhotoUploadError.classify(e);
      if (classified.kind == PhotoUploadErrorKind.retryable) {
        await _queue.enqueue(
          QueuedUpload(
            localPath: file.path,
            storagePath: storagePath,
            recordPath: recordPath,
            fieldName: fieldName,
          ),
        );
      }
      // Always surface to UI; UI decides messaging by kind.
      _errorController.add(classified);
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
  /// queue; retryable failures stay queued for the next attempt. Terminal
  /// failures are removed from the queue (we don't loop forever) and
  /// surfaced on [errorStream]. Call this on connectivity restore.
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
      } catch (e) {
        final classified = PhotoUploadError.classify(e);
        if (classified.kind == PhotoUploadErrorKind.terminal) {
          // Don't loop forever on a permanently-broken upload.
          await _queue.remove(q);
          _errorController.add(classified);
        }
        // Retryable: leave in queue for next flush; no UI surfacing here
        // (the user was already told at first-attempt time).
      }
    }
  }

  /// Closes the internal error stream. Call on app teardown.
  void dispose() {
    _errorController.close();
  }
}
