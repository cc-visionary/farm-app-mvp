import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/farms/application/farm_providers.dart';

/// Renders a user's display name via [userDisplayNameProvider].
///
/// Falls back to the raw [userId] while the provider is loading or if the
/// lookup fails. Use everywhere a Firebase UID would otherwise leak into the
/// UI (shift chips, task assignment, roster, etc.).
class UserDisplay extends ConsumerWidget {
  const UserDisplay({
    super.key,
    required this.userId,
    this.style,
    this.maxLines,
  });

  final String userId;
  final TextStyle? style;
  final int? maxLines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameAsync = ref.watch(userDisplayNameProvider(userId));
    final text = nameAsync.asData?.value ?? userId;
    return Text(
      text,
      style: style,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
    );
  }
}
