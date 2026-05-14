import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A single pending photo upload that has been deferred until network is
/// available (or has failed at least once).
class QueuedUpload {
  QueuedUpload({
    required this.localPath,
    required this.storagePath,
    required this.recordPath,
    required this.fieldName,
  });

  /// On-device file path of the captured photo.
  final String localPath;

  /// Full Firebase Storage path (e.g. "farms/f1/pigs/p1/cover.jpg").
  final String storagePath;

  /// Firestore document path to attach the resulting URL to
  /// (e.g. "farms/f1/pigs/p1").
  final String recordPath;

  /// Field on the Firestore doc to write the URL into. If the name ends with
  /// "s" (e.g. "photoUrls") the URL is appended to an array via
  /// `FieldValue.arrayUnion`; otherwise it overwrites the field.
  final String fieldName;

  Map<String, dynamic> toMap() => {
        'localPath': localPath,
        'storagePath': storagePath,
        'recordPath': recordPath,
        'fieldName': fieldName,
      };

  factory QueuedUpload.fromMap(Map<String, dynamic> m) => QueuedUpload(
        localPath: m['localPath'] as String,
        storagePath: m['storagePath'] as String,
        recordPath: m['recordPath'] as String,
        fieldName: m['fieldName'] as String,
      );
}

/// Persistent buffer of [QueuedUpload]s backed by `shared_preferences` so
/// queued uploads survive process restarts. The queue is consumed by
/// `PhotoUploadService.flushQueue()` once connectivity returns.
class PhotoUploadQueue {
  PhotoUploadQueue(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'photo_upload_queue';

  Future<List<QueuedUpload>> all() async {
    final raw = _prefs.getStringList(_key) ?? const <String>[];
    return raw
        .map((s) => QueuedUpload.fromMap(
              jsonDecode(s) as Map<String, dynamic>,
            ))
        .toList();
  }

  Future<void> enqueue(QueuedUpload q) async {
    final list = await all();
    list.add(q);
    await _persist(list);
  }

  Future<void> remove(QueuedUpload q) async {
    final list = await all();
    list.removeWhere(
      (x) => x.localPath == q.localPath && x.storagePath == q.storagePath,
    );
    await _persist(list);
  }

  Future<void> _persist(List<QueuedUpload> list) async {
    await _prefs.setStringList(
      _key,
      list.map((q) => jsonEncode(q.toMap())).toList(),
    );
  }
}
