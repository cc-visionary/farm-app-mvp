import 'dart:async';
import 'dart:io';

import 'package:farm_app/src/core/errors/photo_upload_error.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('network exceptions classify as retryable', () {
    final classified = PhotoUploadError.classify(
      const SocketException('no internet'),
    );
    expect(classified.kind, PhotoUploadErrorKind.retryable);
    expect(classified.code, 'network');
  });

  test('TimeoutException classifies as retryable', () {
    final classified = PhotoUploadError.classify(TimeoutException('slow'));
    expect(classified.kind, PhotoUploadErrorKind.retryable);
    expect(classified.code, 'network');
  });

  test('Firebase permission-denied classifies as terminal', () {
    final fe = FirebaseException(
      plugin: 'firebase_storage',
      code: 'permission-denied',
    );
    final classified = PhotoUploadError.classify(fe);
    expect(classified.kind, PhotoUploadErrorKind.terminal);
    expect(classified.code, 'permission-denied');
  });

  test('Firebase quota-exceeded classifies as terminal', () {
    final fe = FirebaseException(
      plugin: 'firebase_storage',
      code: 'quota-exceeded',
    );
    expect(
      PhotoUploadError.classify(fe).kind,
      PhotoUploadErrorKind.terminal,
    );
  });

  test('Firebase unavailable classifies as retryable', () {
    final fe = FirebaseException(
      plugin: 'firebase_storage',
      code: 'unavailable',
    );
    expect(
      PhotoUploadError.classify(fe).kind,
      PhotoUploadErrorKind.retryable,
    );
  });

  test('Unknown errors classify as retryable (defensive)', () {
    expect(
      PhotoUploadError.classify(Object()).kind,
      PhotoUploadErrorKind.retryable,
    );
  });
}
