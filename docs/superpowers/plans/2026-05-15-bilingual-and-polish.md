# Bilingual & Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add EN/Filipino bilingual support via `flutter_localizations` + ARB files; close four UX polish gaps deferred from Sub-projects A and B; run a low-end Android performance audit and apply obvious-win fixes.

**Architecture:** Flutter's official i18n toolchain (`gen-l10n`) generates a typed `AppLocalizations` class from ARB files. Locale preference is a Riverpod `StateProvider<Locale?>` backed by `SharedPreferences` with `null` meaning "follow OS." Polish items extend existing repository methods and screens with audit-trail consistency and better error legibility. Perf audit is profile-driven, fix-on-evidence.

**Tech Stack:** No new packages. Reuse existing — `flutter_riverpod`, `flutter_localizations` (SDK), `intl`, `shared_preferences`, `cached_network_image`, `fl_chart`, `fake_cloud_firestore` (dev).

**Spec reference:** `docs/superpowers/specs/2026-05-15-bilingual-and-polish-design.md`. Authoritative for terminology, error taxonomy, and success criteria.

**Required pre-reading:** `CLAUDE.md`, `.impeccable.md`, and the two prior spec docs (`2026-05-14-swine-crm-foundation-design.md`, `2026-05-14-operations-financials-design.md`). Design contract, atomicity contract, role-gating, and the activity-entry-with-every-mutation rule are inherited from there.

---

## Conventions (inherit from prior plans)

- **TDD**: failing test first, then minimal code to pass.
- **Tests** at `test/<mirror-of-lib-path>/<file>_test.dart`.
- **Repository tests** use `fake_cloud_firestore` — no Mockito.
- **Commits**: conventional (`feat:`, `fix:`, `test:`, `refactor:`, `docs:`, `chore:`). Small and focused.
- **Atomicity contract**: every state-changing repository method writes its source record AND the corresponding activity entry (and any derived effects) in a single `WriteBatch` or `runTransaction`.
- **Design contract**: every new screen/widget uses theme tokens (`Theme.of(context).colorScheme.<token>`), shared widgets (`SectionHeader`, `EmptyState`, `StatTile`, `AdaptiveDatePicker`, `ConfirmDialog`, `UserDisplay`), and the iconsax glyph map.
- **Verify before commit**: `flutter analyze` must stay at 0 issues. `flutter test` (140 baseline) must stay green.
- **i18n strings**: every user-visible string in screens / dialogs / SnackBars / app bars goes through `AppLocalizations.of(context).<key>`. ARB key naming: `<feature>_<screen>_<element>` in snake_case.
- **Run `flutter pub get`** after every pubspec change. Run **`flutter gen-l10n`** after every ARB change to regenerate `app_localizations.dart` — actually since `flutter.generate: true` is enabled, `flutter pub get` triggers gen-l10n automatically. Trust the IDE / `flutter analyze` to flag missing keys.

## File structure (delta to Sub-projects A and B)

```
lib/src/
├─ l10n/                          (new)
│   ├─ app_en.arb                  English source
│   ├─ app_fil.arb                 Filipino translations
│   └─ generated/                  flutter_gen output (gitignored)
├─ core/
│   ├─ i18n/                       (new)
│   │   └─ intl_helpers.dart       formatCurrencyPhp(BuildContext, num), formatDate(BuildContext, DateTime)
│   ├─ locale/                     (new)
│   │   ├─ locale_preference.dart  StateProvider<Locale?>, SharedPreferences key 'app_locale'
│   │   └─ locale_providers.dart
│   ├─ errors/                     (new)
│   │   └─ photo_upload_error.dart PhotoUploadError + classify(Object) → PhotoUploadError
│   └─ widgets/
│       └─ user_display.dart       (new) ConsumerWidget wrapping userDisplayNameProvider
└─ features/                       (modified in slices 4–9 + polish slices 11–14)

docs/superpowers/
└─ perf-audit-2026-05-15.md        (new — slice 15)

repo root:
└─ l10n.yaml                       (new — slice 1)
```

Existing files modified:
- `pubspec.yaml` — `flutter_localizations` dep + `flutter.generate: true`
- `analysis_options.yaml` — enable `prefer_const_constructors` (slice 15)
- `lib/main.dart` — `localizationsDelegates`, `supportedLocales`, `locale: ref.watch(localePreferenceProvider)`
- `lib/src/features/settings/presentation/settings_screen.dart` — Language section
- ~30 screen files in slices 4–9 — string extraction
- `lib/src/features/equipment/data/equipment_repository.dart` — atomic `updateEquipment` with activity
- `lib/src/features/pigs/data/pig_repository.dart` — atomic `updatePig` with activity
- `lib/src/features/inventory/data/supply_repository.dart` — atomic `updateSupply` with activity
- `lib/src/features/media/photo_upload_service.dart` — error classification
- `lib/src/features/media/media_providers.dart` — `photoUploadErrorStreamProvider`
- `lib/src/core/widgets/app_shell.dart` — subscribe to error stream, render SnackBar
- `lib/src/features/profitability/presentation/batch_profitability_screen.dart` — pie side legend
- `lib/src/features/shifts/presentation/edit_shift_screen.dart`, `roster_widget.dart`
- `lib/src/features/tasks/presentation/create_task_screen.dart`, `tasks_screen.dart`

---

## Task 1: i18n scaffolding

**Goal:** Wire `flutter_localizations` + `gen-l10n`. Empty-ish ARB files. `MaterialApp` resolves locale. Smoke test with one Hello-world key proves the pipeline works.

**Files:**
- Create: `l10n.yaml`, `lib/src/l10n/app_en.arb`, `lib/src/l10n/app_fil.arb`
- Modify: `pubspec.yaml`, `lib/main.dart`, `.gitignore`

### Steps

- [ ] **Step 1.1: Verify pre-state**

```bash
cd "/home/ccvisionary/Documents/Personal/[01] Ventures/[02] AgriTech/[01] FarmApp"
flutter analyze && flutter test 2>&1 | tail -2
```

Expected: 0 analyze issues, 140 tests pass.

- [ ] **Step 1.2: Add `flutter_localizations` to pubspec.yaml**

Edit `pubspec.yaml`. Inside `dependencies:` block, after `flutter:`, add:

```yaml
  flutter_localizations:
    sdk: flutter
```

Inside the `flutter:` block (the second one, at the bottom of the file), add `generate: true`:

```yaml
flutter:
  uses-material-design: true
  generate: true
```

Run:
```bash
flutter pub get
```

Expected: deps resolve, no errors.

- [ ] **Step 1.3: Create `l10n.yaml` at repo root**

