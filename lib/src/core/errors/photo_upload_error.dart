import 'dart:async' show TimeoutException;
import 'dart:io' show SocketException;

import 'package:firebase_core/firebase_core.dart';

/// Whether a [PhotoUploadError] should be retried later or surfaced as a
/// terminal failure.
///
/// - [retryable]: transient (network, server unavailable, unknown) — the
///   upload is enqueued and the user is told it will retry.
/// - [terminal]: permanent (auth, permission, quota, invalid argument) — the
///   upload is dropped from the queue and the user is told what went wrong.
enum PhotoUploadErrorKind { retryable, terminal }

/// Typed error for photo uploads. [kind] drives retry vs surface-to-user;
/// [code] is the underlying Firebase / system code for telemetry.
class PhotoUploadError implements Exception {
  PhotoUploadError({required this.kind, required this.code, this.cause});

  final PhotoUploadErrorKind kind;
  final String code;
  final Object? cause;

  /// Classifies an arbitrary error/exception into a [PhotoUploadError].
  ///
  /// Conservative default: unknown failures are [PhotoUploadErrorKind.retryable]
  /// so we don't drop user data due to misclassification.
  static PhotoUploadError classify(Object e) {
    if (e is FirebaseException) {
      switch (e.code) {
        case 'unauthenticated':
        case 'permission-denied':
        case 'invalid-argument':
        case 'quota-exceeded':
          return PhotoUploadError(
            kind: PhotoUploadErrorKind.terminal,
            code: e.code,
            cause: e,
          );
        case 'unavailable':
        case 'deadline-exceeded':
        case 'cancelled':
        case 'internal':
          return PhotoUploadError(
            kind: PhotoUploadErrorKind.retryable,
            code: e.code,
            cause: e,
          );
      }
    }
    if (e is SocketException || e is TimeoutException) {
      return PhotoUploadError(
        kind: PhotoUploadErrorKind.retryable,
        code: 'network',
        cause: e,
      );
    }
    return PhotoUploadError(
      kind: PhotoUploadErrorKind.retryable,
      code: 'unknown',
      cause: e,
    );
  }

  @override
  String toString() =>
      'PhotoUploadError(kind=$kind, code=$code, cause=$cause)';
}
