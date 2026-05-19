# Perf Audit Run-Through Guide

**Companion to:** `docs/superpowers/perf-audit-2026-05-15.md`
**Audience:** Engineer with a physical Android device (and optionally an iPhone) sitting in front of them
**Goal:** Fill in every `<requires-device>` placeholder in `perf-audit-2026-05-15.md` with a real measured number, then apply targeted fixes for anything the profiler flags.

> Do **not** modify `perf-audit-2026-05-15.md` while reading this guide. Capture numbers as you go, then transcribe them in a single pass at step 8.

---

## 1. Equipment + setup

### Recommended target device (Android — the bar)

A **2 GB-RAM Android 11 phone** in the ₱5,000 PH-market tier. Any of the following are representative of what a real Worker in a barn is holding:

- **Realme C25 / C25Y / C30** (2 GB RAM, Helio G70/G35, Android 11)
- **Cherry Mobile Aqua S10 / S11**
- **MyPhone myXI3 / myA21**
- **Infinix Smart 6 / Hot 10 Lite**
- **Samsung Galaxy A03 / A04** (2 GB SKU)

**Document the exact model used** at the top of `perf-audit-2026-05-15.md` (manufacturer, model, RAM, Android version, build number). Numbers without device context are useless to the next engineer.

### Emulator alternative (only if no device available)

Android Studio AVD with a low-RAM profile:

1. AVD Manager → Create Virtual Device → pick **Pixel 3**.
2. New Hardware Profile (or clone Pixel 3 and edit):
   - RAM: **2048 MB**
   - VM heap: **256 MB**
   - Internal storage: 4 GB
   - Performance: **Software – GLES 2.0** (forces CPU rasterization, closer to low-end GPU)
3. System image: Android 11 (API 30), x86_64.
4. Advanced settings → CPU cores: **2**.

Emulator numbers will be **optimistic** vs. a real ₱5k phone. Treat them as a floor, not the bar.

### iOS equivalent (nice-to-have, not blocker)

- **iPhone SE (2020)** — A13, 3 GB RAM. This is the low-end iOS target.
- **iPhone SE (1st gen, 2016)** — A9, 2 GB RAM. If the app feels good here, it feels good anywhere on iOS.

iOS is held to a softer bar than Android (see §13).

### Pre-flight checklist

- [ ] Device unlocked, USB debugging on (Android) or paired in Xcode (iOS).
- [ ] `flutter doctor` clean.
- [ ] `flutter devices` shows the target.
- [ ] App's Firebase project pointed at the **staging** project, not prod — seeding 50 pigs in prod is rude.
- [ ] Battery > 50 % and not in low-power mode (low-power throttles the CPU and skews everything).
- [ ] Device temperature normal — a hot phone thermal-throttles silently.

---

## 2. Build for profile mode

**Always use `--profile`. Never measure perf in `--debug`.** Debug mode has assertion checks, debug-only allocations, and disables the AOT compiler — numbers will be 3–5× worse than what users see.

### Android

```bash
flutter run --profile -d <device-id>
```

Where `<device-id>` comes from `flutter devices` (e.g. `RMX3624` for a Realme).

### iOS

```bash
flutter run --profile -d <device-id>
```

(Same flag; works identically.)

### What you should see

Console prints a line like:

```
The Flutter DevTools debugger and profiler on Realme C25 is available at:
http://127.0.0.1:9100?uri=http://127.0.0.1:54321/abc123=/
```

Copy that URL. That's your DevTools entry point.

> **Heads up:** profile builds are slower to compile (full AOT). First build can take 2–3 minutes on a 2 GB device. Be patient.

---

## 3. Open Flutter DevTools

1. Paste the URL from `flutter run --profile` into Chrome.
2. Top nav → **Performance** tab.
3. Settings cog (top-right of the Performance tab):
   - Enable **Track Widget Builds** (lets you see rebuild counts per widget — invaluable for spotting `Consumer` over-rebuilds).
   - Enable **Track Layouts** and **Track Paints** (helps localize jank to a phase).
4. Hit **Start recording** when you're ready to capture.

> **Tip:** DevTools traces get huge fast. Keep recordings under ~10 seconds. Longer captures freeze the DevTools UI on low-RAM dev machines.

---

## 4. Capture: Cold start → Dashboard

