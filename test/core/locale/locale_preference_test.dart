import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:farm_app/src/core/locale/locale_preference.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('readLocaleCode returns null when nothing stored', () async {
    final prefs = await SharedPreferences.getInstance();
    expect(LocalePreference.readLocaleCode(prefs), isNull);
  });

  test('writeLocaleCode + readLocaleCode round-trips', () async {
    final prefs = await SharedPreferences.getInstance();
    await LocalePreference.writeLocaleCode(prefs, 'fil');
    expect(LocalePreference.readLocaleCode(prefs), 'fil');
  });

  test('writeLocaleCode(null) clears the stored value', () async {
    final prefs = await SharedPreferences.getInstance();
    await LocalePreference.writeLocaleCode(prefs, 'en');
    await LocalePreference.writeLocaleCode(prefs, null);
    expect(LocalePreference.readLocaleCode(prefs), isNull);
  });

  test('localeFromCode parses known codes; unknown returns null', () {
    expect(LocalePreference.localeFromCode('en'), const Locale('en'));
    expect(LocalePreference.localeFromCode('fil'), const Locale('fil'));
    expect(LocalePreference.localeFromCode('xyz'), isNull);
    expect(LocalePreference.localeFromCode(null), isNull);
  });
}
