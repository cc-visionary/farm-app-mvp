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

---

## Task 6: String migration — inventory & purchases

**Goal:** Extract strings from inventory (list, detail, add/edit, log consumption) and purchases (list, log purchase) screens.

**Files:**
- Modify: `app_en.arb`, `app_fil.arb`, and 6 screen files under `lib/src/features/inventory/presentation/` and `lib/src/features/purchases/presentation/`.

### Steps

- [ ] **Step 6.1: Append inventory + purchases keys to `app_en.arb`**

```json
,
"inventory_list_title": "Inventory",
"inventory_filter_all": "All",
"inventory_filter_low": "Low stock",
"inventory_filter_out": "Out of stock",
"inventory_empty_title": "No supplies tracked",
"inventory_empty_subtitle": "Tap + to track your first feed or medicine.",
"inventory_no_match_title": "No supplies match",
"inventory_no_match_subtitle": "Try clearing the filter.",
"inventory_fab_add": "Add supply",
"inventory_status_ok": "OK",
"inventory_status_low": "Low",
"inventory_status_out": "Out",
"supply_category_feed": "Feed",
"supply_category_medicine": "Medicine",
"supply_category_other_input": "Other input",
"supply_unit_kg": "kg",
"supply_unit_sack": "sack",
"supply_unit_bag": "bag",
"supply_unit_ml": "ml",
"supply_unit_dose": "dose",
"supply_unit_vial": "vial",
"supply_unit_unit": "unit",

"supply_add_title": "New supply",
"supply_edit_title": "Edit supply",
"supply_form_section_name": "NAME",
"supply_form_section_category": "CATEGORY",
"supply_form_section_unit": "UNIT",
"supply_form_section_thresholds": "PACKAGE & THRESHOLDS",
"supply_form_section_notes": "NOTES",
"supply_form_name_hint": "e.g., Pigrolac Grower",
"supply_form_units_per_package_label": "Units per package (optional)",
"supply_form_units_per_package_helper": "e.g., 50 if a sack is 50 kg",
"supply_form_low_stock_label": "Low-stock alert threshold (optional)",
"supply_form_submit_add": "Add supply",
"supply_form_submit_edit": "Save changes",
"supply_form_name_required": "Name is required.",

"supply_detail_title": "Supply",
"supply_detail_current_stock_label": "Current stock",
"supply_detail_weighted_avg_label": "Weighted avg: ₱{avg} / {unit}",
"@supply_detail_weighted_avg_label": {
  "placeholders": {"avg": {"type": "String"}, "unit": {"type": "String"}}
},
"supply_detail_low_stock_threshold_label": "Low-stock alert at {threshold}",
"@supply_detail_low_stock_threshold_label": {
  "placeholders": {"threshold": {"type": "String"}}
},
"supply_detail_stock_history": "STOCK HISTORY",
"supply_detail_no_movements_title": "No movements yet",
"supply_detail_no_movements_subtitle": "Stock changes will appear here once you log a purchase or consumption.",
"supply_detail_fab_log_consumption": "Log consumption",
"movement_type_purchase": "Purchase",
"movement_type_consumption": "Consumption",
"movement_type_adjustment": "Adjustment",
"movement_type_wastage": "Wastage",

"consumption_log_title": "Log consumption",
"consumption_log_supply_section": "SUPPLY",
"consumption_log_supply_hint": "Pick a supply",
"consumption_log_quantity_section": "QUANTITY",
"consumption_log_quantity_hint": "How much",
"consumption_log_pen_section": "PEN",
"consumption_log_pen_hint": "Pick a pen (optional)",
"consumption_log_pen_unattributed": "— Unattributed —",
"consumption_log_show_all_pens_title": "Show all pens",
"consumption_log_show_all_pens_subtitle": "Includes pens outside your assigned areas",
"consumption_log_pick_supply": "Pick a supply.",
"consumption_log_quantity_required": "Quantity must be a positive number.",
"consumption_log_supply_not_found": "Supply not found.",
"consumption_log_submit": "Save consumption",
"consumption_log_pen_with_count": "{name} · {count} pigs",
"@consumption_log_pen_with_count": {
  "placeholders": {"name": {"type": "String"}, "count": {"type": "int"}}
},
"consumption_log_insufficient_stock": "Insufficient stock — only {current} available.",
"@consumption_log_insufficient_stock": {
  "placeholders": {"current": {"type": "String"}}
},

"purchases_list_title": "Purchases",
"purchases_list_empty_title": "No purchases logged",
"purchases_list_empty_subtitle": "Tap \"Log purchase\" to record your first delivery.",
"purchases_list_fab_log": "Log purchase",

"purchase_log_title": "Log purchase",
"purchase_log_section_vendor": "VENDOR",
"purchase_log_vendor_hint": "Who you bought from",
"purchase_log_section_date": "PURCHASE DATE",
"purchase_log_section_reference": "REFERENCE",
"purchase_log_reference_hint": "Receipt or invoice no. (optional)",
"purchase_log_section_line_items": "LINE ITEMS",
"purchase_log_line_number": "Line {number}",
"@purchase_log_line_number": {
  "placeholders": {"number": {"type": "int"}}
},
"purchase_log_pick_supply": "Pick supply",
"purchase_log_quantity_label": "Quantity",
"purchase_log_unit_cost_label": "Unit cost ₱",
"purchase_log_line_total": "Line: ₱{value}",
"@purchase_log_line_total": {
  "placeholders": {"value": {"type": "String"}}
},
"purchase_log_add_line": "Add line",
"purchase_log_grand_total": "Grand total",
"purchase_log_submit": "Save purchase",
"purchase_log_vendor_required": "Vendor name is required.",
"purchase_log_line_supply_required": "Line {number}: supply not picked.",
"@purchase_log_line_supply_required": {
  "placeholders": {"number": {"type": "int"}}
},
"purchase_log_line_quantity_required": "Line {number}: quantity must be positive.",
"@purchase_log_line_quantity_required": {
  "placeholders": {"number": {"type": "int"}}
},
"purchase_log_line_unit_cost_required": "Line {number}: unit cost must be a number.",
"@purchase_log_line_unit_cost_required": {
  "placeholders": {"number": {"type": "int"}}
}
```

- [ ] **Step 6.2: Append matching Filipino translations to `app_fil.arb`**

