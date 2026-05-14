# Swine CRM Foundation — Design Spec

**Date:** 2026-05-14
**Sub-project:** A (first of a planned series; see "Future sub-projects")
**Status:** Approved scope, ready for implementation planning

---

## 1. Overview

Transform the existing FarmApp scaffold (auth + generic Animal model + basic dashboard) into a working, multi-employee swine CRM for small-to-mid commercial piggeries in the Philippines. The MVP delivers structured pig lifecycle tracking (breeding → farrowing → grow-finish → mortality), health/treatment logging with photos, a real-time activity feed for owners managing remote workers, and role-scoped access across one or more farms per user.

This spec defines **Sub-project A only**. Feed/financials, bilingual UX, push notifications, telemedicine, poultry, multi-site, and B2B marketplace are explicitly deferred — see §13.

## 2. Goals

1. **Replace the broken generic Animal flow** with a swine-specific data model that matches how PH piggeries actually operate.
2. **Enable a team to operate the same farm** — owner, manager, workers, and visiting vets — each with appropriate access.
3. **Give owners real-time visibility** into what workers logged each day, without needing to be on-site.
4. **Reduce data-entry friction** so workers will actually use the app during their shift (one-handed phone use in a barn).
5. **Build a defensible data foundation** for the brainstorm doc's downstream value props (financials, telemedicine, marketplace), without building them yet.

## 3. Non-goals

- Feed/medicine inventory tracking, cost tracking, sales records, P&L reports, construction-project tracking, materials inventory (Sub-project B).
- Feed Conversion Ratio (needs feed consumption data → Sub-project B).
- English ↔ Tagalog localization (Sub-project C — English-only MVP).
- Push notifications (Sub-project D — in-app task list only).
- Vet telemedicine appointments / video consults (Sub-project D — photo attachments only, no scheduling).
- Poultry, cattle, aquaculture (later sub-projects).
- Multi-site within a single farm (one farm = one site for MVP).
- A user-facing chat / DM feature (out of scope; activity feed only).
- Migration of existing test data — see §11.
- Time-attendance / clock-in (Sub-project D). Workforce module covers scheduling only.

## 4. User personas & roles

| Role | Typical user | Permissions summary |
|---|---|---|
| **Owner** | Farm owner / proprietor. Often manages from off-site. | Everything. Only role that can delete the farm, change the owner, or remove other Owners/Managers. |
| **Manager** | On-site supervisor / agriculturist. | Everything except deleting the farm or removing/demoting Owners and other Managers. Can invite workers and vets, manage areas, manage all pigs. |
| **Worker** | Farrowing attendant, feeder, general farm hand. | Logs events (breeding, farrowing, health, mortality, weigh-ins) in assigned areas. Can switch to other areas if needed but defaults to assigned. Can edit own entries within 24h. Cannot delete records or manage team. |
| **Veterinarian** | Visiting vet, possibly serving multiple farms. | Read all farm data. Write health records only. Cannot edit pig profiles, breeding, farrowing, or team. |

A user can hold different roles in different farms (e.g., be Owner of Farm A and Vet for Farm B).

## 5. Data model

Firestore. Sub-collections under `farms/{farmId}` for everything farm-scoped.

