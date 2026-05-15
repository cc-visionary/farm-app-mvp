import 'dart:async';

import 'package:farm_app/src/core/widgets/user_display.dart';
import 'package:farm_app/src/features/farms/application/farm_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows resolved name when provider returns data', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        userDisplayNameProvider('u1')
            .overrideWith((ref) async => 'Juan dela Cruz'),
      ],
      child: const MaterialApp(
        home: Scaffold(body: UserDisplay(userId: 'u1')),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Juan dela Cruz'), findsOneWidget);
  });

  testWidgets('falls back to userId while loading', (tester) async {
    // Completer that never completes within the test, so the provider stays
    // in AsyncLoading and UserDisplay should render the raw userId.
    final pending = Completer<String>();
    addTearDown(() {
      if (!pending.isCompleted) pending.complete('X');
    });

    await tester.pumpWidget(ProviderScope(
      overrides: [
        userDisplayNameProvider('u-pending')
            .overrideWith((ref) => pending.future),
      ],
      child: const MaterialApp(
        home: Scaffold(body: UserDisplay(userId: 'u-pending')),
      ),
    ));
    // Before settle: still loading, so UID falls back.
    expect(find.text('u-pending'), findsOneWidget);
  });
}