```json
,
"inventory_list_title": "Imbentaryo",
"inventory_filter_all": "Lahat",
"inventory_filter_low": "Mababang stock",
"inventory_filter_out": "Naubos na",
"inventory_empty_title": "Walang sinusubaybayang supply",
"inventory_empty_subtitle": "I-tap ang + para masimulan ang pagsubaybay sa pakain o gamot.",
"inventory_no_match_title": "Walang tumugmang supply",
"inventory_no_match_subtitle": "Subukang alisin ang filter.",
"inventory_fab_add": "Magdagdag ng supply",
"inventory_status_ok": "OK",
"inventory_status_low": "Mababa",
"inventory_status_out": "Naubos",
"supply_category_feed": "Pakain",
"supply_category_medicine": "Gamot",
"supply_category_other_input": "Iba pang input",
"supply_unit_kg": "kg",
"supply_unit_sack": "sako",
"supply_unit_bag": "bag",
"supply_unit_ml": "ml",
"supply_unit_dose": "dosis",
"supply_unit_vial": "vial",
"supply_unit_unit": "unit",

"supply_add_title": "Bagong supply",
"supply_edit_title": "I-edit ang supply",
"supply_form_section_name": "PANGALAN",
"supply_form_section_category": "KATEGORYA",
"supply_form_section_unit": "YUNIT",
"supply_form_section_thresholds": "PACKAGE AT THRESHOLDS",
"supply_form_section_notes": "MGA TALA",
"supply_form_name_hint": "hal., Pigrolac Grower",
"supply_form_units_per_package_label": "Units per package (opsyonal)",
"supply_form_units_per_package_helper": "hal., 50 kung 50 kg ang isang sako",
"supply_form_low_stock_label": "Threshold ng low-stock alert (opsyonal)",
"supply_form_submit_add": "Magdagdag ng supply",
"supply_form_submit_edit": "I-save ang mga pagbabago",
"supply_form_name_required": "Kailangan ang pangalan.",

"supply_detail_title": "Supply",
"supply_detail_current_stock_label": "Kasalukuyang stock",
"supply_detail_weighted_avg_label": "Weighted avg: ₱{avg} / {unit}",
"supply_detail_low_stock_threshold_label": "Low-stock alert sa {threshold}",
"supply_detail_stock_history": "KASAYSAYAN NG STOCK",
"supply_detail_no_movements_title": "Wala pang movement",
"supply_detail_no_movements_subtitle": "Lalabas dito ang mga pagbabago sa stock kapag may na-log na purchase o consumption.",
"supply_detail_fab_log_consumption": "I-log ang consumption",
"movement_type_purchase": "Bili",
"movement_type_consumption": "Gamit",
"movement_type_adjustment": "Pag-aayos",
"movement_type_wastage": "Nasayang",

"consumption_log_title": "I-log ang consumption",
"consumption_log_supply_section": "SUPPLY",
"consumption_log_supply_hint": "Pumili ng supply",
"consumption_log_quantity_section": "DAMI",
"consumption_log_quantity_hint": "Magkano",
"consumption_log_pen_section": "KULUNGAN",
"consumption_log_pen_hint": "Pumili ng kulungan (opsyonal)",
"consumption_log_pen_unattributed": "— Walang nakatakda —",
"consumption_log_show_all_pens_title": "Ipakita lahat ng kulungan",
"consumption_log_show_all_pens_subtitle": "Kasama ang mga kulungan sa labas ng iyong assigned areas",
"consumption_log_pick_supply": "Pumili ng supply.",
"consumption_log_quantity_required": "Ang dami ay dapat positibong numero.",
"consumption_log_supply_not_found": "Hindi nahanap ang supply.",
"consumption_log_submit": "I-save ang consumption",
"consumption_log_pen_with_count": "{name} · {count} baboy",
"consumption_log_insufficient_stock": "Kulang ang stock — {current} lang ang available.",

"purchases_list_title": "Mga Pagbili",
"purchases_list_empty_title": "Wala pang naka-log na pagbili",
"purchases_list_empty_subtitle": "I-tap ang \"Log purchase\" para itala ang iyong unang delivery.",
"purchases_list_fab_log": "I-log ang pagbili",

"purchase_log_title": "I-log ang pagbili",
"purchase_log_section_vendor": "VENDOR",
"purchase_log_vendor_hint": "Kanino ka bumili",
"purchase_log_section_date": "PETSA NG PAGBILI",
"purchase_log_section_reference": "REFERENCE",
"purchase_log_reference_hint": "Receipt o invoice no. (opsyonal)",
"purchase_log_section_line_items": "LINE ITEMS",
"purchase_log_line_number": "Linya {number}",
"purchase_log_pick_supply": "Pumili ng supply",
"purchase_log_quantity_label": "Dami",
"purchase_log_unit_cost_label": "Unit cost ₱",
"purchase_log_line_total": "Linya: ₱{value}",
"purchase_log_add_line": "Magdagdag ng linya",
"purchase_log_grand_total": "Kabuuang halaga",
"purchase_log_submit": "I-save ang pagbili",
"purchase_log_vendor_required": "Kailangan ang vendor name.",
"purchase_log_line_supply_required": "Linya {number}: walang napiling supply.",
"purchase_log_line_quantity_required": "Linya {number}: dami ay dapat positibo.",
"purchase_log_line_unit_cost_required": "Linya {number}: dapat numero ang unit cost."
```

Run `flutter pub get`.

- [ ] **Step 6.3: Migrate the 6 screen files**

For each file under `lib/src/features/inventory/presentation/` and `lib/src/features/purchases/presentation/`:
1. Add `import 'package:farm_app/src/l10n/generated/app_localizations.dart';`
2. Add `final l = AppLocalizations.of(context);` at the top of the build method.
3. Replace every hardcoded user-visible string with `l.<key>`.
4. For enums (SupplyCategory, SupplyUnit, MovementType), use helpers added in `lib/src/features/inventory/domain/supply_category.dart`:

```dart
String localizedSupplyCategory(AppLocalizations l, SupplyCategory c) {
  switch (c) {
    case SupplyCategory.feed: return l.supply_category_feed;
    case SupplyCategory.medicine: return l.supply_category_medicine;
    case SupplyCategory.otherInput: return l.supply_category_other_input;
  }
}

String localizedSupplyUnit(AppLocalizations l, SupplyUnit u) {
  switch (u) {
    case SupplyUnit.kg: return l.supply_unit_kg;
    case SupplyUnit.sack: return l.supply_unit_sack;
    case SupplyUnit.bag: return l.supply_unit_bag;
    case SupplyUnit.ml: return l.supply_unit_ml;
    case SupplyUnit.dose: return l.supply_unit_dose;
    case SupplyUnit.vial: return l.supply_unit_vial;
    case SupplyUnit.unit: return l.supply_unit_unit;
  }
}

String localizedMovementType(AppLocalizations l, MovementType t) {
  switch (t) {
    case MovementType.purchase: return l.movement_type_purchase;
    case MovementType.consumption: return l.movement_type_consumption;
    case MovementType.adjustment: return l.movement_type_adjustment;
    case MovementType.wastage: return l.movement_type_wastage;
  }
}
```

Place these as top-level functions in `lib/src/features/inventory/domain/supply_category.dart` (where the enums live).

For currency/date formatting: replace `NumberFormat.decimalPattern('en_PH').format(...)` with `formatDecimal(context, ...)`, and `'₱${val.toStringAsFixed(0)}'` with `formatCurrencyPhp(context, val)` from `intl_helpers.dart`.

For dates: replace `DateFormat.yMMMd().format(...)` with `formatMediumDate(context, ...)`.

- [ ] **Step 6.4: Run + commit**

```bash
flutter analyze && flutter test
```
Expected: 0 issues, 147 tests still pass.

```bash
git add -A
git commit -m "feat(i18n): inventory + purchases string migration (~60 keys, EN + FIL)

- 6 screens use AppLocalizations
- Supply category/unit/movement type enum-to-label helpers in domain layer
- Currency/date formatters routed through intl_helpers (locale-aware)
- Filipino: pakain (feed), gamot (medicine), sako (sack), imbentaryo (inventory)"
```

---

## Task 7: String migration — sales & expenses

**Goal:** Extract strings from sales (list, detail, log sale) and expenses (list, log expense) screens.

**Files:**
- Modify: `app_en.arb`, `app_fil.arb`, 5 screen files under sales/ and expenses/ presentation dirs.

### Steps

- [ ] **Step 7.1: Append sales + expenses keys to `app_en.arb`**

