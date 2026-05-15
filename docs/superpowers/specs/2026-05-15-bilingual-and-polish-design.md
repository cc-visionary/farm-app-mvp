# Bilingual & Polish — Design Spec

**Date:** 2026-05-15
**Sub-project:** C (third in the planned series; A — Swine CRM Foundation — and B — Operations & Financials — complete on `feature/swine-crm-foundation`)
**Status:** Approved scope, ready for implementation planning

---

## 1. Overview

Three coordinated workstreams that round out the production readiness of FarmApp before user testing with PH piggery operators:

1. **Bilingual EN/Filipino** — full app localization using Flutter's official `flutter_localizations` + `gen-l10n` toolchain. ~250 user-facing strings extracted to ARB files; Filipino translations drafted by LLM with Philippine swine domain terminology, marked for manual review during smoke test.
2. **UX polish items deferred from Sub-projects A and B** — four real items flagged during reviews: activity entries on `update*` methods, display-name resolution everywhere, photo upload error classification, pie chart label legibility on profitability.
3. **Low-end Android performance audit** — profile the app on a target low-end device class (2GB RAM, mid-2010s Android), document findings, apply obvious-win fixes (missing `const`, `RepaintBoundary` placement, Riverpod `select` to reduce rebuilds).

This spec defines **Sub-project C only**. Push notifications, telemedicine, Daily Checkup, poultry, and B2B marketplace remain in Sub-projects D, E, F respectively.

## 2. Goals

1. **Make the app usable for Tagalog-first workers** — a farrowing attendant in Bulacan who reads more comfortably in Filipino should never have to guess at an English label.
2. **Respect user choice and OS convention** — follow the device language by default; honor an in-app override for households where the phone is shared.
3. **Close audit-trail gaps** — `update*` operations on Equipment, Pig, and Supply currently bypass the activity feed. Owners deserve to see every meaningful state change.
4. **Make failure modes legible** — silent `catch (_)` in photo upload masks real problems; workers in low-signal barns deserve a SnackBar that says "Will retry when online" not a void.
5. **Render quickly on a ₱5,000 Android phone** — the target user often has exactly that. Profile, fix, document.

## 3. Non-goals

- **Other PH languages.** Bisaya, Cebuano, Ilocano, Hiligaynon — out of scope. The `app_fil.arb` shape generalizes, so future locales can be added without architectural change.
- **Right-to-left support.** Not relevant for any PH language.
- **Translation Memory / TMS integration.** ARB files are the source of truth; future native-speaker passes happen by editing those files directly. No Crowdin/Lokalise integration.
- **Cloud Functions for any deferred items** (withdrawal-end task skipping on sold pigs, supply_movements admin corrections). These are explicitly deferred from Sub-projects A and B; revisit in a future sub-project that's specifically about Cloud Functions.
- **Formal performance SLAs** — we measure, we fix what's obvious, but we don't gate ship on numeric budgets in v1.
- **Accessibility audit beyond defaults.** WCAG-level compliance pass is a separate effort.
- **Custom RTL/LTR icon flipping.** All glyphs are direction-agnostic.

## 4. Personas affected

No changes to the role model. i18n changes affect all four roles uniformly. Polish items respect existing permission gates from Sub-projects A and B.

| Role | Sub-project C impact |
|---|---|
| Owner | Sees new Activity entries for update events; pie chart on Batch P&L now legible. |
| Manager | Same as Owner. Plus: display-name lookups improve shift/task UI. |
| Worker | **Biggest beneficiary of i18n.** Settings → Language → Filipino renders the app in Tagalog with appropriate piggery terminology. Photo upload errors now surface visibly. |
| Veterinarian | Same i18n benefit as Worker. |

## 5. i18n architecture

### 5.1 Stack and config

- **Package**: `flutter_localizations` from the Flutter SDK + `gen-l10n` (built into the SDK; no third-party additions).
- **ARB files**: `lib/src/l10n/app_en.arb` (template, English source) and `lib/src/l10n/app_fil.arb` (Filipino translations). ARB is JSON-ish with ICU plurals and metadata.
- **Locale code for Filipino**: `fil` (per ISO 639-2 and Flutter convention). Not `tl` (Tagalog), not `ph`.

