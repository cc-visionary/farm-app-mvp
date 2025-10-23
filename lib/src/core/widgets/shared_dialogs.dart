// lib/src/core/widgets/shared_dialogs.dart

import 'package:flutter/material.dart';

/// Displays a generic "About App" dialog.
///
/// This function can be called from anywhere in the app that has access
/// to a [BuildContext].
void showAppInfoDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('About Farm App'),
        content: const Text(
          'This is your all-in-one farm management solution! Manage inventory, track animal lifecycles, and monitor farm health with ease.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      );
    },
  );
}