**What we're measuring:** time from launcher tap to "user can do something useful."

### Steps

1. Force-kill the app on the device (swipe away from recents AND clear from system settings if needed — Flutter holds some state).
2. In DevTools: **Start recording**.
3. Tap the app icon on the launcher.
4. Watch the screen. The instant the Dashboard is fully painted (cards visible, no spinner, no skeleton), **stop recording**.

### What to record

| Sub-metric | How to read it |
|---|---|
| Launch → first frame | DevTools timeline: find the first `Frame` event after process start. Capture its `vsync` timestamp minus launch. |
| First frame → interactive | From first frame to the moment the Dashboard's data-bound widgets are rendered (Activity feed showing, KPI cards populated). |
| Frames > 16 ms on UI thread | DevTools highlights these in red in the Frames chart. Count them. |
| Top contributor | Scroll through the Timeline events panel. Look for the longest single span — usually a Firestore `get`, the auth-state stream init, or font loading. |

### Target

- **< 2,500 ms** launch → interactive on a 2 GB Android device.
- **< 5 jank frames** during the launch sequence.

If you're over 2,500 ms, the top contributor is almost always:
- Firestore auth-state stream (~200–500 ms cold)
- Initial farm document read (~150–400 ms)
- Font loading if `google_fonts` is fetching over network — verify Poppins is bundled, not downloaded.

---

## 5. Capture: Pigs list scroll

**What we're measuring:** the most-used list in the app under realistic data load.

### Pre-seed