```yaml
arb-dir: lib/src/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
nullable-getter: false
synthetic-package: false
output-dir: lib/src/l10n/generated
```

- [ ] **Step 1.4: Add generated dir to .gitignore**

Append to `.gitignore`:

```
# Generated i18n
lib/src/l10n/generated/
```

- [ ] **Step 1.5: Create `lib/src/l10n/app_en.arb` (initial scaffold)**

```json
{
  "@@locale": "en",
  "app_name": "FarmApp",
  "@app_name": {
    "description": "Application display name."
  }
}
```

- [ ] **Step 1.6: Create `lib/src/l10n/app_fil.arb` (initial scaffold)**

```json
{
  "@@locale": "fil",
  "app_name": "FarmApp"
}
```

(Brand name stays untranslated.)

- [ ] **Step 1.7: Generate localizations**

```bash
flutter pub get
```

This regenerates `lib/src/l10n/generated/app_localizations.dart` (and `app_localizations_en.dart`, `app_localizations_fil.dart`). Verify the files exist:

```bash
ls lib/src/l10n/generated/
```

Expected: 3 files (`app_localizations.dart`, `app_localizations_en.dart`, `app_localizations_fil.dart`).

- [ ] **Step 1.8: Wire `MaterialApp.router` in `lib/main.dart`**

Read the existing `lib/main.dart`. The `MaterialApp.router` constructor needs three additions: `localizationsDelegates`, `supportedLocales`, and (for slice 2, deferred to that task) `locale`.

For slice 1, just add the delegates + supported locales:

```dart
import 'package:farm_app/src/l10n/generated/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// ... existing code ...

return MaterialApp.router(
  // existing args...
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [Locale('en'), Locale('fil')],
);
```

- [ ] **Step 1.9: Smoke test — show app name**

The simplest smoke is no-op: the app should compile and launch in whatever the OS locale resolves to. Run:

```bash
flutter analyze
flutter test
```

Expected: 0 issues, 140 tests pass. (No tests were modified; the i18n pipeline just needs to not break the build.)

- [ ] **Step 1.10: Commit**

```bash
git add -A
git commit -m "feat(i18n): wire flutter_localizations + gen-l10n with EN/FIL scaffold"
```

---

## Task 2: Locale preference + Settings language selector

**Goal:** Persisted `localePreferenceProvider` (StateProvider<Locale?>) — `null` = follow OS. Settings screen shows a Language section with System / English / Filipino choice chips. Changing the value re-renders the whole app.

**Files:**
- Create:
  - `lib/src/core/locale/locale_preference.dart`
  - `lib/src/core/locale/locale_providers.dart`
  - `test/core/locale/locale_preference_test.dart`
- Modify:
  - `lib/main.dart` (wire `locale:` to provider)
  - `lib/src/features/settings/presentation/settings_screen.dart` (add Language section)

### Steps

- [ ] **Step 2.1: Test — LocalePreference persistence**

`test/core/locale/locale_preference_test.dart`:

```dart
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
```

- [ ] **Step 2.2: Implement LocalePreference**

`lib/src/core/locale/locale_preference.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistence + parsing helpers for the in-app locale override.
/// `null` means "follow the OS locale".
class LocalePreference {
  LocalePreference._();

  static const _key = 'app_locale';
  static const _supported = {'en', 'fil'};

  static String? readLocaleCode(SharedPreferences prefs) {
    final v = prefs.getString(_key);
    if (v == null || !_supported.contains(v)) return null;
    return v;
  }

  static Future<void> writeLocaleCode(SharedPreferences prefs, String? code) async {
    if (code == null) {
      await prefs.remove(_key);
      return;
    }
    if (!_supported.contains(code)) {
      throw ArgumentError('Unsupported locale code: $code');
    }
    await prefs.setString(_key, code);
  }

  static Locale? localeFromCode(String? code) {
    if (code == null) return null;
    if (!_supported.contains(code)) return null;
    return Locale(code);
  }
}
```

Run:
```bash
flutter test test/core/locale/locale_preference_test.dart
```
Expected: 4 tests pass.

- [ ] **Step 2.3: Riverpod providers**

`lib/src/core/locale/locale_providers.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'locale_preference.dart';

/// The in-app locale override. `null` means "follow OS locale".
/// Default state is read from SharedPreferences via [localePreferenceLoaderProvider].
final localePreferenceProvider = StateProvider<Locale?>((_) => null);

/// One-shot loader that initializes [localePreferenceProvider] from SharedPreferences
/// on app start. Watch this provider once at startup to trigger the load.
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
Future<void> setLocalePreference(WidgetRef ref, Locale? locale) async {
  final prefs = await SharedPreferences.getInstance();
  await LocalePreference.writeLocaleCode(prefs, locale?.languageCode);
  ref.read(localePreferenceProvider.notifier).state = locale;
}
```

- [ ] **Step 2.4: Wire `locale:` into `MaterialApp.router`**

Edit `lib/main.dart`. Inside the `MaterialApp.router` constructor, add:

```dart
locale: ref.watch(localePreferenceProvider),
```

And ensure the loader runs at app start by watching it once. Add inside the build method (before `return MaterialApp.router`):

```dart
ref.watch(localePreferenceLoaderProvider);
```

Add import:
```dart
import 'package:farm_app/src/core/locale/locale_providers.dart';
```

- [ ] **Step 2.5: Add language strings to ARB files**

Append to `lib/src/l10n/app_en.arb` (inside the existing JSON, before the closing brace):

```json
,
"settings_language_section_title": "LANGUAGE",
"settings_language_choice_system": "System",
"settings_language_choice_english": "English",
"settings_language_choice_filipino": "Filipino"
```

Append to `lib/src/l10n/app_fil.arb`:

```json
,
"settings_language_section_title": "WIKA",
"settings_language_choice_system": "System",
"settings_language_choice_english": "Ingles",
"settings_language_choice_filipino": "Filipino"
```

Run:
```bash
flutter pub get
```

(Regenerates `AppLocalizations`.)

- [ ] **Step 2.6: Settings screen — Language section**

Read the existing `lib/src/features/settings/presentation/settings_screen.dart`. Add a Language section with three `ChoiceChip`s (System / English / Filipino).

Add imports at top:
```dart
import 'package:farm_app/src/core/locale/locale_providers.dart';
import 'package:farm_app/src/core/widgets/section_header.dart';
import 'package:farm_app/src/l10n/generated/app_localizations.dart';
```

Inside the screen's build method, append a section (the existing screen uses a `ListView` or `Column` — match its pattern):

