import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/media/media_providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../errors/photo_upload_error.dart';
import 'offline_banner.dart';

/// Wraps a screen with:
///
/// - the global [OfflineBanner] (so every route gets the connectivity hint
///   without having to opt-in individually), and
/// - a Riverpod listener on [photoUploadErrorStreamProvider] that surfaces
///   classified photo-upload errors as a SnackBar. Retryable errors get a
///   reassuring "will retry when online" message; terminal errors include
///   the underlying code so the user can act (e.g. re-auth, free quota).
///
/// Usage:
/// ```dart
/// AppShell(child: DashboardScreen())
/// ```
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    ref.listen<AsyncValue<PhotoUploadError>>(
      photoUploadErrorStreamProvider,
      (prev, next) {
        final err = next.asData?.value;
        if (err == null) return;
        final msg = err.kind == PhotoUploadErrorKind.retryable
            ? l.photo_upload_retry_pending
            : l.photo_upload_terminal(err.code);
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(msg)),
        );
      },
    );
    return Column(
      children: [
        const OfflineBanner(),
        Expanded(child: widget.child),
      ],
    );
  }
}