```json
,
"sales_list_title": "Sales",
"sales_list_empty_title": "No sales logged",
"sales_list_empty_subtitle": "Tap \"Log sale\" to record your first transaction.",
"sales_list_fab_log": "Log sale",
"sales_card_heads_weight": "{heads} · {weight} kg",
"@sales_card_heads_weight": {
  "placeholders": {"heads": {"type": "String"}, "weight": {"type": "String"}}
},
"payment_method_cash": "Cash",
"payment_method_bank_transfer": "Bank transfer",
"payment_method_gcash": "GCash",
"payment_method_check": "Check",
"payment_method_other": "Other",
"payment_status_paid": "Paid",
"payment_status_partial": "Partial",
"payment_status_unpaid": "Unpaid",

"sale_detail_title": "Sale",
"sale_detail_line_items_section": "LINE ITEMS",
"sale_detail_total_label": "Total",
"sale_detail_meta_heads_weight": "{heads} heads · {weight} kg",
"@sale_detail_meta_heads_weight": {
  "placeholders": {"heads": {"type": "int"}, "weight": {"type": "String"}}
},
"sale_detail_line_meta": "{weight} kg · ₱{pricePerKg}/kg",
"@sale_detail_line_meta": {
  "placeholders": {"weight": {"type": "String"}, "pricePerKg": {"type": "String"}}
},
"sale_detail_amount_paid_label": "Amount paid",

"sale_log_title": "Log sale",
"sale_log_section_buyer": "BUYER",
"sale_log_buyer_hint": "Buyer name",
"sale_log_buyer_contact_hint": "Contact (optional)",
"sale_log_section_date": "DATE",
"sale_log_section_pigs": "PIGS IN SALE",
"sale_log_add_pigs": "Add pigs",
"sale_log_no_eligible_pigs": "No more eligible pigs to add.",
"sale_log_picker_title": "Pick pigs",
"sale_log_picker_add_button": "Add ({count})",
"@sale_log_picker_add_button": {"placeholders": {"count": {"type": "int"}}},
"sale_log_picker_search_hint": "Search by tag ID",
"sale_log_picker_subtitle": "{stage} · {weight} kg",
"@sale_log_picker_subtitle": {
  "placeholders": {"stage": {"type": "String"}, "weight": {"type": "String"}}
},
"sale_log_row_weight_label": "Weight kg",
"sale_log_row_price_label": "₱/kg",
"sale_log_row_line": "Line: ₱{value}",
"@sale_log_row_line": {"placeholders": {"value": {"type": "String"}}},
"sale_log_totals_heads_weight": "{heads} heads · {weight} kg",
"@sale_log_totals_heads_weight": {
  "placeholders": {"heads": {"type": "int"}, "weight": {"type": "String"}}
},
"sale_log_total_revenue_label": "Total revenue",
"sale_log_section_payment": "PAYMENT",
"sale_log_amount_paid_label": "Amount paid (₱)",
"sale_log_submit": "Save sale",
"sale_log_buyer_required": "Buyer is required.",
"sale_log_pigs_required": "Add at least one pig.",
"sale_log_weight_required": "Pig {tagId}: weight must be positive.",
"@sale_log_weight_required": {"placeholders": {"tagId": {"type": "String"}}},
"sale_log_price_required": "Pig {tagId}: price/kg must be positive.",
"@sale_log_price_required": {"placeholders": {"tagId": {"type": "String"}}},
"sale_log_partial_amount_invalid": "Partial-payment amount must be > 0 and < total.",
"sale_log_pig_not_active": "Pig {tagId} is not active.",
"@sale_log_pig_not_active": {"placeholders": {"tagId": {"type": "String"}}},

"expenses_list_title": "Expenses",
"expenses_list_empty_title": "No expenses logged",
"expenses_list_empty_subtitle": "Tap \"Log expense\" to record your first expense.",
"expenses_list_no_match_title": "No matching expenses",
"expenses_list_no_match_subtitle": "Try clearing the category filter.",
"expenses_list_fab_log": "Log expense",
"expenses_list_total_label": "Total",
"expense_category_feed": "Feed",
"expense_category_medicine": "Medicine",
"expense_category_labor": "Labor",
"expense_category_utilities": "Utilities",
"expense_category_equipment": "Equipment",
"expense_category_maintenance": "Maintenance",
"expense_category_other": "Other",

"expense_log_title": "Log expense",
"expense_log_section_category": "CATEGORY",
"expense_log_section_description": "DESCRIPTION",
"expense_log_description_hint": "What was this expense for?",
"expense_log_section_amount": "AMOUNT",
"expense_log_section_date": "DATE",
"expense_log_submit": "Save expense",
"expense_log_description_required": "Description is required.",
"expense_log_amount_required": "Amount must be a positive number."
```

- [ ] **Step 7.2: Append Filipino translations to `app_fil.arb`**

```json
,
"sales_list_title": "Mga Benta",
"sales_list_empty_title": "Wala pang naka-log na benta",
"sales_list_empty_subtitle": "I-tap ang \"Log sale\" para itala ang iyong unang transaksyon.",
"sales_list_fab_log": "I-log ang benta",
"sales_card_heads_weight": "{heads} · {weight} kg",
"payment_method_cash": "Cash",
"payment_method_bank_transfer": "Bank transfer",
"payment_method_gcash": "GCash",
"payment_method_check": "Tseke",
"payment_method_other": "Iba pa",
"payment_status_paid": "Bayad na",
"payment_status_partial": "Bahagi",
"payment_status_unpaid": "Hindi bayad",

"sale_detail_title": "Benta",
"sale_detail_line_items_section": "MGA LINE ITEM",
"sale_detail_total_label": "Kabuuan",
"sale_detail_meta_heads_weight": "{heads} ulo · {weight} kg",
"sale_detail_line_meta": "{weight} kg · ₱{pricePerKg}/kg",
"sale_detail_amount_paid_label": "Halaga ng binayad",

"sale_log_title": "I-log ang benta",
"sale_log_section_buyer": "BUYER",
"sale_log_buyer_hint": "Pangalan ng buyer",
"sale_log_buyer_contact_hint": "Contact (opsyonal)",
"sale_log_section_date": "PETSA",
"sale_log_section_pigs": "MGA BABOY SA BENTA",
"sale_log_add_pigs": "Magdagdag ng baboy",
"sale_log_no_eligible_pigs": "Wala nang ibang babareng maidaragdag.",
"sale_log_picker_title": "Pumili ng baboy",
"sale_log_picker_add_button": "Idagdag ({count})",
"sale_log_picker_search_hint": "Maghanap ayon sa tag ID",
"sale_log_picker_subtitle": "{stage} · {weight} kg",
"sale_log_row_weight_label": "Bigat kg",
"sale_log_row_price_label": "₱/kg",
"sale_log_row_line": "Linya: ₱{value}",
"sale_log_totals_heads_weight": "{heads} ulo · {weight} kg",
"sale_log_total_revenue_label": "Kabuuang kita",
"sale_log_section_payment": "BAYAD",
"sale_log_amount_paid_label": "Halaga ng binayad (₱)",
"sale_log_submit": "I-save ang benta",
"sale_log_buyer_required": "Kailangan ang buyer.",
"sale_log_pigs_required": "Magdagdag ng kahit isang baboy.",
"sale_log_weight_required": "Baboy {tagId}: dapat positibo ang bigat.",
"sale_log_price_required": "Baboy {tagId}: dapat positibo ang price/kg.",
"sale_log_partial_amount_invalid": "Ang halaga ng partial-payment ay dapat > 0 at < kabuuan.",
"sale_log_pig_not_active": "Hindi aktibo ang baboy {tagId}.",

"expenses_list_title": "Mga Gastusin",
"expenses_list_empty_title": "Wala pang naka-log na gastos",
"expenses_list_empty_subtitle": "I-tap ang \"Log expense\" para itala ang iyong unang gastos.",
"expenses_list_no_match_title": "Walang tumugmang gastos",
"expenses_list_no_match_subtitle": "Subukang alisin ang category filter.",
"expenses_list_fab_log": "I-log ang gastos",
"expenses_list_total_label": "Kabuuan",
"expense_category_feed": "Pakain",
"expense_category_medicine": "Gamot",
"expense_category_labor": "Lakas-paggawa",
"expense_category_utilities": "Utilities",
"expense_category_equipment": "Kagamitan",
"expense_category_maintenance": "Pagpapanatili",
"expense_category_other": "Iba pa",

"expense_log_title": "I-log ang gastos",
"expense_log_section_category": "KATEGORYA",
"expense_log_section_description": "DESKRIPSYON",
"expense_log_description_hint": "Para saan ang gastos na ito?",
"expense_log_section_amount": "HALAGA",
"expense_log_section_date": "PETSA",
"expense_log_submit": "I-save ang gastos",
"expense_log_description_required": "Kailangan ang deskripsyon.",
"expense_log_amount_required": "Ang halaga ay dapat positibong numero."
```

