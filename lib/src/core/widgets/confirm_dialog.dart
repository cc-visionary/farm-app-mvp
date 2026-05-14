// lib/src/core/widgets/confirm_dialog.dart
//
// Adaptive confirm dialog. Cupertino on iOS/macOS (with destructive styling),
// Material AlertDialog elsewhere. Plays a medium haptic on iOS when the user
// confirms a destructive action — matches platform expectation for "this
// cannot be undone" flows like marking an animal deceased.

import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ConfirmDialog {
  ConfirmDialog._();

  /// Shows a platform-adaptive confirm dialog. Returns `true` if confirmed,
  /// `false` if dismissed or cancelled. Plays a medium haptic on iOS when the
  /// destructive button is tapped.
  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool destructive = false,
  }) async {
    if (Platform.isIOS || Platform.isMacOS) {
      final result = await showCupertinoDialog<bool>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text(title),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(message),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(cancelLabel),
            ),
            CupertinoDialogAction(
              isDestructiveAction: destructive,
              onPressed: () {
                if (destructive) HapticFeedback.mediumImpact();
                Navigator.of(ctx).pop(true);
              },
              child: Text(confirmLabel),
            ),
          ],
        ),
      );
      return result ?? false;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(ctx).colorScheme.error,
                  )
                : null,
            onPressed: () {
              if (destructive) HapticFeedback.mediumImpact();
              Navigator.of(ctx).pop(true);
            },
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