```
users/{userId}
  email, displayName, photoUrl?, lastSelectedFarmId?, createdAt

farms/{farmId}
  name, createdBy (userId), createdAt
  └─ members/{userId}
        role: 'owner' | 'manager' | 'worker' | 'vet'
        assignedAreaIds: string[]      (empty = all areas; workers default to specific areas)
        joinedAt, invitedBy
  └─ invitations/{inviteId}
        email (lowercased), role, assignedAreaIds[]
        invitedBy (userId), createdAt, expiresAt, status: 'pending'|'accepted'|'expired'|'revoked'
  └─ areas/{areaId}
        name, purpose: 'breeding'|'gestation'|'farrowing'|'nursery'|'grow_finish'|'quarantine'|'boar_pen'|'isolation'|'other'
        notes?, createdAt
        └─ pens/{penId}
              name, capacity?, currentOccupancy (denormalized counter), notes?
  └─ pigs/{pigId}
        tagId (unique within farm), sex: 'male'|'female',
        breed, birthDate, sireId?, damId?,
        stage: 'suckling'|'weaner'|'grower'|'finisher'|'gilt'|'sow'|'boar',
        status: 'active'|'sold'|'culled'|'deceased',
        currentAreaId, currentPenId?, currentWeight?, weightUpdatedAt?,
        photoUrl?, notes?, createdBy, createdAt, updatedAt
        └─ breeding_records/{id}
              boarId, heatDate?, inseminationDate, method: 'natural'|'ai',
              pregnancyCheckDate?, confirmed: bool,
              expectedFarrowingDate (= inseminationDate + 114 days),
              status: 'planned'|'confirmed'|'farrowed'|'failed'|'aborted',
              notes?, createdBy, createdAt
        └─ farrowing_records/{id}
              breedingRecordId, date, liveBorn, stillborn, mummified,
              avgBirthWeightKg?, litterBatchId?, notes?, createdBy, createdAt
        └─ health_records/{id}
              type: 'vaccination'|'treatment'|'checkup'|'deworming',
              date, productName?, dosage?, route?,
              diagnosis?, withdrawalEndDate?, costPhp?,
              photoUrls: string[], notes?, createdBy, createdAt
        └─ mortality_record/{single doc id='primary'}    // present only when status='deceased'
              date, cause?, photoUrls[], notes?, createdBy, createdAt
  └─ batches/{batchId}                                   // litters, grow-finish groups
        name, type: 'litter'|'grow_finish'|'nursery',
        originPigIds[] (parents for litters), pigIds[] (denormalized members),
        count (denormalized), currentAreaId, currentPenId?,
        status: 'active'|'sold'|'closed', startDate, endDate?,
        createdBy, createdAt
  └─ tasks/{taskId}
        type: 'pregnancy_check'|'farrowing_prep'|'farrowing_expected'|
              'vaccination_due'|'withdrawal_end'|'manual',
        title, description?, dueDate,
        relatedPigId?, relatedBreedingId?, relatedBatchId?, relatedAreaId?,
        assignedTo?: { kind: 'user'|'area', id: string },
        status: 'open'|'completed'|'skipped',
        autoGenerated: bool, source?: { collection, docId },
        completedBy?, completedAt?, createdAt
  └─ activity/{entryId}
        actorUserId, actorDisplayName (denormalized snapshot),
        action: 'pig_added'|'breeding_logged'|'farrowing_logged'|
                'health_logged'|'mortality_logged'|'weight_logged'|
                'pig_moved'|'task_completed'|'member_added'|
                'equipment_added'|'maintenance_logged'|'shift_assigned'|...,
        entityType, entityId, areaId?, summary (denormalized 1-line),
        timestamp
  └─ equipment/{equipmentId}
        name, type: 'ventilation'|'feeder'|'water_pump'|'generator'|
                    'scale'|'vehicle'|'structure'|'tool'|'other',
        areaId? (location), status: 'in_use'|'available'|'needs_repair'|'retired',
        purchaseDate?, purchaseCostPhp?, photoUrl?, notes?,
        createdBy, createdAt, updatedAt
        └─ maintenance_records/{id}
              type: 'preventive'|'repair'|'inspection',
              date, performedBy? (free text — may be external technician),
              partsReplaced?, costPhp?, photoUrls[], notes?,
              createdBy, createdAt
  └─ shifts/{shiftId}
        name (e.g., "Morning Farrowing"),
        pattern: 'daily'|'weekly',
        daysOfWeek: number[]  (0=Sun..6=Sat; empty for 'daily'),
        startTime, endTime  (HH:mm strings),
        assignedAreaId, assignedUserIds: string[],
        notes?, createdBy, createdAt, updatedAt
```

**Why sub-collections instead of top-level collections with `farmId` fields:** scoped security rules become trivial (`request.auth.uid in /databases/.../farms/{farmId}/members`), queries don't need composite indexes for the most common access pattern (everything inside one farm), and the structure mirrors how users mentally model "this pig's farrowing history."

**Why `lastSelectedFarmId` on the user:** drives the farm switcher's default selection on app start. Membership list (and therefore "which farms can I see") is derived from a collection-group query on `members/{userId}`.

## 6. Architecture

**Stack** (unchanged from current):
- Flutter + Riverpod (state) + GoRouter (routing)
- Firebase Auth + Cloud Firestore (with offline persistence) + Firebase Storage (photos)
- `iconsax` icons, `google_fonts` Poppins, existing theme

