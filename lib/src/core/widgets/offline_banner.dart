import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/media/media_providers.dart';

/// Streams the current connectivity state.
///
/// In modern `connectivity_plus`, `onConnectivityChanged` emits a
/// `List<ConnectivityResult>` (rather than a single result) because a device
/// can be connected via multiple transports simultaneously (e.g. Wi-Fi +
/// mobile). The device is considered offline only when every entry is
/// [ConnectivityResult.none].
final connectivityProvider = StreamProvider<List<ConnectivityResult>>(
  (_) => Connectivity().onConnectivityChanged,
);

/// Slim orange banner that appears at the top of the app while the device is
/// offline. When the connection comes back, any queued photo uploads are
/// flushed automatically.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conn = ref.watch(connectivityProvider).asData?.value;
    final isOffline =
        conn != null && conn.every((r) => r == ConnectivityResult.none);

    // Side-effect: when transitioning from offline -> online, flush queued
    // photo uploads. We compare the previous and next AsyncValue snapshots so
    // that we only fire the flush on an actual transition (not on every tick
    // while online).
    ref.listen<AsyncValue<List<ConnectivityResult>>>(
      connectivityProvider,
      (prev, next) {
        final wasOffline = prev?.asData?.value != null &&
            prev!.asData!.value.every((r) => r == ConnectivityResult.none);
        final nowOnline = next.asData?.value != null &&
            next.asData!.value.any((r) => r != ConnectivityResult.none);
        if (wasOffline && nowOnline) {
          final svc = ref.read(photoUploadServiceProvider);
          svc?.flushQueue();
        }
      },
    );

    if (!isOffline) return const SizedBox.shrink();

    return Material(
      color: Colors.orange.shade700,
      child: const SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Icon(Icons.cloud_off, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Offline — changes will sync when you reconnect',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