```dart
const SectionHeader(title: 'LANGUAGE'),
Builder(builder: (context) {
  final l = AppLocalizations.of(context);
  final current = ref.watch(localePreferenceProvider);
  return Wrap(spacing: 8, runSpacing: 8, children: [
    ChoiceChip(
      label: Text(l.settings_language_choice_system),
      selected: current == null,
      onSelected: (_) => setLocalePreference(ref, null),
    ),
    ChoiceChip(
      label: Text(l.settings_language_choice_english),
      selected: current?.languageCode == 'en',
      onSelected: (_) => setLocalePreference(ref, const Locale('en')),
    ),
    ChoiceChip(
      label: Text(l.settings_language_choice_filipino),
      selected: current?.languageCode == 'fil',
      onSelected: (_) => setLocalePreference(ref, const Locale('fil')),
    ),
  ]);
}),
```

Note: the `SectionHeader` already uppercases its `title`, but for new keys we'll keep both layers consistent for now — the section header reads "LANGUAGE" in code, and the ARB key is `settings_language_section_title` which is also "LANGUAGE" in EN and "WIKA" in FIL. To use the localized header text instead, replace the hardcoded `'LANGUAGE'` with `AppLocalizations.of(context).settings_language_section_title` and remove the SectionHeader's internal `.toUpperCase()` for that one call — actually SectionHeader always uppercases. Simpler: leave the section header literal as "LANGUAGE" for now; localize in slice 9 polish.

Actually, to keep this slice clean, do this: pass the localized string TO SectionHeader (it will uppercase it):

```dart
SectionHeader(title: l.settings_language_section_title),
```

Both EN and FIL keys are already uppercase so this works.

- [ ] **Step 2.7: Run + smoke test**

```bash
flutter analyze
flutter test
```
Expected: 0 issues, 140 tests pass + 4 new = 144.

Manual: launch app, navigate to Settings, see the Language section. Tap Filipino — the chip selects and the language header changes to "WIKA". Restart the app — Filipino persists.

- [ ] **Step 2.8: Commit**

```bash
git add -A
git commit -m "feat(i18n,settings): locale preference provider + Settings language selector

- StateProvider<Locale?> backed by SharedPreferences ('app_locale' key)
- null = follow OS; explicit en/fil = override
- Settings screen Language section with System / English / Filipino chips
- App restart preserves the selection"
```

---

## Task 3: Common strings + intl helpers

**Goal:** Extract the most-used "common" strings (Save, Cancel, Back, Loading, Yes, No, Confirm, Delete, Required field, plural pig count, etc.) into ARB files. Build `intl_helpers.dart` with locale-aware currency/date formatters that all later slices use.

**Files:**
- Modify: `lib/src/l10n/app_en.arb`, `lib/src/l10n/app_fil.arb`
- Create:
  - `lib/src/core/i18n/intl_helpers.dart`
  - `test/core/i18n/intl_helpers_test.dart`

### Steps

- [ ] **Step 3.1: Common keys → `app_en.arb`**

Replace the entire content of `lib/src/l10n/app_en.arb` with:

```json
{
  "@@locale": "en",

  "app_name": "FarmApp",
  "@app_name": {"description": "Application display name."},

  "common_save": "Save",
  "common_save_changes": "Save changes",
  "common_cancel": "Cancel",
  "common_back": "Back",
  "common_done": "Done",
  "common_confirm": "Confirm",
  "common_delete": "Delete",
  "common_remove": "Remove",
  "common_edit": "Edit",
  "common_loading": "Loading…",
  "common_yes": "Yes",
  "common_no": "No",
  "common_optional": "Optional",
  "common_notes": "Notes",
  "common_date": "Date",
  "common_total": "Total",
  "common_search": "Search",
  "common_filter": "Filter",
  "common_close": "Close",
  "common_retry": "Retry",
  "common_sign_out": "Sign out",
  "common_required_field": "This field is required.",
  "common_required_field_named": "{field} is required.",
  "@common_required_field_named": {
    "placeholders": {"field": {"type": "String", "example": "Buyer name"}}
  },
  "common_invalid_number": "Must be a number.",
  "common_must_be_positive": "Must be a positive number.",
  "common_must_be_positive_int": "Must be a positive whole number.",
  "common_pigs_count": "{count,plural, =0{No pigs} =1{1 pig} other{{count} pigs}}",
  "@common_pigs_count": {
    "placeholders": {"count": {"type": "int"}}
  },
  "common_heads_count": "{count,plural, =0{No heads} =1{1 head} other{{count} heads}}",
  "@common_heads_count": {
    "placeholders": {"count": {"type": "int"}}
  },

  "settings_language_section_title": "LANGUAGE",
  "settings_language_choice_system": "System",
  "settings_language_choice_english": "English",
  "settings_language_choice_filipino": "Filipino"
}
```

- [ ] **Step 3.2: Common keys → `app_fil.arb`**

Replace the entire content of `lib/src/l10n/app_fil.arb` with:

```json
{
  "@@locale": "fil",

  "app_name": "FarmApp",

  "common_save": "I-save",
  "common_save_changes": "I-save ang mga pagbabago",
  "common_cancel": "Kanselahin",
  "common_back": "Bumalik",
  "common_done": "Tapos",
  "common_confirm": "Kumpirmahin",
  "common_delete": "Burahin",
  "common_remove": "Tanggalin",
  "common_edit": "I-edit",
  "common_loading": "Naglo-load…",
  "common_yes": "Oo",
  "common_no": "Hindi",
  "common_optional": "Opsyonal",
  "common_notes": "Mga tala",
  "common_date": "Petsa",
  "common_total": "Kabuuan",
  "common_search": "Maghanap",
  "common_filter": "Salain",
  "common_close": "Isara",
  "common_retry": "Subukang muli",
  "common_sign_out": "Mag-sign out",
  "common_required_field": "Kailangan ang field na ito.",
  "common_required_field_named": "Kailangan ang {field}.",
  "common_invalid_number": "Dapat ay numero.",
  "common_must_be_positive": "Dapat positibo ang numero.",
  "common_must_be_positive_int": "Dapat positibong buong numero.",
  "common_pigs_count": "{count,plural, =0{Walang baboy} =1{1 baboy} other{{count} baboy}}",
  "common_heads_count": "{count,plural, =0{Walang ulo} =1{1 ulo} other{{count} ulo}}",

  "settings_language_section_title": "WIKA",
  "settings_language_choice_system": "System",
  "settings_language_choice_english": "Ingles",
  "settings_language_choice_filipino": "Filipino"
}
```

Run:
```bash
flutter pub get
```

- [ ] **Step 3.3: Test — intl_helpers**

`test/core/i18n/intl_helpers_test.dart`:

```dart
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
    expect(fil, contains('May') | contains('Mayo'));
  });
}
```

- [ ] **Step 3.4: Implement intl_helpers**

