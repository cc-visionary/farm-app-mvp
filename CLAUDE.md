# CLAUDE.md — FarmApp (Swine CRM)

This file is automatically loaded into every Claude session for this project. It carries the standing design contract and project conventions.

## What this app is

A multi-employee swine CRM for small-to-mid commercial piggeries in the Philippines. Flutter app with Firebase backend (Auth + Firestore + Storage). Four roles: Owner, Manager, Worker, Veterinarian. The full spec lives at `docs/superpowers/specs/2026-05-14-swine-crm-foundation-design.md`; the full implementation plan is at `docs/superpowers/plans/2026-05-14-swine-crm-foundation.md`.

Primary UX inspiration: [EveryPig](https://www.everypig.com/) — "made for people who hate technology." Communication-centric, content over chrome, calm.

## Project conventions

- **Architecture:** Feature-sliced under `lib/src/features/<feature>/{domain,data,application,presentation}`. Sub-collections under `farms/{farmId}/...` for everything farm-scoped.
- **State:** Riverpod 3.x. `firestoreProvider` lives in `lib/src/features/activity/application/activity_providers.dart` — import from there.
- **Routing:** GoRouter 16.x in `lib/src/routing/app_router.dart`.
- **Tests:** `fake_cloud_firestore` for repository tests; pure-function tests for calculators/permissions. No Mockito.
- **Commits:** Conventional (`feat:`, `fix:`, `test:`, `refactor:`, `docs:`, `chore:`). Small and focused.
- **Verification:** `flutter analyze` (baseline: 6 pre-existing info warnings — do not regress) + `flutter test` (currently 105 passing) before every commit.

## Permissions matrix (canonical)

Spec §8 is canonical. UI gates via `PermissionService` in `lib/src/core/permissions/`; Firestore Security Rules mirror it in `firestore.rules`. When in doubt: Owner > Manager > Worker > Vet, with Vet being read-everything-write-health-only.

## Atomicity contract

Every state-changing repository method **must** write its source record AND the corresponding activity entry (and any derived tasks) in a single Firestore `WriteBatch` or transaction. The audit trail is non-negotiable.

---

## Design Context

### Users

**Primary:** Small-to-mid commercial piggery operators in the Philippines and their on-farm teams. Multi-user farms with four distinct roles — Owner (often off-site, manages from phone), Manager (on-site supervisor), Worker (farrowing attendant, feeder, general farm hand — performs most daily logging), Veterinarian (visiting, writes health records only).

**Context of use:**
- One-handed phone use in a barn — gloves, low light, occasional dust.
- Rural Philippines connectivity: 4G that drops, prepaid data, low-end Android devices common alongside iOS.
- Workflow happens during shifts — quick logging between physical animal handling tasks, not deep deskwork sessions.
- Owner/Manager sometimes review on tablets or larger phones; Workers almost always on phones.

**Job to be done:** Replace paper barnsheets with a fast, accurate, team-visible record of every pig's lifecycle (breeding → farrowing → health → sale/mortality) and every team action, so the owner can see what happened today without being there.

### Brand Personality

**Three words:** **Calm. Grounded. Trustworthy.**

**Voice & tone:** Plain language, no buzzwords. Numbers and dates over decorations. Confident in the boring stuff (capacities, dates, counts) — the app's job is to remove uncertainty, not to entertain. Errors and confirmations are direct ("Mark deceased? This cannot be undone.") rather than soft or apologetic.

**Emotional goals:** Confidence (the app won't lose my data), control (I can see what's happening on my farm right now), respect (this isn't condescending or gamified).

### Aesthetic Direction

**Visual tone:** Calm, structured, content-first. Generous whitespace; large tap targets; one or two strong colors carrying weight, not six competing for attention. Cards that feel like physical index cards on a barnsheet — slightly elevated, rounded, neutral surfaces — not glass, not gradient, not glossy.

**Theme:** **Light only** for v1. Primary green (`#2E7D32`) anchors the brand; dark accent green (`#1A3A3A`) for high-emphasis buttons; near-black text on warm-grey background.

**Reference (positive):** EveryPig — explicit inspiration. Their "made for people who hate technology" stance, communication-centric Farmfeed pattern (already mirrored in our Activity Feed), and content-over-chrome surfaces are the north star.

**Anti-references (explicitly avoid):**
- **Enterprise SaaS feel** — no Salesforce/SAP-style data density, no spreadsheet grids as primary UI, no jargon-laden labels.
- **Consumer-app gamification** — no badges, streaks, points, confetti, mascots, or pseudo-game progression.
- **Generic Material 3 defaults** — the app should look intentional, not stock `flutter create`.
- **Heavy decoration** — no gradients, glassmorphism, neumorphism, drop-shadows on text, ornate borders, illustrated mascots.

**Cross-platform approach:** **Material 3 everywhere + iOS niceties.** Single visual language; layer in iOS-native touches where they reduce friction: swipe-back gestures, Cupertino date pickers on iOS, light haptic feedback on destructive confirms, bouncing scroll physics on iOS.

### Design Principles

1. **Content over chrome.** If a card border, divider, or shadow doesn't help the user read or act on data, remove it.

2. **Big targets, generous breathing room.** Minimum 48 dp tap targets, minimum 16 dp gutters, 24 dp between groups.

3. **One accent at a time.** Each screen has one dominant action and one dominant data point.

4. **Numbers are first-class citizens.** Use tabular figures; align decimals; weight numbers more than labels.

5. **Predictable across iOS and Android.** Adopt platform conventions where they reduce friction (back gesture, date picker), keep layouts and icon families consistent.

### Spacing system

4 dp baseline. Approved values: **4, 8, 12, 16, 24, 32, 48 dp.** Avoid arbitrary numbers (6, 10, 14, 20, 28).

Page gutters: 16 dp phones, 24 dp tablets (≥600 dp wide). Card padding: 16 dp. List item gap: 16 dp. Section gap: 24 dp.

### Typography

Family: **Poppins** (already in pubspec). Single family across body and display via weight contrast. Numbers use `FontFeature.tabularFigures()`.

| Style | Size | Weight | Letter spacing |
|---|---|---|---|
| headlineLarge | 28 | w700 | -0.5 |
| headlineMedium | 22 | w600 | -0.25 |
| headlineSmall | 18 | w600 | 0 |
| titleMedium | 16 | w600 | 0 |
| bodyLarge | 16 | w400 | 0 |
| bodyMedium | 14 | w400 | 0 |
| labelLarge | 14 | w600 | 0.1 |
| labelMedium | 12 | w500 | 0.2 |

### Color tokens

| Token | Hex | Use |
|---|---|---|
| primary | `#2E7D32` | Primary buttons, brand |
| primaryContainer | `#C8E6C9` | Subtle good-state surfaces |
| surface | `#FFFFFF` | Cards |
| surfaceContainer | `#F1F3F5` | Page background |
| surfaceContainerHigh | `#E9ECEF` | Pressed/hover surfaces |
| outline | `#D4D6D8` | Borders (used sparingly) |
| onSurface | `#1B1F1A` | Body text |
| onSurfaceVariant | `#5A625C` | Secondary text |
| error | `#C0392B` | Mortality, needs-repair, overdue |
| tertiary | `#E8A317` | Warning (concern, not celebration) |

### Component conventions

- **Cards**: 16 dp radius, elevation 1, 16 dp padding, 12 dp vertical margin.
- **Buttons**: 28 dp pill radius for primary CTAs, 8 dp for secondary. Min 48 dp tall.
- **Inputs**: Filled, no border, 12 dp radius, label above (not floating).
- **Chips**: 32 dp tall, 8 dp horizontal padding, labelMedium.
- **Status pills**: Red is rare and earned (mortality/needs-repair/overdue).
- **Icons**: `iconsax` outlined, 20 dp default, 24 dp for primary actions.
- **Photos**: 12 dp rounded, no shadow.
- **Dividers**: Whitespace preferred; outlineVariant when truly needed.

### Motion

Page transitions: `CupertinoPageTransitionsBuilder` on iOS, `ZoomPageTransitionsBuilder` on Android. List updates: 200 ms fade in, 150 ms fade out. No springs, no parallax, no scroll-driven shaders.

### Iconography map

| Concept | Icon |
|---|---|
| Pig / Animal | `Iconsax.pet` |
| Breeding | `Iconsax.heart` |
| Farrowing | `Icons.child_friendly` |
| Health | `Iconsax.health` |
| Mortality | `Icons.heart_broken` |
| Tasks | `Iconsax.task_square` |
| Area / Location | `Iconsax.location` |
| Equipment | `Iconsax.setting_4` |
| Shifts | `Iconsax.calendar` |
| Activity Feed | `Iconsax.activity` |
| Reports / Yield | `Iconsax.chart_2` |
| Layout / Map | `Iconsax.element_3` |
| Team | `Iconsax.people` |
| Settings | `Iconsax.setting_2` |
| Offline | `Iconsax.cloud_cross` |

---

## Reference docs

- Spec: `docs/superpowers/specs/2026-05-14-swine-crm-foundation-design.md`
- Plan: `docs/superpowers/plans/2026-05-14-swine-crm-foundation.md`
- Manual smoke checklist: `docs/superpowers/manual-smoke-checklist.md`
- Detailed design rules: `.impeccable.md` (same content as the Design Context section above, kept in sync)