**New packages:**
- `image_picker` — camera + gallery
- `firebase_storage` — photo uploads
- `connectivity_plus` — offline banner
- `uuid` — local IDs
- `cached_network_image` — efficient photo display
- `fl_chart` — yield report charts
- `fake_cloud_firestore` (dev only) — repository tests

**File structure (after refactor):**

```
lib/src/
├─ core/
│   ├─ permissions/      permission_service.dart, role.dart
│   ├─ theme/            main_theme.dart   (existing)
│   └─ widgets/          (existing + offline_banner.dart)
└─ features/
    ├─ authentication/   (existing, lightly modified for multi-farm)
    ├─ farms/            farm_model.dart, farm_repository.dart,
    │                    farm_providers.dart, farm_switcher.dart,
    │                    setup_screen.dart, create_farm_screen.dart
    ├─ team/             member_model.dart, invitation_model.dart,
    │                    team_repository.dart, team_providers.dart,
    │                    team_management_screen.dart,
    │                    invite_member_screen.dart,
    │                    accept_invitation_screen.dart
    ├─ areas/            area_model.dart, pen_model.dart,
    │                    area_repository.dart, area_providers.dart,
    │                    areas_list_screen.dart, edit_area_screen.dart
    ├─ pigs/             pig_model.dart, breeding_record.dart,
    │                    farrowing_record.dart, health_record.dart,
    │                    mortality_record.dart, batch_model.dart,
    │                    pig_repository.dart, breeding_repository.dart,
    │                    health_repository.dart, batch_repository.dart,
    │                    pig_providers.dart,
    │                    pigs_list_screen.dart, pig_detail_screen.dart,
    │                    add_edit_pig_screen.dart, breeding_log_screen.dart,
    │                    farrowing_log_screen.dart, health_log_screen.dart,
    │                    mortality_log_screen.dart
    ├─ tasks/            task_model.dart, task_repository.dart,
    │                    task_providers.dart, task_generator.dart,
    │                    tasks_screen.dart
    ├─ activity/         activity_entry.dart, activity_repository.dart,
    │                    activity_providers.dart, activity_feed_widget.dart
    ├─ equipment/        equipment_model.dart, maintenance_record.dart,
    │                    equipment_repository.dart, equipment_providers.dart,
    │                    equipment_list_screen.dart, equipment_detail_screen.dart,
    │                    add_edit_equipment_screen.dart, log_maintenance_screen.dart
    ├─ shifts/           shift_model.dart, shift_repository.dart,
    │                    shift_providers.dart, shifts_screen.dart,
    │                    edit_shift_screen.dart, roster_widget.dart
    ├─ yield/            yield_metrics.dart, yield_calculator.dart,
    │                    yield_providers.dart, yield_screen.dart
    ├─ media/            photo_picker.dart, photo_upload_service.dart,
    │                    photo_upload_queue.dart
    ├─ settings/         (existing, extended)
    └─ dashboard/        dashboard_screen.dart, dashboard_providers.dart
       (extracted from current home_screen.dart)
```

The current `lib/src/features/animals/` and `lib/src/features/locations/` directories are deleted (after wipe — see §11).

`HomeScreen` is restructured as a shell with bottom-nav: Dashboard · Pigs · Tasks · Activity. The current "Locations" tab moves under Settings.

## 7. Feature breakdown

### 7.1 Authentication & multi-farm

- Sign-up flow unchanged (email + password creates `users/{uid}`).
- After sign-up:
  - If the user has a **pending invitation** matching their email → Accept Invitation screen → they join the farm and are dropped into the dashboard.
  - Else → Create First Farm screen → creates `farms/{newId}` and `members/{uid}` with `role: owner`.
- `goRouterProvider` redirect logic updated: route guards on `(authState, userFarmMemberships, selectedFarmId)`.
- Farm switcher: AppBar dropdown showing all farms where the user is a member. Selecting one updates `lastSelectedFarmId` on the user doc.
- "Create another farm" button at the bottom of the switcher.

### 7.2 Team & invitations