### 5.2 Files

```
pubspec.yaml
  dependencies:
    flutter_localizations:
      sdk: flutter
  flutter:
    generate: true            # enables gen-l10n

l10n.yaml                     # new at repo root
  arb-dir: lib/src/l10n
  template-arb-file: app_en.arb
  output-localization-file: app_localizations.dart
  nullable-getter: false
  synthetic-package: false
  output-dir: lib/src/l10n/generated

lib/src/l10n/
  app_en.arb                  # ~250 keys, English source
  app_fil.arb                 # ~250 keys, Filipino translations
  generated/                  # gen-l10n output (gitignored)
```

`MaterialApp.router`:
```dart
localizationsDelegates: AppLocalizations.localizationsDelegates,
supportedLocales: AppLocalizations.supportedLocales,  // [en, fil]
locale: ref.watch(localePreferenceProvider),          // null → follow OS
```

### 5.3 Key naming convention

Snake_case, `<feature>_<screen-or-context>_<element>` pattern. Examples grouped by feature:

```json
{
  "common_save": "Save",
  "common_cancel": "Cancel",
  "common_back": "Back",
  "common_loading": "Loading…",
  "common_required_field_named": "{field} is required.",
  "@common_required_field_named": {
    "description": "Validation error when a named field is empty.",
    "placeholders": {
      "field": {"type": "String", "example": "Buyer name"}
    }
  },
  "common_pigs_count": "{count,plural, =0{No pigs} =1{1 pig} other{{count} pigs}}",
  "@common_pigs_count": {
    "description": "Pluralized pig head count.",
    "placeholders": {
      "count": {"type": "int"}
    }
  },

  "auth_login_title": "Welcome to FarmApp",
  "auth_login_email_label": "Email",
  "auth_login_password_label": "Password",
  "auth_login_submit": "Sign in",
  "auth_login_no_account_cta": "Create an account",

  "pigs_list_title": "Pigs",
  "pigs_list_search_hint": "Search by tag ID",
  "pigs_list_empty_title": "No pigs yet",
  "pigs_list_empty_subtitle": "Tap + to add your first pig.",
  ...
}
```

### 5.4 Locale-aware formatting

Numbers, currency, and dates use `intl` with the current locale:

| Concern | Approach |
|---|---|
| Currency | `NumberFormat.currency(locale: locale.toString(), symbol: '₱', decimalDigits: 0)` — always PHP, format respects locale separators. |
| Counts (decimal) | `NumberFormat.decimalPattern(locale.toString()).format(value)`. |
| Dates | `DateFormat.yMMMd(locale.toString()).format(dt)`. Filipino: "Mayo 15, 2026". |
| Time | `DateFormat.jm(locale.toString())`. |
| Plurals | ICU plural in ARB (`{count,plural, ...}`). |

A small helper `intl_helpers.dart` under `lib/src/core/i18n/` exposes `formatCurrencyPhp(BuildContext, num)` and `formatDate(BuildContext, DateTime)` to centralize locale-fetching from `Localizations.localeOf(context)`.

### 5.5 Locale switching UX

- **Default**: follow OS locale. Flutter's `localeResolutionCallback` is left at default — `AppLocalizations.supportedLocales` matches the OS locale where possible.
- **Override**: Settings screen gains a "Language" tile with three options: *System* (default), *English*, *Filipino*.
- **Persistence**: `SharedPreferences` key `app_locale` stores `null` (system) / `en` / `fil`.
- **State**: `localePreferenceProvider` (StateProvider<Locale?>) reads from prefs on app init, writes on selection. `MaterialApp.locale` watches it.

### 5.6 Filipino translation strategy

LLM-drafted with these conventions:

- **Use natural Filipino** for common UI: *I-save*, *Kanselahin*, *Maghanap*, *Magdagdag*.
- **Keep English technical terms** that are universally understood: *Tag ID*, *GCash*, *kg*, *₱*, *Bluetooth* (n/a here), *email*.
- **Pig terminology**:
  - pig → *baboy*
  - sow → *inahin*
  - boar → *bulugan*
  - piglet → *biik*
  - gilt → *dumalaga*
  - feed → *pakain*
  - farrowing → *panganganak*
  - vaccination → *bakuna*
  - mortality → *kamatayan ng hayop* (or just keep *mortality* in some contexts where the medical register is clearer)
  - withdrawal period → *withdrawal period* (kept English — a regulatory term most users recognize in English)