Run `flutter pub get`.

- [ ] **Step 7.3: Migrate the 5 screens**

For each file under `lib/src/features/sales/presentation/` and `lib/src/features/expenses/presentation/`:
- Add `AppLocalizations.of(context)` access at top of build.
- Replace every hardcoded user-visible string.
- For `PaymentMethod` / `PaymentStatus` / `ExpenseCategory` enums, add `localized*` helpers (top-level in the respective `domain/*_method.dart`, `*_status.dart`, `expense_category.dart` files):

```dart
// In payment_method.dart:
String localizedPaymentMethod(AppLocalizations l, PaymentMethod m) {
  switch (m) {
    case PaymentMethod.cash: return l.payment_method_cash;
    case PaymentMethod.bankTransfer: return l.payment_method_bank_transfer;
    case PaymentMethod.gcash: return l.payment_method_gcash;
    case PaymentMethod.check: return l.payment_method_check;
    case PaymentMethod.other: return l.payment_method_other;
  }
}

// In payment_status.dart:
String localizedPaymentStatus(AppLocalizations l, PaymentStatus s) {
  switch (s) {
    case PaymentStatus.paid: return l.payment_status_paid;
    case PaymentStatus.partial: return l.payment_status_partial;
    case PaymentStatus.unpaid: return l.payment_status_unpaid;
  }
}

// In expense_category.dart:
String localizedExpenseCategory(AppLocalizations l, ExpenseCategory c) {
  switch (c) {
    case ExpenseCategory.feed: return l.expense_category_feed;
    case ExpenseCategory.medicine: return l.expense_category_medicine;
    case ExpenseCategory.labor: return l.expense_category_labor;
    case ExpenseCategory.utilities: return l.expense_category_utilities;
    case ExpenseCategory.equipment: return l.expense_category_equipment;
    case ExpenseCategory.maintenance: return l.expense_category_maintenance;
    case ExpenseCategory.other: return l.expense_category_other;
  }
}
```

- Currency: `formatCurrencyPhp(context, value)`.
- Dates: `formatMediumDate(context, dt)`.

- [ ] **Step 7.4: Run + commit**

```bash
flutter analyze && flutter test
git add -A
git commit -m "feat(i18n): sales + expenses string migration (~55 keys, EN + FIL)

- 5 screens use AppLocalizations
- Payment method/status + expense category enum-to-label helpers
- Filipino: kabuuang kita (total revenue), lakas-paggawa (labor)"
```

---

## Task 8: String migration — dashboard & reports

**Goal:** Extract strings from dashboard, snapshot card, my-tasks card, roster widget, yield reports, batches list, batch profitability, activity feed/screen, and farm layout.

**Files:**
- Modify: `app_en.arb`, `app_fil.arb`, ~9 screen/widget files.

### Steps

- [ ] **Step 8.1: Append dashboard + reports keys to `app_en.arb`**

```json
,
"dashboard_greeting_morning": "Good morning, {name}",
"@dashboard_greeting_morning": {"placeholders": {"name": {"type": "String"}}},
"dashboard_greeting_afternoon": "Good afternoon, {name}",
"@dashboard_greeting_afternoon": {"placeholders": {"name": {"type": "String"}}},
"dashboard_greeting_evening": "Good evening, {name}",
"@dashboard_greeting_evening": {"placeholders": {"name": {"type": "String"}}},
"dashboard_greeting_no_name_morning": "Good morning",
"dashboard_greeting_no_name_afternoon": "Good afternoon",
"dashboard_greeting_no_name_evening": "Good evening",
"dashboard_today_label": "Today, {date}",
"@dashboard_today_label": {"placeholders": {"date": {"type": "String"}}},
"dashboard_my_tasks_title": "Your tasks today",
"dashboard_my_tasks_empty": "No tasks assigned to you. 🎉",
"dashboard_my_tasks_see_all": "See all tasks →",

"snapshot_section_title": "SWINE SNAPSHOT",
"snapshot_total_pigs": "Total pigs (active)",
"snapshot_sows": "Sows",
"snapshot_boars": "Boars",
"snapshot_farrowings_30d": "Farrowings (last 30d)",
"snapshot_mortalities_30d": "Mortalities (last 30d)",
"snapshot_revenue_month": "Revenue this month",
"snapshot_low_stock": "Low stock items",

"roster_today_title": "Today's Roster",
"roster_no_shifts_today": "No shifts scheduled today.",

"yield_title": "Yield reports",
"yield_period_7d": "7d",
"yield_period_30d": "30d",
"yield_period_90d": "90d",
"yield_period_ytd": "YTD",
"yield_period_all": "All-time",
"yield_card_herd": "Herd productivity",
"yield_card_herd_total_farrowings": "Total farrowings",
"yield_card_herd_avg_litter": "Avg litter size",
"yield_card_herd_avg_stillborns": "Avg stillborns / litter",
"yield_card_herd_stillbirth_rate": "Stillbirth rate",
"yield_card_herd_breeding_success": "Breeding success rate",
"yield_card_herd_psy": "PSY (estimate, annualized)",
"yield_card_growth": "Growth & finishing",
"yield_card_growth_active_gf": "Active grow/finish pigs",
"yield_card_growth_adg": "Average daily gain",
"yield_card_growth_adg_value": "{value} kg/d",
"@yield_card_growth_adg_value": {"placeholders": {"value": {"type": "String"}}},
"yield_card_mortality": "Mortality",
"yield_card_mortality_total": "Total deaths (period)",
"yield_card_mortality_rate": "Overall mortality rate",
"yield_card_mortality_top_causes": "Top causes:",
"yield_card_mortality_by_area": "By area:",
"yield_card_output": "Output",
"yield_card_output_sold": "Sold (in period)",
"yield_card_output_culled": "Culled (in period)",
"yield_card_output_b_note": "Sales revenue tracking comes in Sub-project B.",
"yield_profitability_title": "Profitability",
"yield_profitability_revenue": "Revenue",
"yield_profitability_feed": "Feed",
"yield_profitability_medicine": "Medicine",
"yield_profitability_labor": "Labor",
"yield_profitability_utilities": "Utilities",
"yield_profitability_equipment": "Equipment",
"yield_profitability_maintenance": "Maintenance",
"yield_profitability_other": "Other",
"yield_profitability_gross_profit": "Gross profit",
"yield_profitability_margin": "{value}% margin",
"@yield_profitability_margin": {"placeholders": {"value": {"type": "String"}}},
"yield_view_per_batch_button": "View per-batch profitability",

"batches_list_title": "Batches",
"batches_list_empty_title": "No batches yet",
"batches_list_empty_subtitle": "Litter or grow-finish batches will appear here once created.",
"batch_type_litter": "Litter",
"batch_type_grow_finish": "Grow-Finish",
"batch_type_nursery": "Nursery",
"batch_status_active": "active",
"batch_status_sold": "sold",
"batch_status_closed": "closed",
"batch_card_subtitle": "{type} · {count} head",
"@batch_card_subtitle": {
  "placeholders": {"type": {"type": "String"}, "count": {"type": "int"}}
},

"batch_profit_revenue": "Revenue",
"batch_profit_total_cost": "Total cost",
"batch_profit_gross_profit": "Gross profit",
"batch_profit_cost_breakdown": "COST BREAKDOWN",
"batch_profit_cost_no_costs": "No costs yet",

"activity_feed_title": "Recent activity",
"activity_feed_empty_title": "No activity yet",
"activity_feed_empty_subtitle": "Logged events will appear here.",
"activity_feed_see_all": "See all",
"activity_screen_title": "Activity",
"activity_screen_today": "Today",
"activity_screen_yesterday": "Yesterday",
"activity_screen_just_now": "just now",
"activity_time_minutes": "{n}m",
"@activity_time_minutes": {"placeholders": {"n": {"type": "int"}}},
"activity_time_hours": "{n}h",
"@activity_time_hours": {"placeholders": {"n": {"type": "int"}}},
"activity_time_days": "{n}d",
"@activity_time_days": {"placeholders": {"n": {"type": "int"}}},

"farm_layout_title": "Farm layout",
"farm_layout_pigs_label": "Pigs: {count}{capacity}",
"@farm_layout_pigs_label": {
  "placeholders": {"count": {"type": "int"}, "capacity": {"type": "String"}}
},
"farm_layout_pending_tasks_one": "1 pending task",
"farm_layout_pending_tasks_many": "{count} pending tasks",
"@farm_layout_pending_tasks_many": {"placeholders": {"count": {"type": "int"}}},
"farm_layout_pens_label": "Pens",
"farm_layout_equipment_label": "Equipment",
"farm_layout_on_shift_label": "On shift:"
```