`lib/src/core/i18n/intl_helpers.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Formats a PHP amount with ₱ symbol and the current locale's separator.
/// Pass via [BuildContext] so we read the current locale; no decimals in v1.
String formatCurrencyPhp(BuildContext context, num amount) {
  final locale = Localizations.localeOf(context).toString();
  final f = NumberFormat.currency(locale: locale, symbol: '₱', decimalDigits: 0);
  return f.format(amount);
}

/// Formats a date in medium form ("May 15, 2026" / "Mayo 15, 2026").
String formatMediumDate(BuildContext context, DateTime dt) {
  final locale = Localizations.localeOf(context).toString();
  return DateFormat.yMMMd(locale).format(dt);
}

/// Formats a time in jm form ("4:30 PM" / "4:30 PM" — `intl` uses
/// the same skeleton in fil; localized AM/PM may differ slightly).
String formatJm(BuildContext context, DateTime dt) {
  final locale = Localizations.localeOf(context).toString();
  return DateFormat.jm(locale).format(dt);
}

/// Decimal number formatter respecting locale separators.
String formatDecimal(BuildContext context, num value) {
  final locale = Localizations.localeOf(context).toString();
  return NumberFormat.decimalPattern(locale).format(value);
}
```

Run tests:
```bash
flutter test test/core/i18n/intl_helpers_test.dart
```
Expected: 3 tests pass.

- [ ] **Step 3.5: Commit**

```bash
git add -A
git commit -m "feat(i18n): common ARB keys (~30) + intl helpers for currency/date

- Common strings: Save, Cancel, Back, plural pig/head counts, validation
- Filipino translations: I-save, Kanselahin, baboy, etc.
- intl_helpers.dart: formatCurrencyPhp/formatMediumDate/formatJm/formatDecimal
- All read Localizations.localeOf(context) so locale changes propagate"
```

---

## Task 4: String migration — auth & farm setup

**Goal:** Extract user-visible strings from auth (login, signup) and farm-setup screens (create farm, accept invitation, farm setup dispatcher). Add corresponding keys to both ARB files.

**Files:**
- Modify:
  - `lib/src/l10n/app_en.arb`, `lib/src/l10n/app_fil.arb`
  - `lib/src/features/authentication/presentation/login_screen.dart`
  - `lib/src/features/authentication/presentation/signup_screen.dart`
  - `lib/src/features/farms/presentation/create_farm_screen.dart`
  - `lib/src/features/farms/presentation/farm_setup_screen.dart`
  - `lib/src/features/team/presentation/accept_invitation_screen.dart`

### Steps

- [ ] **Step 4.1: Inventory the strings to extract**

Open each of the 5 files. Make a list of every hardcoded string visible to the user. Typical hits (one per file):

- login_screen.dart: "Welcome to FarmApp", "Sign in to your farm", email/password labels, "Sign in" button, "Don't have an account? Sign up", error messages
- signup_screen.dart: "Create your account", email/password labels, "Create account" button, "Already have an account? Sign in"
- create_farm_screen.dart: "Welcome — set up your farm", display name + farm name labels, "Create farm" button
- farm_setup_screen.dart: any loading text (mostly delegates to children)
- accept_invitation_screen.dart: "You're invited", "Accept" button, role labels

- [ ] **Step 4.2: Add auth + setup keys to `app_en.arb`**

Append the following before the closing `}` of `app_en.arb`:

```json
,
"auth_login_title": "Welcome to FarmApp",
"auth_login_subtitle": "Sign in to your farm",
"auth_login_email_label": "Email",
"auth_login_password_label": "Password",
"auth_login_submit": "Sign in",
"auth_login_no_account_cta": "Create an account",
"auth_login_error_invalid_credentials": "Invalid email or password.",
"auth_login_error_generic": "An error occurred. Please try again.",

"auth_signup_title": "Create your account",
"auth_signup_email_label": "Email",
"auth_signup_password_label": "Password",
"auth_signup_submit": "Create account",
"auth_signup_have_account_cta": "I already have an account",
"auth_signup_error_weak_password": "The password provided is too weak.",
"auth_signup_error_email_in_use": "An account already exists for that email.",
"auth_signup_error_invalid_email": "The email address is not valid.",

"farm_setup_create_title": "Welcome — set up your farm",
"farm_setup_create_display_name_label": "Display name",
"farm_setup_create_farm_name_label": "Farm name",
"farm_setup_create_submit": "Create farm",
"farm_setup_both_fields_required": "Both fields are required.",

"invitation_accept_title": "You're invited",
"invitation_accept_role_label": "Role: {role}",
"@invitation_accept_role_label": {
  "placeholders": {"role": {"type": "String"}}
},
"invitation_accept_button": "Accept",
"invitation_role_manager": "Manager",
"invitation_role_worker": "Worker",
"invitation_role_vet": "Veterinarian"
```

- [ ] **Step 4.3: Add the same keys to `app_fil.arb` with translations**

Append:

```json
,
"auth_login_title": "Maligayang pagdating sa FarmApp",
"auth_login_subtitle": "Mag-sign in sa iyong farm",
"auth_login_email_label": "Email",
"auth_login_password_label": "Password",
"auth_login_submit": "Mag-sign in",
"auth_login_no_account_cta": "Gumawa ng account",
"auth_login_error_invalid_credentials": "Mali ang email o password.",
"auth_login_error_generic": "May naganap na error. Pakisubukang muli.",

"auth_signup_title": "Gumawa ng account",
"auth_signup_email_label": "Email",
"auth_signup_password_label": "Password",
"auth_signup_submit": "Gumawa ng account",
"auth_signup_have_account_cta": "May account na ako",
"auth_signup_error_weak_password": "Masyadong mahina ang password.",
"auth_signup_error_email_in_use": "May account na sa email na iyan.",
"auth_signup_error_invalid_email": "Hindi wasto ang email address.",

"farm_setup_create_title": "Maligayang pagdating — i-setup ang iyong farm",
"farm_setup_create_display_name_label": "Iyong pangalan",
"farm_setup_create_farm_name_label": "Pangalan ng farm",
"farm_setup_create_submit": "Gumawa ng farm",
"farm_setup_both_fields_required": "Kailangan ang dalawang field.",

"invitation_accept_title": "Naimbitahan ka",
"invitation_accept_role_label": "Tungkulin: {role}",
"invitation_accept_button": "Tanggapin",
"invitation_role_manager": "Manager",
"invitation_role_worker": "Manggagawa",
"invitation_role_vet": "Beterinaryo"
```

Run `flutter pub get` to regen.

- [ ] **Step 4.4: Edit `login_screen.dart` to use AppLocalizations**

