# Swine CRM Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the existing FarmApp scaffold into a working multi-employee swine CRM with team & role management, structured pig lifecycle tracking (breeding → farrowing → grow-finish → mortality), health & treatment logging with photos, equipment & maintenance, workforce shifts, yield reports, and a spatial farm-layout view.

**Architecture:** Flutter + Riverpod (state) + GoRouter (routing) + Firebase (Auth + Firestore + Storage). Feature-sliced under `lib/src/features/<feature>/{domain,data,application,presentation}`. Sub-collections under `farms/{farmId}/...` for all farm-scoped data. Permission gating via a central `PermissionService` mirrored in Firestore security rules.

**Tech Stack:** Flutter 3.9+, `flutter_riverpod` 3.x, `go_router` 16.x, `firebase_core`/`auth`/`firestore`/`storage`, `image_picker`, `connectivity_plus`, `uuid`, `cached_network_image`, `fl_chart`, `fake_cloud_firestore` (dev).

**Spec reference:** `docs/superpowers/specs/2026-05-14-swine-crm-foundation-design.md`. Read it before starting — it has the authoritative data model and permissions matrix.

---

## File Structure (overview)

```
lib/src/
├─ core/
│   ├─ permissions/   permission_service.dart, role.dart
│   ├─ theme/         main_theme.dart  (existing)
│   └─ widgets/       offline_banner.dart, splash_screen.dart (existing)
└─ features/
    ├─ authentication/  (kept, lightly modified)
    ├─ farms/           (kept, modified for multi-farm)
    ├─ team/            (new)
    ├─ areas/           (replaces locations/)
    ├─ equipment/       (new)
    ├─ pigs/            (replaces animals/)
    ├─ tasks/           (new — includes task_generator.dart)
    ├─ shifts/          (new)
    ├─ activity/        (new)
    ├─ yield/           (new)
    ├─ layout/          (new — farm layout / map view)
    ├─ media/           (new — photo capture/upload)
    ├─ dashboard/       (extracted from current home_screen.dart)
    └─ settings/        (kept, extended)
```

The current `lib/src/features/animals/` and `lib/src/features/locations/` are **deleted entirely** in Task 1 — no migration.

---

## Conventions