- [ ] **Step 8.2: Append Filipino translations to `app_fil.arb`**

```json
,
"dashboard_greeting_morning": "Magandang umaga, {name}",
"dashboard_greeting_afternoon": "Magandang hapon, {name}",
"dashboard_greeting_evening": "Magandang gabi, {name}",
"dashboard_greeting_no_name_morning": "Magandang umaga",
"dashboard_greeting_no_name_afternoon": "Magandang hapon",
"dashboard_greeting_no_name_evening": "Magandang gabi",
"dashboard_today_label": "Ngayong araw, {date}",
"dashboard_my_tasks_title": "Iyong mga gawain ngayon",
"dashboard_my_tasks_empty": "Walang gawaing naka-assign sa iyo. 🎉",
"dashboard_my_tasks_see_all": "Tingnan lahat →",

"snapshot_section_title": "SWINE SNAPSHOT",
"snapshot_total_pigs": "Kabuuang baboy (aktibo)",
"snapshot_sows": "Inahin",
"snapshot_boars": "Bulugan",
"snapshot_farrowings_30d": "Panganganak (huling 30 araw)",
"snapshot_mortalities_30d": "Kamatayan (huling 30 araw)",
"snapshot_revenue_month": "Kita ngayong buwan",
"snapshot_low_stock": "Mababang stock",

"roster_today_title": "Roster Ngayong Araw",
"roster_no_shifts_today": "Walang nakatakdang shift ngayong araw.",

"yield_title": "Yield reports",
"yield_period_7d": "7 araw",
"yield_period_30d": "30 araw",
"yield_period_90d": "90 araw",
"yield_period_ytd": "YTD",
"yield_period_all": "Lahat ng oras",
"yield_card_herd": "Productivity ng kawan",
"yield_card_herd_total_farrowings": "Kabuuang panganganak",
"yield_card_herd_avg_litter": "Avg litter size",
"yield_card_herd_avg_stillborns": "Avg stillborns / litter",
"yield_card_herd_stillbirth_rate": "Stillbirth rate",
"yield_card_herd_breeding_success": "Breeding success rate",
"yield_card_herd_psy": "PSY (estimate, annualized)",
"yield_card_growth": "Paglago at finishing",
"yield_card_growth_active_gf": "Aktibong grow/finish pigs",
"yield_card_growth_adg": "Average daily gain",
"yield_card_growth_adg_value": "{value} kg/d",
"yield_card_mortality": "Kamatayan",
"yield_card_mortality_total": "Kabuuang patay (panahon)",
"yield_card_mortality_rate": "Overall mortality rate",
"yield_card_mortality_top_causes": "Pangunahing dahilan:",
"yield_card_mortality_by_area": "Ayon sa lugar:",
"yield_card_output": "Output",
"yield_card_output_sold": "Naibenta (sa panahon)",
"yield_card_output_culled": "Inalis (sa panahon)",
"yield_card_output_b_note": "Sales revenue tracking sa Sub-project B.",
"yield_profitability_title": "Tubo",
"yield_profitability_revenue": "Kita",
"yield_profitability_feed": "Pakain",
"yield_profitability_medicine": "Gamot",
"yield_profitability_labor": "Lakas-paggawa",
"yield_profitability_utilities": "Utilities",
"yield_profitability_equipment": "Kagamitan",
"yield_profitability_maintenance": "Pagpapanatili",
"yield_profitability_other": "Iba pa",
"yield_profitability_gross_profit": "Gross profit",
"yield_profitability_margin": "{value}% margin",
"yield_view_per_batch_button": "Tingnan ang per-batch profitability",

"batches_list_title": "Mga Batch",
"batches_list_empty_title": "Wala pang batch",
"batches_list_empty_subtitle": "Lalabas dito ang mga litter o grow-finish batch kapag may nilikha.",
"batch_type_litter": "Litter",
"batch_type_grow_finish": "Grow-Finish",
"batch_type_nursery": "Nursery",
"batch_status_active": "aktibo",
"batch_status_sold": "naibenta",
"batch_status_closed": "sarado",
"batch_card_subtitle": "{type} · {count} ulo",

"batch_profit_revenue": "Kita",
"batch_profit_total_cost": "Kabuuang gastos",
"batch_profit_gross_profit": "Gross profit",
"batch_profit_cost_breakdown": "COST BREAKDOWN",
"batch_profit_cost_no_costs": "Wala pang gastos",

"activity_feed_title": "Pinakahuling aktibidad",
"activity_feed_empty_title": "Wala pang aktibidad",
"activity_feed_empty_subtitle": "Lalabas dito ang mga nai-log na pangyayari.",
"activity_feed_see_all": "Tingnan lahat",
"activity_screen_title": "Aktibidad",
"activity_screen_today": "Ngayon",
"activity_screen_yesterday": "Kahapon",
"activity_screen_just_now": "ngayon lang",
"activity_time_minutes": "{n} min",
"activity_time_hours": "{n} oras",
"activity_time_days": "{n} araw",

"farm_layout_title": "Farm layout",
"farm_layout_pigs_label": "Baboy: {count}{capacity}",
"farm_layout_pending_tasks_one": "1 pending na gawain",
"farm_layout_pending_tasks_many": "{count} pending na gawain",
"farm_layout_pens_label": "Mga kulungan",
"farm_layout_equipment_label": "Kagamitan",
"farm_layout_on_shift_label": "Naka-shift:"
```

Run `flutter pub get`.

- [ ] **Step 8.3: Migrate the 9 files**

For each file under `lib/src/features/dashboard/`, `lib/src/features/yield/`, `lib/src/features/profitability/presentation/`, `lib/src/features/activity/presentation/`, `lib/src/features/layout/`:
- Add AppLocalizations access.
- Replace every hardcoded user-visible string.
- For batch type/status enums, add helpers in `lib/src/features/pigs/domain/batch.dart`:

```dart
String localizedBatchType(AppLocalizations l, BatchType t) {
  switch (t) {
    case BatchType.litter: return l.batch_type_litter;
    case BatchType.growFinish: return l.batch_type_grow_finish;
    case BatchType.nursery: return l.batch_type_nursery;
  }
}

String localizedBatchStatus(AppLocalizations l, BatchStatus s) {
  switch (s) {
    case BatchStatus.active: return l.batch_status_active;
    case BatchStatus.sold: return l.batch_status_sold;
    case BatchStatus.closed: return l.batch_status_closed;
  }
}
```

For the dashboard's time-of-day greeting (existing pattern in `dashboard_screen.dart`):

```dart
String greeting(AppLocalizations l, AppUser? user) {
  final hour = DateTime.now().hour;
  final name = user?.displayName;
  if (name == null || name.trim().isEmpty) {
    if (hour < 12) return l.dashboard_greeting_no_name_morning;
    if (hour < 18) return l.dashboard_greeting_no_name_afternoon;
    return l.dashboard_greeting_no_name_evening;
  }
  if (hour < 12) return l.dashboard_greeting_morning(name);
  if (hour < 18) return l.dashboard_greeting_afternoon(name);
  return l.dashboard_greeting_evening(name);
}
```