Read `lib/src/features/authentication/presentation/login_screen.dart`. Find every hardcoded user-visible string and replace with `AppLocalizations.of(context).<key>`. Pattern:

```dart
// At top of file
import 'package:farm_app/src/l10n/generated/app_localizations.dart';

// Inside build (or any method with BuildContext access)
final l = AppLocalizations.of(context);
// Replace
Text('Welcome to FarmApp')
// With
Text(l.auth_login_title)
```

Apply across the whole screen — title, subtitle, field labels, button text, error fallback text, etc.

For error messages thrown from `AuthRepository`: the repository throws `Exception('Invalid email or password.')` etc. The catch site in the screen should map known patterns to localized strings. Keep the repository exception strings as-is (English fallbacks for tests) but show localized strings in the UI:

```dart
} catch (e) {
  final raw = e.toString();
  String message;
  if (raw.contains('Invalid email or password')) {
    message = l.auth_login_error_invalid_credentials;
  } else if (raw.contains('weak-password')) {
    message = l.auth_signup_error_weak_password;
  } else {
    message = l.auth_login_error_generic;
  }
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
```

(Imperfect string-matching, but acceptable for v1. A future polish round can introduce typed exceptions.)

- [ ] **Step 4.5: Edit `signup_screen.dart`**

Same pattern. Replace all hardcoded user-visible strings.

- [ ] **Step 4.6: Edit `create_farm_screen.dart`**

Same pattern. Note: the validation error "Both fields are required." should use `l.farm_setup_both_fields_required`.

- [ ] **Step 4.7: Edit `accept_invitation_screen.dart`**

Same pattern. The role labels: replace the existing `Text('Role: ${inv.role.value}')` with:

```dart
Text(l.invitation_accept_role_label(_roleLabel(l, inv.role.value)))
```

Where `_roleLabel` is a local helper:

```dart
String _roleLabel(AppLocalizations l, String roleValue) {
  switch (roleValue) {
    case 'manager': return l.invitation_role_manager;
    case 'worker': return l.invitation_role_worker;
    case 'vet': return l.invitation_role_vet;
    default: return roleValue;
  }
}
```

- [ ] **Step 4.8: farm_setup_screen.dart**

This screen is mostly a dispatcher. The only user-visible string is the loading indicator (no text) — no extraction needed. Add the import for consistency in case future strings appear here, but no code changes.

- [ ] **Step 4.9: Run + commit**

```bash
flutter analyze
flutter test
```
Expected: 0 issues, 147 tests pass (140 baseline + 4 locale + 3 intl helpers).

```bash
git add -A
git commit -m "feat(i18n): extract auth + farm setup strings to ARB

- Login, signup, create farm, accept invitation screens use AppLocalizations
- Role labels (Manager/Worker/Veterinarian) localized
- Filipino translations: 'Maligayang pagdating', 'Tungkulin: Worker', etc.
- Error mapping in catch blocks routes known patterns to localized strings"
```

---

## Task 5: String migration — pigs

**Goal:** Extract strings from the pigs feature (largest feature in the app): pigs list, pig detail (4 tabs), add/edit pig, and 4 log screens (breeding, farrowing, health, mortality).

**Files:**
- Modify: `app_en.arb`, `app_fil.arb`, and 8 screen files under `lib/src/features/pigs/presentation/`.

### Steps

- [ ] **Step 5.1: Append pigs keys to `app_en.arb`**

Append before closing brace:

