// lib/src/core/widgets/adaptive_date_picker.dart
//
// Cross-platform date picker helper. Cupertino modal on iOS/macOS,
// Material `showDatePicker` on Android and elsewhere.

import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AdaptiveDatePicker {
  AdaptiveDatePicker._();

  /// Shows a Cupertino modal date picker on iOS, Material `showDatePicker`
  /// on Android. Returns the selected [DateTime] or `null` if cancelled.
  static Future<DateTime?> show({
    required BuildContext context,
    required DateTime initial,
    required DateTime firstDate,
    required DateTime lastDate,
    String? helpText,
  }) {
    if (Platform.isIOS || Platform.isMacOS) {
      return _showCupertino(context, initial, firstDate, lastDate);
    }
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: helpText,
    );
  }

  static Future<DateTime?> _showCupertino(
    BuildContext context,
    DateTime initial,
    DateTime firstDate,
    DateTime lastDate,
  ) async {
    DateTime selected = initial;
    final result = await showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (ctx) => Container(
        height: 320,
        color: CupertinoColors.systemBackground.resolveFrom(ctx),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel'),
                  ),
                  CupertinoButton(
                    onPressed: () => Navigator.of(ctx).pop(selected),
                    child: const Text(
                      'Done',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: initial,
                  minimumDate: firstDate,
                  maximumDate: lastDate,
                  onDateTimeChanged: (d) => selected = d,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return result;
  }
}