- **Team management screen** (Owner + Manager): list members with role, last-active timestamp, assigned areas. Actions: invite, change role, change area assignments, remove.
- **Invite flow:** owner enters email + role + (for workers) area assignments. Creates `farms/{id}/invitations/{id}` with `status: 'pending'`. Spec does not include sending an actual email — the invitee discovers the invite when they sign up with that email address.
- **Accept invitation screen:** shown automatically after sign-up if a pending invite matches the user's email. User reviews farm name + role + assigned areas, accepts → invitation marked `accepted`, `members/{userId}` created.
- **Role change:** Owner can promote/demote anyone; Manager can change Worker ↔ Vet but cannot touch other Managers or the Owner.
- **Remove:** soft-delete via setting member doc's `removedAt`; historical activity entries retain the actor's `displayName` snapshot so removed-member contributions stay attributed.

### 7.3 Areas & pens

- **Areas list screen:** flat list of areas grouped by purpose. Counter chip per area showing current pig occupancy.
- **Edit area screen:** name, purpose, notes, list of pens (add/edit/remove inline).
- **Pen detail (lightweight):** name + capacity + currently-residing pigs (drill-down link from pen card).
- Worker default-filter respects area assignments — see §7.4.

### 7.4 Pigs

- **Pigs list screen** (bottom nav, default tab after Dashboard):
  - Search box: matches `tagId` substring.
  - Filter chips: stage (multi-select), area (multi-select), status (active/sold/culled/deceased), sex.
  - Sort: most recently updated (default), tag ID, age.
  - Sectioned list: Sows · Boars · Growers · Finishers · Piglets (collapsible sections).
  - Workers: default filter pre-applied to their assigned areas; they can toggle "Show all areas" to override.
- **Add/Edit Pig screen:** tag, sex, breed (typeahead from breed list seeded for PH market: Yorkshire, Duroc, Landrace, Hampshire, Pietrain, Native — editable), birth date, stage, area+pen, optional sire/dam (typeahead over existing pigs of the appropriate sex), optional photo, weight.
- **Pig Detail screen** (4 tabs):
  - **Profile:** photo, current stats, current area/pen, "Move pig" action.
  - **Breeding:** only for sows/gilts/boars. Timeline of `breeding_records` with status pills. "Log heat / insemination / pregnancy check / farrowing" actions.
  - **Health:** chronological feed of `health_records` (vaccination, treatment, checkup, deworming). Each card shows actor + date + thumbnail. "Log health event" FAB.
  - **Lineage:** simple parent → self → offspring view (one generation each direction). Tappable to navigate.
- **Move pig:** select new area+pen; logs an activity entry; updates `currentAreaId`/`currentPenId`.
- **Sell / cull / mark deceased:** changes `status`; deceased triggers Mortality Log; sold/culled prompts an optional date + notes.

### 7.5 Breeding cycle