```json
,
"pigs_list_title": "Pigs",
"pigs_list_search_hint": "Search by tag ID",
"pigs_list_filter_my_areas": "My areas only",
"pigs_list_filter_show_inactive": "Show inactive",
"pigs_list_empty_title": "No pigs yet",
"pigs_list_empty_subtitle": "Tap + to add your first pig.",
"pigs_list_no_match_title": "No pigs match",
"pigs_list_no_match_subtitle": "Try clearing filters.",
"pigs_list_fab_add": "Add pig",
"pigs_list_section_with_count": "{stage} · {count}",
"@pigs_list_section_with_count": {
  "placeholders": {"stage": {"type": "String"}, "count": {"type": "int"}}
},

"pig_stage_suckling": "Suckling",
"pig_stage_weaner": "Weaner",
"pig_stage_grower": "Grower",
"pig_stage_finisher": "Finisher",
"pig_stage_gilt": "Gilt",
"pig_stage_sow": "Sow",
"pig_stage_boar": "Boar",
"pig_sex_male": "Male",
"pig_sex_female": "Female",
"pig_status_active": "Active",
"pig_status_sold": "Sold",
"pig_status_culled": "Culled",
"pig_status_deceased": "Deceased",

"pig_age_years": "{n} yr",
"@pig_age_years": {"placeholders": {"n": {"type": "int"}}},
"pig_age_months": "{n} mo",
"@pig_age_months": {"placeholders": {"n": {"type": "int"}}},
"pig_age_weeks": "{n} wk",
"@pig_age_weeks": {"placeholders": {"n": {"type": "int"}}},
"pig_age_days": "{n} d",
"@pig_age_days": {"placeholders": {"n": {"type": "int"}}},

"pig_detail_tab_profile": "Profile",
"pig_detail_tab_breeding": "Breeding",
"pig_detail_tab_health": "Health",
"pig_detail_tab_lineage": "Lineage",
"pig_detail_profile_tag_id": "Tag ID",
"pig_detail_profile_sex": "Sex",
"pig_detail_profile_breed": "Breed",
"pig_detail_profile_stage": "Stage",
"pig_detail_profile_status": "Status",
"pig_detail_profile_born": "Born",
"pig_detail_profile_age": "Age",
"pig_detail_profile_current_weight": "Current weight",
"pig_detail_profile_area": "Area",
"pig_detail_profile_pen": "Pen",
"pig_detail_profile_notes": "Notes",
"pig_detail_profile_mark_deceased": "Mark deceased",
"pig_detail_profile_mark_deceased_confirm_title": "Mark deceased",
"pig_detail_profile_mark_deceased_confirm_body": "Mark {tagId} as deceased? This cannot be undone.",
"@pig_detail_profile_mark_deceased_confirm_body": {
  "placeholders": {"tagId": {"type": "String"}}
},
"pig_detail_breeding_not_applicable": "Breeding only applies to sows and gilts.",
"pig_detail_breeding_no_records": "No breeding records yet.",
"pig_detail_breeding_fab_log": "Log breeding",
"pig_detail_breeding_action_pregnancy_check": "Log pregnancy check",
"pig_detail_breeding_action_farrow": "Log farrowing",
"pig_detail_health_no_records": "No health records yet.",
"pig_detail_health_fab_log": "Log health",
"pig_detail_lineage_sire": "Sire",
"pig_detail_lineage_dam": "Dam",
"pig_detail_lineage_unknown": "Unknown",
"pig_detail_lineage_not_in_farm": "Not in this farm",
"pig_detail_sold_banner_title": "Sold",
"pig_detail_sold_banner_subtitle": "{date} · {buyer}",
"@pig_detail_sold_banner_subtitle": {
  "placeholders": {"date": {"type": "String"}, "buyer": {"type": "String"}}
},

"pig_add_title": "Add pig",
"pig_edit_title": "Edit pig",
"pig_form_section_photo": "PHOTO",
"pig_form_section_basic_info": "BASIC INFO",
"pig_form_section_location": "LOCATION",
"pig_form_section_weight": "WEIGHT",
"pig_form_section_lineage": "LINEAGE",
"pig_form_section_notes": "NOTES",
"pig_form_label_tag_id": "Tag ID",
"pig_form_label_breed": "Breed",
"pig_form_label_birth_date": "Birth date",
"pig_form_label_area": "Area",
"pig_form_label_pen": "Pen (optional)",
"pig_form_label_weight_kg": "Weight (kg, optional)",
"pig_form_label_sire": "Sire (optional)",
"pig_form_label_dam": "Dam (optional)",
"pig_form_pen_none": "— none —",
"pig_form_parent_unknown": "— unknown —",
"pig_form_save_add": "Add pig",
"pig_form_save_edit": "Save changes",
"pig_form_validation_tag_required": "Tag ID is required.",
"pig_form_validation_breed_required": "Breed is required.",
"pig_form_validation_birth_required": "Birth date is required.",
"pig_form_validation_area_required": "Area is required.",
"pig_form_photo_add": "Add photo",
"pig_form_photo_change": "Change photo",

"breeding_method_natural": "Natural",
"breeding_method_ai": "AI",
"breeding_status_planned": "Planned",
"breeding_status_confirmed": "Confirmed pregnant",
"breeding_status_farrowed": "Farrowed",
"breeding_status_failed": "Failed",
"breeding_status_aborted": "Aborted",
"breeding_log_title": "Log breeding · {tagId}",
"@breeding_log_title": {"placeholders": {"tagId": {"type": "String"}}},
"breeding_log_heat_date_label": "Heat observed (optional)",
"breeding_log_heat_date_unset": "—",
"breeding_log_insemination_date_label": "Insemination date",
"breeding_log_boar_label": "Boar",
"breeding_log_boar_required": "Select a boar.",
"breeding_log_expected_label": "Expected farrowing: {date}",
"@breeding_log_expected_label": {"placeholders": {"date": {"type": "String"}}},
"breeding_log_submit": "Save breeding",
"breeding_pregnancy_check_dialog_title": "Pregnancy check",
"breeding_pregnancy_check_dialog_body": "Was the sow confirmed pregnant?",
"breeding_pregnancy_check_no": "No / Failed",
"breeding_pregnancy_check_yes": "Yes / Confirmed",

"farrowing_log_title": "Farrowing · {tagId}",
"@farrowing_log_title": {"placeholders": {"tagId": {"type": "String"}}},
"farrowing_log_date_label": "Farrowing date",
"farrowing_log_live_label": "Live born",
"farrowing_log_still_label": "Stillborn",
"farrowing_log_mumm_label": "Mummified",
"farrowing_log_avg_weight_label": "Avg birth weight (kg, optional)",
"farrowing_log_create_batch_title": "Create litter batch",
"farrowing_log_create_batch_subtitle": "Tracks the piglets as a group",
"farrowing_log_submit": "Save farrowing",
"farrowing_log_live_required": "Live born required.",

"health_event_type_vaccination": "Vaccination",
"health_event_type_treatment": "Treatment",
"health_event_type_checkup": "Checkup",
"health_event_type_deworming": "Deworming",
"health_route_oral": "Oral",
"health_route_im": "IM (intramuscular)",
"health_route_sc": "SC (subcutaneous)",
"health_route_topical": "Topical",
"health_log_title": "Log health · {tagId}",
"@health_log_title": {"placeholders": {"tagId": {"type": "String"}}},
"health_log_product_label": "Product (e.g., PRRS vaccine)",
"health_log_dosage_label": "Dosage",
"health_log_route_label": "Route",
"health_log_diagnosis_label": "Diagnosis",
"health_log_withdrawal_days_label": "Withdrawal period (days, optional)",
"health_log_cost_label": "Cost (PHP, optional)",
"health_log_photos_section": "Photos",
"health_log_submit": "Save health record",
"health_record_withdrawal_until": "Withdrawal until: {date}",
"@health_record_withdrawal_until": {"placeholders": {"date": {"type": "String"}}},

"mortality_log_title": "Mortality · {tagId}",
"@mortality_log_title": {"placeholders": {"tagId": {"type": "String"}}},
"mortality_log_cause_label": "Cause",
"mortality_log_cause_respiratory": "Respiratory",
"mortality_log_cause_digestive": "Digestive",
"mortality_log_cause_accident": "Accident",
"mortality_log_cause_unknown": "Unknown",
"mortality_log_cause_asf": "ASF-suspected",
"mortality_log_cause_other": "Other",
"mortality_log_photos_section": "Photos (optional)",
"mortality_log_submit": "Mark deceased",
"mortality_log_confirm_title": "Confirm mortality",
"mortality_log_confirm_body": "Mark {tagId} as deceased? This cannot be undone.",
"@mortality_log_confirm_body": {"placeholders": {"tagId": {"type": "String"}}}
```

- [ ] **Step 5.2: Append pigs keys to `app_fil.arb`**

Append matching translations. Snippet (apply pattern for the rest):