- **Loanwords welcome where natural**: *farm*, *vendor*, *receipt*, *batch* all OK.
- **Code-switching when it reads better**: "Magdagdag ng Pig" rather than "Magdagdag ng Baboy" in some technical contexts where the data model is the noun, not the animal.
- **Translation review marker**: each `app_fil.arb` entry whose translation wasn't trivially copied gets an `@key` block with `"description": "TRANSLATION-REVIEW: ..."` so a `grep -n "TRANSLATION-REVIEW" lib/src/l10n/app_fil.arb` enumerates everything to double-check.

### 5.7 Migration approach for ~250 strings

15 implementation slices (§9). Slices 4–9 walk feature-by-feature, extracting strings as we go. Each commit replaces hardcoded strings in 5–10 files with `AppLocalizations.of(context).<key>` calls and adds the corresponding entries to `app_en.arb`. `app_fil.arb` gets stubs filled in slice 10 once the full key inventory is settled.

## 6. Polish items

### 6.1 Activity entries on `update*` methods

**Problem**: `EquipmentRepository.updateEquipment`, `PigRepository.updatePig`, and `SupplyRepository.updateSupply` silently mutate documents without writing an activity entry. The activity feed shows creates and status changes but not generic updates. Owners auditing "what changed on Pig SOW-001 yesterday?" miss edits.

**Fix**: Each `update*` method runs inside a `WriteBatch` that includes an `ActivityRepository.addActivityToBatch` write. Action strings:
- `equipment_updated` — summary: "{actor} updated equipment {name}"
- `pig_updated` — summary: "{actor} updated pig {tagId}"
- `supply_updated` — summary: "{actor} updated supply {name}"

**Signature changes**: each method gains `actorUserId` and `actorDisplayName` parameters. Call-sites in Add/Edit screens already have these from existing patterns.

**Tests**: 3 repository tests confirming the activity entry lands atomically with the update.

### 6.2 Display name resolution everywhere

**Problem**: Several screens still show raw Firebase UIDs where a human-readable name belongs.
- `shifts/edit_shift_screen.dart` — worker chip labels
- `shifts/roster_widget.dart` — "On shift" list rendering
- `tasks/create_task_screen.dart` — "Specific user" assign-to dropdown
- `tasks/tasks_screen.dart` — assigned-to subtitle on task cards

**Fix**: A reusable `_UserDisplay` ConsumerWidget at `lib/src/core/widgets/user_display.dart`:

```dart
class UserDisplay extends ConsumerWidget {
  const UserDisplay({super.key, required this.userId, this.style});
  final String userId;
  final TextStyle? style;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameAsync = ref.watch(userDisplayNameProvider(userId));
    return Text(nameAsync.asData?.value ?? userId, style: style);
  }
}
```

Replace `Text(uid)` at the 4 known call sites with `UserDisplay(userId: uid)`.

**Tests**: One widget test asserting the widget renders the resolved name when the provider returns data, and falls back to the UID while loading.

### 6.3 Photo upload error classification

**Problem**: `PhotoUploadService.uploadAndAttach` and `flushQueue` both do `catch (_) { ... enqueue ... }`. This means a permanent failure (permission denied, bucket quota exhausted) gets queued forever, silently. Workers don't know the upload didn't make it.

**Fix**:

1. New file `lib/src/core/errors/photo_upload_error.dart`:
```dart
enum PhotoUploadErrorKind { retryable, terminal }

class PhotoUploadError implements Exception {
  PhotoUploadError({required this.kind, required this.code, this.cause});
  final PhotoUploadErrorKind kind;
  final String code;
  final Object? cause;

  static PhotoUploadError classify(Object e) {
    if (e is FirebaseException) {
      switch (e.code) {
        case 'unauthenticated':
        case 'permission-denied':
        case 'invalid-argument':
        case 'quota-exceeded':
          return PhotoUploadError(kind: PhotoUploadErrorKind.terminal, code: e.code, cause: e);
        case 'unavailable':
        case 'deadline-exceeded':
        case 'cancelled':
        case 'internal':
          return PhotoUploadError(kind: PhotoUploadErrorKind.retryable, code: e.code, cause: e);
      }
    }
    if (e is SocketException || e is TimeoutException) {
      return PhotoUploadError(kind: PhotoUploadErrorKind.retryable, code: 'network', cause: e);
    }
    return PhotoUploadError(kind: PhotoUploadErrorKind.retryable, code: 'unknown', cause: e);
  }
}
```

