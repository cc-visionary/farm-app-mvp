import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/core/i18n/intl_helpers.dart';
import 'package:farm_app/src/l10n/generated/app_localizations.dart';

Widget _harness({required Locale locale, required WidgetBuilder builder}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('fil')],
    home: Builder(builder: builder),
  );
}

void main() {
  testWidgets('formatCurrencyPhp renders with ₱ and locale separator (en)', (tester) async {
    String? out;
    await tester.pumpWidget(_harness(
      locale: const Locale('en'),
      builder: (ctx) {
        out = formatCurrencyPhp(ctx, 48000);
        return const SizedBox.shrink();
      },
    ));
    expect(out, contains('₱'));
    expect(out, contains('48,000'));
  });

  testWidgets('formatCurrencyPhp renders with ₱ on fil locale', (tester) async {
    String? out;
    await tester.pumpWidget(_harness(
      locale: const Locale('fil'),
      builder: (ctx) {
        out = formatCurrencyPhp(ctx, 48000);
        return const SizedBox.shrink();
      },
    ));
    expect(out, contains('₱'));
    expect(out, contains('48,000'));
  });

  testWidgets('formatMediumDate uses locale month names', (tester) async {
    final dt = DateTime(2026, 5, 15);
    String? en;
    String? fil;
    await tester.pumpWidget(_harness(
      locale: const Locale('en'),
      builder: (ctx) {
        en = formatMediumDate(ctx, dt);
        return const SizedBox.shrink();
      },
    ));
    await tester.pumpWidget(_harness(
      locale: const Locale('fil'),
      builder: (ctx) {
        fil = formatMediumDate(ctx, dt);
        return const SizedBox.shrink();
      },
    ));
    expect(en, contains('May'));
    expect(fil, anyOf(contains('May'), contains('Mayo')));
  });
}