- **TDD:** Each implementation step is preceded by a failing test, followed by minimal code to pass.
- **Tests live in:** `test/<mirror-of-lib-path>/<file>_test.dart`.
- **Repository tests use `fake_cloud_firestore`** — no Mockito. Pass a `FakeFirebaseFirestore` instance.
- **Models implement `==` and `hashCode`** via field-by-field comparison (use Dart's `Object.hash`).
- **Commits:** small, frequent, conventional (`feat:`, `fix:`, `refactor:`, `test:`, `chore:`, `docs:`).
- **Run tests:** `flutter test test/path/to/file_test.dart` or all: `flutter test`.
- **Run app:** `flutter run -d <device>`.
- **Analyze:** `flutter analyze` must pass with zero issues before each commit.

---

## Task 1: Cleanup & scaffolding

**Goal:** Wipe old test data, remove `animals/` + `locations/` directories, add new packages, scaffold empty feature directories, verify the app still launches into login.

**Files:**
- Delete: `lib/src/features/animals/` (entire directory), `lib/src/features/locations/` (entire directory)
- Modify: `pubspec.yaml`, `lib/src/routing/app_router.dart`, `lib/src/features/farms/presentation/home_screen.dart`, `lib/src/features/farms/presentation/setup_screen.dart`
- Create empty placeholders so future tasks have a target:
  - `lib/src/features/{team,areas,equipment,pigs,tasks,shifts,activity,yield,layout,media,dashboard}/.gitkeep`
  - `lib/src/core/permissions/.gitkeep`

### Steps

- [ ] **Step 1.1: Verify current state**

```bash
flutter analyze
flutter test
```
Expected: existing analyze passes (may have warnings), tests pass.

- [ ] **Step 1.2: Wipe Firestore test data**

In Firebase Console for project `farm-app-...`:
1. Firestore → delete collections: `farms`, `users`, `animals`, `locations` (any others that exist from testing).
2. Authentication → leave users intact (they can re-login; they'll be sent to Create First Farm).

(Equivalent: run a manual admin-SDK script — left as ops detail.)

- [ ] **Step 1.3: Update pubspec.yaml — add packages**

Replace the dependencies block in `pubspec.yaml` with:

```yaml
dependencies:
  flutter:
    sdk: flutter

  firebase_core: ^4.2.0
  firebase_auth: ^6.1.1
  cloud_firestore: ^6.0.3
  firebase_storage: ^13.0.0
  provider: ^6.1.2

  cupertino_icons: ^1.0.8
  google_fonts: ^6.3.2
  flutter_riverpod: ^3.0.3
  go_router: ^16.3.0
  iconsax: ^0.0.8
  intl: ^0.20.2

  image_picker: ^1.1.2
  connectivity_plus: ^6.0.5
  uuid: ^4.5.1
  cached_network_image: ^3.4.1
  fl_chart: ^0.69.0
  shared_preferences: ^2.3.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  fake_cloud_firestore: ^3.1.0
  firebase_auth_mocks: ^0.14.1
```

Run:
```bash
flutter pub get
```
Expected: dependencies resolve.

- [ ] **Step 1.4: Delete old feature directories**

```bash
rm -rf lib/src/features/animals lib/src/features/locations
```

- [ ] **Step 1.5: Scaffold new feature directories**

```bash
for dir in team areas equipment pigs tasks shifts activity yield layout media dashboard; do
  mkdir -p "lib/src/features/$dir/domain" "lib/src/features/$dir/data" "lib/src/features/$dir/application" "lib/src/features/$dir/presentation"
  touch "lib/src/features/$dir/.gitkeep"
done
mkdir -p lib/src/core/permissions
touch lib/src/core/permissions/.gitkeep
```

- [ ] **Step 1.6: Stub `app_router.dart` to remove broken imports**

Replace `lib/src/routing/app_router.dart` with:

```dart
import 'package:farm_app/src/core/widgets/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/authentication/application/auth_providers.dart';
import '../features/authentication/presentation/login_screen.dart';
import '../features/authentication/presentation/signup_screen.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateChangesProvider);

  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      if (authState.isLoading) return '/splash';
      final isLoggedIn = authState.asData?.value != null;
      final isAtAuth = state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup';
      if (!isLoggedIn) return isAtAuth ? null : '/login';
      if (isLoggedIn && isAtAuth) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (c, s) => const SignUpScreen()),
      GoRoute(
        path: '/',
        builder: (c, s) => const Scaffold(
          body: Center(child: Text('Home — to be built')),
        ),
      ),
    ],
  );
});
```

(`SetupScreen` and `HomeScreen` will be replaced in Tasks 2 and 16. They reference deleted features so they must go now.)

- [ ] **Step 1.7: Remove obsolete screens**

```bash
rm lib/src/features/farms/presentation/home_screen.dart
rm lib/src/features/farms/presentation/setup_screen.dart
```

- [ ] **Step 1.8: Verify app builds and launches**

```bash
flutter analyze
flutter run -d <device>
```
Expected: analyze passes; app launches to login screen; login flow still works (loads, just lands on the temporary `/` placeholder).

- [ ] **Step 1.9: Commit**

```bash
git add -A
git commit -m "chore: wipe old features and scaffold new structure

- Delete lib/src/features/animals and locations (will be replaced)
- Delete old home_screen.dart and setup_screen.dart
- Add new feature directories: team, areas, equipment, pigs, tasks,
  shifts, activity, yield, layout, media, dashboard
- Add packages: image_picker, firebase_storage, connectivity_plus,
  uuid, cached_network_image, fl_chart, shared_preferences,
  fake_cloud_firestore (dev)
- Stub app_router.dart with placeholder home route"
```

---

## Task 2: Foundation — Role, PermissionService, AppUser, Multi-farm membership, Activity model

**Goal:** Build the core scaffolding that everything else depends on — roles, permissions, the updated user model, the membership model, and the activity record. Stub repositories that will be expanded in later tasks. No UI yet beyond updating the existing auth screens for the new flow.

**Files:**
- Create:
  - `lib/src/core/permissions/role.dart`
  - `lib/src/core/permissions/permission_service.dart`
  - `lib/src/features/team/domain/member.dart`
  - `lib/src/features/team/domain/invitation.dart`
  - `lib/src/features/activity/domain/activity_entry.dart`
  - `lib/src/features/activity/data/activity_repository.dart`
  - `lib/src/features/activity/application/activity_providers.dart`
  - `test/core/permissions/permission_service_test.dart`
  - `test/features/team/domain/member_test.dart`
  - `test/features/team/domain/invitation_test.dart`
  - `test/features/activity/domain/activity_entry_test.dart`
  - `test/features/activity/data/activity_repository_test.dart`
- Modify:
  - `lib/src/features/authentication/domain/user_model.dart` (extend with `lastSelectedFarmId`, `photoUrl`)

### Steps

- [ ] **Step 2.1: Test — Role enum**

Create `test/core/permissions/role_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/core/permissions/role.dart';

void main() {
  test('Role.fromString returns the matching enum', () {
    expect(Role.fromString('owner'), Role.owner);
    expect(Role.fromString('manager'), Role.manager);
    expect(Role.fromString('worker'), Role.worker);
    expect(Role.fromString('vet'), Role.vet);
  });

  test('Role.fromString defaults to worker for unknown', () {
    expect(Role.fromString('asdf'), Role.worker);
  });

  test('Role.value returns the wire string', () {
    expect(Role.owner.value, 'owner');
    expect(Role.vet.value, 'vet');
  });
}
```

Run: `flutter test test/core/permissions/role_test.dart` → fails (no Role).

- [ ] **Step 2.2: Implement Role**

`lib/src/core/permissions/role.dart`:

```dart
enum Role {
  owner('owner'),
  manager('manager'),
  worker('worker'),
  vet('vet');

  const Role(this.value);
  final String value;

  static Role fromString(String s) {
    return Role.values.firstWhere(
      (r) => r.value == s,
      orElse: () => Role.worker,
    );
  }
}
```

Run: `flutter test test/core/permissions/role_test.dart` → passes.

- [ ] **Step 2.3: Test — PermissionService (matrix coverage)**

Create `test/core/permissions/permission_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/core/permissions/permission_service.dart';
import 'package:farm_app/src/core/permissions/role.dart';

void main() {
  group('PermissionService.canEditFarm', () {
    test('owner can', () => expect(PermissionService.canEditFarm(Role.owner), true));
    test('others cannot', () {
      for (final r in [Role.manager, Role.worker, Role.vet]) {
        expect(PermissionService.canEditFarm(r), false);
      }
    });
  });

  group('PermissionService.canManageTeam', () {
    test('owner & manager can', () {
      expect(PermissionService.canManageTeam(Role.owner), true);
      expect(PermissionService.canManageTeam(Role.manager), true);
    });
    test('worker & vet cannot', () {
      expect(PermissionService.canManageTeam(Role.worker), false);
      expect(PermissionService.canManageTeam(Role.vet), false);
    });
  });

  group('PermissionService.canManageAreas', () {
    test('owner & manager can; worker & vet cannot', () {
      expect(PermissionService.canManageAreas(Role.owner), true);
      expect(PermissionService.canManageAreas(Role.manager), true);
      expect(PermissionService.canManageAreas(Role.worker), false);
      expect(PermissionService.canManageAreas(Role.vet), false);
    });
  });

  group('PermissionService.canEditPig', () {
    test('owner, manager, worker can; vet cannot', () {
      expect(PermissionService.canEditPig(Role.owner), true);
      expect(PermissionService.canEditPig(Role.manager), true);
      expect(PermissionService.canEditPig(Role.worker), true);
      expect(PermissionService.canEditPig(Role.vet), false);
    });
  });

  group('PermissionService.canLogHealth', () {
    test('all four can', () {
      for (final r in Role.values) {
        expect(PermissionService.canLogHealth(r), true);
      }
    });
  });

  group('PermissionService.canLogMortality', () {
    test('owner, manager, worker can; vet cannot', () {
      expect(PermissionService.canLogMortality(Role.owner), true);
      expect(PermissionService.canLogMortality(Role.manager), true);
      expect(PermissionService.canLogMortality(Role.worker), true);
      expect(PermissionService.canLogMortality(Role.vet), false);
    });
  });

  group('PermissionService.canEditEquipment', () {
    test('owner & manager can; worker & vet cannot', () {
      expect(PermissionService.canEditEquipment(Role.owner), true);
      expect(PermissionService.canEditEquipment(Role.manager), true);
      expect(PermissionService.canEditEquipment(Role.worker), false);
      expect(PermissionService.canEditEquipment(Role.vet), false);
    });
  });

  group('PermissionService.canQuickToggleEquipmentStatus', () {
    test('owner, manager, worker can; vet cannot', () {
      expect(PermissionService.canQuickToggleEquipmentStatus(Role.owner), true);
      expect(PermissionService.canQuickToggleEquipmentStatus(Role.manager), true);
      expect(PermissionService.canQuickToggleEquipmentStatus(Role.worker), true);
      expect(PermissionService.canQuickToggleEquipmentStatus(Role.vet), false);
    });
  });

  group('PermissionService.canManageShifts', () {
    test('owner & manager only', () {
      expect(PermissionService.canManageShifts(Role.owner), true);
      expect(PermissionService.canManageShifts(Role.manager), true);
      expect(PermissionService.canManageShifts(Role.worker), false);
      expect(PermissionService.canManageShifts(Role.vet), false);
    });
  });

  group('PermissionService.canDeleteRecord', () {
    test('owner & manager only', () {
      expect(PermissionService.canDeleteRecord(Role.owner), true);
      expect(PermissionService.canDeleteRecord(Role.manager), true);
      expect(PermissionService.canDeleteRecord(Role.worker), false);
      expect(PermissionService.canDeleteRecord(Role.vet), false);
    });
  });

  group('PermissionService.canEditOwnRecord', () {
    test('within 24h, anyone can', () {
      final now = DateTime.now();
      final ten = now.subtract(const Duration(hours: 10));
      for (final r in Role.values) {
        expect(PermissionService.canEditOwnRecord(r, 'u', 'u', ten, now), true);
      }
    });
    test('after 24h, owner/manager only', () {
      final now = DateTime.now();
      final past = now.subtract(const Duration(hours: 25));
      expect(PermissionService.canEditOwnRecord(Role.owner, 'u', 'u', past, now), true);
      expect(PermissionService.canEditOwnRecord(Role.manager, 'u', 'u', past, now), true);
      expect(PermissionService.canEditOwnRecord(Role.worker, 'u', 'u', past, now), false);
      expect(PermissionService.canEditOwnRecord(Role.vet, 'u', 'u', past, now), false);
    });
    test('not own record, owner/manager only', () {
      final now = DateTime.now();
      final ten = now.subtract(const Duration(hours: 10));
      expect(PermissionService.canEditOwnRecord(Role.owner, 'a', 'b', ten, now), true);
      expect(PermissionService.canEditOwnRecord(Role.manager, 'a', 'b', ten, now), true);
      expect(PermissionService.canEditOwnRecord(Role.worker, 'a', 'b', ten, now), false);
      expect(PermissionService.canEditOwnRecord(Role.vet, 'a', 'b', ten, now), false);
    });
  });

  group('PermissionService.isAreaInScope', () {
    test('empty assignment = all areas', () {
      expect(PermissionService.isAreaInScope([], 'anything'), true);
    });
    test('non-empty: in list returns true', () {
      expect(PermissionService.isAreaInScope(['a', 'b'], 'a'), true);
    });
    test('non-empty: not in list returns false', () {
      expect(PermissionService.isAreaInScope(['a', 'b'], 'c'), false);
    });
  });
}
```

Run: fails (no PermissionService).

- [ ] **Step 2.4: Implement PermissionService**

`lib/src/core/permissions/permission_service.dart`:

```dart
import 'role.dart';

/// Pure functions gating UI actions. Mirror the Firestore security rules.
class PermissionService {
  PermissionService._();

  static bool canEditFarm(Role r) => r == Role.owner;

  static bool canManageTeam(Role r) => r == Role.owner || r == Role.manager;

  static bool canManageAreas(Role r) => r == Role.owner || r == Role.manager;

  static bool canEditPig(Role r) =>
      r == Role.owner || r == Role.manager || r == Role.worker;

  static bool canLogBreeding(Role r) => canEditPig(r);

  static bool canLogFarrowing(Role r) => canEditPig(r);

  static bool canLogHealth(Role r) =>
      r == Role.owner || r == Role.manager || r == Role.worker || r == Role.vet;

  static bool canLogMortality(Role r) => canEditPig(r);

  static bool canEditEquipment(Role r) =>
      r == Role.owner || r == Role.manager;

  static bool canQuickToggleEquipmentStatus(Role r) =>
      r == Role.owner || r == Role.manager || r == Role.worker;

  static bool canLogMaintenance(Role r) =>
      r == Role.owner || r == Role.manager || r == Role.worker;

  static bool canManageShifts(Role r) =>
      r == Role.owner || r == Role.manager;

  static bool canCreateOrAssignTasks(Role r) =>
      r == Role.owner || r == Role.manager;

  static bool canDeleteRecord(Role r) =>
      r == Role.owner || r == Role.manager;

  /// `recordCreatedBy` is the userId on the record; `currentUserId` is who is editing.
  /// Owner/Manager can always edit. Worker/Vet can edit only own records within 24h.
  static bool canEditOwnRecord(
    Role r,
    String recordCreatedBy,
    String currentUserId,
    DateTime recordCreatedAt,
    DateTime now,
  ) {
    if (r == Role.owner || r == Role.manager) return true;
    if (recordCreatedBy != currentUserId) return false;
    return now.difference(recordCreatedAt).inHours < 24;
  }

  /// Empty assignedAreaIds means "all areas". Otherwise the area must be in the list.
  static bool isAreaInScope(List<String> assignedAreaIds, String areaId) {
    if (assignedAreaIds.isEmpty) return true;
    return assignedAreaIds.contains(areaId);
  }
}
```

Run: `flutter test test/core/permissions/` → passes.

- [ ] **Step 2.5: Commit (perms scaffold)**

```bash
git add lib/src/core/permissions test/core/permissions
git commit -m "feat(core): add Role enum and PermissionService"
```

- [ ] **Step 2.6: Test — Member model**

`test/features/team/domain/member_test.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/features/team/domain/member.dart';
import 'package:farm_app/src/core/permissions/role.dart';

void main() {
  test('Member round-trips through map', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('farms').doc('f1').collection('members').doc('u1').set({
      'role': 'worker',
      'assignedAreaIds': ['a1', 'a2'],
      'joinedAt': Timestamp.fromMillisecondsSinceEpoch(1000),
      'invitedBy': 'u-owner',
    });
    final doc = await firestore.collection('farms').doc('f1').collection('members').doc('u1').get();
    final m = Member.fromFirestore(doc, farmId: 'f1');

    expect(m.userId, 'u1');
    expect(m.farmId, 'f1');
    expect(m.role, Role.worker);
    expect(m.assignedAreaIds, ['a1', 'a2']);
    expect(m.invitedBy, 'u-owner');
    expect(m.joinedAt.millisecondsSinceEpoch, 1000);

    final back = m.toMap();
    expect(back['role'], 'worker');
    expect(back['assignedAreaIds'], ['a1', 'a2']);
    expect(back['invitedBy'], 'u-owner');
  });

  test('Member equality is by field', () {
    final t = Timestamp.fromMillisecondsSinceEpoch(1000);
    final a = Member(
      userId: 'u1', farmId: 'f1', role: Role.owner,
      assignedAreaIds: const [], joinedAt: t, invitedBy: null,
    );
    final b = Member(
      userId: 'u1', farmId: 'f1', role: Role.owner,
      assignedAreaIds: const [], joinedAt: t, invitedBy: null,
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });
}
```

Run: fails (no Member).

- [ ] **Step 2.7: Implement Member**

`lib/src/features/team/domain/member.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/permissions/role.dart';

class Member {
  final String userId;
  final String farmId;
  final Role role;
  final List<String> assignedAreaIds;
  final Timestamp joinedAt;
  final String? invitedBy;
  final Timestamp? removedAt;

  const Member({
    required this.userId,
    required this.farmId,
    required this.role,
    required this.assignedAreaIds,
    required this.joinedAt,
    required this.invitedBy,
    this.removedAt,
  });

  factory Member.fromFirestore(DocumentSnapshot doc, {required String farmId}) {
    final data = doc.data() as Map<String, dynamic>;
    return Member(
      userId: doc.id,
      farmId: farmId,
      role: Role.fromString(data['role'] as String? ?? 'worker'),
      assignedAreaIds: List<String>.from(data['assignedAreaIds'] ?? const []),
      joinedAt: data['joinedAt'] as Timestamp? ?? Timestamp.now(),
      invitedBy: data['invitedBy'] as String?,
      removedAt: data['removedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => {
    'role': role.value,
    'assignedAreaIds': assignedAreaIds,
    'joinedAt': joinedAt,
    'invitedBy': invitedBy,
    if (removedAt != null) 'removedAt': removedAt,
  };

  Member copyWith({
    Role? role,
    List<String>? assignedAreaIds,
    Timestamp? removedAt,
  }) => Member(
    userId: userId,
    farmId: farmId,
    role: role ?? this.role,
    assignedAreaIds: assignedAreaIds ?? this.assignedAreaIds,
    joinedAt: joinedAt,
    invitedBy: invitedBy,
    removedAt: removedAt ?? this.removedAt,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Member &&
          userId == other.userId &&
          farmId == other.farmId &&
          role == other.role &&
          _listEquals(assignedAreaIds, other.assignedAreaIds) &&
          joinedAt == other.joinedAt &&
          invitedBy == other.invitedBy &&
          removedAt == other.removedAt;

  @override
  int get hashCode => Object.hash(
    userId, farmId, role, Object.hashAll(assignedAreaIds),
    joinedAt, invitedBy, removedAt,
  );
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
```

Run: passes.

- [ ] **Step 2.8: Test — Invitation model**

`test/features/team/domain/invitation_test.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/features/team/domain/invitation.dart';
import 'package:farm_app/src/core/permissions/role.dart';

void main() {
  test('Invitation round-trips', () async {
    final f = FakeFirebaseFirestore();
    final t = Timestamp.fromMillisecondsSinceEpoch(2000);
    await f.collection('farms').doc('f1').collection('invitations').doc('i1').set({
      'email': 'juan@example.com',
      'role': 'worker',
      'assignedAreaIds': ['a1'],
      'invitedBy': 'u-owner',
      'createdAt': t,
      'expiresAt': Timestamp.fromMillisecondsSinceEpoch(99999999),
      'status': 'pending',
    });
    final doc = await f.collection('farms').doc('f1').collection('invitations').doc('i1').get();
    final inv = Invitation.fromFirestore(doc, farmId: 'f1');

    expect(inv.id, 'i1');
    expect(inv.farmId, 'f1');
    expect(inv.email, 'juan@example.com');
    expect(inv.role, Role.worker);
    expect(inv.assignedAreaIds, ['a1']);
    expect(inv.status, InvitationStatus.pending);
  });

  test('Email is normalized to lowercase', () {
    final inv = Invitation(
      id: 'x', farmId: 'f', email: 'JOSE@Example.COM',
      role: Role.worker, assignedAreaIds: const [], invitedBy: 'u',
      createdAt: Timestamp.now(), expiresAt: Timestamp.now(),
      status: InvitationStatus.pending,
    );
    expect(inv.normalizedEmail, 'jose@example.com');
  });
}
```

Run: fails.

- [ ] **Step 2.9: Implement Invitation**

`lib/src/features/team/domain/invitation.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/permissions/role.dart';

enum InvitationStatus {
  pending('pending'),
  accepted('accepted'),
  expired('expired'),
  revoked('revoked');

  const InvitationStatus(this.value);
  final String value;

  static InvitationStatus fromString(String s) =>
      InvitationStatus.values.firstWhere(
        (e) => e.value == s,
        orElse: () => InvitationStatus.pending,
      );
}

class Invitation {
  final String id;
  final String farmId;
  final String email;
  final Role role;
  final List<String> assignedAreaIds;
  final String invitedBy;
  final Timestamp createdAt;
  final Timestamp expiresAt;
  final InvitationStatus status;

  const Invitation({
    required this.id,
    required this.farmId,
    required this.email,
    required this.role,
    required this.assignedAreaIds,
    required this.invitedBy,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
  });

  String get normalizedEmail => email.trim().toLowerCase();

  factory Invitation.fromFirestore(DocumentSnapshot doc, {required String farmId}) {
    final d = doc.data() as Map<String, dynamic>;
    return Invitation(
      id: doc.id,
      farmId: farmId,
      email: d['email'] as String,
      role: Role.fromString(d['role'] as String),
      assignedAreaIds: List<String>.from(d['assignedAreaIds'] ?? const []),
      invitedBy: d['invitedBy'] as String,
      createdAt: d['createdAt'] as Timestamp,
      expiresAt: d['expiresAt'] as Timestamp,
      status: InvitationStatus.fromString(d['status'] as String? ?? 'pending'),
    );
  }

  Map<String, dynamic> toMap() => {
    'email': normalizedEmail,
    'role': role.value,
    'assignedAreaIds': assignedAreaIds,
    'invitedBy': invitedBy,
    'createdAt': createdAt,
    'expiresAt': expiresAt,
    'status': status.value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Invitation &&
          id == other.id && farmId == other.farmId &&
          email == other.email && role == other.role &&
          createdAt == other.createdAt && expiresAt == other.expiresAt &&
          status == other.status && invitedBy == other.invitedBy;

  @override
  int get hashCode => Object.hash(
    id, farmId, email, role, createdAt, expiresAt, status, invitedBy,
  );
}
```

Run: passes.

- [ ] **Step 2.10: Test — ActivityEntry**

`test/features/activity/domain/activity_entry_test.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/features/activity/domain/activity_entry.dart';

void main() {
  test('ActivityEntry round-trips', () async {
    final f = FakeFirebaseFirestore();
    final t = Timestamp.fromMillisecondsSinceEpoch(3000);
    await f.collection('farms').doc('f1').collection('activity').doc('e1').set({
      'actorUserId': 'u1',
      'actorDisplayName': 'Juan',
      'action': 'pig_added',
      'entityType': 'pig',
      'entityId': 'p1',
      'areaId': 'a1',
      'summary': 'Juan added pig SOW-001',
      'timestamp': t,
    });
    final doc = await f.collection('farms').doc('f1').collection('activity').doc('e1').get();
    final e = ActivityEntry.fromFirestore(doc, farmId: 'f1');

    expect(e.id, 'e1');
    expect(e.actorUserId, 'u1');
    expect(e.actorDisplayName, 'Juan');
    expect(e.action, 'pig_added');
    expect(e.entityType, 'pig');
    expect(e.entityId, 'p1');
    expect(e.areaId, 'a1');
    expect(e.summary, 'Juan added pig SOW-001');
    expect(e.timestamp, t);
  });
}
```

Run: fails.

- [ ] **Step 2.11: Implement ActivityEntry**

`lib/src/features/activity/domain/activity_entry.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityEntry {
  final String id;
  final String farmId;
  final String actorUserId;
  final String actorDisplayName;
  final String action;
  final String entityType;
  final String entityId;
  final String? areaId;
  final String summary;
  final Timestamp timestamp;

  const ActivityEntry({
    required this.id,
    required this.farmId,
    required this.actorUserId,
    required this.actorDisplayName,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.areaId,
    required this.summary,
    required this.timestamp,
  });

  factory ActivityEntry.fromFirestore(DocumentSnapshot doc, {required String farmId}) {
    final d = doc.data() as Map<String, dynamic>;
    return ActivityEntry(
      id: doc.id,
      farmId: farmId,
      actorUserId: d['actorUserId'] as String,
      actorDisplayName: d['actorDisplayName'] as String,
      action: d['action'] as String,
      entityType: d['entityType'] as String,
      entityId: d['entityId'] as String,
      areaId: d['areaId'] as String?,
      summary: d['summary'] as String,
      timestamp: d['timestamp'] as Timestamp,
    );
  }

  Map<String, dynamic> toMap() => {
    'actorUserId': actorUserId,
    'actorDisplayName': actorDisplayName,
    'action': action,
    'entityType': entityType,
    'entityId': entityId,
    if (areaId != null) 'areaId': areaId,
    'summary': summary,
    'timestamp': timestamp,
  };
}
```

Run: passes.

- [ ] **Step 2.12: Test — ActivityRepository (writes via batch)**

`test/features/activity/data/activity_repository_test.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/features/activity/data/activity_repository.dart';

void main() {
  test('addActivityToBatch writes to farms/{id}/activity/', () async {
    final f = FakeFirebaseFirestore();
    final repo = ActivityRepository(f);
    final batch = f.batch();
    repo.addActivityToBatch(
      batch: batch,
      farmId: 'f1',
      actorUserId: 'u1',
      actorDisplayName: 'Juan',
      action: 'pig_added',
      entityType: 'pig',
      entityId: 'p1',
      areaId: 'a1',
      summary: 'Juan added pig SOW-001',
    );
    await batch.commit();

    final snap = await f.collection('farms').doc('f1').collection('activity').get();
    expect(snap.docs, hasLength(1));
    final d = snap.docs.first.data();
    expect(d['actorUserId'], 'u1');
    expect(d['action'], 'pig_added');
    expect(d['summary'], 'Juan added pig SOW-001');
  });

  test('streamRecent returns entries newest-first, limited', () async {
    final f = FakeFirebaseFirestore();
    for (var i = 0; i < 3; i++) {
      await f.collection('farms').doc('f1').collection('activity').add({
        'actorUserId': 'u1', 'actorDisplayName': 'Juan',
        'action': 'pig_added', 'entityType': 'pig', 'entityId': 'p$i',
        'summary': 's$i',
        'timestamp': Timestamp.fromMillisecondsSinceEpoch(i * 1000),
      });
    }
    final repo = ActivityRepository(f);
    final entries = await repo.streamRecent('f1', limit: 2).first;
    expect(entries, hasLength(2));
    expect(entries[0].summary, 's2');
    expect(entries[1].summary, 's1');
  });
}
```

Run: fails.

- [ ] **Step 2.13: Implement ActivityRepository**

`lib/src/features/activity/data/activity_repository.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/activity_entry.dart';

class ActivityRepository {
  ActivityRepository(this._firestore);
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _col(String farmId) =>
      _firestore.collection('farms').doc(farmId).collection('activity');

  /// Adds an activity write to an existing batch so the source-record write
  /// and the activity entry land atomically.
  void addActivityToBatch({
    required WriteBatch batch,
    required String farmId,
    required String actorUserId,
    required String actorDisplayName,
    required String action,
    required String entityType,
    required String entityId,
    String? areaId,
    required String summary,
  }) {
    final doc = _col(farmId).doc();
    batch.set(doc, {
      'actorUserId': actorUserId,
      'actorDisplayName': actorDisplayName,
      'action': action,
      'entityType': entityType,
      'entityId': entityId,
      if (areaId != null) 'areaId': areaId,
      'summary': summary,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<ActivityEntry>> streamRecent(String farmId, {int limit = 50}) {
    return _col(farmId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs
            .map((d) => ActivityEntry.fromFirestore(d, farmId: farmId))
            .toList());
  }

  Stream<List<ActivityEntry>> streamFiltered(
    String farmId, {
    int limit = 50,
    List<String>? actorIds,
    List<String>? actions,
    List<String>? areaIds,
  }) {
    Query<Map<String, dynamic>> q = _col(farmId).orderBy('timestamp', descending: true);
    if (actorIds != null && actorIds.isNotEmpty) {
      q = q.where('actorUserId', whereIn: actorIds);
    }
    if (actions != null && actions.isNotEmpty) {
      q = q.where('action', whereIn: actions);
    }
    if (areaIds != null && areaIds.isNotEmpty) {
      q = q.where('areaId', whereIn: areaIds);
    }
    q = q.limit(limit);
    return q.snapshots().map((s) =>
        s.docs.map((d) => ActivityEntry.fromFirestore(d, farmId: farmId)).toList());
  }
}
```

Run: passes.

- [ ] **Step 2.14: Activity providers**

`lib/src/features/activity/application/activity_providers.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/activity_repository.dart';
import '../domain/activity_entry.dart';

final firestoreProvider = Provider<FirebaseFirestore>((_) => FirebaseFirestore.instance);

final activityRepositoryProvider = Provider<ActivityRepository>(
  (ref) => ActivityRepository(ref.watch(firestoreProvider)),
);

final recentActivityProvider =
    StreamProvider.family<List<ActivityEntry>, String>((ref, farmId) {
  return ref.watch(activityRepositoryProvider).streamRecent(farmId, limit: 50);
});
```

(`firestoreProvider` is centralized here; subsequent repositories will import it.)

- [ ] **Step 2.15: Update AppUser model**

Edit `lib/src/features/authentication/domain/user_model.dart`:

```dart
class AppUser {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String? lastSelectedFarmId;

  const AppUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.lastSelectedFarmId,
  });

  factory AppUser.fromMap(Map<String, dynamic> data) => AppUser(
    uid: data['uid'] as String,
    email: data['email'] as String,
    displayName: data['displayName'] as String?,
    photoUrl: data['photoUrl'] as String?,
    lastSelectedFarmId: data['lastSelectedFarmId'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
    'displayName': displayName,
    'photoUrl': photoUrl,
    'lastSelectedFarmId': lastSelectedFarmId,
  };

  AppUser copyWith({
    String? displayName,
    String? photoUrl,
    String? lastSelectedFarmId,
  }) => AppUser(
    uid: uid, email: email,
    displayName: displayName ?? this.displayName,
    photoUrl: photoUrl ?? this.photoUrl,
    lastSelectedFarmId: lastSelectedFarmId ?? this.lastSelectedFarmId,
  );
}
```

Note: `farmId` and `hasCompletedSetup` are gone. The router's "has farm membership" check is now driven by a collection-group query on `members/{uid}` — added in Task 2's team repository (next).

- [ ] **Step 2.16: Run full test suite + analyze**

```bash
flutter analyze
flutter test
```
Expected: both pass.

- [ ] **Step 2.17: Commit**

```bash
git add lib test
git commit -m "feat(team,activity): add Member, Invitation, ActivityEntry, ActivityRepository

- Member and Invitation models with Firestore round-trip tests
- ActivityEntry + ActivityRepository with atomic-batch write helper
- Extend AppUser with photoUrl and lastSelectedFarmId
- Remove obsolete farmId + hasCompletedSetup (replaced by membership query)"
```

---

## Task 3: TeamRepository, FarmRepository, Multi-farm membership stream, Farm switcher, Auth flow rewrite

**Goal:** Build the complete data path for team management + multi-farm membership. Replace the old setup flow with: sign-up → accept invitation if present, else → create-first-farm. Add a farm-switcher UI in the AppBar. Build invite/manage-team screens.

**Files:**
- Create:
  - `lib/src/features/team/data/team_repository.dart`
  - `lib/src/features/team/application/team_providers.dart`
  - `lib/src/features/team/presentation/team_management_screen.dart`
  - `lib/src/features/team/presentation/invite_member_screen.dart`
  - `lib/src/features/team/presentation/accept_invitation_screen.dart`
  - `lib/src/features/farms/data/farm_repository.dart` (replaces existing)
  - `lib/src/features/farms/application/farm_providers.dart` (replaces existing)
  - `lib/src/features/farms/presentation/farm_switcher.dart`
  - `lib/src/features/farms/presentation/create_farm_screen.dart`
  - `lib/src/features/farms/presentation/farm_setup_screen.dart`
  - `test/features/team/data/team_repository_test.dart`
  - `test/features/farms/data/farm_repository_test.dart`
- Modify:
  - `lib/src/features/farms/domain/farm_model.dart`
  - `lib/src/features/authentication/application/auth_providers.dart`
  - `lib/src/features/authentication/data/auth_repository.dart`
  - `lib/src/routing/app_router.dart`

### Steps

- [ ] **Step 3.1: Test — TeamRepository CRUD**

`test/features/team/data/team_repository_test.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/core/permissions/role.dart';
import 'package:farm_app/src/features/team/data/team_repository.dart';

void main() {
  test('addMember writes to members subcollection', () async {
    final f = FakeFirebaseFirestore();
    final repo = TeamRepository(f);
    await repo.addMember(
      farmId: 'f1', userId: 'u1', role: Role.owner,
      assignedAreaIds: const [], invitedBy: null,
    );
    final doc = await f.collection('farms').doc('f1').collection('members').doc('u1').get();
    expect(doc.exists, true);
    expect(doc.data()!['role'], 'owner');
  });

  test('streamMembers returns all non-removed', () async {
    final f = FakeFirebaseFirestore();
    final repo = TeamRepository(f);
    await repo.addMember(farmId: 'f1', userId: 'u1', role: Role.owner, assignedAreaIds: const [], invitedBy: null);
    await repo.addMember(farmId: 'f1', userId: 'u2', role: Role.worker, assignedAreaIds: const ['a1'], invitedBy: 'u1');
    final members = await repo.streamMembers('f1').first;
    expect(members, hasLength(2));
  });

  test('updateMemberRole changes role', () async {
    final f = FakeFirebaseFirestore();
    final repo = TeamRepository(f);
    await repo.addMember(farmId: 'f1', userId: 'u2', role: Role.worker, assignedAreaIds: const [], invitedBy: 'u1');
    await repo.updateMemberRole(farmId: 'f1', userId: 'u2', newRole: Role.manager);
    final doc = await f.collection('farms').doc('f1').collection('members').doc('u2').get();
    expect(doc.data()!['role'], 'manager');
  });

  test('createInvitation sets normalized email + pending status', () async {
    final f = FakeFirebaseFirestore();
    final repo = TeamRepository(f);
    final id = await repo.createInvitation(
      farmId: 'f1', email: 'NEW@Example.COM', role: Role.worker,
      assignedAreaIds: const ['a1'], invitedBy: 'u1',
    );
    final doc = await f.collection('farms').doc('f1').collection('invitations').doc(id).get();
    expect(doc.data()!['email'], 'new@example.com');
    expect(doc.data()!['status'], 'pending');
  });

  test('findPendingInvitationsForEmail returns matches across farms', () async {
    final f = FakeFirebaseFirestore();
    final repo = TeamRepository(f);
    await repo.createInvitation(farmId: 'f1', email: 'me@x.com', role: Role.worker, assignedAreaIds: const [], invitedBy: 'u1');
    await repo.createInvitation(farmId: 'f2', email: 'me@x.com', role: Role.vet, assignedAreaIds: const [], invitedBy: 'u1');
    final results = await repo.findPendingInvitationsForEmail('me@x.com');
    expect(results, hasLength(2));
  });

  test('acceptInvitation creates member and marks invitation accepted', () async {
    final f = FakeFirebaseFirestore();
    final repo = TeamRepository(f);
    final invId = await repo.createInvitation(
      farmId: 'f1', email: 'me@x.com', role: Role.worker, assignedAreaIds: const ['a1'], invitedBy: 'u1',
    );
    await repo.acceptInvitation(farmId: 'f1', invitationId: invId, userId: 'u-new');
    final memberDoc = await f.collection('farms').doc('f1').collection('members').doc('u-new').get();
    expect(memberDoc.exists, true);
    expect(memberDoc.data()!['role'], 'worker');
    final invDoc = await f.collection('farms').doc('f1').collection('invitations').doc(invId).get();
    expect(invDoc.data()!['status'], 'accepted');
  });

  test('streamUserMemberships returns user farms via collection-group', () async {
    final f = FakeFirebaseFirestore();
    final repo = TeamRepository(f);
    await repo.addMember(farmId: 'f1', userId: 'u-me', role: Role.owner, assignedAreaIds: const [], invitedBy: null);
    await repo.addMember(farmId: 'f2', userId: 'u-me', role: Role.vet, assignedAreaIds: const [], invitedBy: 'u1');
    await repo.addMember(farmId: 'f1', userId: 'u-other', role: Role.worker, assignedAreaIds: const [], invitedBy: null);
    final result = await repo.streamUserMemberships('u-me').first;
    expect(result.map((m) => m.farmId).toSet(), {'f1', 'f2'});
  });
}
```

Run: fails (no TeamRepository).

- [ ] **Step 3.2: Implement TeamRepository**

`lib/src/features/team/data/team_repository.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/permissions/role.dart';
import '../domain/member.dart';
import '../domain/invitation.dart';

class TeamRepository {
  TeamRepository(this._firestore);
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _members(String farmId) =>
      _firestore.collection('farms').doc(farmId).collection('members');

  CollectionReference<Map<String, dynamic>> _invitations(String farmId) =>
      _firestore.collection('farms').doc(farmId).collection('invitations');

  Future<void> addMember({
    required String farmId,
    required String userId,
    required Role role,
    required List<String> assignedAreaIds,
    required String? invitedBy,
  }) async {
    await _members(farmId).doc(userId).set({
      'role': role.value,
      'assignedAreaIds': assignedAreaIds,
      'joinedAt': FieldValue.serverTimestamp(),
      'invitedBy': invitedBy,
    });
  }

  Stream<List<Member>> streamMembers(String farmId) {
    return _members(farmId).snapshots().map((s) => s.docs
        .map((d) => Member.fromFirestore(d, farmId: farmId))
        .where((m) => m.removedAt == null)
        .toList());
  }

  Stream<Member?> streamMember({required String farmId, required String userId}) {
    return _members(farmId).doc(userId).snapshots().map(
      (d) => d.exists ? Member.fromFirestore(d, farmId: farmId) : null,
    );
  }

  Future<void> updateMemberRole({
    required String farmId,
    required String userId,
    required Role newRole,
  }) async {
    await _members(farmId).doc(userId).update({'role': newRole.value});
  }

  Future<void> updateMemberAreaAssignments({
    required String farmId,
    required String userId,
    required List<String> assignedAreaIds,
  }) async {
    await _members(farmId).doc(userId).update({'assignedAreaIds': assignedAreaIds});
  }

  Future<void> removeMember({required String farmId, required String userId}) async {
    await _members(farmId).doc(userId).update({'removedAt': FieldValue.serverTimestamp()});
  }

  Future<String> createInvitation({
    required String farmId,
    required String email,
    required Role role,
    required List<String> assignedAreaIds,
    required String invitedBy,
  }) async {
    final normalized = email.trim().toLowerCase();
    final doc = _invitations(farmId).doc();
    final now = Timestamp.now();
    final expires = Timestamp.fromDate(now.toDate().add(const Duration(days: 14)));
    await doc.set({
      'email': normalized,
      'role': role.value,
      'assignedAreaIds': assignedAreaIds,
      'invitedBy': invitedBy,
      'createdAt': now,
      'expiresAt': expires,
      'status': 'pending',
    });
    return doc.id;
  }

  Stream<List<Invitation>> streamInvitations(String farmId) {
    return _invitations(farmId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Invitation.fromFirestore(d, farmId: farmId)).toList());
  }

  Future<void> revokeInvitation({required String farmId, required String invitationId}) async {
    await _invitations(farmId).doc(invitationId).update({'status': 'revoked'});
  }

  /// Collection-group query on `invitations` to find all pending invites for an email
  /// across every farm.
  Future<List<Invitation>> findPendingInvitationsForEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    final snap = await _firestore
        .collectionGroup('invitations')
        .where('email', isEqualTo: normalized)
        .where('status', isEqualTo: 'pending')
        .get();
    return snap.docs.map((d) {
      final farmId = d.reference.parent.parent!.id;
      return Invitation.fromFirestore(d, farmId: farmId);
    }).toList();
  }

  Future<void> acceptInvitation({
    required String farmId,
    required String invitationId,
    required String userId,
  }) async {
    final invRef = _invitations(farmId).doc(invitationId);
    final memberRef = _members(farmId).doc(userId);
    final inv = await invRef.get();
    final d = inv.data()!;
    final batch = _firestore.batch();
    batch.set(memberRef, {
      'role': d['role'],
      'assignedAreaIds': d['assignedAreaIds'] ?? const [],
      'joinedAt': FieldValue.serverTimestamp(),
      'invitedBy': d['invitedBy'],
    });
    batch.update(invRef, {'status': 'accepted'});
    await batch.commit();
  }

  /// Collection-group query on `members` to list all farms a user belongs to.
  Stream<List<Member>> streamUserMemberships(String userId) {
    return _firestore
        .collectionGroup('members')
        .where(FieldPath.documentId, isEqualTo: userId)
        .snapshots()
        .map((s) {
          return s.docs.map((d) {
            final farmId = d.reference.parent.parent!.id;
            return Member.fromFirestore(d, farmId: farmId);
          }).where((m) => m.removedAt == null).toList();
        });
  }
}
```

Run: passes.

- [ ] **Step 3.3: Test — FarmRepository**

`test/features/farms/data/farm_repository_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/core/permissions/role.dart';
import 'package:farm_app/src/features/farms/data/farm_repository.dart';

void main() {
  test('createFarmWithOwner creates farm + owner member atomically', () async {
    final f = FakeFirebaseFirestore();
    final repo = FarmRepository(f);
    final farmId = await repo.createFarmWithOwner(name: 'My Piggery', ownerUserId: 'u1');

    final farmDoc = await f.collection('farms').doc(farmId).get();
    expect(farmDoc.exists, true);
    expect(farmDoc.data()!['name'], 'My Piggery');
    expect(farmDoc.data()!['createdBy'], 'u1');

    final memberDoc = await f.collection('farms').doc(farmId).collection('members').doc('u1').get();
    expect(memberDoc.exists, true);
    expect(memberDoc.data()!['role'], 'owner');
  });

  test('updateFarmName updates name', () async {
    final f = FakeFirebaseFirestore();
    final repo = FarmRepository(f);
    final id = await repo.createFarmWithOwner(name: 'A', ownerUserId: 'u1');
    await repo.updateFarmName(farmId: id, newName: 'B');
    final farmDoc = await f.collection('farms').doc(id).get();
    expect(farmDoc.data()!['name'], 'B');
  });

  test('streamFarm emits the farm doc', () async {
    final f = FakeFirebaseFirestore();
    final repo = FarmRepository(f);
    final id = await repo.createFarmWithOwner(name: 'X', ownerUserId: 'u1');
    final farm = await repo.streamFarm(id).first;
    expect(farm?.name, 'X');
    expect(farm?.id, id);
  });
}
```

Run: fails.

- [ ] **Step 3.4: Update Farm model and implement FarmRepository**

Replace `lib/src/features/farms/domain/farm_model.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Farm {
  final String id;
  final String name;
  final String createdBy;
  final Timestamp createdAt;

  const Farm({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.createdAt,
  });

  factory Farm.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Farm(
      id: doc.id,
      name: d['name'] as String,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'createdBy': createdBy,
    'createdAt': createdAt,
  };
}
```

Create `lib/src/features/farms/data/farm_repository.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/farm_model.dart';

class FarmRepository {
  FarmRepository(this._firestore);
  final FirebaseFirestore _firestore;

  Future<String> createFarmWithOwner({
    required String name,
    required String ownerUserId,
  }) async {
    final farmRef = _firestore.collection('farms').doc();
    final memberRef = farmRef.collection('members').doc(ownerUserId);
    final batch = _firestore.batch();
    batch.set(farmRef, {
      'name': name.trim(),
      'createdBy': ownerUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(memberRef, {
      'role': 'owner',
      'assignedAreaIds': <String>[],
      'joinedAt': FieldValue.serverTimestamp(),
      'invitedBy': null,
    });
    await batch.commit();
    return farmRef.id;
  }

  Future<void> updateFarmName({required String farmId, required String newName}) async {
    await _firestore.collection('farms').doc(farmId).update({'name': newName.trim()});
  }

  Stream<Farm?> streamFarm(String farmId) {
    return _firestore.collection('farms').doc(farmId).snapshots().map(
      (d) => d.exists ? Farm.fromFirestore(d) : null,
    );
  }
}
```

Run: passes.

- [ ] **Step 3.5: Team providers + farm providers**

`lib/src/features/team/application/team_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../activity/application/activity_providers.dart';
import '../data/team_repository.dart';
import '../domain/invitation.dart';
import '../domain/member.dart';

final teamRepositoryProvider = Provider<TeamRepository>(
  (ref) => TeamRepository(ref.watch(firestoreProvider)),
);

final membersStreamProvider =
    StreamProvider.family<List<Member>, String>((ref, farmId) {
  return ref.watch(teamRepositoryProvider).streamMembers(farmId);
});

final memberForUserProvider =
    StreamProvider.family<Member?, ({String farmId, String userId})>((ref, args) {
  return ref.watch(teamRepositoryProvider).streamMember(
        farmId: args.farmId,
        userId: args.userId,
      );
});

final invitationsStreamProvider =
    StreamProvider.family<List<Invitation>, String>((ref, farmId) {
  return ref.watch(teamRepositoryProvider).streamInvitations(farmId);
});

final userMembershipsProvider =
    StreamProvider.family<List<Member>, String>((ref, userId) {
  return ref.watch(teamRepositoryProvider).streamUserMemberships(userId);
});
```

`lib/src/features/farms/application/farm_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../activity/application/activity_providers.dart';
import '../../authentication/application/auth_providers.dart';
import '../../team/application/team_providers.dart';
import '../data/farm_repository.dart';
import '../domain/farm_model.dart';

final farmRepositoryProvider = Provider<FarmRepository>(
  (ref) => FarmRepository(ref.watch(firestoreProvider)),
);

/// The user's currently selected farm.
/// - If user has a stored preference matching a farm they belong to, use it.
/// - Else use the first membership.
/// - Returns null if user has no memberships (triggers create-first-farm flow).
final selectedFarmIdProvider = StateProvider<String?>((ref) => null);

final selectedFarmProvider = StreamProvider<Farm?>((ref) {
  final farmId = ref.watch(selectedFarmIdProvider);
  if (farmId == null) return const Stream.empty();
  return ref.watch(farmRepositoryProvider).streamFarm(farmId);
});

/// Resolves the initial selected farm from user memberships + stored preference.
/// Called once at app start when memberships first load.
final initialFarmResolverProvider = Provider<void>((ref) {
  final user = ref.watch(authStateChangesProvider).asData?.value;
  if (user == null) return;
  final memberships = ref.watch(userMembershipsProvider(user.uid)).asData?.value;
  if (memberships == null || memberships.isEmpty) return;
  final current = ref.read(selectedFarmIdProvider);
  if (current != null && memberships.any((m) => m.farmId == current)) return;

  SharedPreferences.getInstance().then((prefs) {
    final stored = prefs.getString('lastSelectedFarmId_${user.uid}');
    final pick = stored != null && memberships.any((m) => m.farmId == stored)
        ? stored
        : memberships.first.farmId;
    ref.read(selectedFarmIdProvider.notifier).state = pick;
  });
});

Future<void> persistSelectedFarmId(String userId, String farmId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('lastSelectedFarmId_$userId', farmId);
}
```

- [ ] **Step 3.6: Update AuthRepository**

Replace `lib/src/features/authentication/data/auth_repository.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../domain/user_model.dart' as model;

class AuthRepository {
  AuthRepository(this._auth, this._firestore);
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password,
      );
      if (cred.user != null) await _ensureUserDoc(cred.user!);
      return cred;
    } on FirebaseAuthException catch (e) {
      throw _authError(e);
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw _authError(e);
    }
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> _ensureUserDoc(User user) async {
    final ref = _firestore.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set(model.AppUser(
        uid: user.uid,
        email: user.email!,
      ).toMap());
    }
  }

  Future<model.AppUser?> getUserDoc(String uid) async {
    final snap = await _firestore.collection('users').doc(uid).get();
    if (!snap.exists) return null;
    return model.AppUser.fromMap(snap.data()!);
  }

  Future<void> setDisplayName({required String userId, required String displayName}) async {
    await _firestore.collection('users').doc(userId).update({'displayName': displayName.trim()});
  }

  Future<void> setLastSelectedFarmId({required String userId, required String farmId}) async {
    await _firestore.collection('users').doc(userId).update({'lastSelectedFarmId': farmId});
  }

  Exception _authError(FirebaseAuthException e) {
    if (e.code == 'weak-password') return Exception('The password provided is too weak.');
    if (e.code == 'email-already-in-use') return Exception('An account already exists for that email.');
    if (e.code == 'invalid-email') return Exception('The email address is not valid.');
    if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
      return Exception('Invalid email or password.');
    }
    return Exception('An error occurred. Please try again.');
  }
}
```

- [ ] **Step 3.7: Update auth providers**

`lib/src/features/authentication/application/auth_providers.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../activity/application/activity_providers.dart';
import '../data/auth_repository.dart';
import '../domain/user_model.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((_) => FirebaseAuth.instance);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(firebaseAuthProvider), ref.watch(firestoreProvider)),
);

final authStateChangesProvider = StreamProvider<User?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges,
);

final currentAppUserProvider = StreamProvider<AppUser?>((ref) {
  final user = ref.watch(authStateChangesProvider).asData?.value;
  if (user == null) return Stream.value(null);
  return ref.watch(firestoreProvider)
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((d) => d.exists ? AppUser.fromMap(d.data()!) : null);
});
```

- [ ] **Step 3.8: Implement Farm Setup screens**

`lib/src/features/farms/presentation/create_farm_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../authentication/application/auth_providers.dart';
import '../application/farm_providers.dart';

class CreateFarmScreen extends ConsumerStatefulWidget {
  const CreateFarmScreen({super.key});
  @override
  ConsumerState<CreateFarmScreen> createState() => _CreateFarmScreenState();
}

class _CreateFarmScreenState extends ConsumerState<CreateFarmScreen> {
  final _displayName = TextEditingController();
  final _farmName = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() { _displayName.dispose(); _farmName.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (user == null) return;
    if (_displayName.text.trim().isEmpty || _farmName.text.trim().isEmpty) {
      setState(() => _error = 'Both fields are required.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authRepositoryProvider).setDisplayName(
            userId: user.uid, displayName: _displayName.text.trim(),
          );
      final farmId = await ref.read(farmRepositoryProvider).createFarmWithOwner(
            name: _farmName.text.trim(), ownerUserId: user.uid,
          );
      await ref.read(authRepositoryProvider).setLastSelectedFarmId(
            userId: user.uid, farmId: farmId,
          );
      await persistSelectedFarmId(user.uid, farmId);
      ref.read(selectedFarmIdProvider.notifier).state = farmId;
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome — set up your farm')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Your name', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(controller: _displayName, decoration: const InputDecoration(labelText: 'Display name')),
            const SizedBox(height: 24),
            const Text('Farm name', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(controller: _farmName, decoration: const InputDecoration(labelText: 'Farm name')),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading ? const CircularProgressIndicator() : const Text('Create farm'),
            ),
          ],
        ),
      ),
    );
  }
}
```

`lib/src/features/farms/presentation/farm_setup_screen.dart` — dispatches between Accept Invitation and Create First Farm:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/application/auth_providers.dart';
import '../../team/application/team_providers.dart';
import '../../team/presentation/accept_invitation_screen.dart';
import 'create_farm_screen.dart';

class FarmSetupScreen extends ConsumerWidget {
  const FarmSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentAppUserProvider).asData?.value;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final invitationsAsync = ref.watch(_pendingInvitationsProvider(user.email));
    return invitationsAsync.when(
      data: (invs) => invs.isNotEmpty
          ? AcceptInvitationScreen(invitations: invs)
          : const CreateFarmScreen(),
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}

final _pendingInvitationsProvider = FutureProvider.family((ref, String email) {
  return ref.watch(teamRepositoryProvider).findPendingInvitationsForEmail(email);
});
```

- [ ] **Step 3.9: Accept Invitation screen**

`lib/src/features/team/presentation/accept_invitation_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../application/team_providers.dart';
import '../domain/invitation.dart';

class AcceptInvitationScreen extends ConsumerStatefulWidget {
  const AcceptInvitationScreen({super.key, required this.invitations});
  final List<Invitation> invitations;
  @override
  ConsumerState<AcceptInvitationScreen> createState() => _State();
}

class _State extends ConsumerState<AcceptInvitationScreen> {
  bool _busy = false;

  Future<void> _accept(Invitation inv) async {
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (user == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(teamRepositoryProvider).acceptInvitation(
            farmId: inv.farmId, invitationId: inv.id, userId: user.uid,
          );
      await persistSelectedFarmId(user.uid, inv.farmId);
      ref.read(selectedFarmIdProvider.notifier).state = inv.farmId;
      if (mounted) context.go('/');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("You're invited")),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: widget.invitations.length,
        itemBuilder: (_, i) {
          final inv = widget.invitations[i];
          return Card(
            child: ListTile(
              title: Text('Farm ${inv.farmId}'),
              subtitle: Text('Role: ${inv.role.value}'),
              trailing: ElevatedButton(
                onPressed: _busy ? null : () => _accept(inv),
                child: const Text('Accept'),
              ),
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 3.10: Team Management & Invite Member screens**

`lib/src/features/team/presentation/invite_member_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/permissions/role.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../application/team_providers.dart';

class InviteMemberScreen extends ConsumerStatefulWidget {
  const InviteMemberScreen({super.key});
  @override
  ConsumerState<InviteMemberScreen> createState() => _S();
}

class _S extends ConsumerState<InviteMemberScreen> {
  final _email = TextEditingController();
  Role _role = Role.worker;
  bool _busy = false;
  String? _error;

  @override
  void dispose() { _email.dispose(); super.dispose(); }

  Future<void> _send() async {
    final farmId = ref.read(selectedFarmIdProvider);
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return;
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'Email required.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await ref.read(teamRepositoryProvider).createInvitation(
            farmId: farmId, email: _email.text,
            role: _role, assignedAreaIds: const [],
            invitedBy: user.uid,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invite member')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 16),
            DropdownButtonFormField<Role>(
              value: _role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: const [
                DropdownMenuItem(value: Role.manager, child: Text('Manager')),
                DropdownMenuItem(value: Role.worker, child: Text('Worker')),
                DropdownMenuItem(value: Role.vet, child: Text('Veterinarian')),
              ],
              onChanged: (v) => setState(() => _role = v ?? Role.worker),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _busy ? null : _send,
              child: _busy ? const CircularProgressIndicator() : const Text('Send invitation'),
            ),
          ],
        ),
      ),
    );
  }
}
```

`lib/src/features/team/presentation/team_management_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/permissions/role.dart';
import '../../farms/application/farm_providers.dart';
import '../application/team_providers.dart';
import 'invite_member_screen.dart';

class TeamManagementScreen extends ConsumerWidget {
  const TeamManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) {
      return const Scaffold(body: Center(child: Text('No farm selected')));
    }
    final membersAsync = ref.watch(membersStreamProvider(farmId));
    final invitationsAsync = ref.watch(invitationsStreamProvider(farmId));

    return Scaffold(
      appBar: AppBar(title: const Text('Team')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add),
        label: const Text('Invite'),
        onPressed: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => const InviteMemberScreen()),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Members', style: TextStyle(fontWeight: FontWeight.bold)),
          membersAsync.when(
            data: (members) => Column(
              children: members.map((m) => Card(
                child: ListTile(
                  title: Text(m.userId),
                  subtitle: Text('Role: ${m.role.value}'),
                  trailing: DropdownButton<Role>(
                    value: m.role,
                    onChanged: (v) {
                      if (v != null) {
                        ref.read(teamRepositoryProvider).updateMemberRole(
                              farmId: farmId, userId: m.userId, newRole: v,
                            );
                      }
                    },
                    items: Role.values.map((r) =>
                      DropdownMenuItem(value: r, child: Text(r.value))).toList(),
                  ),
                ),
              )).toList(),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
          const SizedBox(height: 24),
          const Text('Pending invitations', style: TextStyle(fontWeight: FontWeight.bold)),
          invitationsAsync.when(
            data: (invs) => Column(
              children: invs.where((i) => i.status.value == 'pending').map((inv) => Card(
                child: ListTile(
                  title: Text(inv.email),
                  subtitle: Text('${inv.role.value} · expires ${inv.expiresAt.toDate().toLocal()}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.cancel),
                    onPressed: () => ref.read(teamRepositoryProvider)
                        .revokeInvitation(farmId: farmId, invitationId: inv.id),
                  ),
                ),
              )).toList(),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3.11: Farm switcher widget**

`lib/src/features/farms/presentation/farm_switcher.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../authentication/application/auth_providers.dart';
import '../../team/application/team_providers.dart';
import '../application/farm_providers.dart';

class FarmSwitcher extends ConsumerWidget {
  const FarmSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateChangesProvider).asData?.value;
    if (user == null) return const SizedBox.shrink();
    final memberships = ref.watch(userMembershipsProvider(user.uid));
    final selectedFarm = ref.watch(selectedFarmProvider);

    return memberships.when(
      data: (members) {
        final farms = members.map((m) => m.farmId).toList();
        return PopupMenuButton<String>(
          tooltip: 'Switch farm',
          onSelected: (value) async {
            if (value == '__new__') {
              context.push('/create-farm');
            } else {
              await persistSelectedFarmId(user.uid, value);
              await ref.read(authRepositoryProvider).setLastSelectedFarmId(
                    userId: user.uid, farmId: value,
                  );
              ref.read(selectedFarmIdProvider.notifier).state = value;
            }
          },
          itemBuilder: (_) => [
            ...farms.map((id) => PopupMenuItem(value: id, child: Text('Farm $id'))),
            const PopupMenuDivider(),
            const PopupMenuItem(value: '__new__', child: Text('+ Create new farm')),
          ],
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(selectedFarm.asData?.value?.name ?? '—',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const Icon(Icons.error),
    );
  }
}
```

- [ ] **Step 3.12: Rewire `app_router.dart`**

Replace `lib/src/routing/app_router.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/splash_screen.dart';
import '../features/authentication/application/auth_providers.dart';
import '../features/authentication/presentation/login_screen.dart';
import '../features/authentication/presentation/signup_screen.dart';
import '../features/farms/application/farm_providers.dart';
import '../features/farms/presentation/create_farm_screen.dart';
import '../features/farms/presentation/farm_setup_screen.dart';
import '../features/team/application/team_providers.dart';
import '../features/team/presentation/team_management_screen.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final user = authState.asData?.value;

  // Drive initial farm selection.
  ref.watch(initialFarmResolverProvider);

  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      if (authState.isLoading) return '/splash';
      final isLoggedIn = user != null;
      final isAtAuth = state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup';
      final isAtSetup = state.matchedLocation == '/setup' ||
          state.matchedLocation == '/create-farm';

      if (!isLoggedIn) return isAtAuth ? null : '/login';

      final memberships = ref.read(userMembershipsProvider(user.uid)).asData?.value;
      // Memberships still loading? Hold at splash.
      if (memberships == null) return '/splash';

      if (memberships.isEmpty) {
        return isAtSetup ? null : '/setup';
      }

      // Has at least one membership; ensure selected farm is set.
      final selected = ref.read(selectedFarmIdProvider);
      if (selected == null) return '/splash';

      if (isAtAuth || isAtSetup) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (c, s) => const SignUpScreen()),
      GoRoute(path: '/setup', builder: (c, s) => const FarmSetupScreen()),
      GoRoute(path: '/create-farm', builder: (c, s) => const CreateFarmScreen()),
      GoRoute(path: '/team', builder: (c, s) => const TeamManagementScreen()),
      GoRoute(
        path: '/',
        builder: (c, s) => const Scaffold(
          body: Center(child: Text('Home — Pigs/Dashboard built in later tasks')),
        ),
      ),
    ],
  );
});
```

- [ ] **Step 3.13: Run tests + manual smoke**

```bash
flutter analyze
flutter test
flutter run -d <device>
```

Manual:
1. Sign up as User A → see Create Farm screen → create "My Test Piggery" → land on placeholder home.
2. Sign up as User B → invite from a separate path doesn't exist yet (covered by /team — but they'd need to be invited from A's session first). Sign out, log back in as A → go to /team → invite User B's email as Worker.
3. Sign up as User B → should land on Accept Invitation → accept → home.

- [ ] **Step 3.14: Commit**

```bash
git add -A
git commit -m "feat(team,farms): multi-farm membership, invitations, switcher, auth flow

- TeamRepository with member CRUD, invitations, collection-group lookups
- FarmRepository with createFarmWithOwner (atomic farm + owner member)
- Replace single-farm setup with: sign-up → accept invite OR create farm
- Add FarmSwitcher widget for AppBar
- Rewire app_router.dart for new flow"
```

---

## Task 4: Areas & Pens

**Goal:** Replace the deleted flat `locations/` with the new `areas/{id}/pens/{id}` hierarchy. Build the areas list, edit-area screen with inline pen management, and pen detail.

**Files:**
- Create:
  - `lib/src/features/areas/domain/area.dart`
  - `lib/src/features/areas/domain/pen.dart`
  - `lib/src/features/areas/data/area_repository.dart`
  - `lib/src/features/areas/application/area_providers.dart`
  - `lib/src/features/areas/presentation/areas_list_screen.dart`
  - `lib/src/features/areas/presentation/edit_area_screen.dart`
  - `test/features/areas/domain/area_test.dart`
  - `test/features/areas/domain/pen_test.dart`
  - `test/features/areas/data/area_repository_test.dart`

### Steps

- [ ] **Step 4.1: Test — Area & Pen models**

`test/features/areas/domain/area_test.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/features/areas/domain/area.dart';

void main() {
  test('AreaPurpose.fromString resolves all values', () {
    for (final p in AreaPurpose.values) {
      expect(AreaPurpose.fromString(p.value), p);
    }
    expect(AreaPurpose.fromString('asdf'), AreaPurpose.other);
  });

  test('Area round-trips', () async {
    final f = FakeFirebaseFirestore();
    await f.collection('farms').doc('f1').collection('areas').doc('a1').set({
      'name': 'Farrowing 1',
      'purpose': 'farrowing',
      'notes': 'south wing',
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(1000),
    });
    final doc = await f.collection('farms').doc('f1').collection('areas').doc('a1').get();
    final a = Area.fromFirestore(doc, farmId: 'f1');
    expect(a.id, 'a1');
    expect(a.name, 'Farrowing 1');
    expect(a.purpose, AreaPurpose.farrowing);
    expect(a.notes, 'south wing');
  });
}
```

`test/features/areas/domain/pen_test.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/features/areas/domain/pen.dart';

void main() {
  test('Pen round-trips', () async {
    final f = FakeFirebaseFirestore();
    await f.collection('farms').doc('f1').collection('areas').doc('a1').collection('pens').doc('p1').set({
      'name': 'Pen 1',
      'capacity': 12,
      'currentOccupancy': 8,
      'notes': null,
    });
    final doc = await f.collection('farms').doc('f1').collection('areas').doc('a1').collection('pens').doc('p1').get();
    final p = Pen.fromFirestore(doc, farmId: 'f1', areaId: 'a1');
    expect(p.id, 'p1');
    expect(p.areaId, 'a1');
    expect(p.capacity, 12);
    expect(p.currentOccupancy, 8);
  });
}
```

- [ ] **Step 4.2: Implement Area + Pen models**

`lib/src/features/areas/domain/area.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum AreaPurpose {
  breeding('breeding', 'Breeding'),
  gestation('gestation', 'Gestation'),
  farrowing('farrowing', 'Farrowing'),
  nursery('nursery', 'Nursery'),
  growFinish('grow_finish', 'Grow-Finish'),
  quarantine('quarantine', 'Quarantine'),
  boarPen('boar_pen', 'Boar Pen'),
  isolation('isolation', 'Isolation'),
  other('other', 'Other');

  const AreaPurpose(this.value, this.label);
  final String value;
  final String label;

  static AreaPurpose fromString(String s) =>
      AreaPurpose.values.firstWhere(
        (p) => p.value == s,
        orElse: () => AreaPurpose.other,
      );

  /// Ordering used by Farm Layout and grouped lists.
  int get sortOrder => AreaPurpose.values.indexOf(this);
}

class Area {
  final String id;
  final String farmId;
  final String name;
  final AreaPurpose purpose;
  final String? notes;
  final Timestamp createdAt;

  const Area({
    required this.id,
    required this.farmId,
    required this.name,
    required this.purpose,
    required this.notes,
    required this.createdAt,
  });

  factory Area.fromFirestore(DocumentSnapshot doc, {required String farmId}) {
    final d = doc.data() as Map<String, dynamic>;
    return Area(
      id: doc.id,
      farmId: farmId,
      name: d['name'] as String,
      purpose: AreaPurpose.fromString(d['purpose'] as String? ?? 'other'),
      notes: d['notes'] as String?,
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'purpose': purpose.value,
    if (notes != null) 'notes': notes,
    'createdAt': createdAt,
  };
}
```

`lib/src/features/areas/domain/pen.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Pen {
  final String id;
  final String farmId;
  final String areaId;
  final String name;
  final int? capacity;
  final int currentOccupancy;
  final String? notes;

  const Pen({
    required this.id,
    required this.farmId,
    required this.areaId,
    required this.name,
    required this.capacity,
    required this.currentOccupancy,
    required this.notes,
  });

  factory Pen.fromFirestore(DocumentSnapshot doc, {required String farmId, required String areaId}) {
    final d = doc.data() as Map<String, dynamic>;
    return Pen(
      id: doc.id,
      farmId: farmId,
      areaId: areaId,
      name: d['name'] as String,
      capacity: d['capacity'] as int?,
      currentOccupancy: (d['currentOccupancy'] as int?) ?? 0,
      notes: d['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    if (capacity != null) 'capacity': capacity,
    'currentOccupancy': currentOccupancy,
    if (notes != null) 'notes': notes,
  };

  double get occupancyRatio {
    if (capacity == null || capacity == 0) return 0;
    return currentOccupancy / capacity!;
  }
}
```

- [ ] **Step 4.3: Test — AreaRepository**

`test/features/areas/data/area_repository_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/features/areas/data/area_repository.dart';
import 'package:farm_app/src/features/areas/domain/area.dart';

void main() {
  test('createArea + streamAreas', () async {
    final f = FakeFirebaseFirestore();
    final repo = AreaRepository(f);
    final id = await repo.createArea(
      farmId: 'f1', name: 'Farrowing 1',
      purpose: AreaPurpose.farrowing, notes: null,
    );
    expect(id, isNotEmpty);
    final areas = await repo.streamAreas('f1').first;
    expect(areas, hasLength(1));
    expect(areas.first.name, 'Farrowing 1');
  });

  test('updateArea changes name', () async {
    final f = FakeFirebaseFirestore();
    final repo = AreaRepository(f);
    final id = await repo.createArea(
      farmId: 'f1', name: 'Old', purpose: AreaPurpose.nursery, notes: null,
    );
    await repo.updateArea(farmId: 'f1', areaId: id, name: 'New',
        purpose: AreaPurpose.nursery, notes: 'updated');
    final areas = await repo.streamAreas('f1').first;
    expect(areas.first.name, 'New');
    expect(areas.first.notes, 'updated');
  });

  test('createPen + streamPens', () async {
    final f = FakeFirebaseFirestore();
    final repo = AreaRepository(f);
    final aId = await repo.createArea(
      farmId: 'f1', name: 'Farrowing', purpose: AreaPurpose.farrowing, notes: null,
    );
    final pId = await repo.createPen(
      farmId: 'f1', areaId: aId, name: 'Pen 1', capacity: 10, notes: null,
    );
    expect(pId, isNotEmpty);
    final pens = await repo.streamPens(farmId: 'f1', areaId: aId).first;
    expect(pens, hasLength(1));
    expect(pens.first.capacity, 10);
  });

  test('deletePen + deleteArea', () async {
    final f = FakeFirebaseFirestore();
    final repo = AreaRepository(f);
    final aId = await repo.createArea(
      farmId: 'f1', name: 'Q', purpose: AreaPurpose.quarantine, notes: null,
    );
    final pId = await repo.createPen(
      farmId: 'f1', areaId: aId, name: 'P', capacity: 5, notes: null,
    );
    await repo.deletePen(farmId: 'f1', areaId: aId, penId: pId);
    expect((await repo.streamPens(farmId: 'f1', areaId: aId).first), isEmpty);
    await repo.deleteArea(farmId: 'f1', areaId: aId);
    expect((await repo.streamAreas('f1').first), isEmpty);
  });
}
```

- [ ] **Step 4.4: Implement AreaRepository**

`lib/src/features/areas/data/area_repository.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/area.dart';
import '../domain/pen.dart';

class AreaRepository {
  AreaRepository(this._firestore);
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _areas(String farmId) =>
      _firestore.collection('farms').doc(farmId).collection('areas');

  CollectionReference<Map<String, dynamic>> _pens(String farmId, String areaId) =>
      _areas(farmId).doc(areaId).collection('pens');

  Future<String> createArea({
    required String farmId,
    required String name,
    required AreaPurpose purpose,
    required String? notes,
  }) async {
    final ref = _areas(farmId).doc();
    await ref.set({
      'name': name.trim(),
      'purpose': purpose.value,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> updateArea({
    required String farmId,
    required String areaId,
    required String name,
    required AreaPurpose purpose,
    required String? notes,
  }) async {
    await _areas(farmId).doc(areaId).update({
      'name': name.trim(),
      'purpose': purpose.value,
      'notes': notes?.trim(),
    });
  }

  Future<void> deleteArea({required String farmId, required String areaId}) async {
    await _areas(farmId).doc(areaId).delete();
  }

  Stream<List<Area>> streamAreas(String farmId) {
    return _areas(farmId).snapshots().map((s) {
      final list = s.docs.map((d) => Area.fromFirestore(d, farmId: farmId)).toList();
      list.sort((a, b) {
        final cmp = a.purpose.sortOrder.compareTo(b.purpose.sortOrder);
        return cmp != 0 ? cmp : a.name.compareTo(b.name);
      });
      return list;
    });
  }

  Future<String> createPen({
    required String farmId,
    required String areaId,
    required String name,
    required int? capacity,
    required String? notes,
  }) async {
    final ref = _pens(farmId, areaId).doc();
    await ref.set({
      'name': name.trim(),
      if (capacity != null) 'capacity': capacity,
      'currentOccupancy': 0,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    });
    return ref.id;
  }

  Future<void> updatePen({
    required String farmId,
    required String areaId,
    required String penId,
    required String name,
    required int? capacity,
    required String? notes,
  }) async {
    await _pens(farmId, areaId).doc(penId).update({
      'name': name.trim(),
      'capacity': capacity,
      'notes': notes?.trim(),
    });
  }

  Future<void> deletePen({
    required String farmId, required String areaId, required String penId,
  }) async {
    await _pens(farmId, areaId).doc(penId).delete();
  }

  Stream<List<Pen>> streamPens({required String farmId, required String areaId}) {
    return _pens(farmId, areaId).snapshots().map((s) => s.docs
        .map((d) => Pen.fromFirestore(d, farmId: farmId, areaId: areaId))
        .toList()..sort((a, b) => a.name.compareTo(b.name)));
  }

  /// Streams all pens across all areas for a farm — used by Farm Layout.
  Stream<List<Pen>> streamAllPens(String farmId) {
    return _firestore.collectionGroup('pens').snapshots().map((s) {
      return s.docs
          .where((d) {
            final parts = d.reference.path.split('/');
            return parts.length >= 5 && parts[0] == 'farms' && parts[1] == farmId;
          })
          .map((d) {
            final areaId = d.reference.parent.parent!.id;
            return Pen.fromFirestore(d, farmId: farmId, areaId: areaId);
          })
          .toList();
    });
  }

  Future<void> incrementPenOccupancy({
    required String farmId, required String areaId, required String penId, required int delta,
  }) async {
    await _pens(farmId, areaId).doc(penId).update({
      'currentOccupancy': FieldValue.increment(delta),
    });
  }
}
```

- [ ] **Step 4.5: Providers**

`lib/src/features/areas/application/area_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../activity/application/activity_providers.dart';
import '../data/area_repository.dart';
import '../domain/area.dart';
import '../domain/pen.dart';

final areaRepositoryProvider = Provider<AreaRepository>(
  (ref) => AreaRepository(ref.watch(firestoreProvider)),
);

final areasStreamProvider =
    StreamProvider.family<List<Area>, String>((ref, farmId) {
  return ref.watch(areaRepositoryProvider).streamAreas(farmId);
});

final pensStreamProvider =
    StreamProvider.family<List<Pen>, ({String farmId, String areaId})>((ref, args) {
  return ref.watch(areaRepositoryProvider).streamPens(
        farmId: args.farmId, areaId: args.areaId,
      );
});

final allPensStreamProvider =
    StreamProvider.family<List<Pen>, String>((ref, farmId) {
  return ref.watch(areaRepositoryProvider).streamAllPens(farmId);
});
```

- [ ] **Step 4.6: Areas list screen**

`lib/src/features/areas/presentation/areas_list_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../farms/application/farm_providers.dart';
import '../application/area_providers.dart';
import '../domain/area.dart';
import 'edit_area_screen.dart';

class AreasListScreen extends ConsumerWidget {
  const AreasListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) return const SizedBox.shrink();
    final areasAsync = ref.watch(areasStreamProvider(farmId));

    return Scaffold(
      appBar: AppBar(title: const Text('Areas')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const EditAreaScreen())),
        child: const Icon(Icons.add),
      ),
      body: areasAsync.when(
        data: (areas) {
          if (areas.isEmpty) {
            return const Center(child: Text('No areas yet. Tap + to add one.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: areas.length,
            itemBuilder: (_, i) {
              final a = areas[i];
              return Card(
                child: ListTile(
                  title: Text(a.name),
                  subtitle: Text(a.purpose.label),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => EditAreaScreen(existing: a))),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
```

- [ ] **Step 4.7: Edit area screen (with inline pen list)**

`lib/src/features/areas/presentation/edit_area_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../farms/application/farm_providers.dart';
import '../application/area_providers.dart';
import '../domain/area.dart';
import '../domain/pen.dart';

class EditAreaScreen extends ConsumerStatefulWidget {
  const EditAreaScreen({super.key, this.existing});
  final Area? existing;
  @override
  ConsumerState<EditAreaScreen> createState() => _S();
}

class _S extends ConsumerState<EditAreaScreen> {
  late final TextEditingController _name;
  late final TextEditingController _notes;
  late AreaPurpose _purpose;
  bool _busy = false;
  String? _savedAreaId;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _notes = TextEditingController(text: widget.existing?.notes ?? '');
    _purpose = widget.existing?.purpose ?? AreaPurpose.other;
    _savedAreaId = widget.existing?.id;
  }

  @override
  void dispose() { _name.dispose(); _notes.dispose(); super.dispose(); }

  Future<void> _save() async {
    final farmId = ref.read(selectedFarmIdProvider);
    if (farmId == null) return;
    if (_name.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final repo = ref.read(areaRepositoryProvider);
    try {
      if (_savedAreaId == null) {
        final id = await repo.createArea(
          farmId: farmId, name: _name.text, purpose: _purpose,
          notes: _notes.text.trim().isEmpty ? null : _notes.text,
        );
        setState(() => _savedAreaId = id);
      } else {
        await repo.updateArea(
          farmId: farmId, areaId: _savedAreaId!,
          name: _name.text, purpose: _purpose,
          notes: _notes.text.trim().isEmpty ? null : _notes.text,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addPen() async {
    if (_savedAreaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Save area first before adding pens.')),
      );
      return;
    }
    final farmId = ref.read(selectedFarmIdProvider)!;
    final nameCtl = TextEditingController();
    final capCtl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add pen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtl, decoration: const InputDecoration(labelText: 'Pen name')),
            TextField(controller: capCtl, decoration: const InputDecoration(labelText: 'Capacity (optional)'),
                keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
        ],
      ),
    );
    if (result == true && nameCtl.text.trim().isNotEmpty) {
      await ref.read(areaRepositoryProvider).createPen(
            farmId: farmId, areaId: _savedAreaId!,
            name: nameCtl.text, capacity: int.tryParse(capCtl.text), notes: null,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmId = ref.watch(selectedFarmIdProvider);
    return Scaffold(
      appBar: AppBar(title: Text(_savedAreaId == null ? 'New area' : 'Edit area')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 16),
            DropdownButtonFormField<AreaPurpose>(
              value: _purpose,
              decoration: const InputDecoration(labelText: 'Purpose'),
              items: AreaPurpose.values.map((p) =>
                DropdownMenuItem(value: p, child: Text(p.label))).toList(),
              onChanged: (v) => setState(() => _purpose = v ?? AreaPurpose.other),
            ),
            const SizedBox(height: 16),
            TextField(controller: _notes,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
                maxLines: 3),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _busy ? null : _save,
                child: Text(_savedAreaId == null ? 'Save area' : 'Save changes')),
            if (_savedAreaId != null && farmId != null) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  const Text('Pens', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.add), onPressed: _addPen),
                ],
              ),
              _PenList(farmId: farmId, areaId: _savedAreaId!),
            ],
          ],
        ),
      ),
    );
  }
}

class _PenList extends ConsumerWidget {
  const _PenList({required this.farmId, required this.areaId});
  final String farmId;
  final String areaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pens = ref.watch(pensStreamProvider((farmId: farmId, areaId: areaId)));
    return pens.when(
      data: (list) => Column(
        children: list.map((p) => Card(
          child: ListTile(
            title: Text(p.name),
            subtitle: Text(p.capacity == null
                ? 'Capacity: —'
                : 'Occupancy: ${p.currentOccupancy} / ${p.capacity}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => ref.read(areaRepositoryProvider).deletePen(
                    farmId: farmId, areaId: areaId, penId: p.id,
                  ),
            ),
          ),
        )).toList(),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
    );
  }
}
```

- [ ] **Step 4.8: Wire route + verify**

In `app_router.dart`, add:

```dart
GoRoute(path: '/areas', builder: (c, s) => const AreasListScreen()),
```

Import: `import '../features/areas/presentation/areas_list_screen.dart';`

Run:
```bash
flutter analyze
flutter test
flutter run -d <device>
```

Manual smoke: from home, navigate manually (`/areas` via debug menu — to be wired in Task 16 — or temporarily add a button on the placeholder home). Create an area, add a pen, edit, delete. Verify data appears in Firestore console.

- [ ] **Step 4.9: Commit**

```bash
git add -A
git commit -m "feat(areas): replace flat locations with Area > Pen hierarchy

- AreaPurpose enum with sort order driving Farm Layout grouping
- AreaRepository: CRUD for areas and pens, currentOccupancy increment
- streamAllPens via collectionGroup for layout queries
- Areas list + edit screen with inline pen management"
```

---

---

## Task 5: Equipment + Maintenance

**Goal:** Equipment CRUD (areas-located assets like ventilation fans, feeders, generators, scales, structures), status quick-toggle (in use / available / needs repair / retired), maintenance log with photos. Manager/Owner only for edit + maintenance; workers can quick-toggle status.

**Files:**
- Create:
  - `lib/src/features/equipment/domain/equipment.dart`
  - `lib/src/features/equipment/domain/maintenance_record.dart`
  - `lib/src/features/equipment/data/equipment_repository.dart`
  - `lib/src/features/equipment/application/equipment_providers.dart`
  - `lib/src/features/equipment/presentation/equipment_list_screen.dart`
  - `lib/src/features/equipment/presentation/equipment_detail_screen.dart`
  - `lib/src/features/equipment/presentation/add_edit_equipment_screen.dart`
  - `lib/src/features/equipment/presentation/log_maintenance_screen.dart`
  - `test/features/equipment/domain/equipment_test.dart`
  - `test/features/equipment/data/equipment_repository_test.dart`

Photo capture will be stubbed with a string URL field for now; full photo upload integrates in Task 9 (Health) where the media service is built. Equipment photos hook in once that exists.

### Steps

- [ ] **Step 5.1: Test — Equipment model**

`test/features/equipment/domain/equipment_test.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/features/equipment/domain/equipment.dart';

void main() {
  test('EquipmentType.fromString resolves all', () {
    for (final t in EquipmentType.values) {
      expect(EquipmentType.fromString(t.value), t);
    }
    expect(EquipmentType.fromString('foo'), EquipmentType.other);
  });

  test('EquipmentStatus.fromString resolves all', () {
    for (final s in EquipmentStatus.values) {
      expect(EquipmentStatus.fromString(s.value), s);
    }
    expect(EquipmentStatus.fromString('asdf'), EquipmentStatus.available);
  });

  test('EquipmentStatus.next cycles through in_use → available → needs_repair', () {
    expect(EquipmentStatus.inUse.next, EquipmentStatus.available);
    expect(EquipmentStatus.available.next, EquipmentStatus.needsRepair);
    expect(EquipmentStatus.needsRepair.next, EquipmentStatus.inUse);
    expect(EquipmentStatus.retired.next, EquipmentStatus.retired);
  });

  test('Equipment round-trips', () async {
    final f = FakeFirebaseFirestore();
    final t = Timestamp.fromMillisecondsSinceEpoch(1000);
    await f.collection('farms').doc('f1').collection('equipment').doc('e1').set({
      'name': 'Tunnel Fan A',
      'type': 'ventilation',
      'areaId': 'a1',
      'status': 'in_use',
      'purchaseDate': t,
      'purchaseCostPhp': 25000.0,
      'photoUrl': null,
      'notes': 'south wall',
      'createdBy': 'u1',
      'createdAt': t,
      'updatedAt': t,
    });
    final doc = await f.collection('farms').doc('f1').collection('equipment').doc('e1').get();
    final eq = Equipment.fromFirestore(doc, farmId: 'f1');
    expect(eq.id, 'e1');
    expect(eq.type, EquipmentType.ventilation);
    expect(eq.status, EquipmentStatus.inUse);
    expect(eq.purchaseCostPhp, 25000.0);
  });
}
```

Run: fails.

- [ ] **Step 5.2: Implement Equipment + MaintenanceRecord**

`lib/src/features/equipment/domain/equipment.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum EquipmentType {
  ventilation('ventilation', 'Ventilation'),
  feeder('feeder', 'Feeder'),
  waterPump('water_pump', 'Water Pump'),
  generator('generator', 'Generator'),
  scale('scale', 'Scale'),
  vehicle('vehicle', 'Vehicle'),
  structure('structure', 'Structure'),
  tool('tool', 'Tool'),
  other('other', 'Other');

  const EquipmentType(this.value, this.label);
  final String value;
  final String label;

  static EquipmentType fromString(String s) =>
      EquipmentType.values.firstWhere((e) => e.value == s, orElse: () => EquipmentType.other);
}

enum EquipmentStatus {
  inUse('in_use', 'In use'),
  available('available', 'Available'),
  needsRepair('needs_repair', 'Needs repair'),
  retired('retired', 'Retired');

  const EquipmentStatus(this.value, this.label);
  final String value;
  final String label;

  static EquipmentStatus fromString(String s) =>
      EquipmentStatus.values.firstWhere((e) => e.value == s, orElse: () => EquipmentStatus.available);

  /// Used by the one-tap status cycle (excluding retired which is a manual choice).
  EquipmentStatus get next {
    switch (this) {
      case EquipmentStatus.inUse: return EquipmentStatus.available;
      case EquipmentStatus.available: return EquipmentStatus.needsRepair;
      case EquipmentStatus.needsRepair: return EquipmentStatus.inUse;
      case EquipmentStatus.retired: return EquipmentStatus.retired;
    }
  }
}

class Equipment {
  final String id;
  final String farmId;
  final String name;
  final EquipmentType type;
  final String? areaId;
  final EquipmentStatus status;
  final Timestamp? purchaseDate;
  final double? purchaseCostPhp;
  final String? photoUrl;
  final String? notes;
  final String createdBy;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  const Equipment({
    required this.id,
    required this.farmId,
    required this.name,
    required this.type,
    required this.areaId,
    required this.status,
    required this.purchaseDate,
    required this.purchaseCostPhp,
    required this.photoUrl,
    required this.notes,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Equipment.fromFirestore(DocumentSnapshot doc, {required String farmId}) {
    final d = doc.data() as Map<String, dynamic>;
    return Equipment(
      id: doc.id,
      farmId: farmId,
      name: d['name'] as String,
      type: EquipmentType.fromString(d['type'] as String? ?? 'other'),
      areaId: d['areaId'] as String?,
      status: EquipmentStatus.fromString(d['status'] as String? ?? 'available'),
      purchaseDate: d['purchaseDate'] as Timestamp?,
      purchaseCostPhp: (d['purchaseCostPhp'] as num?)?.toDouble(),
      photoUrl: d['photoUrl'] as String?,
      notes: d['notes'] as String?,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: d['updatedAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'type': type.value,
    if (areaId != null) 'areaId': areaId,
    'status': status.value,
    if (purchaseDate != null) 'purchaseDate': purchaseDate,
    if (purchaseCostPhp != null) 'purchaseCostPhp': purchaseCostPhp,
    if (photoUrl != null) 'photoUrl': photoUrl,
    if (notes != null) 'notes': notes,
    'createdBy': createdBy,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };
}
```

`lib/src/features/equipment/domain/maintenance_record.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum MaintenanceType {
  preventive('preventive', 'Preventive'),
  repair('repair', 'Repair'),
  inspection('inspection', 'Inspection');

  const MaintenanceType(this.value, this.label);
  final String value;
  final String label;

  static MaintenanceType fromString(String s) =>
      MaintenanceType.values.firstWhere((e) => e.value == s, orElse: () => MaintenanceType.repair);
}

class MaintenanceRecord {
  final String id;
  final String farmId;
  final String equipmentId;
  final MaintenanceType type;
  final Timestamp date;
  final String? performedBy;
  final String? partsReplaced;
  final double? costPhp;
  final List<String> photoUrls;
  final String? notes;
  final String createdBy;
  final Timestamp createdAt;

  const MaintenanceRecord({
    required this.id,
    required this.farmId,
    required this.equipmentId,
    required this.type,
    required this.date,
    required this.performedBy,
    required this.partsReplaced,
    required this.costPhp,
    required this.photoUrls,
    required this.notes,
    required this.createdBy,
    required this.createdAt,
  });

  factory MaintenanceRecord.fromFirestore(
    DocumentSnapshot doc, {
    required String farmId, required String equipmentId,
  }) {
    final d = doc.data() as Map<String, dynamic>;
    return MaintenanceRecord(
      id: doc.id,
      farmId: farmId,
      equipmentId: equipmentId,
      type: MaintenanceType.fromString(d['type'] as String? ?? 'repair'),
      date: d['date'] as Timestamp,
      performedBy: d['performedBy'] as String?,
      partsReplaced: d['partsReplaced'] as String?,
      costPhp: (d['costPhp'] as num?)?.toDouble(),
      photoUrls: List<String>.from(d['photoUrls'] ?? const []),
      notes: d['notes'] as String?,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'type': type.value,
    'date': date,
    if (performedBy != null) 'performedBy': performedBy,
    if (partsReplaced != null) 'partsReplaced': partsReplaced,
    if (costPhp != null) 'costPhp': costPhp,
    'photoUrls': photoUrls,
    if (notes != null) 'notes': notes,
    'createdBy': createdBy,
    'createdAt': createdAt,
  };
}
```

- [ ] **Step 5.3: Test — EquipmentRepository**

`test/features/equipment/data/equipment_repository_test.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/features/equipment/data/equipment_repository.dart';
import 'package:farm_app/src/features/equipment/domain/equipment.dart';
import 'package:farm_app/src/features/equipment/domain/maintenance_record.dart';
import 'package:farm_app/src/features/activity/data/activity_repository.dart';

void main() {
  test('createEquipment writes and emits activity', () async {
    final f = FakeFirebaseFirestore();
    final repo = EquipmentRepository(f, ActivityRepository(f));
    final id = await repo.createEquipment(
      farmId: 'f1',
      name: 'Fan A', type: EquipmentType.ventilation, areaId: 'a1',
      status: EquipmentStatus.inUse, purchaseDate: null, purchaseCostPhp: null,
      photoUrl: null, notes: null,
      actorUserId: 'u1', actorDisplayName: 'Juan',
    );
    final eq = await f.collection('farms').doc('f1').collection('equipment').doc(id).get();
    expect(eq.data()!['name'], 'Fan A');
    final activity = await f.collection('farms').doc('f1').collection('activity').get();
    expect(activity.docs, hasLength(1));
    expect(activity.docs.first.data()['action'], 'equipment_added');
  });

  test('quickToggleStatus cycles status', () async {
    final f = FakeFirebaseFirestore();
    final repo = EquipmentRepository(f, ActivityRepository(f));
    final id = await repo.createEquipment(
      farmId: 'f1', name: 'X', type: EquipmentType.tool, areaId: null,
      status: EquipmentStatus.available, purchaseDate: null, purchaseCostPhp: null,
      photoUrl: null, notes: null, actorUserId: 'u1', actorDisplayName: 'J',
    );
    await repo.quickToggleStatus(
      farmId: 'f1', equipmentId: id,
      actorUserId: 'u1', actorDisplayName: 'J',
    );
    final eq = await f.collection('farms').doc('f1').collection('equipment').doc(id).get();
    expect(eq.data()!['status'], 'needs_repair');
  });

  test('logMaintenance writes record + activity', () async {
    final f = FakeFirebaseFirestore();
    final repo = EquipmentRepository(f, ActivityRepository(f));
    final id = await repo.createEquipment(
      farmId: 'f1', name: 'Y', type: EquipmentType.feeder, areaId: 'a1',
      status: EquipmentStatus.inUse, purchaseDate: null, purchaseCostPhp: null,
      photoUrl: null, notes: null, actorUserId: 'u1', actorDisplayName: 'J',
    );
    await repo.logMaintenance(
      farmId: 'f1', equipmentId: id, equipmentName: 'Y',
      type: MaintenanceType.repair, date: Timestamp.now(),
      performedBy: 'ACME Repairs', partsReplaced: 'belt', costPhp: 500,
      photoUrls: const [], notes: null,
      actorUserId: 'u1', actorDisplayName: 'J',
    );
    final maint = await f.collection('farms').doc('f1').collection('equipment').doc(id).collection('maintenance_records').get();
    expect(maint.docs, hasLength(1));
    final activity = await f.collection('farms').doc('f1').collection('activity').get();
    expect(activity.docs.where((d) => d.data()['action'] == 'maintenance_logged'), hasLength(1));
  });
}
```

- [ ] **Step 5.4: Implement EquipmentRepository**

`lib/src/features/equipment/data/equipment_repository.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../activity/data/activity_repository.dart';
import '../domain/equipment.dart';
import '../domain/maintenance_record.dart';

class EquipmentRepository {
  EquipmentRepository(this._firestore, this._activity);
  final FirebaseFirestore _firestore;
  final ActivityRepository _activity;

  CollectionReference<Map<String, dynamic>> _col(String farmId) =>
      _firestore.collection('farms').doc(farmId).collection('equipment');

  CollectionReference<Map<String, dynamic>> _maint(String farmId, String eqId) =>
      _col(farmId).doc(eqId).collection('maintenance_records');

  Future<String> createEquipment({
    required String farmId,
    required String name,
    required EquipmentType type,
    required String? areaId,
    required EquipmentStatus status,
    required Timestamp? purchaseDate,
    required double? purchaseCostPhp,
    required String? photoUrl,
    required String? notes,
    required String actorUserId,
    required String actorDisplayName,
  }) async {
    final ref = _col(farmId).doc();
    final batch = _firestore.batch();
    batch.set(ref, {
      'name': name.trim(),
      'type': type.value,
      if (areaId != null) 'areaId': areaId,
      'status': status.value,
      if (purchaseDate != null) 'purchaseDate': purchaseDate,
      if (purchaseCostPhp != null) 'purchaseCostPhp': purchaseCostPhp,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      'createdBy': actorUserId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _activity.addActivityToBatch(
      batch: batch, farmId: farmId,
      actorUserId: actorUserId, actorDisplayName: actorDisplayName,
      action: 'equipment_added', entityType: 'equipment', entityId: ref.id,
      areaId: areaId, summary: '$actorDisplayName added equipment "$name"',
    );
    await batch.commit();
    return ref.id;
  }

  Future<void> updateEquipment({
    required String farmId,
    required String equipmentId,
    required String name,
    required EquipmentType type,
    required String? areaId,
    required EquipmentStatus status,
    required Timestamp? purchaseDate,
    required double? purchaseCostPhp,
    required String? photoUrl,
    required String? notes,
  }) async {
    await _col(farmId).doc(equipmentId).update({
      'name': name.trim(),
      'type': type.value,
      'areaId': areaId,
      'status': status.value,
      'purchaseDate': purchaseDate,
      'purchaseCostPhp': purchaseCostPhp,
      'photoUrl': photoUrl,
      'notes': notes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteEquipment({required String farmId, required String equipmentId}) async {
    await _col(farmId).doc(equipmentId).delete();
  }

  Future<void> quickToggleStatus({
    required String farmId,
    required String equipmentId,
    required String actorUserId,
    required String actorDisplayName,
  }) async {
    final doc = await _col(farmId).doc(equipmentId).get();
    final eq = Equipment.fromFirestore(doc, farmId: farmId);
    final next = eq.status.next;
    final batch = _firestore.batch();
    batch.update(_col(farmId).doc(equipmentId), {
      'status': next.value, 'updatedAt': FieldValue.serverTimestamp(),
    });
    _activity.addActivityToBatch(
      batch: batch, farmId: farmId,
      actorUserId: actorUserId, actorDisplayName: actorDisplayName,
      action: 'equipment_status_changed', entityType: 'equipment', entityId: equipmentId,
      areaId: eq.areaId,
      summary: '$actorDisplayName set "${eq.name}" → ${next.label}',
    );
    await batch.commit();
  }

  Future<void> setStatus({
    required String farmId,
    required String equipmentId,
    required EquipmentStatus status,
    required String actorUserId,
    required String actorDisplayName,
  }) async {
    final doc = await _col(farmId).doc(equipmentId).get();
    final eq = Equipment.fromFirestore(doc, farmId: farmId);
    final batch = _firestore.batch();
    batch.update(_col(farmId).doc(equipmentId), {
      'status': status.value, 'updatedAt': FieldValue.serverTimestamp(),
    });
    _activity.addActivityToBatch(
      batch: batch, farmId: farmId,
      actorUserId: actorUserId, actorDisplayName: actorDisplayName,
      action: 'equipment_status_changed', entityType: 'equipment', entityId: equipmentId,
      areaId: eq.areaId,
      summary: '$actorDisplayName set "${eq.name}" → ${status.label}',
    );
    await batch.commit();
  }

  Stream<List<Equipment>> streamEquipment(String farmId) {
    return _col(farmId).snapshots().map((s) {
      final list = s.docs.map((d) => Equipment.fromFirestore(d, farmId: farmId)).toList();
      list.sort((a, b) {
        final cmp = a.type.index.compareTo(b.type.index);
        return cmp != 0 ? cmp : a.name.compareTo(b.name);
      });
      return list;
    });
  }

  Stream<Equipment?> streamEquipmentById({required String farmId, required String equipmentId}) {
    return _col(farmId).doc(equipmentId).snapshots().map(
      (d) => d.exists ? Equipment.fromFirestore(d, farmId: farmId) : null,
    );
  }

  Future<void> logMaintenance({
    required String farmId,
    required String equipmentId,
    required String equipmentName,
    required MaintenanceType type,
    required Timestamp date,
    required String? performedBy,
    required String? partsReplaced,
    required double? costPhp,
    required List<String> photoUrls,
    required String? notes,
    required String actorUserId,
    required String actorDisplayName,
  }) async {
    final ref = _maint(farmId, equipmentId).doc();
    final batch = _firestore.batch();
    batch.set(ref, {
      'type': type.value,
      'date': date,
      if (performedBy != null) 'performedBy': performedBy,
      if (partsReplaced != null) 'partsReplaced': partsReplaced,
      if (costPhp != null) 'costPhp': costPhp,
      'photoUrls': photoUrls,
      if (notes != null) 'notes': notes,
      'createdBy': actorUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    _activity.addActivityToBatch(
      batch: batch, farmId: farmId,
      actorUserId: actorUserId, actorDisplayName: actorDisplayName,
      action: 'maintenance_logged', entityType: 'equipment', entityId: equipmentId,
      summary: '$actorDisplayName logged ${type.label} on "$equipmentName"',
    );
    await batch.commit();
  }

  Stream<List<MaintenanceRecord>> streamMaintenance({
    required String farmId, required String equipmentId,
  }) {
    return _maint(farmId, equipmentId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) =>
            MaintenanceRecord.fromFirestore(d, farmId: farmId, equipmentId: equipmentId)).toList());
  }
}
```

- [ ] **Step 5.5: Equipment providers**

`lib/src/features/equipment/application/equipment_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../activity/application/activity_providers.dart';
import '../data/equipment_repository.dart';
import '../domain/equipment.dart';
import '../domain/maintenance_record.dart';

final equipmentRepositoryProvider = Provider<EquipmentRepository>(
  (ref) => EquipmentRepository(
    ref.watch(firestoreProvider),
    ref.watch(activityRepositoryProvider),
  ),
);

final equipmentStreamProvider =
    StreamProvider.family<List<Equipment>, String>((ref, farmId) {
  return ref.watch(equipmentRepositoryProvider).streamEquipment(farmId);
});

final equipmentByIdProvider =
    StreamProvider.family<Equipment?, ({String farmId, String equipmentId})>((ref, args) {
  return ref.watch(equipmentRepositoryProvider).streamEquipmentById(
        farmId: args.farmId, equipmentId: args.equipmentId,
      );
});

final maintenanceStreamProvider =
    StreamProvider.family<List<MaintenanceRecord>, ({String farmId, String equipmentId})>((ref, args) {
  return ref.watch(equipmentRepositoryProvider).streamMaintenance(
        farmId: args.farmId, equipmentId: args.equipmentId,
      );
});
```

- [ ] **Step 5.6: Equipment list screen**

`lib/src/features/equipment/presentation/equipment_list_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../core/permissions/role.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../../team/application/team_providers.dart';
import '../application/equipment_providers.dart';
import '../domain/equipment.dart';
import 'add_edit_equipment_screen.dart';
import 'equipment_detail_screen.dart';

class EquipmentListScreen extends ConsumerStatefulWidget {
  const EquipmentListScreen({super.key});
  @override
  ConsumerState<EquipmentListScreen> createState() => _S();
}

class _S extends ConsumerState<EquipmentListScreen> {
  EquipmentStatus? _statusFilter;
  String? _areaFilter;

  @override
  Widget build(BuildContext context) {
    final farmId = ref.watch(selectedFarmIdProvider);
    final user = ref.watch(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return const SizedBox.shrink();
    final role = ref.watch(memberForUserProvider((farmId: farmId, userId: user.uid)))
        .asData?.value?.role ?? Role.worker;
    final equipmentAsync = ref.watch(equipmentStreamProvider(farmId));

    return Scaffold(
      appBar: AppBar(title: const Text('Equipment')),
      floatingActionButton: PermissionService.canEditEquipment(role)
          ? FloatingActionButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AddEditEquipmentScreen())),
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Needs repair'),
                  selected: _statusFilter == EquipmentStatus.needsRepair,
                  onSelected: (sel) => setState(() => _statusFilter =
                      sel ? EquipmentStatus.needsRepair : null),
                ),
                FilterChip(
                  label: const Text('In use'),
                  selected: _statusFilter == EquipmentStatus.inUse,
                  onSelected: (sel) => setState(() => _statusFilter =
                      sel ? EquipmentStatus.inUse : null),
                ),
                FilterChip(
                  label: const Text('Available'),
                  selected: _statusFilter == EquipmentStatus.available,
                  onSelected: (sel) => setState(() => _statusFilter =
                      sel ? EquipmentStatus.available : null),
                ),
              ],
            ),
          ),
          Expanded(
            child: equipmentAsync.when(
              data: (list) {
                var filtered = list.where((e) =>
                  e.status != EquipmentStatus.retired &&
                  (_statusFilter == null || e.status == _statusFilter) &&
                  (_areaFilter == null || e.areaId == _areaFilter)
                ).toList();
                if (filtered.isEmpty) {
                  return const Center(child: Text('No equipment matches filters.'));
                }
                // Group by type.
                final byType = <EquipmentType, List<Equipment>>{};
                for (final e in filtered) {
                  byType.putIfAbsent(e.type, () => []).add(e);
                }
                final types = byType.keys.toList()..sort((a, b) => a.index.compareTo(b.index));
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: types.length,
                  itemBuilder: (_, ti) {
                    final t = types[ti];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 4),
                          child: Text(t.label,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        ...byType[t]!.map((eq) => _EquipmentCard(
                          eq: eq, role: role, farmId: farmId,
                          userId: user.uid,
                        )),
                      ],
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _EquipmentCard extends ConsumerWidget {
  const _EquipmentCard({required this.eq, required this.role, required this.farmId, required this.userId});
  final Equipment eq;
  final Role role;
  final String farmId;
  final String userId;

  Color _statusColor(EquipmentStatus s) {
    switch (s) {
      case EquipmentStatus.inUse: return Colors.green;
      case EquipmentStatus.available: return Colors.grey;
      case EquipmentStatus.needsRepair: return Colors.red;
      case EquipmentStatus.retired: return Colors.black26;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canToggle = PermissionService.canQuickToggleEquipmentStatus(role);
    final actorName = ref.read(currentAppUserProvider).asData?.value?.displayName ?? '';
    return Card(
      child: ListTile(
        title: Text(eq.name),
        subtitle: Text(eq.areaId == null ? eq.type.label : '${eq.type.label} · area ${eq.areaId}'),
        trailing: GestureDetector(
          onTap: canToggle ? () => ref.read(equipmentRepositoryProvider).quickToggleStatus(
                farmId: farmId, equipmentId: eq.id,
                actorUserId: userId, actorDisplayName: actorName,
              ) : null,
          child: Chip(
            label: Text(eq.status.label,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: _statusColor(eq.status),
          ),
        ),
        onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => EquipmentDetailScreen(equipmentId: eq.id))),
      ),
    );
  }
}
```

- [ ] **Step 5.7: Add/Edit equipment screen**

`lib/src/features/equipment/presentation/add_edit_equipment_screen.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../areas/application/area_providers.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../application/equipment_providers.dart';
import '../domain/equipment.dart';

class AddEditEquipmentScreen extends ConsumerStatefulWidget {
  const AddEditEquipmentScreen({super.key, this.existing});
  final Equipment? existing;
  @override
  ConsumerState<AddEditEquipmentScreen> createState() => _S();
}

class _S extends ConsumerState<AddEditEquipmentScreen> {
  late final TextEditingController _name;
  late final TextEditingController _cost;
  late final TextEditingController _notes;
  late EquipmentType _type;
  late EquipmentStatus _status;
  String? _areaId;
  DateTime? _purchaseDate;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _cost = TextEditingController(text: e?.purchaseCostPhp?.toStringAsFixed(0) ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _type = e?.type ?? EquipmentType.other;
    _status = e?.status ?? EquipmentStatus.available;
    _areaId = e?.areaId;
    _purchaseDate = e?.purchaseDate?.toDate();
  }

  @override
  void dispose() { _name.dispose(); _cost.dispose(); _notes.dispose(); super.dispose(); }

  Future<void> _save() async {
    final farmId = ref.read(selectedFarmIdProvider);
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return;
    if (_name.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final repo = ref.read(equipmentRepositoryProvider);
    final actorName = ref.read(currentAppUserProvider).asData?.value?.displayName ?? '';
    final cost = double.tryParse(_cost.text);
    final purchase = _purchaseDate == null ? null : Timestamp.fromDate(_purchaseDate!);
    try {
      if (widget.existing == null) {
        await repo.createEquipment(
          farmId: farmId, name: _name.text, type: _type, areaId: _areaId,
          status: _status, purchaseDate: purchase, purchaseCostPhp: cost,
          photoUrl: null, notes: _notes.text,
          actorUserId: user.uid, actorDisplayName: actorName,
        );
      } else {
        await repo.updateEquipment(
          farmId: farmId, equipmentId: widget.existing!.id,
          name: _name.text, type: _type, areaId: _areaId, status: _status,
          purchaseDate: purchase, purchaseCostPhp: cost,
          photoUrl: widget.existing!.photoUrl, notes: _notes.text,
        );
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmId = ref.watch(selectedFarmIdProvider);
    final areasAsync = farmId != null
        ? ref.watch(areasStreamProvider(farmId))
        : const AsyncValue<List>.data([]);
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'New equipment' : 'Edit equipment')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            DropdownButtonFormField<EquipmentType>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: EquipmentType.values.map((t) =>
                DropdownMenuItem(value: t, child: Text(t.label))).toList(),
              onChanged: (v) => setState(() => _type = v ?? EquipmentType.other),
            ),
            const SizedBox(height: 12),
            areasAsync.when(
              data: (areas) => DropdownButtonFormField<String?>(
                value: _areaId,
                decoration: const InputDecoration(labelText: 'Area (optional)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('— no area —')),
                  ...areas.map((a) =>
                    DropdownMenuItem(value: a.id as String?, child: Text(a.name))),
                ],
                onChanged: (v) => setState(() => _areaId = v),
              ),
              loading: () => const SizedBox.shrink(),
              error: (e, _) => Text('Areas error: $e'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<EquipmentStatus>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: EquipmentStatus.values.map((s) =>
                DropdownMenuItem(value: s, child: Text(s.label))).toList(),
              onChanged: (v) => setState(() => _status = v ?? EquipmentStatus.available),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Purchase date (optional)'),
              subtitle: Text(_purchaseDate?.toLocal().toString().split(' ')[0] ?? '—'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context, initialDate: _purchaseDate ?? DateTime.now(),
                  firstDate: DateTime(2000), lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _purchaseDate = picked);
              },
            ),
            const SizedBox(height: 12),
            TextField(controller: _cost,
              decoration: const InputDecoration(labelText: 'Purchase cost (PHP, optional)'),
              keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            TextField(controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
              maxLines: 3),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _busy ? null : _save,
              child: _busy ? const CircularProgressIndicator() : const Text('Save')),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5.8: Equipment detail screen + Log maintenance screen**

`lib/src/features/equipment/presentation/equipment_detail_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../core/permissions/role.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../../team/application/team_providers.dart';
import '../application/equipment_providers.dart';
import 'add_edit_equipment_screen.dart';
import 'log_maintenance_screen.dart';

class EquipmentDetailScreen extends ConsumerWidget {
  const EquipmentDetailScreen({super.key, required this.equipmentId});
  final String equipmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmId = ref.watch(selectedFarmIdProvider);
    final user = ref.watch(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return const SizedBox.shrink();
    final eqAsync = ref.watch(equipmentByIdProvider((farmId: farmId, equipmentId: equipmentId)));
    final maintAsync = ref.watch(maintenanceStreamProvider((farmId: farmId, equipmentId: equipmentId)));
    final role = ref.watch(memberForUserProvider((farmId: farmId, userId: user.uid)))
        .asData?.value?.role ?? Role.worker;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Equipment'),
        actions: [
          if (PermissionService.canEditEquipment(role))
            eqAsync.maybeWhen(
              data: (eq) => eq == null ? const SizedBox.shrink() : IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => AddEditEquipmentScreen(existing: eq))),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
        ],
      ),
      floatingActionButton: PermissionService.canLogMaintenance(role)
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.build),
              label: const Text('Log maintenance'),
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => LogMaintenanceScreen(equipmentId: equipmentId))),
            )
          : null,
      body: eqAsync.when(
        data: (eq) {
          if (eq == null) return const Center(child: Text('Not found'));
          final maintList = maintAsync.asData?.value ?? const [];
          final totalCost = maintList.fold<double>(0, (sum, m) => sum + (m.costPhp ?? 0));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(eq.name, style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      Text('Type: ${eq.type.label}'),
                      Text('Status: ${eq.status.label}'),
                      if (eq.purchaseDate != null)
                        Text('Purchased: ${DateFormat.yMMMd().format(eq.purchaseDate!.toDate())}'),
                      if (eq.purchaseCostPhp != null)
                        Text('Purchase cost: ₱${eq.purchaseCostPhp!.toStringAsFixed(0)}'),
                      if (eq.notes != null) ...[
                        const SizedBox(height: 8),
                        Text(eq.notes!),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Maintenance history',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text('Total: ₱${totalCost.toStringAsFixed(0)}'),
                ],
              ),
              const SizedBox(height: 8),
              maintAsync.when(
                data: (list) {
                  if (list.isEmpty) return const Text('No maintenance logged yet.');
                  return Column(
                    children: list.map((m) => Card(
                      child: ListTile(
                        leading: Icon(_iconFor(m.type.value)),
                        title: Text(m.type.label),
                        subtitle: Text(DateFormat.yMMMd().format(m.date.toDate()) +
                            (m.performedBy != null ? ' · ${m.performedBy}' : '')),
                        trailing: m.costPhp != null
                            ? Text('₱${m.costPhp!.toStringAsFixed(0)}')
                            : null,
                      ),
                    )).toList(),
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('$e'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  IconData _iconFor(String t) {
    switch (t) {
      case 'preventive': return Icons.check_circle;
      case 'repair': return Icons.build;
      case 'inspection': return Icons.visibility;
      default: return Icons.help_outline;
    }
  }
}
```

`lib/src/features/equipment/presentation/log_maintenance_screen.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../application/equipment_providers.dart';
import '../domain/maintenance_record.dart';

class LogMaintenanceScreen extends ConsumerStatefulWidget {
  const LogMaintenanceScreen({super.key, required this.equipmentId});
  final String equipmentId;
  @override
  ConsumerState<LogMaintenanceScreen> createState() => _S();
}

class _S extends ConsumerState<LogMaintenanceScreen> {
  final _performedBy = TextEditingController();
  final _parts = TextEditingController();
  final _cost = TextEditingController();
  final _notes = TextEditingController();
  MaintenanceType _type = MaintenanceType.repair;
  DateTime _date = DateTime.now();
  bool _busy = false;

  @override
  void dispose() {
    _performedBy.dispose(); _parts.dispose(); _cost.dispose(); _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final farmId = ref.read(selectedFarmIdProvider);
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return;
    setState(() => _busy = true);
    final repo = ref.read(equipmentRepositoryProvider);
    final actorName = ref.read(currentAppUserProvider).asData?.value?.displayName ?? '';
    final eq = await ref.read(equipmentByIdProvider(
        (farmId: farmId, equipmentId: widget.equipmentId)).future);
    if (eq == null) {
      setState(() => _busy = false);
      return;
    }
    try {
      await repo.logMaintenance(
        farmId: farmId, equipmentId: widget.equipmentId, equipmentName: eq.name,
        type: _type, date: Timestamp.fromDate(_date),
        performedBy: _performedBy.text.trim().isEmpty ? null : _performedBy.text.trim(),
        partsReplaced: _parts.text.trim().isEmpty ? null : _parts.text.trim(),
        costPhp: double.tryParse(_cost.text),
        photoUrls: const [],  // Photo capture comes in Task 9.
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        actorUserId: user.uid, actorDisplayName: actorName,
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log maintenance')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<MaintenanceType>(
              segments: MaintenanceType.values.map((t) =>
                ButtonSegment(value: t, label: Text(t.label))).toList(),
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text(_date.toLocal().toString().split(' ')[0]),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context, initialDate: _date,
                  firstDate: DateTime(2020), lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            TextField(controller: _performedBy,
              decoration: const InputDecoration(labelText: 'Performed by (technician name, optional)')),
            const SizedBox(height: 12),
            TextField(controller: _parts,
              decoration: const InputDecoration(labelText: 'Parts replaced (optional)')),
            const SizedBox(height: 12),
            TextField(controller: _cost,
              decoration: const InputDecoration(labelText: 'Cost (PHP, optional)'),
              keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            TextField(controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes'), maxLines: 3),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _busy ? null : _save,
              child: _busy ? const CircularProgressIndicator() : const Text('Save')),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5.9: Wire route + run tests + manual smoke**

In `app_router.dart`, add:

```dart
GoRoute(path: '/equipment', builder: (c, s) => const EquipmentListScreen()),
```

Import `import '../features/equipment/presentation/equipment_list_screen.dart';`

```bash
flutter analyze
flutter test
flutter run -d <device>
```

Manual: navigate to `/equipment`, add a "Tunnel Fan A" (Ventilation, area = your first area, status = In use, cost = 25000). Verify it appears, tap the status chip → cycles to Available → Needs repair → In use. Open detail → Log maintenance (Repair, parts = belt, cost = 500) → returns to detail with one record.

- [ ] **Step 5.10: Commit**

```bash
git add -A
git commit -m "feat(equipment): CRUD + maintenance log with status quick-toggle

- Equipment + MaintenanceRecord models, status enum with cyclic .next
- EquipmentRepository writes activity entries in same batch
- List grouped by type, filter chips for needs-repair/in-use/available
- Quick-toggle status by tapping chip
- Detail screen with maintenance history + cost total"
```

---

_(Tasks 6–17 continue in subsequent commits to this file.)_