```json
,
"pigs_list_title": "Mga Baboy",
"pigs_list_search_hint": "Maghanap ayon sa tag ID",
"pigs_list_filter_my_areas": "Mga assigned area ko lang",
"pigs_list_filter_show_inactive": "Ipakita ang inactive",
"pigs_list_empty_title": "Wala pang baboy",
"pigs_list_empty_subtitle": "I-tap ang + para magdagdag ng iyong unang baboy.",
"pigs_list_no_match_title": "Walang nakitang baboy",
"pigs_list_no_match_subtitle": "Subukang alisin ang mga filter.",
"pigs_list_fab_add": "Magdagdag ng baboy",
"pigs_list_section_with_count": "{stage} · {count}",

"pig_stage_suckling": "Suckling",
"pig_stage_weaner": "Weaner",
"pig_stage_grower": "Grower",
"pig_stage_finisher": "Finisher",
"pig_stage_gilt": "Dumalaga",
"pig_stage_sow": "Inahin",
"pig_stage_boar": "Bulugan",
"pig_sex_male": "Lalaki",
"pig_sex_female": "Babae",
"pig_status_active": "Aktibo",
"pig_status_sold": "Naibenta",
"pig_status_culled": "Inalis",
"pig_status_deceased": "Patay",

"pig_age_years": "{n} taon",
"pig_age_months": "{n} buwan",
"pig_age_weeks": "{n} linggo",
"pig_age_days": "{n} araw",

"pig_detail_tab_profile": "Profile",
"pig_detail_tab_breeding": "Pagpapalahi",
"pig_detail_tab_health": "Kalusugan",
"pig_detail_tab_lineage": "Lahi",
"pig_detail_profile_tag_id": "Tag ID",
"pig_detail_profile_sex": "Kasarian",
"pig_detail_profile_breed": "Lahi",
"pig_detail_profile_stage": "Yugto",
"pig_detail_profile_status": "Status",
"pig_detail_profile_born": "Ipinanganak",
"pig_detail_profile_age": "Edad",
"pig_detail_profile_current_weight": "Kasalukuyang bigat",
"pig_detail_profile_area": "Lugar",
"pig_detail_profile_pen": "Kulungan",
"pig_detail_profile_notes": "Mga tala",
"pig_detail_profile_mark_deceased": "Markahan na patay",
"pig_detail_profile_mark_deceased_confirm_title": "Markahan na patay",
"pig_detail_profile_mark_deceased_confirm_body": "Markahan ang {tagId} na patay? Hindi na ito mababawi.",
"pig_detail_breeding_not_applicable": "Para lang sa inahin at dumalaga ang pagpapalahi.",
"pig_detail_breeding_no_records": "Wala pang breeding record.",
"pig_detail_breeding_fab_log": "I-log ang pagpapalahi",
"pig_detail_breeding_action_pregnancy_check": "I-log ang pregnancy check",
"pig_detail_breeding_action_farrow": "I-log ang panganganak",
"pig_detail_health_no_records": "Wala pang health record.",
"pig_detail_health_fab_log": "I-log ang kalusugan",
"pig_detail_lineage_sire": "Ama (bulugan)",
"pig_detail_lineage_dam": "Ina (inahin)",
"pig_detail_lineage_unknown": "Hindi alam",
"pig_detail_lineage_not_in_farm": "Wala sa farm na ito",
"pig_detail_sold_banner_title": "Naibenta",
"pig_detail_sold_banner_subtitle": "{date} · {buyer}",

"pig_add_title": "Magdagdag ng baboy",
"pig_edit_title": "I-edit ang baboy",
"pig_form_section_photo": "LARAWAN",
"pig_form_section_basic_info": "PANGUNAHING IMPORMASYON",
"pig_form_section_location": "LOKASYON",
"pig_form_section_weight": "BIGAT",
"pig_form_section_lineage": "LAHI",
"pig_form_section_notes": "MGA TALA",
"pig_form_label_tag_id": "Tag ID",
"pig_form_label_breed": "Lahi",
"pig_form_label_birth_date": "Petsa ng kapanganakan",
"pig_form_label_area": "Lugar",
"pig_form_label_pen": "Kulungan (opsyonal)",
"pig_form_label_weight_kg": "Bigat (kg, opsyonal)",
"pig_form_label_sire": "Ama (opsyonal)",
"pig_form_label_dam": "Ina (opsyonal)",
"pig_form_pen_none": "— wala —",
"pig_form_parent_unknown": "— hindi alam —",
"pig_form_save_add": "Magdagdag ng baboy",
"pig_form_save_edit": "I-save ang mga pagbabago",
"pig_form_validation_tag_required": "Kailangan ang Tag ID.",
"pig_form_validation_breed_required": "Kailangan ang lahi.",
"pig_form_validation_birth_required": "Kailangan ang petsa ng kapanganakan.",
"pig_form_validation_area_required": "Kailangan ang lugar.",
"pig_form_photo_add": "Magdagdag ng larawan",
"pig_form_photo_change": "Palitan ang larawan",

"breeding_method_natural": "Natural",
"breeding_method_ai": "AI",
"breeding_status_planned": "Nakaplano",
"breeding_status_confirmed": "Buntis (kumpirmado)",
"breeding_status_farrowed": "Nanganak na",
"breeding_status_failed": "Hindi nangyari",
"breeding_status_aborted": "Nakunan",
"breeding_log_title": "I-log ang pagpapalahi · {tagId}",
"breeding_log_heat_date_label": "Naobserbahang heat (opsyonal)",
"breeding_log_heat_date_unset": "—",
"breeding_log_insemination_date_label": "Petsa ng pagpapaalaga",
"breeding_log_boar_label": "Bulugan",
"breeding_log_boar_required": "Pumili ng bulugan.",
"breeding_log_expected_label": "Inaasahang panganganak: {date}",
"breeding_log_submit": "I-save ang breeding",
"breeding_pregnancy_check_dialog_title": "Pregnancy check",
"breeding_pregnancy_check_dialog_body": "Nakumpirma bang buntis ang inahin?",
"breeding_pregnancy_check_no": "Hindi / Nabigo",
"breeding_pregnancy_check_yes": "Oo / Buntis",

"farrowing_log_title": "Panganganak · {tagId}",
"farrowing_log_date_label": "Petsa ng panganganak",
"farrowing_log_live_label": "Bilang ng buhay",
"farrowing_log_still_label": "Patay nang ipinanganak",
"farrowing_log_mumm_label": "Mummified",
"farrowing_log_avg_weight_label": "Avg birth weight (kg, opsyonal)",
"farrowing_log_create_batch_title": "Gumawa ng litter batch",
"farrowing_log_create_batch_subtitle": "Para masubaybayan ang mga biik bilang grupo",
"farrowing_log_submit": "I-save ang panganganak",
"farrowing_log_live_required": "Kailangan ang bilang ng buhay.",

"health_event_type_vaccination": "Bakuna",
"health_event_type_treatment": "Paggamot",
"health_event_type_checkup": "Checkup",
"health_event_type_deworming": "Deworming",
"health_route_oral": "Pinapainom",
"health_route_im": "IM (intramuscular)",
"health_route_sc": "SC (subcutaneous)",
"health_route_topical": "Pamahid",
"health_log_title": "I-log ang kalusugan · {tagId}",
"health_log_product_label": "Produkto (hal., PRRS vaccine)",
"health_log_dosage_label": "Dosage",
"health_log_route_label": "Daan",
"health_log_diagnosis_label": "Diagnosis",
"health_log_withdrawal_days_label": "Withdrawal period (araw, opsyonal)",
"health_log_cost_label": "Halaga (PHP, opsyonal)",
"health_log_photos_section": "Mga larawan",
"health_log_submit": "I-save ang health record",
"health_record_withdrawal_until": "Withdrawal hanggang: {date}",

"mortality_log_title": "Kamatayan · {tagId}",
"mortality_log_cause_label": "Sanhi",
"mortality_log_cause_respiratory": "Respiratory",
"mortality_log_cause_digestive": "Digestive",
"mortality_log_cause_accident": "Aksidente",
"mortality_log_cause_unknown": "Hindi alam",
"mortality_log_cause_asf": "Pinaghihinalaang ASF",
"mortality_log_cause_other": "Iba pa",
"mortality_log_photos_section": "Mga larawan (opsyonal)",
"mortality_log_submit": "Markahan na patay",
"mortality_log_confirm_title": "Kumpirmahin ang kamatayan",
"mortality_log_confirm_body": "Markahan ang {tagId} na patay? Hindi na ito mababawi."
```