For activity relative timestamps (existing `_relative` in `activity_feed_widget.dart`):

```dart
String _relative(AppLocalizations l, DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return l.activity_screen_just_now;
  if (d.inMinutes < 60) return l.activity_time_minutes(d.inMinutes);
  if (d.inHours < 24) return l.activity_time_hours(d.inHours);
  if (d.inDays < 7) return l.activity_time_days(d.inDays);
  return DateFormat.MMMd(Localizations.localeOf(context).toString()).format(t);
}
```

For "1 pending task" / "N pending tasks": prefer a single ICU plural key instead of two separate keys — refactor to one key. Actually we already split for clarity; an alternative is a plural form `farm_layout_pending_tasks` with `=1` and `other` branches. For consistency with `common_pigs_count`, use the plural form. Decide: keep two keys for now (matches the plan above); a future cleanup can collapse them into an ICU plural.

- [ ] **Step 8.4: Run + commit**

```bash
flutter analyze && flutter test
git add -A
git commit -m "feat(i18n): dashboard + reports string migration (~80 keys, EN + FIL)

- 9 screens/widgets use AppLocalizations
- Batch type/status helpers in domain layer
- Time-of-day greeting + activity relative timestamps fully localized
- Filipino: 'Magandang umaga', 'Productivity ng kawan', 'Roster Ngayong Araw'"
```

---

## Task 9: String migration — equipment, shifts, tasks, areas, team

**Goal:** Extract strings from the remaining feature screens: equipment (list, detail, add/edit, log maintenance), shifts (list, edit, roster), tasks (list, create), areas (list, edit), team (management, invite, accept invitation).

**Files:**
- Modify: `app_en.arb`, `app_fil.arb`, ~12 screen files across `equipment/`, `shifts/`, `tasks/`, `areas/`, `team/`.

### Steps

- [ ] **Step 9.1: Append keys for these features to `app_en.arb`**

```json
,
"equipment_list_title": "Equipment",
"equipment_list_filter_needs_repair": "Needs repair",
"equipment_list_filter_in_use": "In use",
"equipment_list_filter_available": "Available",
"equipment_list_empty_title": "No equipment matches filters.",
"equipment_list_fab_add": "Add equipment",
"equipment_type_ventilation": "Ventilation",
"equipment_type_feeder": "Feeder",
"equipment_type_water_pump": "Water Pump",
"equipment_type_generator": "Generator",
"equipment_type_scale": "Scale",
"equipment_type_vehicle": "Vehicle",
"equipment_type_structure": "Structure",
"equipment_type_tool": "Tool",
"equipment_type_other": "Other",
"equipment_status_in_use": "In use",
"equipment_status_available": "Available",
"equipment_status_needs_repair": "Needs repair",
"equipment_status_retired": "Retired",
"equipment_card_area_with_type": "{type} · area {areaId}",
"@equipment_card_area_with_type": {
  "placeholders": {"type": {"type": "String"}, "areaId": {"type": "String"}}
},

"equipment_add_title": "New equipment",
"equipment_edit_title": "Edit equipment",
"equipment_form_name_label": "Name",
"equipment_form_type_label": "Type",
"equipment_form_area_label": "Area (optional)",
"equipment_form_area_none": "— no area —",
"equipment_form_status_label": "Status",
"equipment_form_purchase_date_label": "Purchase date (optional)",
"equipment_form_purchase_date_none": "—",
"equipment_form_cost_label": "Purchase cost (PHP, optional)",
"equipment_form_notes_label": "Notes (optional)",
"equipment_form_submit": "Save",
"equipment_form_name_required": "Name is required.",

"equipment_detail_title": "Equipment",
"equipment_detail_type_label": "Type: {value}",
"@equipment_detail_type_label": {"placeholders": {"value": {"type": "String"}}},
"equipment_detail_status_label": "Status: {value}",
"@equipment_detail_status_label": {"placeholders": {"value": {"type": "String"}}},
"equipment_detail_purchase_date_label": "Purchased: {date}",
"@equipment_detail_purchase_date_label": {"placeholders": {"date": {"type": "String"}}},
"equipment_detail_purchase_cost_label": "Purchase cost: ₱{value}",
"@equipment_detail_purchase_cost_label": {"placeholders": {"value": {"type": "String"}}},
"equipment_detail_maintenance_history": "Maintenance history",
"equipment_detail_no_maintenance": "No maintenance logged yet.",
"equipment_detail_total_label": "Total: ₱{value}",
"@equipment_detail_total_label": {"placeholders": {"value": {"type": "String"}}},
"equipment_detail_fab_log": "Log maintenance",

"maintenance_type_preventive": "Preventive",
"maintenance_type_repair": "Repair",
"maintenance_type_inspection": "Inspection",
"maintenance_log_title": "Log maintenance",
"maintenance_log_performed_by_label": "Performed by (technician name, optional)",
"maintenance_log_parts_label": "Parts replaced (optional)",
"maintenance_log_cost_label": "Cost (PHP, optional)",
"maintenance_log_notes_label": "Notes",
"maintenance_log_submit": "Save",

"shifts_screen_title": "Shifts & Roster",
"shifts_section_all_shifts": "All shifts",
"shifts_card_daily": "Daily",
"shifts_card_pattern": "{days} · {start}-{end} · area {areaId} · {workers} worker(s)",
"@shifts_card_pattern": {
  "placeholders": {
    "days": {"type": "String"}, "start": {"type": "String"},
    "end": {"type": "String"}, "areaId": {"type": "String"},
    "workers": {"type": "int"}
  }
},
"shift_pattern_daily": "Daily",
"shift_pattern_weekly": "Weekly",
"shift_dow_sun": "S",
"shift_dow_mon": "M",
"shift_dow_tue": "T",
"shift_dow_wed": "W",
"shift_dow_thu": "T",
"shift_dow_fri": "F",
"shift_dow_sat": "S",

"shift_add_title": "New shift",
"shift_edit_title": "Edit shift",
"shift_form_name_label": "Shift name",
"shift_form_pattern_label": "Pattern",
"shift_form_start_label": "Start (HH:mm)",
"shift_form_end_label": "End (HH:mm)",
"shift_form_area_label": "Area",
"shift_form_workers_label": "Workers",
"shift_form_submit": "Save shift",
"shift_form_delete": "Delete",
"shift_form_name_required": "Shift name is required.",
"shift_form_area_required": "Pick an area.",
"shift_form_days_required": "Pick at least one day for a weekly shift.",

"tasks_screen_title": "Tasks",
"tasks_tab_my": "My Tasks",
"tasks_tab_all": "All Open",
"tasks_empty_my": "No tasks assigned to you.",
"tasks_empty_all": "No open tasks.",
"task_type_pregnancy_check": "Pregnancy check",
"task_type_farrowing_prep": "Farrowing prep",
"task_type_farrowing_expected": "Farrowing expected",
"task_type_vaccination_due": "Vaccination due",
"task_type_withdrawal_end": "Withdrawal period ends",
"task_type_manual": "Manual",
"task_card_due": "Due {date}",
"@task_card_due": {"placeholders": {"date": {"type": "String"}}},
"task_card_assigned_to": "assigned to {kind}:{id}",
"@task_card_assigned_to": {
  "placeholders": {"kind": {"type": "String"}, "id": {"type": "String"}}
},
"task_card_mark_complete": "Mark complete",

"task_create_title": "New task",
"task_create_title_label": "Title",
"task_create_description_label": "Description",
"task_create_due_date_label": "Due date",
"task_create_assign_to_label": "Assign to",
"task_create_assign_type_label": "Type",
"task_create_assign_none": "— unassigned —",
"task_create_assign_user": "Specific user",
"task_create_assign_area": "Any worker in an area",
"task_create_user_label": "User",
"task_create_area_label": "Area",
"task_create_submit": "Create task",
"task_create_title_required": "Title is required.",

"areas_list_title": "Areas",
"areas_list_empty": "No areas yet. Tap + to add one.",
"areas_list_fab_add": "Add area",
"area_purpose_breeding": "Breeding",
"area_purpose_gestation": "Gestation",
"area_purpose_farrowing": "Farrowing",
"area_purpose_nursery": "Nursery",
"area_purpose_grow_finish": "Grow-Finish",
"area_purpose_quarantine": "Quarantine",
"area_purpose_boar_pen": "Boar Pen",
"area_purpose_isolation": "Isolation",
"area_purpose_other": "Other",

"area_add_title": "New area",
"area_edit_title": "Edit area",
"area_form_name_label": "Name",
"area_form_purpose_label": "Purpose",
"area_form_notes_label": "Notes (optional)",
"area_form_submit_add": "Save area",
"area_form_submit_edit": "Save changes",
"area_form_save_first_for_pens": "Save area first before adding pens.",
"area_form_name_required": "Area name is required.",
"area_form_pens_section": "Pens",
"pen_dialog_title": "Add pen",
"pen_dialog_name_label": "Pen name",
"pen_dialog_capacity_label": "Capacity (optional)",
"pen_dialog_name_required": "Pen name is required.",
"pen_dialog_capacity_positive": "Capacity must be a positive whole number.",
"pen_card_capacity_unknown": "Capacity: —",
"pen_card_occupancy": "Occupancy: {current} / {capacity}",
"@pen_card_occupancy": {
  "placeholders": {"current": {"type": "int"}, "capacity": {"type": "int"}}
},

"team_screen_title": "Team",
"team_section_members": "Members",
"team_section_invitations": "Pending invitations",
"team_fab_invite": "Invite",
"team_member_role_label": "Role: {role}",
"@team_member_role_label": {"placeholders": {"role": {"type": "String"}}},
"team_role_owner": "Owner",
"team_role_manager": "Manager",
"team_role_worker": "Worker",
"team_role_vet": "Veterinarian",
"team_invitation_meta": "{role} · expires {date}",
"@team_invitation_meta": {
  "placeholders": {"role": {"type": "String"}, "date": {"type": "String"}}
},

"invite_member_title": "Invite member",
"invite_member_email_label": "Email",
"invite_member_role_label": "Role",
"invite_member_submit": "Send invitation",
"invite_member_email_required": "Email required.",
"invite_member_owner_omitted_note": "Owner role is omitted: only one owner per farm; ownership transfer is a separate flow."
```

