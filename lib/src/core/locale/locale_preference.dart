import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistence + parsing helpers for the in-app locale override.
///
/// `null` means "follow the OS locale". Supported codes are `'en'` and
/// `'fil'`; anything else is treated as unset (returns `null`).
///
/// SharedPreferences key: `'app_locale'`.
class LocalePreference {
  LocalePreference._();

  static const _key = 'app_locale';
  static const _supported = {'en', 'fil'};

  /// Reads the persisted locale code. Returns `null` when nothing is stored
  /// or the stored value is not a supported code.
  static String? readLocaleCode(SharedPreferences prefs) {
    final v = prefs.getString(_key);
    if (v == null || !_supported.contains(v)) return null;
    return v;
  }

  /// Writes [code] to SharedPreferences. Passing `null` clears the stored
  /// value (effectively "follow the OS locale").
  static Future<void> writeLocaleCode(
    SharedPreferences prefs,
    String? code,
  ) async {
    if (code == null) {
      await prefs.remove(_key);
      return;
    }
    if (!_supported.contains(code)) {
      throw ArgumentError('Unsupported locale code: $code');
    }
    await prefs.setString(_key, code);
  }

  /// Parses a locale code into a [Locale]. Returns `null` for unknown or
  /// null codes.
  static Locale? localeFromCode(String? code) {
    if (code == null) return null;
    if (!_supported.contains(code)) return null;
    return Locale(code);
  }
}