- **Breeding Log screen** (reached from a sow's Breeding tab or from the FAB menu):
  - Step 1: heat observed date (optional).
  - Step 2: insemination — date, boar (dropdown of boars on this farm), method (natural / AI).
  - Step 3: expected farrowing date is auto-computed (+114 days, gestation length) and displayed as confirmation.
- After save, the system auto-generates these `tasks/`:
  - `pregnancy_check` at insemination + 30 days
  - `farrowing_prep` at insemination + 107 days (7 days before)
  - `farrowing_expected` at insemination + 114 days
- **Pregnancy check action** on a breeding record: confirmed (yes/no). If no → status `failed`. If yes → status `confirmed`.
- **Repeat breeding:** if a sow's last breeding `failed`, the "Log heat" button is highlighted.

### 7.6 Farrowing

- **Farrowing Log screen** (reached from a sow's open breeding record OR from FAB → "Log Farrowing"):
  - Live born (number), stillborn (number), mummified (number), avg birth weight (kg, optional), notes.
  - "Create litter batch?" toggle (default ON). Toggling creates a `batches/{id}` of type `litter` with `count = liveBorn`, `currentAreaId/currentPenId` defaulting to the sow's current location.
  - Closes the breeding record (`status = 'farrowed'`).
  - Auto-generates `vaccination_due` tasks for the litter at standard PH intervals (configurable later; for MVP use placeholders: iron at day 3, deworming at week 3, etc. — final schedule chosen during implementation with the user).

### 7.7 Health & treatments

- **Health Log screen** (per-pig OR per-batch):
  - Type chip selector (Vaccination · Treatment · Checkup · Deworming).
  - Product (text + recently-used quick chips).
  - Dosage, route (oral / IM / SC / topical).
  - Diagnosis (if treatment/checkup).
  - Withdrawal period (days from today) → `withdrawalEndDate` computed. If set, auto-generates a `withdrawal_end` task.
  - Cost (PHP, optional — used later by Sub-project B).
  - Photos (multi-attach, camera or gallery, compressed to max 1280px JPEG ~80%).
  - Notes.
- Health records are immutable to anyone except their original author within 24h. Editable by Manager/Owner anytime (with an audit entry).
- Vet role can write health records but nothing else.

### 7.8 Mortality

- **Mortality Log screen** (from Pig Detail → "Mark deceased"):
  - Date, cause (free text with quick chips: respiratory, digestive, accident, unknown, …), optional photos, notes.
  - Sets pig `status = 'deceased'`.
  - Posts to activity feed.
  - Removes pig from "active" filters by default but remains visible under "Show deceased."

### 7.9 Tasks

- **Tasks screen** (bottom nav):
  - Tabs: "My Tasks" (assigned to me) / "Open" (all open) / "Completed" (last 7 days).
  - Filter by area, due date range, type.
  - Sort by due date.
- Task cards show title, due date (with overdue highlighting), related entity (tappable jump-to-detail), assigned-to (user or area).
- Tap → mark complete (optionally with a note).
- **Manual tasks:** Owner/Manager can create with title, description, due date, assignment, related pig/area.
- **Auto-generated tasks** come from `lib/src/features/tasks/task_generator.dart`, a service invoked by the breeding and health repository wrappers whenever a relevant record is written. It creates derived tasks in the same Firestore batch as the source record. Idempotency via `source: {collection, docId}` field — a re-run upserts rather than duplicates.

### 7.10 Activity feed

- **Activity feed widget** appears on the Dashboard as the bottom card, and a full-screen "Activity" tab gives the unfiltered firehose.
- Each entry: avatar/initials of actor, summary string ("Juan logged farrowing on Sow #14 — 9 live, 1 stillborn"), area badge, relative timestamp. Tappable → entity detail.
- Today / Yesterday / earlier sections.
- Filterable by actor, area, action type.
- Workers see entries only from their assigned areas by default; Owner/Manager/Vet see everything.
- Activity entries are written via a wrapper repository method that writes both the source record and the activity entry in a single Firestore batch. No Cloud Function needed.

### 7.11 Equipment & maintenance

- **Equipment list screen** (under Settings, accessible to all roles read-only; edit by Manager/Owner):
  - Grouped by `type` (Ventilation, Feeder, Water pump, Generator, Scale, Vehicle, Structure, Tool, Other) with a status pill (**in use / available / needs repair / retired**).
  - Filter by area and by status. "Needs repair" filter is one-tap (Owner/Manager triage view).
  - Status quick-toggle on each card: tap pill → cycle through in use → available → needs repair.
- **Equipment detail screen:**
  - Profile: name, type, area, status, purchase date, purchase cost (PHP), photo, notes.
  - Maintenance history tab: chronological list of maintenance records with cost totals.
- **Add/Edit equipment** (Manager/Owner): name, type, area, status, optional purchase date + cost, photo.
- **Log maintenance** (Manager/Owner): type (preventive / repair / inspection), date, performed by (free text — may be external technician), parts replaced, cost, photos, notes.
- Maintenance writes also create an `activity/` entry with action `maintenance_logged`.
- Structures (e.g., a specific barn) are modeled as equipment of `type: 'structure'`, distinct from `areas/` which are operational zones. A barn is an asset; "Farrowing Area 1" is a zone — they can coexist.

### 7.12 Shifts & roster (workforce allocation)

- **Shifts screen** (Manager/Owner):
  - List of recurring shifts: name, area, days, time window, assigned workers.
  - "Today's Roster" header card showing who's working which area today (derived from shifts where `daysOfWeek` includes today's day-of-week or `pattern: 'daily'`).
- **Edit shift screen** (Manager/Owner): name, pattern (daily / weekly), days-of-week multi-select (weekly only), start time + end time, area, workers multi-select (only members with role=worker), notes.
- **Roster widget** (on the Dashboard for Owner/Manager; on "My Schedule" for workers):
  - Owner/Manager: today's full roster grouped by area.
  - Worker: only their own assignments for today + the next 6 days.
- Workforce module does NOT replace the existing Tasks system — tasks remain per-event work units, shifts are recurring presence assignments. A worker assigned to a shift in the Farrowing area inherits that as their *current* `assignedAreaIds[]` filter for the duration of the shift (UI hint only; full membership area assignments remain authoritative for permissions).
- Time-attendance / clock-in is explicitly out of scope (see §3).

### 7.13 Yield reports

- **Yield Reports screen** (bottom-nav "Reports" tab — replaces the current placeholder):
  - Period selector at top: 7d / 30d / 90d / YTD / All-time. Affects all metrics below.
  - **Herd productivity card:**
    - PSY estimate (pigs weaned / active sow / year), derived from farrowing records' `liveBorn - preweaningMortalityCount` over period.
    - Avg litter size (live born), avg stillbirth count.
    - Stillbirth rate (stillborn / (liveBorn + stillborn)).
    - Pre-weaning mortality rate (deaths under 28 days / litter total).
    - Breeding success rate (confirmed pregnancies / total inseminations).
  - **Growth & finishing card:**
    - Average daily gain (ADG), computed only when ≥2 weight log entries exist for a pig; aggregated mean across grow-finish pigs.
    - Active grow-finish batches: count, total head, avg days on feed.
  - **Mortality card:**
    - Overall mortality rate (deceased in period / herd at period start).
    - Bar chart by area.
    - Top 3 causes (from `mortality_record.cause`).
  - **Output card** (lightweight stand-in until Sub-project B adds sales):
    - Pigs marked `status: sold` in period (count).
    - Pigs marked `status: culled` in period (count).
- All metrics computed client-side from streamed Firestore data via `lib/src/features/yield/yield_calculator.dart` (pure functions, fully unit-testable).
- Charts use `fl_chart`.

### 7.14 Farm Layout (spatial overview)

A non-geographic "map" view giving the owner/manager an at-a-glance picture of the farm's spatial state.

- **Farm Layout screen** (accessible from Dashboard "View layout" button and as a bottom-nav option for Owner/Manager):
  - Vertical scroll of **area cards**, ordered by purpose (Breeding → Gestation → Farrowing → Nursery → Grow-Finish → Quarantine → Boar Pen → Isolation → Other).
  - Each card shows:
    - Area name + purpose badge.
    - Pig occupancy: `X / Y` where Y = sum of pen capacities (or "—" if not set).
    - Pen mini-grid: each pen as a tile colored by occupancy (green ≤50%, yellow ≤80%, red >80%). Capacity overlaid as text.
    - **Equipment chips** below the pen grid: one chip per equipment item in this area, colored by status (green=in use, grey=available, red=needs repair). Tappable → equipment detail.
    - Pending tasks count for the area.
    - Active workers right now (from Shifts → Today's Roster) as small avatar stack.
  - "Drag-to-rearrange order" disabled — order is fixed by purpose. (Custom ordering is out of scope; can come in a later sub-project.)
- Workers see Farm Layout filtered to their assigned areas, with a one-tap toggle to see all.
- No GPS, no map tiles, no canvas-based coordinates. This is **purely a structured visual summary** — building a true geographic map is deferred.

### 7.15 Dashboard (replaces hardcoded current dashboard)

Top-to-bottom:
1. Greeting + current farm name + farm switcher (AppBar).
2. **Snapshot card:** Total pigs, Sows (active), Boars (active), Active gestations, Due to farrow (≤7 days), Mortalities (last 30 days). All live counts via Firestore aggregation queries (`count()`) where supported, fallback to `length` of cached lists for the small ones.
3. **My tasks today** (top 5, expandable to full Tasks screen).
4. **Area occupancy** (compact grid of areas with `count / capacity`).
5. **Recent activity** (top 8 entries, expandable to full Activity tab).
6. **Offline banner** at the top when `connectivity_plus` reports no connection.

### 7.16 Permissions

A single `PermissionService` (`lib/src/core/permissions/permission_service.dart`) exposes pure functions like:

```dart
bool canEditPig(Role role, Pig pig, String userId);
bool canDeleteHealthRecord(Role role, HealthRecord r, String userId);
bool canInviteMembers(Role role);
bool canSwitchToArea(Role role, List<String> assignedAreaIds, String areaId);
bool canEditEquipment(Role role);
bool canEditShifts(Role role);
```

UI calls these to gate buttons; the same logic is mirrored in Firestore security rules (written as part of implementation, not in this design doc).

Worker scoping is **soft** — they default to their assigned areas but can switch to others. The UI shows a banner "Viewing outside your assigned area" when they do.

### 7.17 Photo capture

- `PhotoPicker` widget — opens action sheet with Camera / Gallery / Cancel.
- On pick, image is compressed in-memory (`flutter_image_compress` or built-in `image_picker` quality flag) to ≤1280px max dimension at ~80% quality. Target ≤200 KB per photo.
- Upload to `farms/{farmId}/{recordType}/{recordId}/{n}.jpg` in Firebase Storage.
- **Offline path:** if upload fails, the local file path + target Storage path are enqueued in `photo_upload_queue` (persisted via `shared_preferences`). A reconnect listener retries. The health/mortality record's `photoUrls` field is updated when the upload completes.

### 7.18 Offline behavior

- Firestore offline persistence (already enabled by default in current setup — verify in code).
- A small "Offline · changes will sync" banner appears via `OfflineBanner` when `connectivity_plus.onConnectivityChanged` reports `none`.
- Writes queue in Firestore's local cache and reconcile on reconnect (last-write-wins).
- Photo upload queue is the only custom offline mechanism (Firestore doesn't queue binary uploads).

## 8. Permissions matrix

| Action | Owner | Manager | Worker | Vet |
|---|:---:|:---:|:---:|:---:|
| Edit farm name | ✓ | – | – | – |
| Manage team (invite/remove/role change) | ✓ | ✓¹ | – | – |
| Manage areas & pens | ✓ | ✓ | – | – |
| Add/edit pig profile | ✓ | ✓ | ✓² | – |
| Move pig | ✓ | ✓ | ✓² | – |
| Log breeding / farrowing | ✓ | ✓ | ✓² | – |
| Log health record | ✓ | ✓ | ✓² | ✓ |
| Log mortality | ✓ | ✓ | ✓² | – |
| Add/edit equipment | ✓ | ✓ | – | – |
| Quick-toggle equipment status | ✓ | ✓ | ✓² | – |
| Log maintenance | ✓ | ✓ | ✓² | – |
| Manage shifts (create/edit/assign) | ✓ | ✓ | – | – |
| View own shifts | ✓ | ✓ | ✓ | – |
| View yield reports | ✓ | ✓ | ✓³ | ✓ |
| View farm layout | ✓ | ✓ | ✓³ | ✓ |
| Edit own record < 24h | ✓ | ✓ | ✓ | ✓ |
| Edit anyone's record anytime | ✓ | ✓ | – | – |
| Delete records | ✓ | ✓ | – | – |
| View all farm data | ✓ | ✓ | ✓³ | ✓ |
| Create/assign tasks | ✓ | ✓ | – | – |
| Complete assigned tasks | ✓ | ✓ | ✓ | ✓ |

¹ Manager cannot promote to Owner, cannot remove the Owner, cannot demote other Managers.
² Worker actions default-filtered to their assigned areas; can switch contexts.
³ Worker sees everything but UI defaults to their assigned areas.

## 9. Testing strategy

- **Model unit tests:** every domain class has `fromMap`/`toMap` round-trip tests.
- **Repository tests:** use `fake_cloud_firestore` — no mocks. Cover CRUD + the "write source record + write activity entry atomically" flow.
- **Permission service tests:** pure function tests covering each row of the matrix in §8.
- **Task generator tests:** verify expected tasks are created from breeding/health writes; verify idempotency on re-run.
- **Yield calculator tests:** pure function tests on synthetic Pig/BreedingRecord/FarrowingRecord/MortalityRecord fixtures covering every metric.
- **Widget tests (4 highest-value screens):** PigDetail (renders by role), BreedingLogScreen (state machine validation), AddEditPigScreen (form validation), FarmLayoutScreen (renders areas with equipment + occupancy from fake data).
- **Manual smoke test checklist** (in implementation plan) covers the cross-role flows end-to-end.

## 10. Implementation slices (preview for the implementation plan)

Rough ordering — final plan is the next artifact, produced by `writing-plans`:

1. **Cleanup & scaffolding** — wipe Firestore test data, delete `animals/`/`locations/` dirs, set up new folder skeleton, add packages, regenerate firebase options.
2. **Multi-farm + team foundation** — `members`, `invitations`, farm switcher, create-farm flow, accept-invite flow, permission service, updated router redirects.
3. **Areas & pens** — replace flat `locations/` with `areas/{id}/pens/{id}`.
4. **Equipment + maintenance** — CRUD, status quick-toggle, maintenance log with photos.
5. **Pig model + Pig Detail (read-only) + Pigs list (with working search/filter)**.
6. **Add/Edit Pig with photo** — wire the broken Save flow; add photo capture.
7. **Breeding log + task generator (breeding tasks only)**.
8. **Farrowing log + litter batch creation**.
9. **Health log + photo attachments + withdrawal task** — and the Vet role's write path.
10. **Mortality log**.
11. **Tasks screen + manual task creation + assignment**.
12. **Shifts + roster (workforce allocation)**.
13. **Activity feed** (dashboard card + full screen).
14. **Yield reports** — replaces placeholder Reports tab, with `fl_chart`.
15. **Farm Layout screen** — spatial overview integrating areas, equipment, occupancy, roster.
16. **Real dashboard** — snapshot card, area occupancy, replaces hardcoded values. Offline banner + photo upload queue.
17. **Firestore security rules + final permission audit**.

Each slice is independently shippable behind the current branch's working state.

## 11. Migration / wipe

Existing test data in `farms/`, `users/`, `animals/`, `locations/` Firestore collections is wiped before/during slice 1. Cleanup script:

- Manual: Firebase console → delete the four collections.
- Or scripted: a one-time Dart script `tool/wipe_test_data.dart` using admin SDK (left as an implementation detail).

Code paths referring to `Animal`, `AnimalEvent`, `Location` are deleted, not refactored. Auth users in Firebase Auth are left intact (they still log in; on first login post-wipe they'll be sent to the Create First Farm screen because their `users/{uid}` doc no longer has a farm membership).

## 12. Open implementation decisions (resolve during planning, not now)

- **PH-standard piglet vaccination schedule** for the auto-generated tasks in §7.6 — final intervals to be confirmed with a vet reference or the user; placeholder used until then.
- **Aggregation query support** — Firestore `count()` is available; for fields the SDK can't aggregate natively (e.g., "due to farrow ≤7d"), fall back to a small cached query.
- **Breed list seed** — final list to confirm during implementation; spec proposes Yorkshire, Duroc, Landrace, Hampshire, Pietrain, Native, with user-editable additions.
- **Photo storage cost ceiling** — not addressed; acceptable for MVP given expected scale (single-piggery, hundreds of pigs).

## 13. Future sub-projects (deferred, not designed here)

- **B — Operations & Financials:** feed inventory, medicine inventory, cost tracking per batch, sales records, profitability report.
- **C — Bilingual & polish:** EN/Tagalog via `flutter_localizations` + `.arb`, icon-driven empty states, low-end Android perf audit.
- **D — Notifications & telemedicine:** FCM push for tasks & overdue alerts; vet appointment scheduling; async photo-based consults.
- **E — Poultry module:** replicate framework for layers/broilers, add egg collection.
- **F — Marketplace:** B2B feed/pharma listings, buyer connections.

Each gets its own spec + plan + build cycle.

## 14. Success criteria

Sub-project A is "done" when:

1. A new owner can sign up, create a farm, and add their first pig in under 3 minutes.
2. An owner can invite a worker, and that worker can sign up + log a farrowing event from the barn.
3. The dashboard shows real (not hardcoded) counts and reflects events logged in the last 30 seconds via Firestore's real-time stream.
4. The activity feed shows all team actions with correct actor attribution.
5. All breeding cycles trigger automated pregnancy-check and farrowing tasks.
6. Health events with withdrawal periods generate withdrawal-end tasks.
7. Photo upload works on a real Android device, including with airplane mode toggled mid-upload.
8. A user belonging to two farms can switch between them and see independent data sets.
9. Workers default to seeing their assigned areas, with a one-tap toggle to see all.
10. The Equipment list correctly groups by type, allows quick status toggle (in use ↔ available ↔ needs repair), and shows maintenance history per item.
11. A Manager can create a weekly shift assigning two workers to the Farrowing area on Mon/Wed/Fri, and those workers see the shift in their "My Schedule" view; the Roster widget shows them as active on those days.
12. The Yield Reports tab renders all six metric cards with non-zero values when seeded with sample data, and recomputes when the period selector changes.
13. The Farm Layout screen displays every area as a card with pen occupancy tiles, equipment status chips, and active-worker avatars derived from today's roster.
14. All tests pass; Firestore security rules deny cross-farm reads/writes.