2. `PhotoUploadService.uploadAndAttach`:
   - Catches → classifies.
   - Retryable → enqueue (current behavior).
   - Terminal → does NOT enqueue. Publishes the error to a `photoUploadErrorStreamProvider` (StreamController-backed).
   - Returns `null` in both cases (caller decides if it needs to react).

3. UI surface: a small listener widget mounted under `AppShell` (top of the tree) subscribes to the error stream and shows a `SnackBar` with appropriate message.

4. `flushQueue` similarly removes terminal-error entries from the queue (with logging) instead of leaving them forever.

**Tests**: 3 unit tests covering classify for: a network exception → retryable; a `permission-denied` Firebase exception → terminal; a `unavailable` Firebase exception → retryable.

### 6.4 Pie chart label legibility

**Problem**: `BatchProfitabilityScreen._CostPie` puts category labels (e.g., "Feed", "Med") inside each slice with white text. Slices colored `primaryContainer` (light green) and `surfaceContainerHigh` (light grey) make the text borderline unreadable.

**Fix**: Remove in-slice labels. Show percentages on slices ≥ 8% (so labels don't overlap on small slices). Below the chart, render a `Wrap` of legend rows: small colored square + category name + value, using `bodyMedium` style on `onSurface` background.

**Tests**: No new tests (UI-only change). Manual smoke step covers it.

## 7. Performance audit

### 7.1 Method

- **Profile environment**: `flutter run --profile -d <android-low-end-emulator>` with Flutter DevTools attached. If a physical low-end Android device is available, prefer that. Target device class: 2GB RAM, Android 9–11.
- **Measure**:
  - Cold start time (from `flutter run` finish to first interactive screen).
  - UI thread frame times during scroll on Pigs list, Activity feed, Yield Reports.
  - Raster thread frame times during chart rendering on Yield + Batch P&L screens.
  - Memory baseline after login + after navigating every primary screen.
- **Document** in `docs/superpowers/perf-audit-2026-05-15.md` with screenshots + numbers.

### 7.2 Fix scope (obvious wins only)

After measurement, apply these classes of fix if and only if they show measurable improvement in DevTools:

1. **Add `const` to widget constructors** where missing. Enable analyzer `prefer_const_constructors` lint temporarily, audit, fix, then keep the lint enabled going forward.
2. **`RepaintBoundary`** around `BarChart`, `PieChart`, and around each `Card` in long scroll lists if isolated repaints reduce raster cost.
3. **Riverpod `ref.watch(provider.select((x) => x.specificField))`** in screens that watch a large object but only need one field. Reduces rebuild scope.
4. **Image rendering audit**: every `Image.network(...)` call must be `CachedNetworkImage(...)`. `cached_network_image` is already in pubspec.
5. **Photo compression**: verify `image_picker`'s `imageQuality: 80, maxWidth: 1280, maxHeight: 1280` is set on every `pick()` call (it is, but verify after the audit).
6. **Reduce widget tree depth** where it's obviously bloated (no specific targets identified upfront — only fix what the profiler points at).

### 7.3 What we do NOT do

- No formal frame-time / cold-start SLA.
- No `Isolate` work or heavy parallelism (Firestore SDK + image_picker are already off the UI thread).
- No replacement of `fl_chart` with a faster lib unless the profiler shows it's a top offender.
- No Material 3 → Material 2 downgrade or other large refactors.

## 8. File structure additions

```
lib/src/
├─ l10n/
│   ├─ app_en.arb
│   ├─ app_fil.arb
│   └─ generated/                  (gitignored — flutter gen-l10n output)
├─ core/
│   ├─ i18n/
│   │   └─ intl_helpers.dart       (formatCurrencyPhp, formatDate, …)
│   ├─ locale/
│   │   ├─ locale_preference.dart  (StateProvider, SharedPreferences-backed)
│   │   └─ locale_providers.dart
│   ├─ errors/
│   │   └─ photo_upload_error.dart (PhotoUploadError + classify)
│   └─ widgets/
│       └─ user_display.dart       (ConsumerWidget for userDisplayNameProvider)
└─ features/settings/presentation/
    └─ language_setting_section.dart  (or inline within settings_screen.dart)

l10n.yaml                          (repo root, new)
docs/superpowers/
└─ perf-audit-2026-05-15.md        (new)
```

Modifications:
- `lib/main.dart` — `localizationsDelegates`, `supportedLocales`, `locale` wired
- `lib/src/routing/app_router.dart` — `MaterialApp.router` already constructed in main; nothing to change there
- Every screen file (~30 files) — strings extracted and replaced with `AppLocalizations.of(context).<key>`
- `lib/src/features/equipment/data/equipment_repository.dart` — `updateEquipment` becomes atomic batch with activity entry
- `lib/src/features/pigs/data/pig_repository.dart` — `updatePig` ditto
- `lib/src/features/inventory/data/supply_repository.dart` — `updateSupply` ditto
- `lib/src/features/media/photo_upload_service.dart` — error classification
- `lib/src/features/media/media_providers.dart` — add `photoUploadErrorStreamProvider`
- `lib/src/core/widgets/app_shell.dart` — subscribe to error stream, render SnackBar
- `lib/src/features/profitability/presentation/batch_profitability_screen.dart` — pie chart side legend
- `lib/src/features/shifts/presentation/edit_shift_screen.dart`, `roster_widget.dart`, `lib/src/features/tasks/presentation/create_task_screen.dart`, `tasks_screen.dart` — `UserDisplay` adoption
- `pubspec.yaml` — `flutter.generate: true`, `flutter_localizations` dep
- `analysis_options.yaml` — enable `prefer_const_constructors` lint

## 9. Implementation slices (preview for `writing-plans`)

15 slices, each independently shippable:

1. **i18n scaffolding** — pubspec changes, `l10n.yaml`, empty `app_en.arb` / `app_fil.arb`, `MaterialApp` wiring with placeholder `Hello world` key, build runs cleanly.
2. **Locale preference + Settings language selector** — `localePreferenceProvider` backed by `SharedPreferences`, Settings screen "Language" section with System / English / Filipino choice chips, persistence.
3. **Common strings + intl helpers** — extract `common_*` keys (Save, Cancel, Back, Loading, Yes, No, Confirm, Delete, Required field), build `intl_helpers.dart` with locale-aware currency/date formatters.
4. **String migration — auth & farm setup** — login, signup, create farm, accept invitation, farm setup screens.
5. **String migration — pigs** — pigs list, pig detail (4 tabs), add/edit pig, breeding log, farrowing log, health log, mortality log.
6. **String migration — inventory & purchases** — inventory list, supply detail, add/edit supply, log consumption, purchases list, log purchase.
7. **String migration — sales & expenses** — sales list, sale detail, log sale, expenses list, log expense.
8. **String migration — dashboard & reports** — dashboard, snapshot card, my tasks card, roster widget, yield reports, batches list, batch profitability, activity feed/screen, farm layout.
9. **String migration — equipment, shifts, tasks, areas, team** — remaining feature screens.
10. **Tagalog translations (app_fil.arb)** — LLM-drafted Filipino for all keys, with `TRANSLATION-REVIEW` markers and metadata.
11. **Polish A: Activity on `update*`** — Equipment/Pig/Supply repository `update*` methods become atomic with activity entries; 3 new tests.
12. **Polish B: Display name resolution** — `UserDisplay` widget + 4 call-site refactors + 1 widget test.
13. **Polish C: Photo upload error classification** — `PhotoUploadError` typed exception, classify(), terminal-vs-retryable handling in `uploadAndAttach` + `flushQueue`, error-stream provider, UI surface in `AppShell`, 3 unit tests.
14. **Polish D: Pie chart side legend** — `BatchProfitabilityScreen._CostPie` refactor.
15. **Perf audit + obvious-win fixes** — profile, document in `perf-audit-2026-05-15.md`, enable `prefer_const_constructors`, add `RepaintBoundary` where measured, swap to `select` where measured, verify image rendering paths. Final commit.

## 10. Testing strategy

- **Existing 140 tests**: must continue to pass. String extraction does not change behavior — tests are largely unaffected.
- **New tests added in this sub-project** (~9 total):
  - 1 widget test for `UserDisplay` resolution.
  - 3 repository tests for activity-on-update (Equipment, Pig, Supply).
  - 3 unit tests for `PhotoUploadError.classify`.
  - 1 widget test for locale-aware date formatting (verifying May vs Mayo on `Locale('fil')`).
  - 1 widget test for `AppLocalizations` loading the right .arb for a given locale.
- **Manual smoke checklist additions**: a new "Sub-project C — Filipino smoke" section listing the primary user flows to walk through with `locale: fil` set.

Final test count target: **~149 tests passing**, `flutter analyze` at **0 issues**.

## 11. Open implementation decisions (resolve during planning, not now)

- **Cold-start budget**: the perf audit will document the baseline; a numeric target (e.g., "under 3 seconds on a 2GB Android") is set after measurement, not in advance.
- **`prefer_const_constructors` lint scope**: enabling globally may surface many warnings. Plan resolves them all in slice 15; if the count is unwieldy, we may scope by directory.
- **Filipino translations for rare strings** (debug-only labels, deeply nested error messages): if a string is engineering-only and unlikely to face a worker, it can be left in English with a comment in `app_fil.arb`. Decided per-string during slice 10.
- **`pluralization` for irregular cases**: most plurals in Filipino don't inflect the noun (one pig = isang baboy, two pigs = dalawang baboy — "baboy" stays the same). ICU plurals still work; we just route both `=1` and `other` to the same template.

## 12. Future sub-projects (still deferred)

- **D — Notifications, telemedicine & Daily Checkup:** FCM push for tasks & overdue alerts; vet appointment scheduling; async photo-based consults; EveryPig-style Daily Checkup pen-walk.
- **E — Poultry module:** replicate framework for layers/broilers.
- **F — Marketplace:** B2B feed/pharma listings, buyer connections.

## 13. Success criteria

Sub-project C is "done" when:

1. Setting the device language to Filipino renders every primary screen in Tagalog without `?key?` placeholder text or layout breakage.
2. Switching the in-app language toggle to English overrides the system Filipino setting and persists across app restarts.
3. Switching to System (null) on a Filipino phone produces Tagalog UI; switching to System on an English phone produces English UI.
4. Currency values render with `₱` and locale-correct separators ("₱48,000" stays as is; both locales use the same thousands separator).
5. Dates render in the locale's month names: "May 15, 2026" (en) vs "Mayo 15, 2026" (fil).
6. Plural counts render correctly: "1 pig" / "12 pigs" (en); "1 baboy" / "12 baboy" (fil).
7. Updating equipment, pig, or supply writes a corresponding activity entry visible in the Activity feed.
8. Workers see colleague display names (not Firebase UIDs) in Shifts chips, Tasks dropdown, and Activity feed.
9. Toggling airplane mode mid-photo-upload of a health record produces a "Will retry when online" SnackBar (retryable error) within ≤2 seconds.
10. A simulated permission-denied photo upload produces a "Couldn't upload photo: permission denied" SnackBar and does NOT queue indefinitely.
11. The Batch Profitability cost pie chart has a side legend with readable category names and values; in-slice text shows percentages only on slices ≥ 8%.
12. The perf audit document exists at `docs/superpowers/perf-audit-2026-05-15.md` with baseline + post-fix numbers and a brief commentary.
13. All ~149 tests pass; `flutter analyze` stays at **0 issues** with `prefer_const_constructors` enabled.

---

**Pre-implementation reading:** `CLAUDE.md`, `.impeccable.md`, the two prior spec docs (`2026-05-14-swine-crm-foundation-design.md`, `2026-05-14-operations-financials-design.md`). Design contract, atomicity contract, role-gating, and the activity-entry-with-every-mutation rule are inherited from there.