Run `flutter pub get`.

- [ ] **Step 5.3: Migrate pigs_list_screen.dart**

Edit `lib/src/features/pigs/presentation/pigs_list_screen.dart`. Replace every hardcoded user-visible string with `AppLocalizations.of(context).<key>`. Use the local helper pattern:

```dart
final l = AppLocalizations.of(context);
```

Specifically:
- AppBar title: `Text(l.pigs_list_title)`
- Search hint: `hintText: l.pigs_list_search_hint`
- "My areas only" toggle label: `l.pigs_list_filter_my_areas`
- Show inactive icon tooltip: `l.pigs_list_filter_show_inactive`
- Empty state title/subtitle for both branches (no pigs / no matches).
- FAB extended label: `l.pigs_list_fab_add`.

For the stage chips (filter chips for each `PigStage.label`), and the section headers within the list ("Sow · 3"), use the new `pig_stage_*` and `pigs_list_section_with_count` keys.

To convert a `PigStage` to its localized label, add a helper at the bottom of the file (or in `pig.dart` extension):

```dart
String localizedPigStage(AppLocalizations l, PigStage s) {
  switch (s) {
    case PigStage.suckling: return l.pig_stage_suckling;
    case PigStage.weaner: return l.pig_stage_weaner;
    case PigStage.grower: return l.pig_stage_grower;
    case PigStage.finisher: return l.pig_stage_finisher;
    case PigStage.gilt: return l.pig_stage_gilt;
    case PigStage.sow: return l.pig_stage_sow;
    case PigStage.boar: return l.pig_stage_boar;
  }
}

String localizedPigSex(AppLocalizations l, PigSex s) =>
    s == PigSex.female ? l.pig_sex_female : l.pig_sex_male;

String localizedPigStatus(AppLocalizations l, PigStatus s) {
  switch (s) {
    case PigStatus.active: return l.pig_status_active;
    case PigStatus.sold: return l.pig_status_sold;
    case PigStatus.culled: return l.pig_status_culled;
    case PigStatus.deceased: return l.pig_status_deceased;
  }
}
```

Place these as **top-level functions** in `lib/src/features/pigs/domain/pig.dart` (or a sibling `pig_l10n.dart`). They can be imported by every pigs screen.

For age string ("1 yr / 12 mo / 4 wk / 3 d"): update `Pig.ageString(now)` to take a `BuildContext` (breaking change). Cleaner: add `ageString(AppLocalizations l, DateTime now)` as a new method and migrate callers; deprecate the old one.

Or simplest: add a top-level helper `String localizedAge(AppLocalizations l, Pig pig, DateTime now)` and migrate callers. Use this approach.

```dart
String localizedAge(AppLocalizations l, Pig pig, DateTime now) {
  final diff = now.difference(pig.birthDate.toDate());
  final days = diff.inDays;
  if (days >= 365) return l.pig_age_years(days ~/ 365);
  if (days >= 30) return l.pig_age_months(days ~/ 30);
  if (days >= 7) return l.pig_age_weeks(days ~/ 7);
  return l.pig_age_days(days);
}
```

Note: `Pig.ageString(DateTime now)` (the old method, no context) is still used in tests — keep it for backward compat, just don't use it in the UI anymore.

- [ ] **Step 5.4: Migrate pig_detail_screen.dart**

Same pattern. Tab labels → `l.pig_detail_tab_*`. Profile rows → `l.pig_detail_profile_*`. "Mark deceased" button + confirm dialog body via the named placeholder helper:

```dart
content: Text(l.pig_detail_profile_mark_deceased_confirm_body(pig.tagId)),
```

The breeding/health placeholder texts when not applicable get localized.

For the sold banner: `Text(l.pig_detail_sold_banner_subtitle(formatMediumDate(context, sale.saleDate.toDate()), sale.buyerName))`.

- [ ] **Step 5.5: Migrate add_edit_pig_screen.dart**

Replace section header titles with localized values (note that `SectionHeader` already uppercases — pass the lowercase localized string and it will be uppercased):

Actually, our existing ARB keys for the section headers are uppercase ("PHOTO", "BASIC INFO"). Two options:
1. Pass `l.pig_form_section_photo` directly to `SectionHeader(title: ...)` — it'll be re-uppercased (no-op).
2. Change `SectionHeader` to not uppercase.

Pick option 1 for consistency. The ARB values are already uppercase.

Replace all field labels (`labelText: l.pig_form_label_tag_id`, etc.), Save button label (depending on add/edit state), validation snackbar messages, photo overlay text ("Add photo" / "Change photo"), etc.

- [ ] **Step 5.6: Migrate breeding_log_screen.dart, farrowing_log_screen.dart, health_log_screen.dart, mortality_log_screen.dart**

Same pattern per screen. Use the new keys.

For the breeding pregnancy check `AlertDialog` (still inside `pig_detail_screen.dart`'s `_BreedingTab` per Sub-project A): also localize.

- [ ] **Step 5.7: Run + commit**

```bash
flutter analyze && flutter test
```
Expected: 0 issues, 147 tests pass (no test count change — tests use English fallback since `MaterialApp` in tests doesn't have l10n delegates unless overridden).

```bash
git add -A
git commit -m "feat(i18n): extract pigs feature strings (~80 keys, EN + FIL)

- Pigs list, detail (4 tabs), add/edit, and 4 log screens use AppLocalizations
- Enum-to-label helpers: localizedPigStage / Sex / Status / age
- Filipino terminology: inahin (sow), bulugan (boar), dumalaga (gilt),
  panganganak (farrowing), bakuna (vaccination)"
```

---

_(Tasks 6–15 continue. Each follows the same TDD + commit cadence. Remaining tasks cover inventory & purchases, sales & expenses, dashboard & reports, equipment & shifts & tasks & areas & team, Tagalog completion, then the four polish items and the perf audit.)_