You need **at least 50 pigs** in the active farm. Use the seed script (or write one if it doesn't exist yet — `tool/seed_smoke_data.dart` is the convention):

```bash
dart run tool/seed_smoke_data.dart --pigs 50 --batches 3 --farm <farmId>
```

If the seed script isn't built yet, manually create them via the app, or fall back to a one-shot Dart script that bulk-writes to the staging Firestore project.

### Steps

1. Log in, navigate to **Pigs list**.
2. Scroll to the top. Wait for the list to fully settle.
3. **Start recording** in DevTools.
4. Flick-scroll briskly from top to bottom over **~1.5 seconds** (one fast scroll gesture, not a slow drag).
5. Wait for the list to settle at the bottom (1–2 sec).
6. **Stop recording**.

### What to record

| Sub-metric | Where in DevTools |
|---|---|
| Mean UI thread frame time | Performance → Frames chart → hover the time range, read the average. |
| 99th percentile UI frame time | Frames chart → sort by duration → 99th worst frame. |
| Raster thread peaks | Same chart, raster (purple) bars. Note the worst. |
| Memory growth during scroll | DevTools **Memory** tab → snapshot before scroll, snapshot after. Delta = leak suspect. |

### Target

- **Mean UI frame: < 8 ms** (i.e. 120 fps headroom on a 60 Hz display).
- **99th: < 16 ms** (no visible jank).
- **Raster peak: < 16 ms**.
- **Memory delta: < 10 MB** for a 50-row scroll. Anything more suggests an image cache leak or a forgotten `dispose()`.

---

## 6. Capture: Batch Profitability render

**What we're measuring:** the heaviest single screen — pie chart + bar chart + multiple cost categories.

### Pre-seed

Pick or create a batch with **all 4 cost categories populated**:
- Feed consumption (at least 5 entries)
- Medicine/health costs (at least 3 entries)
- Misc expenses (at least 3 entries)
- A few sale entries (so revenue side renders too)

### Steps

1. Navigate to **Yield Reports** → **Per-batch profitability**.
2. Wait for the batch list to settle.
3. **Start recording**.
4. Tap a batch row.
5. Wait for the cost pie chart to fully paint (legend visible, slice colors stable).
6. **Stop recording**.

### What to record

| Sub-metric | How |
|---|---|
| Screen push → chart first paint | Timeline: from the `Navigator.push` event to the first `Paint` event for `_CostPie`. |
| Frames > 16 ms during chart render | Frames chart, count red frames in the capture window. |
| Build count for `_CostPie` | If you enabled "Track Widget Builds": should be **1**. Anything > 1 is a rebuild bug. |

### Target

- **Screen push → chart first paint: < 600 ms** on Android 2 GB.
- **< 3 jank frames** total.
- **`_CostPie` builds once.**

`fl_chart`'s pie computation is the usual suspect if this is slow. The RepaintBoundary added in Sub-project C should already isolate repaints — verify in the trace.

---

## 7. Memory baseline

**What we're measuring:** does the app's working set stay reasonable as the user navigates around?

### Steps

1. Fresh app launch (kill first).
2. DevTools **Memory** tab → **Snapshot** immediately after Dashboard renders. Record the **Dart heap** and **RSS** values.
3. Tour every primary screen, ~5 seconds each:
   - Dashboard
   - Pigs list (scroll a bit)
   - Sales
   - Inventory
   - Equipment
   - Shifts
   - Yield Reports (open one batch profitability)
   - Layout/Map
4. Return to Dashboard. **Snapshot** again.

### What to record

| Sub-metric | Target |
|---|---|
| Dart heap at start | Note baseline. |
| Dart heap after tour | Should be **< 1.5×** the start. |
| RSS at start | Note baseline. |
| RSS after tour | **< 250 MB** on Android 2 GB (Android starts killing background apps near 300 MB on these devices). |

If RSS grows monotonically as you re-visit the same screens, you have a leak — likely a Riverpod provider not being auto-disposed, or an image cache eviction not firing. Use the Memory tab's **Diff** view to find the leaking class.

---

## 8. Filling in `perf-audit-2026-05-15.md`

Open `docs/superpowers/perf-audit-2026-05-15.md` and replace each `<requires-device>` token with the captured number. Use this format consistently:

```markdown
| Metric | Baseline | Notes |
|---|---|---|
| Cold start → Dashboard | **1,847 ms** | Realme C25 (2 GB RAM, Android 11, build RMX3624_11_A.42). Slowest contributor: Firestore auth-state stream (~300 ms). |
| Pigs list scroll (mean UI frame) | **6.2 ms** | Same device. 50 pigs seeded. 99th: 14 ms. |
| Batch Profitability first paint | **480 ms** | Same device. 4 cost categories, 11 cost entries total. |
| RSS after nav tour | **198 MB** | Same device. Started at 142 MB. |
```

**Always include:**
- The unit (ms, MB, fps).
- The device model.
- The data conditions (how many pigs, batches, etc.).
- The top contributor if you spotted one.

---

## 9. Post-fix measurements

Sub-project C already applied the obvious-win fixes:
- `prefer_const_constructors` lint enforcement (analyzer clean, no manual fixes needed).
- `RepaintBoundary` wrapped around `_CostPie` and `_AreaBarChart` in the yield reports.
- Verified `cached_network_image` is used everywhere (zero raw `Image.network` calls).

If your profile reveals **new** offenders, document them under a **Findings** section in `perf-audit-2026-05-15.md` with **specific file:line references**, apply the fix, then re-measure. Example finding entry:

```markdown
### Finding F-1 — Consumer over-rebuild on Pigs list search

**Where:** `lib/src/features/pigs/presentation/pigs_list_page.dart:142`
**Symptom:** Every keystroke in the search field rebuilds the entire `_PigListView` (1 build per keystroke, ~8 ms each).
**Cause:** `Consumer` watches the whole `pigsFilteredProvider` instead of `select`-ing only the filtered list.
**Fix:** Use `ref.watch(pigsFilteredProvider.select((s) => s.items))`.
**Before:** 99th UI frame 22 ms.
**After:** 99th UI frame 11 ms.
**Commit:** <SHA>
```

---

## 10. Common offenders to look for

Sorted by how often they show up in Flutter perf audits, most common first:

1. **`Consumer` rebuilds on every keystroke / scroll position change** even though the widget only uses one field.
   - Fix: `ref.watch(provider.select((s) => s.specificField))`.
   - Look for: any `Consumer` whose child has a `TextField` or `ScrollController`.

2. **Long lists rendered with `Column`/`SingleChildScrollView` instead of `ListView.builder`.**
   - Sub-project A's Pigs list and Inventory list **already use `.builder`** — verified clean.
   - Re-check the **Activity Feed** once it has > 100 entries.

3. **`Image.network` without caching.** Audited clean in Sub-project C. Re-check if anyone adds new image widgets.

4. **Heavy widgets in `build()` that should be `const`.** The `prefer_const_constructors` lint is on; if you've added new code, run `flutter analyze` and accept the auto-fixes.

5. **`setState()` on a large widget when a smaller sub-tree could own the state.** Look for `StatefulWidget`s whose `build()` is > 50 lines.

6. **Forgotten `dispose()` on `AnimationController`, `TextEditingController`, `ScrollController`, `StreamSubscription`.** Memory tab will tell you — class count grows monotonically.

7. **Synchronous Firestore reads on the UI thread.** Already off the UI thread in our codebase (everything uses streams/futures), but verify if you've added new code.

---

## 11. What NOT to fix

- **Don't speculate.** Only fix what the profiler points at. "I bet this is slow" is not data.
- **Don't replace `fl_chart`** unless it's a top-3 offender in the Batch Profitability trace. Migration cost is huge; the chart is rarely the actual bottleneck.
- **Don't try to `Isolate` any work.** Firestore reads are already off-thread (they run in platform channels). `image_picker` is already off-thread (native plugin). Adding `compute()` calls just for the sake of it adds serialization cost.
- **Don't add `RepaintBoundary` everywhere.** Each one costs a render-target allocation. Sub-project C added them only where the profiler showed repaint cost — copy that discipline.
- **Don't optimize for the emulator.** Real devices have different bottlenecks (memory bandwidth, GPU fillrate). Always re-measure on hardware before celebrating.

---

## 12. Iteration loop

For each fix:

1. Apply the change.
2. Re-build profile: `flutter run --profile -d <device-id>`.
3. Re-capture the same trace (same scenario, same data).
4. Update the **Post-fix** column in `perf-audit-2026-05-15.md`.
5. Commit with a one-liner that includes before/after numbers:

```
perf(pigs-list): use select() in PigsListConsumer — 99th frame 22ms → 11ms
perf(yield): hoist _CostPie out of parent build — first paint 720ms → 480ms
perf(activity-feed): switch to ListView.builder — mean frame 18ms → 6ms
```

Small commits, one fix each. Easier to bisect if something regresses later.

---

## 13. iOS-specific notes

- **Use Instruments.app** for deep iOS profiling. DevTools is fine for frame-time and memory, but Instruments shows you Metal command buffer cost, Core Animation server time, and Energy Log impact — things DevTools can't.
  - Xcode → Open Developer Tool → Instruments → **Time Profiler** or **Animation Hitches**.
  - Attach to the profile-mode build on the device.
- **The Flutter performance overlay** can be enabled via `MaterialApp(showPerformanceOverlay: true)` for a quick on-device readout — but only in development; never ship it.
- **Metal renderer handles charts well.** Raster thread frames on iOS tend to be **2–3× cheaper** than the same scene on Android. **Don't over-index on good iOS numbers.** Android is the bar. If Android is happy, iOS is happy. The reverse is not true.
- **iPhone SE (1st gen)** with 2 GB RAM is your iOS floor. If the app works there, it works everywhere on iOS.

---

## 14. When to stop

The audit is complete when **all** of the following are true:

- [ ] Every `<requires-device>` placeholder in `perf-audit-2026-05-15.md` is filled with a real measurement.
- [ ] Each metric is either:
  - within target (see §4–§7 targets above), OR
  - documented with a follow-up under **Findings** with a clear next step and an owner.
- [ ] No **new** critical jank introduced: **no frames > 33 ms on the UI thread** during any captured scenario (33 ms = visible stutter to the user).
- [ ] Device, OS, and data conditions are documented at the top of the findings doc.
- [ ] At least one round of re-measurement after applying any fixes (so the "Post-fix" column has values, not "TBD").

Once those checkboxes are green, the audit is shippable. Commit the filled-in `perf-audit-2026-05-15.md` separately from this guide.

---

## Appendix: Quick-reference command list

```bash
# 1. Verify device
flutter devices

# 2. Profile build
flutter run --profile -d <device-id>

# 3. Seed data (once script exists)
dart run tool/seed_smoke_data.dart --pigs 50 --batches 3 --farm <farmId>

# 4. Verification before commit (always)
flutter analyze        # must stay at baseline (6 pre-existing info warnings, do not regress)
flutter test           # 105 passing, do not regress

# 5. Commit format
git commit -m "perf(<area>): <one-line summary> — <metric> Xms → Yms"
```

---

**End of guide.** Hand this to the engineer with a device. They follow it top-to-bottom and the `perf-audit-2026-05-15.md` gets filled in by the end of a single afternoon session.