- [ ] **Step 9.2: Append matching Filipino translations to `app_fil.arb`**

```json
,
"equipment_list_title": "Kagamitan",
"equipment_list_filter_needs_repair": "Kailangang ayusin",
"equipment_list_filter_in_use": "Ginagamit",
"equipment_list_filter_available": "Available",
"equipment_list_empty_title": "Walang kagamitang tumutugma sa filter.",
"equipment_list_fab_add": "Magdagdag ng kagamitan",
"equipment_type_ventilation": "Ventilation",
"equipment_type_feeder": "Feeder",
"equipment_type_water_pump": "Water pump",
"equipment_type_generator": "Generator",
"equipment_type_scale": "Timbangan",
"equipment_type_vehicle": "Sasakyan",
"equipment_type_structure": "Estruktura",
"equipment_type_tool": "Kasangkapan",
"equipment_type_other": "Iba pa",
"equipment_status_in_use": "Ginagamit",
"equipment_status_available": "Available",
"equipment_status_needs_repair": "Kailangang ayusin",
"equipment_status_retired": "Hindi na ginagamit",
"equipment_card_area_with_type": "{type} · area {areaId}",

"equipment_add_title": "Bagong kagamitan",
"equipment_edit_title": "I-edit ang kagamitan",
"equipment_form_name_label": "Pangalan",
"equipment_form_type_label": "Uri",
"equipment_form_area_label": "Lugar (opsyonal)",
"equipment_form_area_none": "— walang lugar —",
"equipment_form_status_label": "Status",
"equipment_form_purchase_date_label": "Petsa ng pagbili (opsyonal)",
"equipment_form_purchase_date_none": "—",
"equipment_form_cost_label": "Halaga ng pagbili (PHP, opsyonal)",
"equipment_form_notes_label": "Mga tala (opsyonal)",
"equipment_form_submit": "I-save",
"equipment_form_name_required": "Kailangan ang pangalan.",

"equipment_detail_title": "Kagamitan",
"equipment_detail_type_label": "Uri: {value}",
"equipment_detail_status_label": "Status: {value}",
"equipment_detail_purchase_date_label": "Binili: {date}",
"equipment_detail_purchase_cost_label": "Halaga ng pagbili: ₱{value}",
"equipment_detail_maintenance_history": "Kasaysayan ng pagpapanatili",
"equipment_detail_no_maintenance": "Wala pang nai-log na maintenance.",
"equipment_detail_total_label": "Kabuuan: ₱{value}",
"equipment_detail_fab_log": "I-log ang maintenance",

"maintenance_type_preventive": "Preventive",
"maintenance_type_repair": "Pagkukumpuni",
"maintenance_type_inspection": "Inspeksiyon",
"maintenance_log_title": "I-log ang maintenance",
"maintenance_log_performed_by_label": "Nagsagawa (pangalan ng technician, opsyonal)",
"maintenance_log_parts_label": "Mga pinalitang parts (opsyonal)",
"maintenance_log_cost_label": "Halaga (PHP, opsyonal)",
"maintenance_log_notes_label": "Mga tala",
"maintenance_log_submit": "I-save",

"shifts_screen_title": "Shifts at Roster",
"shifts_section_all_shifts": "Lahat ng shift",
"shifts_card_daily": "Araw-araw",
"shifts_card_pattern": "{days} · {start}-{end} · lugar {areaId} · {workers} manggagawa",
"shift_pattern_daily": "Araw-araw",
"shift_pattern_weekly": "Lingguhan",
"shift_dow_sun": "L",
"shift_dow_mon": "L",
"shift_dow_tue": "M",
"shift_dow_wed": "M",
"shift_dow_thu": "H",
"shift_dow_fri": "B",
"shift_dow_sat": "S",

"shift_add_title": "Bagong shift",
"shift_edit_title": "I-edit ang shift",
"shift_form_name_label": "Pangalan ng shift",
"shift_form_pattern_label": "Pattern",
"shift_form_start_label": "Simula (HH:mm)",
"shift_form_end_label": "Tapos (HH:mm)",
"shift_form_area_label": "Lugar",
"shift_form_workers_label": "Mga manggagawa",
"shift_form_submit": "I-save ang shift",
"shift_form_delete": "Burahin",
"shift_form_name_required": "Kailangan ang pangalan ng shift.",
"shift_form_area_required": "Pumili ng lugar.",
"shift_form_days_required": "Pumili ng kahit isang araw para sa weekly shift.",

"tasks_screen_title": "Mga Gawain",
"tasks_tab_my": "Aking Gawain",
"tasks_tab_all": "Lahat ng Open",
"tasks_empty_my": "Walang gawaing naka-assign sa iyo.",
"tasks_empty_all": "Walang open na gawain.",
"task_type_pregnancy_check": "Pregnancy check",
"task_type_farrowing_prep": "Paghahanda sa panganganak",
"task_type_farrowing_expected": "Inaasahang panganganak",
"task_type_vaccination_due": "Bakuna",
"task_type_withdrawal_end": "Pagtatapos ng withdrawal period",
"task_type_manual": "Manual",
"task_card_due": "Due {date}",
"task_card_assigned_to": "naka-assign sa {kind}:{id}",
"task_card_mark_complete": "Markahan na tapos",

"task_create_title": "Bagong gawain",
"task_create_title_label": "Pamagat",
"task_create_description_label": "Deskripsyon",
"task_create_due_date_label": "Petsa ng due",
"task_create_assign_to_label": "I-assign sa",
"task_create_assign_type_label": "Uri",
"task_create_assign_none": "— walang nakatakda —",
"task_create_assign_user": "Tukoy na user",
"task_create_assign_area": "Kahit sinong manggagawa sa isang lugar",
"task_create_user_label": "User",
"task_create_area_label": "Lugar",
"task_create_submit": "Gumawa ng gawain",
"task_create_title_required": "Kailangan ang pamagat.",

"areas_list_title": "Mga Lugar",
"areas_list_empty": "Wala pang lugar. I-tap ang + para magdagdag.",
"areas_list_fab_add": "Magdagdag ng lugar",
"area_purpose_breeding": "Pagpapalahi",
"area_purpose_gestation": "Gestation",
"area_purpose_farrowing": "Panganganak",
"area_purpose_nursery": "Nursery",
"area_purpose_grow_finish": "Grow-Finish",
"area_purpose_quarantine": "Quarantine",
"area_purpose_boar_pen": "Kulungan ng Bulugan",
"area_purpose_isolation": "Isolation",
"area_purpose_other": "Iba pa",

"area_add_title": "Bagong lugar",
"area_edit_title": "I-edit ang lugar",
"area_form_name_label": "Pangalan",
"area_form_purpose_label": "Layunin",
"area_form_notes_label": "Mga tala (opsyonal)",
"area_form_submit_add": "I-save ang lugar",
"area_form_submit_edit": "I-save ang mga pagbabago",
"area_form_save_first_for_pens": "I-save muna ang lugar bago magdagdag ng kulungan.",
"area_form_name_required": "Kailangan ang pangalan ng lugar.",
"area_form_pens_section": "Mga kulungan",
"pen_dialog_title": "Magdagdag ng kulungan",
"pen_dialog_name_label": "Pangalan ng kulungan",
"pen_dialog_capacity_label": "Kapasidad (opsyonal)",
"pen_dialog_name_required": "Kailangan ang pangalan ng kulungan.",
"pen_dialog_capacity_positive": "Ang kapasidad ay dapat positibong buong numero.",
"pen_card_capacity_unknown": "Kapasidad: —",
"pen_card_occupancy": "Bilang: {current} / {capacity}",

"team_screen_title": "Team",
"team_section_members": "Mga miyembro",
"team_section_invitations": "Pending na imbitasyon",
"team_fab_invite": "Mag-imbita",
"team_member_role_label": "Tungkulin: {role}",
"team_role_owner": "May-ari",
"team_role_manager": "Manager",
"team_role_worker": "Manggagawa",
"team_role_vet": "Beterinaryo",
"team_invitation_meta": "{role} · mag-expire {date}",

"invite_member_title": "Mag-imbita ng miyembro",
"invite_member_email_label": "Email",
"invite_member_role_label": "Tungkulin",
"invite_member_submit": "Ipadala ang imbitasyon",
"invite_member_email_required": "Kailangan ang email.",
"invite_member_owner_omitted_note": "Ang tungkulin ng Owner ay hindi kasama: isang owner lang per farm; ang ownership transfer ay hiwalay na flow."
```

