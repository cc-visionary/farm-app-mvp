import 'package:flutter/material.dart';

import 'offline_banner.dart';

/// Wraps a screen with the global offline indicator so every route gets the
/// banner without having to opt-in individually.
///
/// Usage:
/// ```dart
/// AppShell(child: DashboardScreen())
/// ```
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const OfflineBanner(),
        Expanded(child: child),
      ],
    );
  }
}
