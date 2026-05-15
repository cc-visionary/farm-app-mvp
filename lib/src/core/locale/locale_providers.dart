import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'locale_preference.dart';

/// The in-app locale override.
///
/// `null` means "follow OS locale" — `MaterialApp.router` falls back to the
/// device's locale when this is `null`. Default state is read from
/// SharedPreferences via [localePreferenceLoaderProvider] on app start.
final localePreferenceProvider = StateProvider<Locale?>((_) => null);

/// One-shot loader that initializes [localePreferenceProvider] from
/// SharedPreferences on app start. Watch this provider once at startup
/// (e.g. in `MyApp.build`) to trigger the load.
final localePreferenceLoaderProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final code = LocalePreference.readLocaleCode(prefs);
  final loaded = LocalePreference.localeFromCode(code);
  // Avoid an unnecessary state set if already at the default value.
  if (loaded != ref.read(localePreferenceProvider)) {
    ref.read(localePreferenceProvider.notifier).state = loaded;
  }
});

/// Persists a locale change and updates the provider state.
///
/// Pass `null` to clear the override (follow the OS locale).
Future<void> setLocalePreference(WidgetRef ref, Locale? locale) async {
  final prefs = await SharedPreferences.getInstance();
  await LocalePreference.writeLocaleCode(prefs, locale?.languageCode);
  ref.read(localePreferenceProvider.notifier).state = locale;
}