Run `flutter pub get`.

- [ ] **Step 9.3: Migrate the 12 files**

For each file under the respective feature directories, apply the same pattern: import AppLocalizations, grab `final l = ...` in build, replace strings.

Add localized enum helpers in domain layers:
- `equipment.dart` — `localizedEquipmentType(l, t)`, `localizedEquipmentStatus(l, s)`
- `maintenance_record.dart` — `localizedMaintenanceType(l, t)`
- `shift.dart` — `localizedShiftPattern(l, p)` + a `shiftDowLabels(AppLocalizations l) -> List<String>` returning the 7 single-letter day-of-week labels in S/M/T/W/T/F/S order.
- `task.dart` — `localizedTaskType(l, t)`
- `area.dart` — `localizedAreaPurpose(l, p)`
- `role.dart` — `localizedRole(l, r)` for owner/manager/worker/vet.

For `team_management_screen.dart`'s role dropdown items (currently `Text(r.value)`), use `localizedRole(l, r)`.

For the activity feed `DateFormat.MMMd()` call: pass the locale string from `Localizations.localeOf(context).toString()`.

- [ ] **Step 9.4: Run + commit**

```bash
flutter analyze && flutter test
git add -A
git commit -m "feat(i18n): equipment/shifts/tasks/areas/team migration (~80 keys, EN + FIL)

- 12 screens use AppLocalizations
- Enum helpers in domain layers (equipment type/status, maintenance type,
  shift pattern, task type, area purpose, role)
- Filipino: 'Kulungan ng Bulugan' (Boar Pen), 'Beterinaryo' (Vet),
  'Pagpapalahi' (Breeding)"
```

---

## Task 10: Tagalog completion (review + gap fill)

**Goal:** Comb through `app_fil.arb` to ensure every key in `app_en.arb` has a Filipino translation. Add `@key` metadata with `TRANSLATION-REVIEW` markers for non-trivial translations so a smoke test can grep them.

**Files:**
- Modify: `lib/src/l10n/app_fil.arb`

### Steps

- [ ] **Step 10.1: Diff EN vs FIL keys**

```bash
cd "/home/ccvisionary/Documents/Personal/[01] Ventures/[02] AgriTech/[01] FarmApp"
python3 -c "
import json
en = set(json.load(open('lib/src/l10n/app_en.arb')).keys())
fil = set(json.load(open('lib/src/l10n/app_fil.arb')).keys())
en_keys = {k for k in en if not k.startswith('@')}
fil_keys = {k for k in fil if not k.startswith('@')}
missing = en_keys - fil_keys
print('Missing in FIL:', sorted(missing))
"
```

Expected: empty list (Tasks 4-9 should have kept the ARB files in sync).

If anything is missing, add Filipino translations using the terminology guide in the spec §5.6.

- [ ] **Step 10.2: Add @ metadata blocks with TRANSLATION-REVIEW markers**

For every key in `app_fil.arb` whose translation isn't a trivial copy (not "OK", "GCash", "kg", etc.), add a metadata block:

```json
"@common_save": {
  "description": "TRANSLATION-REVIEW: 'I-save' — Filipino imperative for 'save'."
},
```

This is tedious. Bulk approach: rather than annotating every key, just commit a single grep-friendly marker by editing the file header:

```json
{
  "@@locale": "fil",
  "@@x-translation-review-pending": "All non-trivial translations were LLM-drafted on 2026-05-15. Native speaker review pending. Search 'TRANSLATION-REVIEW' to find specific concerns.",
  ...
}
```

For specific terms the LLM has lower confidence on (regional variation, jargon), do annotate individually:

```json
"@area_purpose_grow_finish": {
  "description": "TRANSLATION-REVIEW: kept 'Grow-Finish' as English term; some PH farms use 'Pataba'."
},
"@area_purpose_quarantine": {
  "description": "TRANSLATION-REVIEW: kept English; 'Kuwarentinas' exists but less common in farm context."
},
"@shift_dow_thu": {
  "description": "TRANSLATION-REVIEW: 'Huwebes' = H. Tagalog DoW: L/L/M/M/H/B/S — distinct from English S/M/T/W/T/F/S."
}
```

Add ~10–15 such markers for the most translation-fragile keys.

- [ ] **Step 10.3: Run + commit**

```bash
flutter analyze && flutter test
git add -A
git commit -m "feat(i18n): Tagalog completion + TRANSLATION-REVIEW markers

- Diff EN vs FIL confirms key parity (no orphans)
- @@x-translation-review-pending header marker for whole-file scan
- ~12 individual @ metadata blocks flagging translation-fragile keys
  (region-specific terms, days-of-week initial collisions)
- Ready for native-speaker pass during manual smoke checklist"
```

---

_(Tasks 11–15 continue. Each follows the established TDD + commit cadence. Remaining tasks cover the four polish items (activity-on-update, UserDisplay widget, PhotoUploadError classification, pie chart side legend) and the perf audit.)_
