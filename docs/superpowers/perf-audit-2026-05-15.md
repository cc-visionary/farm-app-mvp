# Performance Audit — 2026-05-15

**Branch:** `feature/swine-crm-foundation`
**Device class (target):** Android 11 emulator @ 2 GB RAM (or low-end real device).
**Build mode:** profile.
**Author:** C-Task 15 implementer.

---

## Scope of this audit

Sub-project C, Task 15 calls for a profile-mode run, three DevTools traces
(cold start, pigs list scroll, batch P&L render), and a set of obvious-win
fixes derived from those measurements.

> **Important — baseline + post-fix measurements are deferred.**
>
> The audit was performed in an environment without an attached Android device
> or running emulator, so `flutter run --profile` and the associated DevTools
> traces could not be captured. The placeholders below are marked
> `<requires-device>` and should be filled in by the next engineer who runs
> the app on hardware. The structural fixes that do NOT require profiling
> evidence (const lints, RepaintBoundary around known-hot chart widgets,
> image-rendering audit) were applied in this slice.

---

## Baseline measurements

| Metric | Baseline | Notes |
|---|---|---|
| Cold start → Dashboard | `<requires-device>` ms | From `flutter run --profile -d <device>` to first interactive frame. |
| Pigs list 60-frame scroll | mean: `<requires-device>` ms / 99p: `<requires-device>` ms | Seed with 50 pigs. |
| Batch P&L first paint | `<requires-device>` ms | 1 batch with ≥4 cost categories. |
| Memory after navigating every screen | `<requires-device>` MB | RSS via DevTools Memory tab. |

---

## Findings

DevTools-derived findings cannot be enumerated until a profile run is
captured. The following structural observations were derived from
static analysis of the codebase during this slice:

1. **Const-cleanliness — already excellent.** After enabling
   `prefer_const_constructors`, `prefer_const_constructors_in_immutables`,
   and `prefer_const_literals_to_create_immutables` in
   `analysis_options.yaml`, `flutter analyze` reported **0 violations** and
   `dart fix --apply` reported **"Nothing to fix"**. The codebase appears to
   have been written with const-discipline from day one. No auto-fixes were
   needed.

2. **Chart widgets — newly isolated with `RepaintBoundary`.** Two raster-heavy
   widgets that are known to repaint on any ancestor rebuild were wrapped:
   - `_CostPie` (the PieChart inside `batch_profitability_screen.dart`).
   - `_AreaBarChart` (the BarChart inside `yield_screen.dart`).

   Both wraps are *defensive*, not based on a captured trace. They are safe
   because:
   - Charts have substantial per-frame raster cost relative to surrounding
     content.
   - The wrapped widgets are stateless and small in tree depth, so the
     RepaintBoundary itself does not add measurable overhead.

3. **Network images — already 100% cached.** `grep -rn "Image\.network"
   lib/src/` returned **zero hits**. All photo rendering in the app already
   goes through `cached_network_image` (verified earlier in Sub-project A).

4. **`ref.watch(provider.select(...))` opportunities — deferred.**
   The plan calls out 2–4 such refactors but only when the profiler points
   at a specific watcher as a rebuild hot spot. Without profiler evidence we
   did NOT speculatively refactor providers — over-eager `select` can hurt
   readability without measurable benefit. Future engineer should:
   1. Capture the rebuild inspector from DevTools on Dashboard and Yield
      screens.
   2. For any provider rebuild that fires more often than its consumed slice
      changes, introduce a `select(...)`.

---

## Fixes applied in this slice

- **Enabled three `prefer_const*` lints** in `analysis_options.yaml`.
  Outcome: 0 new analyzer issues — codebase already const-clean.
- **`dart fix --apply`**: ran clean, "Nothing to fix".
- **`RepaintBoundary` around `_CostPie`** in
  `lib/src/features/profitability/presentation/batch_profitability_screen.dart`.
- **`RepaintBoundary` around `_AreaBarChart`** in
  `lib/src/features/yield/yield_screen.dart`.
- **Verified `cached_network_image` coverage**: zero `Image.network` hits in
  `lib/src/`.

### Fixes explicitly NOT applied

- **No `ref.watch(provider.select(...))` refactors** — see Finding 4 above.
  Awaiting profiler evidence.
- **No speculative `RepaintBoundary` on activity feed cards or pig list
  rows** — the plan permits this only when the long-scroll trace shows
  raster-thread jank. Static guesswork could increase memory pressure.
- **No bundle-size, image-asset, or font-subsetting changes.**
- **No engine flag or `--tree-shake-icons` tweaks** — out of scope.

---

## Post-fix measurements

| Metric | Post-fix | Δ from baseline |
|---|---|---|
| Cold start → Dashboard | `<requires-device>` ms | `<requires-device>` |
| Pigs list 60-frame scroll | mean: `<requires-device>` ms / 99p: `<requires-device>` ms | `<requires-device>` |
| Batch P&L first paint | `<requires-device>` ms | `<requires-device>` |

The const-lint + RepaintBoundary fixes are conservative; the expected
improvement on a low-end device class is in the single-digit-percent range
on the chart-render frames. The bigger wins (if any) will surface only after
the profile run reveals where rebuild storms or raster spikes actually live.

---

## How to complete this audit on a real device

When a device is available:

```bash
# 1. Pick a profile-mode target.
flutter devices
flutter run --profile -d <device-id>

# 2. Capture DevTools traces:
flutter pub global activate devtools
flutter pub global run devtools
# Open Performance tab; record:
#   - Cold start to Dashboard
#   - Pigs list 60-frame scroll (seed 50 pigs first)
#   - Batch P&L first paint
# Open Memory tab; capture RSS after touching every screen.

# 3. Fill in the placeholders above.

# 4. Inspect the rebuild inspector. Note any provider watcher that fires
#    more often than its consumed slice changes — replace those with
#    ref.watch(provider.select((x) => …)).

# 5. If the trace shows raster-thread jank during list scroll, add
#    RepaintBoundary around the list-card widget. Re-measure to confirm.
```

---

## Open follow-ups (not in this slice)

- Capture the baseline + post-fix numbers on the target device class.
- Decide on speculative `RepaintBoundary` for activity feed cards based on
  scroll-trace evidence.
- Audit Riverpod `watch` patterns on Dashboard and Yield screens with the
  rebuild inspector; introduce `select(...)` where it shrinks the rebuild
  scope.
- Track app-startup work that happens synchronously in `main.dart` — every
  millisecond there shows up directly in cold-start.
- Re-run `flutter build apk --analyze-size` to capture the final APK size
  baseline; compare to pre-Sub-project-C size.
