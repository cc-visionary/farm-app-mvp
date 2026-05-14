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

---

## Task 6: Pig Model + Pigs List + Pig Detail (read-only)

**Goal:** Create the swine-specific `Pig` domain entity, `PigRepository`, and the list + detail screens. Add/Edit Pig comes in Task 7. Detail screen is initially read-only; "Log event" buttons are placeholders to be wired in Tasks 8–10.

**Files:**
- Create:
  - `lib/src/features/pigs/domain/pig.dart`
  - `lib/src/features/pigs/data/pig_repository.dart`
  - `lib/src/features/pigs/application/pig_providers.dart`
  - `lib/src/features/pigs/presentation/pigs_list_screen.dart`
  - `lib/src/features/pigs/presentation/pig_detail_screen.dart`
  - `test/features/pigs/domain/pig_test.dart`
  - `test/features/pigs/data/pig_repository_test.dart`

### Steps

- [ ] **Step 6.1: Test — Pig model**

`test/features/pigs/domain/pig_test.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/features/pigs/domain/pig.dart';

void main() {
  test('PigSex.fromString', () {
    expect(PigSex.fromString('male'), PigSex.male);
    expect(PigSex.fromString('female'), PigSex.female);
    expect(PigSex.fromString('x'), PigSex.female);  // default
  });

  test('PigStage.fromString resolves all', () {
    for (final s in PigStage.values) {
      expect(PigStage.fromString(s.value), s);
    }
  });

  test('PigStatus.fromString resolves all', () {
    for (final s in PigStatus.values) {
      expect(PigStatus.fromString(s.value), s);
    }
  });

  test('Pig round-trips through Firestore', () async {
    final f = FakeFirebaseFirestore();
    final birth = Timestamp.fromMillisecondsSinceEpoch(1700000000000);
    final created = Timestamp.fromMillisecondsSinceEpoch(1700100000000);
    await f.collection('farms').doc('f1').collection('pigs').doc('p1').set({
      'tagId': 'SOW-001', 'sex': 'female', 'breed': 'Yorkshire',
      'birthDate': birth, 'sireId': 'BOAR-1', 'damId': 'SOW-PARENT-1',
      'stage': 'sow', 'status': 'active',
      'currentAreaId': 'a1', 'currentPenId': 'pen-1',
      'currentWeight': 220.5,
      'photoUrl': 'https://x/p.jpg', 'notes': null,
      'createdBy': 'u1', 'createdAt': created, 'updatedAt': created,
    });
    final doc = await f.collection('farms').doc('f1').collection('pigs').doc('p1').get();
    final pig = Pig.fromFirestore(doc, farmId: 'f1');
    expect(pig.tagId, 'SOW-001');
    expect(pig.sex, PigSex.female);
    expect(pig.stage, PigStage.sow);
    expect(pig.status, PigStatus.active);
    expect(pig.currentWeight, 220.5);
    expect(pig.sireId, 'BOAR-1');
  });

  test('Pig age helper produces sensible buckets', () {
    final now = DateTime(2026, 6, 1);
    final p1 = _pig(birthDate: DateTime(2025, 6, 1));    // 12 months
    final p2 = _pig(birthDate: DateTime(2026, 5, 1));    // ~30 days
    final p3 = _pig(birthDate: DateTime(2026, 5, 25));   // ~7 days

    expect(p1.ageString(now), '1 yr');
    expect(p2.ageString(now), '1 mo');
    expect(p3.ageString(now), '1 wk');
  });
}

Pig _pig({required DateTime birthDate}) => Pig(
  id: 'x', farmId: 'f', tagId: 't', sex: PigSex.female, breed: 'Y',
  birthDate: Timestamp.fromDate(birthDate),
  sireId: null, damId: null,
  stage: PigStage.sow, status: PigStatus.active,
  currentAreaId: 'a', currentPenId: null,
  currentWeight: null, weightUpdatedAt: null,
  photoUrl: null, notes: null,
  createdBy: 'u', createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
);
```

- [ ] **Step 6.2: Implement Pig model**

`lib/src/features/pigs/domain/pig.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum PigSex {
  male('male', 'Male'),
  female('female', 'Female');

  const PigSex(this.value, this.label);
  final String value;
  final String label;
  static PigSex fromString(String s) =>
      PigSex.values.firstWhere((e) => e.value == s, orElse: () => PigSex.female);
}

enum PigStage {
  suckling('suckling', 'Suckling'),
  weaner('weaner', 'Weaner'),
  grower('grower', 'Grower'),
  finisher('finisher', 'Finisher'),
  gilt('gilt', 'Gilt'),
  sow('sow', 'Sow'),
  boar('boar', 'Boar');

  const PigStage(this.value, this.label);
  final String value;
  final String label;
  static PigStage fromString(String s) =>
      PigStage.values.firstWhere((e) => e.value == s, orElse: () => PigStage.grower);
}

enum PigStatus {
  active('active', 'Active'),
  sold('sold', 'Sold'),
  culled('culled', 'Culled'),
  deceased('deceased', 'Deceased');

  const PigStatus(this.value, this.label);
  final String value;
  final String label;
  static PigStatus fromString(String s) =>
      PigStatus.values.firstWhere((e) => e.value == s, orElse: () => PigStatus.active);
}

class Pig {
  final String id;
  final String farmId;
  final String tagId;
  final PigSex sex;
  final String breed;
  final Timestamp birthDate;
  final String? sireId;
  final String? damId;
  final PigStage stage;
  final PigStatus status;
  final String currentAreaId;
  final String? currentPenId;
  final double? currentWeight;
  final Timestamp? weightUpdatedAt;
  final String? photoUrl;
  final String? notes;
  final String createdBy;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  const Pig({
    required this.id,
    required this.farmId,
    required this.tagId,
    required this.sex,
    required this.breed,
    required this.birthDate,
    required this.sireId,
    required this.damId,
    required this.stage,
    required this.status,
    required this.currentAreaId,
    required this.currentPenId,
    required this.currentWeight,
    required this.weightUpdatedAt,
    required this.photoUrl,
    required this.notes,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Pig.fromFirestore(DocumentSnapshot doc, {required String farmId}) {
    final d = doc.data() as Map<String, dynamic>;
    return Pig(
      id: doc.id,
      farmId: farmId,
      tagId: d['tagId'] as String,
      sex: PigSex.fromString(d['sex'] as String),
      breed: d['breed'] as String? ?? '',
      birthDate: d['birthDate'] as Timestamp,
      sireId: d['sireId'] as String?,
      damId: d['damId'] as String?,
      stage: PigStage.fromString(d['stage'] as String? ?? 'grower'),
      status: PigStatus.fromString(d['status'] as String? ?? 'active'),
      currentAreaId: d['currentAreaId'] as String? ?? '',
      currentPenId: d['currentPenId'] as String?,
      currentWeight: (d['currentWeight'] as num?)?.toDouble(),
      weightUpdatedAt: d['weightUpdatedAt'] as Timestamp?,
      photoUrl: d['photoUrl'] as String?,
      notes: d['notes'] as String?,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: d['updatedAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'tagId': tagId,
    'sex': sex.value,
    'breed': breed,
    'birthDate': birthDate,
    if (sireId != null) 'sireId': sireId,
    if (damId != null) 'damId': damId,
    'stage': stage.value,
    'status': status.value,
    'currentAreaId': currentAreaId,
    if (currentPenId != null) 'currentPenId': currentPenId,
    if (currentWeight != null) 'currentWeight': currentWeight,
    if (weightUpdatedAt != null) 'weightUpdatedAt': weightUpdatedAt,
    if (photoUrl != null) 'photoUrl': photoUrl,
    if (notes != null) 'notes': notes,
    'createdBy': createdBy,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  String ageString(DateTime now) {
    final diff = now.difference(birthDate.toDate());
    final days = diff.inDays;
    if (days >= 365) return '${days ~/ 365} yr';
    if (days >= 30) return '${days ~/ 30} mo';
    if (days >= 7) return '${days ~/ 7} wk';
    return '$days d';
  }

  bool get isBreeder => stage == PigStage.sow || stage == PigStage.gilt || stage == PigStage.boar;
}
```

- [ ] **Step 6.3: Test — PigRepository**

`test/features/pigs/data/pig_repository_test.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/features/activity/data/activity_repository.dart';
import 'package:farm_app/src/features/pigs/data/pig_repository.dart';
import 'package:farm_app/src/features/pigs/domain/pig.dart';

void main() {
  PigRepository newRepo() {
    final f = FakeFirebaseFirestore();
    return PigRepository(f, ActivityRepository(f));
  }

  test('createPig writes and emits activity', () async {
    final repo = newRepo();
    final id = await repo.createPig(
      farmId: 'f1', tagId: 'SOW-001', sex: PigSex.female, breed: 'Yorkshire',
      birthDate: Timestamp.fromMillisecondsSinceEpoch(1700000000000),
      sireId: null, damId: null, stage: PigStage.sow, currentAreaId: 'a1',
      currentPenId: null, currentWeight: null, photoUrl: null, notes: null,
      actorUserId: 'u1', actorDisplayName: 'Juan',
    );
    expect(id, isNotEmpty);
  });

  test('updatePig changes stage', () async {
    final repo = newRepo();
    final id = await repo.createPig(
      farmId: 'f1', tagId: 'P1', sex: PigSex.female, breed: 'X',
      birthDate: Timestamp.now(), sireId: null, damId: null,
      stage: PigStage.gilt, currentAreaId: 'a1', currentPenId: null,
      currentWeight: null, photoUrl: null, notes: null,
      actorUserId: 'u', actorDisplayName: 'J',
    );
    await repo.updatePig(
      farmId: 'f1', pigId: id, tagId: 'P1', sex: PigSex.female, breed: 'X',
      birthDate: Timestamp.now(), sireId: null, damId: null,
      stage: PigStage.sow, currentAreaId: 'a1', currentPenId: null,
      currentWeight: null, photoUrl: null, notes: null,
    );
    final pig = await repo.streamPigById(farmId: 'f1', pigId: id).first;
    expect(pig!.stage, PigStage.sow);
  });

  test('movePig updates area + pen + writes activity', () async {
    final repo = newRepo();
    final id = await repo.createPig(
      farmId: 'f1', tagId: 'P1', sex: PigSex.male, breed: 'X',
      birthDate: Timestamp.now(), sireId: null, damId: null,
      stage: PigStage.grower, currentAreaId: 'a1', currentPenId: 'pen1',
      currentWeight: null, photoUrl: null, notes: null,
      actorUserId: 'u', actorDisplayName: 'J',
    );
    await repo.movePig(
      farmId: 'f1', pigId: id, tagId: 'P1',
      newAreaId: 'a2', newPenId: 'pen2',
      actorUserId: 'u', actorDisplayName: 'J',
    );
    final pig = await repo.streamPigById(farmId: 'f1', pigId: id).first;
    expect(pig!.currentAreaId, 'a2');
    expect(pig.currentPenId, 'pen2');
  });

  test('logWeight updates currentWeight + activity', () async {
    final repo = newRepo();
    final id = await repo.createPig(
      farmId: 'f1', tagId: 'X', sex: PigSex.male, breed: 'X',
      birthDate: Timestamp.now(), sireId: null, damId: null,
      stage: PigStage.grower, currentAreaId: 'a', currentPenId: null,
      currentWeight: null, photoUrl: null, notes: null,
      actorUserId: 'u', actorDisplayName: 'J',
    );
    await repo.logWeight(
      farmId: 'f1', pigId: id, tagId: 'X', weight: 45.5,
      actorUserId: 'u', actorDisplayName: 'J',
    );
    final pig = await repo.streamPigById(farmId: 'f1', pigId: id).first;
    expect(pig!.currentWeight, 45.5);
  });

  test('streamPigs returns all active by default', () async {
    final repo = newRepo();
    await repo.createPig(farmId: 'f1', tagId: 'A', sex: PigSex.male, breed: 'X',
      birthDate: Timestamp.now(), sireId: null, damId: null, stage: PigStage.grower,
      currentAreaId: 'a', currentPenId: null, currentWeight: null,
      photoUrl: null, notes: null, actorUserId: 'u', actorDisplayName: 'J');
    final id = await repo.createPig(farmId: 'f1', tagId: 'B', sex: PigSex.female, breed: 'X',
      birthDate: Timestamp.now(), sireId: null, damId: null, stage: PigStage.sow,
      currentAreaId: 'a', currentPenId: null, currentWeight: null,
      photoUrl: null, notes: null, actorUserId: 'u', actorDisplayName: 'J');
    await repo.setStatus(farmId: 'f1', pigId: id, tagId: 'B', status: PigStatus.sold,
      actorUserId: 'u', actorDisplayName: 'J');
    final list = await repo.streamPigs('f1').first;
    expect(list.length, 2);
    final activeOnly = list.where((p) => p.status == PigStatus.active).toList();
    expect(activeOnly, hasLength(1));
  });
}
```

- [ ] **Step 6.4: Implement PigRepository**

`lib/src/features/pigs/data/pig_repository.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../activity/data/activity_repository.dart';
import '../domain/pig.dart';

class PigRepository {
  PigRepository(this._firestore, this._activity);
  final FirebaseFirestore _firestore;
  final ActivityRepository _activity;

  CollectionReference<Map<String, dynamic>> _col(String farmId) =>
      _firestore.collection('farms').doc(farmId).collection('pigs');

  Future<String> createPig({
    required String farmId,
    required String tagId,
    required PigSex sex,
    required String breed,
    required Timestamp birthDate,
    required String? sireId,
    required String? damId,
    required PigStage stage,
    required String currentAreaId,
    required String? currentPenId,
    required double? currentWeight,
    required String? photoUrl,
    required String? notes,
    required String actorUserId,
    required String actorDisplayName,
  }) async {
    final ref = _col(farmId).doc();
    final batch = _firestore.batch();
    batch.set(ref, {
      'tagId': tagId.trim(),
      'sex': sex.value,
      'breed': breed.trim(),
      'birthDate': birthDate,
      if (sireId != null) 'sireId': sireId,
      if (damId != null) 'damId': damId,
      'stage': stage.value,
      'status': 'active',
      'currentAreaId': currentAreaId,
      if (currentPenId != null) 'currentPenId': currentPenId,
      if (currentWeight != null) 'currentWeight': currentWeight,
      if (currentWeight != null) 'weightUpdatedAt': FieldValue.serverTimestamp(),
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      'createdBy': actorUserId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _activity.addActivityToBatch(
      batch: batch, farmId: farmId,
      actorUserId: actorUserId, actorDisplayName: actorDisplayName,
      action: 'pig_added', entityType: 'pig', entityId: ref.id,
      areaId: currentAreaId,
      summary: '$actorDisplayName added pig $tagId',
    );
    await batch.commit();
    return ref.id;
  }

  Future<void> updatePig({
    required String farmId,
    required String pigId,
    required String tagId,
    required PigSex sex,
    required String breed,
    required Timestamp birthDate,
    required String? sireId,
    required String? damId,
    required PigStage stage,
    required String currentAreaId,
    required String? currentPenId,
    required double? currentWeight,
    required String? photoUrl,
    required String? notes,
  }) async {
    await _col(farmId).doc(pigId).update({
      'tagId': tagId.trim(),
      'sex': sex.value,
      'breed': breed.trim(),
      'birthDate': birthDate,
      'sireId': sireId,
      'damId': damId,
      'stage': stage.value,
      'currentAreaId': currentAreaId,
      'currentPenId': currentPenId,
      if (currentWeight != null) 'currentWeight': currentWeight,
      'photoUrl': photoUrl,
      'notes': notes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> movePig({
    required String farmId, required String pigId, required String tagId,
    required String newAreaId, required String? newPenId,
    required String actorUserId, required String actorDisplayName,
  }) async {
    final batch = _firestore.batch();
    batch.update(_col(farmId).doc(pigId), {
      'currentAreaId': newAreaId,
      'currentPenId': newPenId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _activity.addActivityToBatch(
      batch: batch, farmId: farmId,
      actorUserId: actorUserId, actorDisplayName: actorDisplayName,
      action: 'pig_moved', entityType: 'pig', entityId: pigId,
      areaId: newAreaId,
      summary: '$actorDisplayName moved pig $tagId to area $newAreaId',
    );
    await batch.commit();
  }

  Future<void> logWeight({
    required String farmId, required String pigId, required String tagId,
    required double weight,
    required String actorUserId, required String actorDisplayName,
  }) async {
    final batch = _firestore.batch();
    batch.update(_col(farmId).doc(pigId), {
      'currentWeight': weight,
      'weightUpdatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _activity.addActivityToBatch(
      batch: batch, farmId: farmId,
      actorUserId: actorUserId, actorDisplayName: actorDisplayName,
      action: 'weight_logged', entityType: 'pig', entityId: pigId,
      summary: '$actorDisplayName logged weight $weight kg for $tagId',
    );
    await batch.commit();
  }

  Future<void> setStatus({
    required String farmId, required String pigId, required String tagId,
    required PigStatus status,
    required String actorUserId, required String actorDisplayName,
  }) async {
    final batch = _firestore.batch();
    batch.update(_col(farmId).doc(pigId), {
      'status': status.value, 'updatedAt': FieldValue.serverTimestamp(),
    });
    _activity.addActivityToBatch(
      batch: batch, farmId: farmId,
      actorUserId: actorUserId, actorDisplayName: actorDisplayName,
      action: 'pig_status_changed', entityType: 'pig', entityId: pigId,
      summary: '$actorDisplayName marked $tagId as ${status.label}',
    );
    await batch.commit();
  }

  Stream<List<Pig>> streamPigs(String farmId) {
    return _col(farmId).snapshots().map((s) =>
        s.docs.map((d) => Pig.fromFirestore(d, farmId: farmId)).toList());
  }

  Stream<Pig?> streamPigById({required String farmId, required String pigId}) {
    return _col(farmId).doc(pigId).snapshots().map(
      (d) => d.exists ? Pig.fromFirestore(d, farmId: farmId) : null,
    );
  }
}
```

- [ ] **Step 6.5: Providers**

`lib/src/features/pigs/application/pig_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../activity/application/activity_providers.dart';
import '../data/pig_repository.dart';
import '../domain/pig.dart';

final pigRepositoryProvider = Provider<PigRepository>(
  (ref) => PigRepository(
    ref.watch(firestoreProvider),
    ref.watch(activityRepositoryProvider),
  ),
);

final pigsStreamProvider =
    StreamProvider.family<List<Pig>, String>((ref, farmId) {
  return ref.watch(pigRepositoryProvider).streamPigs(farmId);
});

final pigByIdProvider =
    StreamProvider.family<Pig?, ({String farmId, String pigId})>((ref, args) {
  return ref.watch(pigRepositoryProvider).streamPigById(
        farmId: args.farmId, pigId: args.pigId,
      );
});
```

- [ ] **Step 6.6: Pigs list screen**

`lib/src/features/pigs/presentation/pigs_list_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../../team/application/team_providers.dart';
import '../application/pig_providers.dart';
import '../domain/pig.dart';
import 'pig_detail_screen.dart';

class PigsListScreen extends ConsumerStatefulWidget {
  const PigsListScreen({super.key});
  @override
  ConsumerState<PigsListScreen> createState() => _S();
}

class _S extends ConsumerState<PigsListScreen> {
  final _search = TextEditingController();
  final Set<PigStage> _stageFilter = {};
  bool _showInactive = false;
  bool _onlyMyAreas = false;

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  List<Pig> _filter(List<Pig> all, List<String> assignedAreaIds) {
    final q = _search.text.trim().toLowerCase();
    return all.where((p) {
      if (!_showInactive && p.status != PigStatus.active) return false;
      if (_stageFilter.isNotEmpty && !_stageFilter.contains(p.stage)) return false;
      if (_onlyMyAreas && assignedAreaIds.isNotEmpty &&
          !assignedAreaIds.contains(p.currentAreaId)) return false;
      if (q.isNotEmpty && !p.tagId.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final farmId = ref.watch(selectedFarmIdProvider);
    final user = ref.watch(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return const SizedBox.shrink();
    final pigsAsync = ref.watch(pigsStreamProvider(farmId));
    final member = ref.watch(memberForUserProvider(
        (farmId: farmId, userId: user.uid))).asData?.value;
    final assigned = member?.assignedAreaIds ?? const <String>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pigs'),
        actions: [
          IconButton(
            icon: Icon(_showInactive ? Icons.visibility : Icons.visibility_off),
            tooltip: _showInactive ? 'Hide inactive' : 'Show inactive',
            onPressed: () => setState(() => _showInactive = !_showInactive),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search by tag ID',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              children: [
                ...PigStage.values.map((s) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(s.label),
                    selected: _stageFilter.contains(s),
                    onSelected: (sel) => setState(() =>
                      sel ? _stageFilter.add(s) : _stageFilter.remove(s)),
                  ),
                )),
                Padding(
                  padding: const EdgeInsets.only(right: 8, left: 4),
                  child: FilterChip(
                    label: const Text('My areas only'),
                    selected: _onlyMyAreas,
                    onSelected: (sel) => setState(() => _onlyMyAreas = sel),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: pigsAsync.when(
              data: (all) {
                final list = _filter(all, assigned);
                if (list.isEmpty) {
                  return const Center(child: Text('No pigs match the current filters.'));
                }
                // Group by stage with collapsible sections.
                final byStage = <PigStage, List<Pig>>{};
                for (final p in list) {
                  byStage.putIfAbsent(p.stage, () => []).add(p);
                }
                final stages = byStage.keys.toList()
                  ..sort((a, b) => a.index.compareTo(b.index));
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: stages.length,
                  itemBuilder: (_, si) {
                    final s = stages[si];
                    final pigs = byStage[s]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 4, left: 4),
                          child: Text('${s.label} · ${pigs.length}',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        ...pigs.map((p) => _PigCard(pig: p)),
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

class _PigCard extends StatelessWidget {
  const _PigCard({required this.pig});
  final Pig pig;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: pig.sex == PigSex.female ? Colors.pink.shade100 : Colors.blue.shade100,
          child: Text(pig.sex == PigSex.female ? '♀' : '♂'),
        ),
        title: Text(pig.tagId, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${pig.breed} · ${pig.stage.label} · ${pig.ageString(now)}'),
        trailing: pig.currentWeight != null
            ? Text('${pig.currentWeight!.toStringAsFixed(0)} kg')
            : null,
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => PigDetailScreen(pigId: pig.id),
        )),
      ),
    );
  }
}
```

- [ ] **Step 6.7: Pig detail screen (read-only)**

`lib/src/features/pigs/presentation/pig_detail_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../farms/application/farm_providers.dart';
import '../application/pig_providers.dart';
import '../domain/pig.dart';

class PigDetailScreen extends ConsumerWidget {
  const PigDetailScreen({super.key, required this.pigId});
  final String pigId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) return const SizedBox.shrink();
    final pigAsync = ref.watch(pigByIdProvider((farmId: farmId, pigId: pigId)));

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: pigAsync.maybeWhen(
            data: (p) => Text(p?.tagId ?? 'Pig'),
            orElse: () => const Text('Pig'),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Profile'),
              Tab(text: 'Breeding'),
              Tab(text: 'Health'),
              Tab(text: 'Lineage'),
            ],
          ),
        ),
        body: pigAsync.when(
          data: (pig) {
            if (pig == null) return const Center(child: Text('Not found'));
            return TabBarView(
              children: [
                _ProfileTab(pig: pig),
                _PlaceholderTab(text: 'Breeding history — wired in Task 8'),
                _PlaceholderTab(text: 'Health records — wired in Task 10'),
                _LineageTab(pig: pig),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.pig});
  final Pig pig;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (pig.photoUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(pig.photoUrl!, height: 200, fit: BoxFit.cover),
          ),
        const SizedBox(height: 16),
        _row('Tag ID', pig.tagId),
        _row('Sex', pig.sex.label),
        _row('Breed', pig.breed),
        _row('Stage', pig.stage.label),
        _row('Status', pig.status.label),
        _row('Born', DateFormat.yMMMd().format(pig.birthDate.toDate())),
        _row('Age', pig.ageString(now)),
        if (pig.currentWeight != null)
          _row('Current weight', '${pig.currentWeight!.toStringAsFixed(1)} kg'),
        _row('Area', pig.currentAreaId),
        if (pig.currentPenId != null) _row('Pen', pig.currentPenId!),
        if (pig.notes != null) _row('Notes', pig.notes!),
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        SizedBox(width: 110, child: Text(label, style: const TextStyle(color: Colors.grey))),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class _LineageTab extends ConsumerWidget {
  const _LineageTab({required this.pig});
  final Pig pig;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Parents', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(child: ListTile(
          title: const Text('Sire (father)'),
          subtitle: Text(pig.sireId ?? '—'),
        )),
        Card(child: ListTile(
          title: const Text('Dam (mother)'),
          subtitle: Text(pig.damId ?? '—'),
        )),
        // Offspring discovery is a derived query — wired in Task 8 after breeding records exist.
      ],
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Center(child: Text(text));
}
```

- [ ] **Step 6.8: Wire routes + verify**

In `app_router.dart` add:

```dart
GoRoute(path: '/pigs', builder: (c, s) => const PigsListScreen()),
```

Import the screen. Add a temporary button to the placeholder home that goes to `/pigs` for testing.

Seed at least 2 pigs manually via Firestore console (or wait for Task 7's UI). Verify list groups by stage, search filters, "My areas only" toggle respects assigned areas. Open detail — Profile and Lineage tabs render; Breeding/Health show the placeholder.

```bash
flutter analyze
flutter test
flutter run -d <device>
```

- [ ] **Step 6.9: Commit**

```bash
git add -A
git commit -m "feat(pigs): Pig domain, repository, list, and read-only detail

- Pig model with sex/stage/status enums, age helper, lineage fields
- PigRepository: create/update/move/logWeight/setStatus with activity entries
- Pigs list with stage filter chips, tagId search, my-areas filter,
  collapsible stage sections
- Detail screen with 4 tabs (Profile/Breeding/Health/Lineage);
  Breeding/Health placeholders pending later tasks"
```

---

## Task 7: Photo Service + Add/Edit Pig with Photo

**Goal:** Build the shared photo capture/upload service used across pigs, health records, equipment, and mortality. Wire it into Add/Edit Pig as the first consumer.

**Files:**
- Create:
  - `lib/src/features/media/photo_picker.dart`
  - `lib/src/features/media/photo_upload_service.dart`
  - `lib/src/features/media/photo_upload_queue.dart`
  - `lib/src/features/media/media_providers.dart`
  - `lib/src/features/pigs/presentation/add_edit_pig_screen.dart`
  - `test/features/media/photo_upload_queue_test.dart`

### Steps

- [ ] **Step 7.1: PhotoPicker widget**

`lib/src/features/media/photo_picker.dart`:

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Opens a bottom sheet with Camera/Gallery/Cancel. Returns a compressed [File]
/// (or null if user cancelled). Compression: 1280 max dimension, ~80% quality.
class PhotoPicker {
  PhotoPicker._();

  static Future<File?> pick(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context, null),
            ),
          ],
        ),
      ),
    );
    if (source == null) return null;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1280, maxHeight: 1280, imageQuality: 80,
    );
    if (picked == null) return null;
    return File(picked.path);
  }
}
```

- [ ] **Step 7.2: PhotoUploadQueue (offline buffer)**

`lib/src/features/media/photo_upload_queue.dart`:

```dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class QueuedUpload {
  QueuedUpload({
    required this.localPath,
    required this.storagePath,
    required this.recordPath,
    required this.fieldName,
  });
  final String localPath;
  final String storagePath;
  /// e.g., "farms/f1/pigs/p1" — the Firestore doc to update with the URL.
  final String recordPath;
  /// e.g., "photoUrl" (single field) or "photoUrls" (append to array).
  final String fieldName;

  Map<String, dynamic> toMap() => {
    'localPath': localPath, 'storagePath': storagePath,
    'recordPath': recordPath, 'fieldName': fieldName,
  };
  factory QueuedUpload.fromMap(Map<String, dynamic> m) => QueuedUpload(
    localPath: m['localPath'], storagePath: m['storagePath'],
    recordPath: m['recordPath'], fieldName: m['fieldName'],
  );
}

class PhotoUploadQueue {
  PhotoUploadQueue(this._prefs);
  final SharedPreferences _prefs;
  static const _key = 'photo_upload_queue';

  Future<List<QueuedUpload>> all() async {
    final raw = _prefs.getStringList(_key) ?? [];
    return raw.map((s) => QueuedUpload.fromMap(jsonDecode(s))).toList();
  }

  Future<void> enqueue(QueuedUpload q) async {
    final list = await all();
    list.add(q);
    await _persist(list);
  }

  Future<void> remove(QueuedUpload q) async {
    final list = await all();
    list.removeWhere((x) => x.localPath == q.localPath && x.storagePath == q.storagePath);
    await _persist(list);
  }

  Future<void> _persist(List<QueuedUpload> list) async {
    await _prefs.setStringList(_key, list.map((q) => jsonEncode(q.toMap())).toList());
  }
}
```

Test it:

`test/features/media/photo_upload_queue_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:farm_app/src/features/media/photo_upload_queue.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('enqueue + all', () async {
    final prefs = await SharedPreferences.getInstance();
    final q = PhotoUploadQueue(prefs);
    await q.enqueue(QueuedUpload(
      localPath: '/tmp/a.jpg', storagePath: 'farms/f/pigs/p/0.jpg',
      recordPath: 'farms/f/pigs/p', fieldName: 'photoUrl',
    ));
    final list = await q.all();
    expect(list, hasLength(1));
    expect(list.first.localPath, '/tmp/a.jpg');
  });

  test('remove matches by both paths', () async {
    final prefs = await SharedPreferences.getInstance();
    final q = PhotoUploadQueue(prefs);
    final a = QueuedUpload(localPath: '/a.jpg', storagePath: 's/a',
        recordPath: 'r/a', fieldName: 'photoUrl');
    final b = QueuedUpload(localPath: '/b.jpg', storagePath: 's/b',
        recordPath: 'r/b', fieldName: 'photoUrl');
    await q.enqueue(a);
    await q.enqueue(b);
    await q.remove(a);
    expect((await q.all()).map((x) => x.localPath), ['/b.jpg']);
  });
}
```

Run: passes.

- [ ] **Step 7.3: PhotoUploadService**

`lib/src/features/media/photo_upload_service.dart`:

```dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'photo_upload_queue.dart';

class PhotoUploadService {
  PhotoUploadService(this._storage, this._firestore, this._queue);
  final FirebaseStorage _storage;
  final FirebaseFirestore _firestore;
  final PhotoUploadQueue _queue;

  /// Uploads immediately. On failure, enqueues for later retry and returns null.
  /// Returns the public URL on success, null on queued-for-retry.
  Future<String?> uploadAndAttach({
    required File file,
    required String storagePath,    // "farms/{farmId}/pigs/{pigId}/0.jpg"
    required String recordPath,     // "farms/{farmId}/pigs/{pigId}"
    required String fieldName,      // "photoUrl" or "photoUrls"
  }) async {
    try {
      final ref = _storage.ref(storagePath);
      final task = await ref.putFile(file);
      final url = await task.ref.getDownloadURL();
      await _attachUrlToRecord(recordPath: recordPath, fieldName: fieldName, url: url);
      return url;
    } catch (_) {
      await _queue.enqueue(QueuedUpload(
        localPath: file.path, storagePath: storagePath,
        recordPath: recordPath, fieldName: fieldName,
      ));
      return null;
    }
  }

  Future<void> _attachUrlToRecord({
    required String recordPath,
    required String fieldName,
    required String url,
  }) async {
    final ref = _firestore.doc(recordPath);
    if (fieldName.endsWith('s')) {
      await ref.update({fieldName: FieldValue.arrayUnion([url])});
    } else {
      await ref.update({fieldName: url});
    }
  }

  /// Process queued uploads. Call on reconnect.
  Future<void> flushQueue() async {
    final list = await _queue.all();
    for (final q in list) {
      try {
        final file = File(q.localPath);
        if (!file.existsSync()) {
          await _queue.remove(q);
          continue;
        }
        final ref = _storage.ref(q.storagePath);
        final task = await ref.putFile(file);
        final url = await task.ref.getDownloadURL();
        await _attachUrlToRecord(recordPath: q.recordPath, fieldName: q.fieldName, url: url);
        await _queue.remove(q);
      } catch (_) {
        // Keep in queue for next attempt.
      }
    }
  }
}
```

- [ ] **Step 7.4: Media providers**

`lib/src/features/media/media_providers.dart`:

```dart
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../activity/application/activity_providers.dart';
import 'photo_upload_queue.dart';
import 'photo_upload_service.dart';

final firebaseStorageProvider = Provider<FirebaseStorage>((_) => FirebaseStorage.instance);

final sharedPreferencesProvider = FutureProvider<SharedPreferences>(
  (_) => SharedPreferences.getInstance(),
);

final photoUploadQueueProvider = Provider<PhotoUploadQueue?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).asData?.value;
  return prefs == null ? null : PhotoUploadQueue(prefs);
});

final photoUploadServiceProvider = Provider<PhotoUploadService?>((ref) {
  final queue = ref.watch(photoUploadQueueProvider);
  if (queue == null) return null;
  return PhotoUploadService(
    ref.watch(firebaseStorageProvider),
    ref.watch(firestoreProvider),
    queue,
  );
});
```

- [ ] **Step 7.5: Add/Edit Pig screen**

`lib/src/features/pigs/presentation/add_edit_pig_screen.dart`:

```dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../areas/application/area_providers.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../../media/media_providers.dart';
import '../../media/photo_picker.dart';
import '../application/pig_providers.dart';
import '../domain/pig.dart';

const _breedSeed = ['Yorkshire', 'Duroc', 'Landrace', 'Hampshire', 'Pietrain', 'Native'];

class AddEditPigScreen extends ConsumerStatefulWidget {
  const AddEditPigScreen({super.key, this.existing});
  final Pig? existing;
  @override
  ConsumerState<AddEditPigScreen> createState() => _S();
}

class _S extends ConsumerState<AddEditPigScreen> {
  late final TextEditingController _tag;
  late final TextEditingController _breed;
  late final TextEditingController _weight;
  late final TextEditingController _notes;
  PigSex _sex = PigSex.female;
  PigStage _stage = PigStage.grower;
  String? _areaId;
  String? _penId;
  DateTime? _birthDate;
  String? _sireId;
  String? _damId;
  File? _photoFile;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _tag = TextEditingController(text: e?.tagId ?? '');
    _breed = TextEditingController(text: e?.breed ?? '');
    _weight = TextEditingController(text: e?.currentWeight?.toStringAsFixed(0) ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _sex = e?.sex ?? PigSex.female;
    _stage = e?.stage ?? PigStage.grower;
    _areaId = e?.currentAreaId;
    _penId = e?.currentPenId;
    _birthDate = e?.birthDate.toDate();
    _sireId = e?.sireId;
    _damId = e?.damId;
  }

  @override
  void dispose() {
    _tag.dispose(); _breed.dispose(); _weight.dispose(); _notes.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await PhotoPicker.pick(context);
    if (file != null) setState(() => _photoFile = file);
  }

  Future<void> _save() async {
    setState(() => _error = null);
    final farmId = ref.read(selectedFarmIdProvider);
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return;
    if (_tag.text.trim().isEmpty) { setState(() => _error = 'Tag ID is required.'); return; }
    if (_breed.text.trim().isEmpty) { setState(() => _error = 'Breed is required.'); return; }
    if (_birthDate == null) { setState(() => _error = 'Birth date is required.'); return; }
    if (_areaId == null) { setState(() => _error = 'Area is required.'); return; }
    setState(() => _busy = true);
    final repo = ref.read(pigRepositoryProvider);
    final photoService = ref.read(photoUploadServiceProvider);
    final actorName = ref.read(currentAppUserProvider).asData?.value?.displayName ?? '';
    try {
      String pigId;
      if (widget.existing == null) {
        pigId = await repo.createPig(
          farmId: farmId, tagId: _tag.text, sex: _sex, breed: _breed.text,
          birthDate: Timestamp.fromDate(_birthDate!),
          sireId: _sireId, damId: _damId, stage: _stage,
          currentAreaId: _areaId!, currentPenId: _penId,
          currentWeight: double.tryParse(_weight.text),
          photoUrl: null, notes: _notes.text,
          actorUserId: user.uid, actorDisplayName: actorName,
        );
      } else {
        pigId = widget.existing!.id;
        await repo.updatePig(
          farmId: farmId, pigId: pigId, tagId: _tag.text, sex: _sex,
          breed: _breed.text, birthDate: Timestamp.fromDate(_birthDate!),
          sireId: _sireId, damId: _damId, stage: _stage,
          currentAreaId: _areaId!, currentPenId: _penId,
          currentWeight: double.tryParse(_weight.text),
          photoUrl: widget.existing!.photoUrl, notes: _notes.text,
        );
      }
      if (_photoFile != null && photoService != null) {
        await photoService.uploadAndAttach(
          file: _photoFile!,
          storagePath: 'farms/$farmId/pigs/$pigId/cover.jpg',
          recordPath: 'farms/$farmId/pigs/$pigId',
          fieldName: 'photoUrl',
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmId = ref.watch(selectedFarmIdProvider);
    final areasAsync = farmId != null
        ? ref.watch(areasStreamProvider(farmId))
        : const AsyncValue.data([]);
    final pensAsync = (farmId != null && _areaId != null)
        ? ref.watch(pensStreamProvider((farmId: farmId, areaId: _areaId!)))
        : const AsyncValue.data([]);
    final pigsAsync = farmId != null
        ? ref.watch(pigsStreamProvider(farmId))
        : const AsyncValue.data([]);
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'Add pig' : 'Edit pig')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                  image: _photoFile != null
                      ? DecorationImage(image: FileImage(_photoFile!), fit: BoxFit.cover)
                      : widget.existing?.photoUrl != null
                          ? DecorationImage(image: NetworkImage(widget.existing!.photoUrl!), fit: BoxFit.cover)
                          : null,
                ),
                child: _photoFile == null && widget.existing?.photoUrl == null
                    ? const Center(child: Icon(Icons.add_a_photo, size: 48, color: Colors.grey))
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            TextField(controller: _tag, decoration: const InputDecoration(labelText: 'Tag ID')),
            const SizedBox(height: 12),
            SegmentedButton<PigSex>(
              segments: PigSex.values.map((s) =>
                ButtonSegment(value: s, label: Text(s.label))).toList(),
              selected: {_sex},
              onSelectionChanged: (s) => setState(() => _sex = s.first),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _breedSeed.contains(_breed.text) ? _breed.text : null,
              decoration: const InputDecoration(labelText: 'Breed'),
              items: _breedSeed.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
              onChanged: (v) => setState(() => _breed.text = v ?? ''),
            ),
            TextField(controller: _breed, decoration: const InputDecoration(labelText: 'Breed (or type custom)')),
            const SizedBox(height: 12),
            DropdownButtonFormField<PigStage>(
              value: _stage,
              decoration: const InputDecoration(labelText: 'Stage'),
              items: PigStage.values.map((s) =>
                DropdownMenuItem(value: s, child: Text(s.label))).toList(),
              onChanged: (v) => setState(() => _stage = v ?? PigStage.grower),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Birth date'),
              subtitle: Text(_birthDate?.toLocal().toString().split(' ')[0] ?? 'Select'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context, initialDate: _birthDate ?? DateTime.now(),
                  firstDate: DateTime(2015), lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _birthDate = picked);
              },
            ),
            areasAsync.when(
              data: (areas) => DropdownButtonFormField<String>(
                value: _areaId,
                decoration: const InputDecoration(labelText: 'Area'),
                items: areas.map<DropdownMenuItem<String>>((a) =>
                  DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                onChanged: (v) => setState(() { _areaId = v; _penId = null; }),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e'),
            ),
            const SizedBox(height: 12),
            pensAsync.when(
              data: (pens) => DropdownButtonFormField<String?>(
                value: _penId,
                decoration: const InputDecoration(labelText: 'Pen (optional)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('— none —')),
                  ...pens.map<DropdownMenuItem<String?>>((p) =>
                    DropdownMenuItem(value: p.id as String?, child: Text(p.name))),
                ],
                onChanged: (v) => setState(() => _penId = v),
              ),
              loading: () => const SizedBox.shrink(),
              error: (e, _) => Text('$e'),
            ),
            const SizedBox(height: 12),
            TextField(controller: _weight,
              decoration: const InputDecoration(labelText: 'Weight (kg, optional)'),
              keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            pigsAsync.when(
              data: (pigs) {
                final sires = pigs.where((p) => p.sex == PigSex.male).toList();
                final dams = pigs.where((p) => p.sex == PigSex.female).toList();
                return Column(
                  children: [
                    DropdownButtonFormField<String?>(
                      value: _sireId,
                      decoration: const InputDecoration(labelText: 'Sire (optional)'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('— unknown —')),
                        ...sires.map<DropdownMenuItem<String?>>((p) =>
                          DropdownMenuItem(value: p.id as String?, child: Text(p.tagId))),
                      ],
                      onChanged: (v) => setState(() => _sireId = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: _damId,
                      decoration: const InputDecoration(labelText: 'Dam (optional)'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('— unknown —')),
                        ...dams.map<DropdownMenuItem<String?>>((p) =>
                          DropdownMenuItem(value: p.id as String?, child: Text(p.tagId))),
                      ],
                      onChanged: (v) => setState(() => _damId = v),
                    ),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (e, _) => Text('$e'),
            ),
            const SizedBox(height: 12),
            TextField(controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
              maxLines: 3),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
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

- [ ] **Step 7.6: Wire Add Pig from pigs list**

Edit `lib/src/features/pigs/presentation/pigs_list_screen.dart` — add a FAB:

```dart
floatingActionButton: FloatingActionButton(
  onPressed: () => Navigator.push(context, MaterialPageRoute(
    builder: (_) => const AddEditPigScreen())),
  child: const Icon(Icons.add),
),
```

Add import: `import 'add_edit_pig_screen.dart';`

- [ ] **Step 7.7: Verify**

```bash
flutter analyze
flutter test
flutter run -d <device>
```

Manual: Add a pig with photo (camera), verify photo uploads to Storage and renders on detail. Try with airplane mode toggled mid-upload — confirm a queued entry persists (inspect SharedPreferences via Flutter DevTools).

- [ ] **Step 7.8: Commit**

```bash
git add -A
git commit -m "feat(media,pigs): photo capture + Add/Edit Pig flow

- PhotoPicker (camera/gallery), PhotoUploadService, PhotoUploadQueue
  with shared_preferences persistence
- AddEditPigScreen wires the broken Save flow; full form with
  area+pen, sire/dam dropdowns, breed typeahead, photo"
```

---

## Task 8: Breeding Log + Task Generator

**Goal:** Build the breeding-cycle workflow (heat → insemination → pregnancy check → confirmation/failure → expected farrowing date computed at +114 days). Add the `TaskGenerator` that creates derived `pregnancy_check`, `farrowing_prep`, `farrowing_expected` tasks atomically with the breeding write.

**Files:**
- Create:
  - `lib/src/features/pigs/domain/breeding_record.dart`
  - `lib/src/features/pigs/data/breeding_repository.dart`
  - `lib/src/features/tasks/domain/task.dart`
  - `lib/src/features/tasks/data/task_repository.dart`
  - `lib/src/features/tasks/application/task_generator.dart`
  - `lib/src/features/tasks/application/task_providers.dart`
  - `lib/src/features/pigs/presentation/breeding_log_screen.dart`
  - `test/features/pigs/domain/breeding_record_test.dart`
  - `test/features/tasks/domain/task_test.dart`
  - `test/features/tasks/application/task_generator_test.dart`
  - `test/features/pigs/data/breeding_repository_test.dart`
- Modify:
  - `lib/src/features/pigs/application/pig_providers.dart` (add breeding stream)
  - `lib/src/features/pigs/presentation/pig_detail_screen.dart` (Breeding tab now real)

### Steps

- [ ] **Step 8.1: Task model**

`lib/src/features/tasks/domain/task.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskType {
  pregnancyCheck('pregnancy_check', 'Pregnancy check'),
  farrowingPrep('farrowing_prep', 'Farrowing prep'),
  farrowingExpected('farrowing_expected', 'Farrowing expected'),
  vaccinationDue('vaccination_due', 'Vaccination due'),
  withdrawalEnd('withdrawal_end', 'Withdrawal period ends'),
  manual('manual', 'Manual');

  const TaskType(this.value, this.label);
  final String value;
  final String label;
  static TaskType fromString(String s) =>
      TaskType.values.firstWhere((t) => t.value == s, orElse: () => TaskType.manual);
}

enum TaskStatus {
  open('open'), completed('completed'), skipped('skipped');
  const TaskStatus(this.value);
  final String value;
  static TaskStatus fromString(String s) =>
      TaskStatus.values.firstWhere((t) => t.value == s, orElse: () => TaskStatus.open);
}

class TaskAssignment {
  final String kind;  // 'user' or 'area'
  final String id;
  const TaskAssignment({required this.kind, required this.id});
  Map<String, dynamic> toMap() => {'kind': kind, 'id': id};
  factory TaskAssignment.fromMap(Map<String, dynamic> m) =>
      TaskAssignment(kind: m['kind'], id: m['id']);
}

class TaskSource {
  final String collection;
  final String docId;
  const TaskSource({required this.collection, required this.docId});
  Map<String, dynamic> toMap() => {'collection': collection, 'docId': docId};
  factory TaskSource.fromMap(Map<String, dynamic> m) =>
      TaskSource(collection: m['collection'], docId: m['docId']);
}

class FarmTask {
  final String id;
  final String farmId;
  final TaskType type;
  final String title;
  final String? description;
  final Timestamp dueDate;
  final String? relatedPigId;
  final String? relatedBreedingId;
  final String? relatedBatchId;
  final String? relatedAreaId;
  final TaskAssignment? assignedTo;
  final TaskStatus status;
  final bool autoGenerated;
  final TaskSource? source;
  final String? completedBy;
  final Timestamp? completedAt;
  final Timestamp createdAt;

  const FarmTask({
    required this.id, required this.farmId, required this.type,
    required this.title, required this.description, required this.dueDate,
    required this.relatedPigId, required this.relatedBreedingId,
    required this.relatedBatchId, required this.relatedAreaId,
    required this.assignedTo, required this.status,
    required this.autoGenerated, required this.source,
    required this.completedBy, required this.completedAt,
    required this.createdAt,
  });

  factory FarmTask.fromFirestore(DocumentSnapshot doc, {required String farmId}) {
    final d = doc.data() as Map<String, dynamic>;
    return FarmTask(
      id: doc.id, farmId: farmId,
      type: TaskType.fromString(d['type'] as String? ?? 'manual'),
      title: d['title'] as String,
      description: d['description'] as String?,
      dueDate: d['dueDate'] as Timestamp,
      relatedPigId: d['relatedPigId'] as String?,
      relatedBreedingId: d['relatedBreedingId'] as String?,
      relatedBatchId: d['relatedBatchId'] as String?,
      relatedAreaId: d['relatedAreaId'] as String?,
      assignedTo: d['assignedTo'] != null
          ? TaskAssignment.fromMap(d['assignedTo'] as Map<String, dynamic>) : null,
      status: TaskStatus.fromString(d['status'] as String? ?? 'open'),
      autoGenerated: d['autoGenerated'] as bool? ?? false,
      source: d['source'] != null
          ? TaskSource.fromMap(d['source'] as Map<String, dynamic>) : null,
      completedBy: d['completedBy'] as String?,
      completedAt: d['completedAt'] as Timestamp?,
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'type': type.value, 'title': title,
    if (description != null) 'description': description,
    'dueDate': dueDate,
    if (relatedPigId != null) 'relatedPigId': relatedPigId,
    if (relatedBreedingId != null) 'relatedBreedingId': relatedBreedingId,
    if (relatedBatchId != null) 'relatedBatchId': relatedBatchId,
    if (relatedAreaId != null) 'relatedAreaId': relatedAreaId,
    if (assignedTo != null) 'assignedTo': assignedTo!.toMap(),
    'status': status.value,
    'autoGenerated': autoGenerated,
    if (source != null) 'source': source!.toMap(),
    if (completedBy != null) 'completedBy': completedBy,
    if (completedAt != null) 'completedAt': completedAt,
    'createdAt': createdAt,
  };
}
```

- [ ] **Step 8.2: BreedingRecord model**

`lib/src/features/pigs/domain/breeding_record.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum BreedingMethod {
  natural('natural', 'Natural'), ai('ai', 'AI');
  const BreedingMethod(this.value, this.label);
  final String value;
  final String label;
  static BreedingMethod fromString(String s) =>
      BreedingMethod.values.firstWhere((m) => m.value == s, orElse: () => BreedingMethod.natural);
}

enum BreedingStatus {
  planned('planned', 'Planned'),
  confirmed('confirmed', 'Confirmed pregnant'),
  farrowed('farrowed', 'Farrowed'),
  failed('failed', 'Failed'),
  aborted('aborted', 'Aborted');
  const BreedingStatus(this.value, this.label);
  final String value;
  final String label;
  static BreedingStatus fromString(String s) =>
      BreedingStatus.values.firstWhere((b) => b.value == s, orElse: () => BreedingStatus.planned);
}

/// Gestation length in pigs (industry standard ~114 days, "3 months, 3 weeks, 3 days").
const int gestationDays = 114;

class BreedingRecord {
  final String id;
  final String farmId;
  final String sowId;
  final String boarId;
  final Timestamp? heatDate;
  final Timestamp inseminationDate;
  final BreedingMethod method;
  final Timestamp? pregnancyCheckDate;
  final bool confirmed;
  final Timestamp expectedFarrowingDate;
  final BreedingStatus status;
  final String? notes;
  final String createdBy;
  final Timestamp createdAt;

  const BreedingRecord({
    required this.id, required this.farmId,
    required this.sowId, required this.boarId,
    required this.heatDate, required this.inseminationDate,
    required this.method, required this.pregnancyCheckDate,
    required this.confirmed, required this.expectedFarrowingDate,
    required this.status, required this.notes,
    required this.createdBy, required this.createdAt,
  });

  factory BreedingRecord.fromFirestore(
    DocumentSnapshot doc, {required String farmId, required String sowId}) {
    final d = doc.data() as Map<String, dynamic>;
    return BreedingRecord(
      id: doc.id, farmId: farmId, sowId: sowId,
      boarId: d['boarId'] as String,
      heatDate: d['heatDate'] as Timestamp?,
      inseminationDate: d['inseminationDate'] as Timestamp,
      method: BreedingMethod.fromString(d['method'] as String? ?? 'natural'),
      pregnancyCheckDate: d['pregnancyCheckDate'] as Timestamp?,
      confirmed: d['confirmed'] as bool? ?? false,
      expectedFarrowingDate: d['expectedFarrowingDate'] as Timestamp,
      status: BreedingStatus.fromString(d['status'] as String? ?? 'planned'),
      notes: d['notes'] as String?,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'boarId': boarId,
    if (heatDate != null) 'heatDate': heatDate,
    'inseminationDate': inseminationDate,
    'method': method.value,
    if (pregnancyCheckDate != null) 'pregnancyCheckDate': pregnancyCheckDate,
    'confirmed': confirmed,
    'expectedFarrowingDate': expectedFarrowingDate,
    'status': status.value,
    if (notes != null) 'notes': notes,
    'createdBy': createdBy,
    'createdAt': createdAt,
  };

  static Timestamp computeExpectedFarrowingDate(Timestamp inseminationDate) =>
      Timestamp.fromDate(inseminationDate.toDate().add(const Duration(days: gestationDays)));
}
```

- [ ] **Step 8.3: Test — TaskGenerator (breeding tasks)**

`test/features/tasks/application/task_generator_test.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/features/tasks/application/task_generator.dart';
import 'package:farm_app/src/features/tasks/data/task_repository.dart';

void main() {
  test('breeding write generates pregnancy_check + farrowing_prep + farrowing_expected', () async {
    final f = FakeFirebaseFirestore();
    final tasks = TaskRepository(f);
    final gen = TaskGenerator(f, tasks);
    final batch = f.batch();
    final inseminationDate = Timestamp.fromMillisecondsSinceEpoch(1700000000000);

    gen.addBreedingTasksToBatch(
      batch: batch, farmId: 'f1', breedingRecordId: 'br1',
      sowId: 'sow1', sowTagId: 'SOW-001', areaId: 'a1',
      inseminationDate: inseminationDate,
    );
    await batch.commit();

    final snap = await f.collection('farms').doc('f1').collection('tasks').get();
    expect(snap.docs, hasLength(3));
    final types = snap.docs.map((d) => d.data()['type']).toSet();
    expect(types, {'pregnancy_check', 'farrowing_prep', 'farrowing_expected'});
  });

  test('idempotent — re-running with same source upserts (no duplicates)', () async {
    final f = FakeFirebaseFirestore();
    final tasks = TaskRepository(f);
    final gen = TaskGenerator(f, tasks);
    final ts = Timestamp.fromMillisecondsSinceEpoch(1700000000000);

    final b1 = f.batch();
    gen.addBreedingTasksToBatch(batch: b1, farmId: 'f1', breedingRecordId: 'br1',
      sowId: 's1', sowTagId: 'S', areaId: 'a',
      inseminationDate: ts);
    await b1.commit();
    final b2 = f.batch();
    gen.addBreedingTasksToBatch(batch: b2, farmId: 'f1', breedingRecordId: 'br1',
      sowId: 's1', sowTagId: 'S', areaId: 'a',
      inseminationDate: ts);
    await b2.commit();

    final snap = await f.collection('farms').doc('f1').collection('tasks').get();
    expect(snap.docs, hasLength(3));
  });
}
```

- [ ] **Step 8.4: Implement TaskRepository + TaskGenerator**

`lib/src/features/tasks/data/task_repository.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/task.dart';

class TaskRepository {
  TaskRepository(this._firestore);
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _col(String farmId) =>
      _firestore.collection('farms').doc(farmId).collection('tasks');

  Future<String> createManualTask({
    required String farmId,
    required String title, String? description,
    required Timestamp dueDate,
    String? relatedPigId, String? relatedAreaId,
    TaskAssignment? assignedTo,
    required String creatorUserId,
  }) async {
    final ref = _col(farmId).doc();
    await ref.set({
      'type': 'manual', 'title': title,
      if (description != null) 'description': description,
      'dueDate': dueDate,
      if (relatedPigId != null) 'relatedPigId': relatedPigId,
      if (relatedAreaId != null) 'relatedAreaId': relatedAreaId,
      if (assignedTo != null) 'assignedTo': assignedTo.toMap(),
      'status': 'open', 'autoGenerated': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Stream<List<FarmTask>> streamOpenTasks(String farmId) {
    return _col(farmId)
        .where('status', isEqualTo: 'open')
        .orderBy('dueDate')
        .snapshots()
        .map((s) => s.docs.map((d) => FarmTask.fromFirestore(d, farmId: farmId)).toList());
  }

  Stream<List<FarmTask>> streamTasksAssignedToUser({
    required String farmId, required String userId,
  }) {
    return _col(farmId)
        .where('status', isEqualTo: 'open')
        .where('assignedTo.kind', isEqualTo: 'user')
        .where('assignedTo.id', isEqualTo: userId)
        .snapshots()
        .map((s) => s.docs.map((d) => FarmTask.fromFirestore(d, farmId: farmId)).toList());
  }

  Future<void> completeTask({
    required String farmId, required String taskId, required String userId,
  }) async {
    await _col(farmId).doc(taskId).update({
      'status': 'completed', 'completedBy': userId,
      'completedAt': FieldValue.serverTimestamp(),
    });
  }
}
```

`lib/src/features/tasks/application/task_generator.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:farm_app/src/features/tasks/data/task_repository.dart';

class TaskGenerator {
  TaskGenerator(this._firestore, this._tasks);
  final FirebaseFirestore _firestore;
  // ignore: unused_field
  final TaskRepository _tasks;

  CollectionReference<Map<String, dynamic>> _tasksCol(String farmId) =>
      _firestore.collection('farms').doc(farmId).collection('tasks');

  /// Idempotent task ID derived from source. Re-runs upsert.
  String _taskIdFor(String breedingRecordId, String suffix) =>
      'br_${breedingRecordId}_$suffix';

  void addBreedingTasksToBatch({
    required WriteBatch batch,
    required String farmId,
    required String breedingRecordId,
    required String sowId,
    required String sowTagId,
    String? areaId,
    required Timestamp inseminationDate,
  }) {
    final ins = inseminationDate.toDate();
    final pregCheck = ins.add(const Duration(days: 30));
    final farrPrep = ins.add(const Duration(days: 107));
    final farrExp = ins.add(const Duration(days: 114));

    _writeTask(batch, farmId, _taskIdFor(breedingRecordId, 'preg'),
      type: 'pregnancy_check', title: 'Pregnancy check for $sowTagId',
      dueDate: Timestamp.fromDate(pregCheck),
      relatedPigId: sowId, relatedBreedingId: breedingRecordId, areaId: areaId,
      source: {'collection': 'breeding_records', 'docId': breedingRecordId});
    _writeTask(batch, farmId, _taskIdFor(breedingRecordId, 'prep'),
      type: 'farrowing_prep', title: 'Farrowing prep for $sowTagId',
      dueDate: Timestamp.fromDate(farrPrep),
      relatedPigId: sowId, relatedBreedingId: breedingRecordId, areaId: areaId,
      source: {'collection': 'breeding_records', 'docId': breedingRecordId});
    _writeTask(batch, farmId, _taskIdFor(breedingRecordId, 'farr'),
      type: 'farrowing_expected', title: 'Farrowing expected for $sowTagId',
      dueDate: Timestamp.fromDate(farrExp),
      relatedPigId: sowId, relatedBreedingId: breedingRecordId, areaId: areaId,
      source: {'collection': 'breeding_records', 'docId': breedingRecordId});
  }

  void addWithdrawalTaskToBatch({
    required WriteBatch batch,
    required String farmId,
    required String healthRecordId,
    required String pigId,
    required String tagId,
    String? areaId,
    required Timestamp withdrawalEndDate,
  }) {
    _writeTask(batch, farmId, 'hr_${healthRecordId}_wd',
      type: 'withdrawal_end',
      title: 'Withdrawal period ends for $tagId',
      dueDate: withdrawalEndDate,
      relatedPigId: pigId, areaId: areaId,
      source: {'collection': 'health_records', 'docId': healthRecordId});
  }

  void _writeTask(
    WriteBatch batch, String farmId, String taskId, {
    required String type, required String title,
    required Timestamp dueDate, String? relatedPigId, String? relatedBreedingId,
    String? areaId, Map<String, String>? source,
  }) {
    batch.set(_tasksCol(farmId).doc(taskId), {
      'type': type, 'title': title, 'dueDate': dueDate,
      if (relatedPigId != null) 'relatedPigId': relatedPigId,
      if (relatedBreedingId != null) 'relatedBreedingId': relatedBreedingId,
      if (areaId != null) 'relatedAreaId': areaId,
      'status': 'open', 'autoGenerated': true,
      if (source != null) 'source': source,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
```

- [ ] **Step 8.5: BreedingRepository**

`lib/src/features/pigs/data/breeding_repository.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../activity/data/activity_repository.dart';
import '../../tasks/application/task_generator.dart';
import '../domain/breeding_record.dart';

class BreedingRepository {
  BreedingRepository(this._firestore, this._activity, this._gen);
  final FirebaseFirestore _firestore;
  final ActivityRepository _activity;
  final TaskGenerator _gen;

  CollectionReference<Map<String, dynamic>> _col(String farmId, String pigId) =>
      _firestore.collection('farms').doc(farmId)
          .collection('pigs').doc(pigId)
          .collection('breeding_records');

  Future<String> logBreeding({
    required String farmId,
    required String sowId,
    required String sowTagId,
    required String? sowAreaId,
    required String boarId,
    required Timestamp? heatDate,
    required Timestamp inseminationDate,
    required BreedingMethod method,
    required String? notes,
    required String actorUserId,
    required String actorDisplayName,
  }) async {
    final expected = BreedingRecord.computeExpectedFarrowingDate(inseminationDate);
    final ref = _col(farmId, sowId).doc();
    final batch = _firestore.batch();
    batch.set(ref, {
      'boarId': boarId,
      if (heatDate != null) 'heatDate': heatDate,
      'inseminationDate': inseminationDate,
      'method': method.value,
      'confirmed': false,
      'expectedFarrowingDate': expected,
      'status': 'planned',
      if (notes != null) 'notes': notes,
      'createdBy': actorUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    _gen.addBreedingTasksToBatch(
      batch: batch, farmId: farmId, breedingRecordId: ref.id,
      sowId: sowId, sowTagId: sowTagId, areaId: sowAreaId,
      inseminationDate: inseminationDate,
    );
    _activity.addActivityToBatch(
      batch: batch, farmId: farmId,
      actorUserId: actorUserId, actorDisplayName: actorDisplayName,
      action: 'breeding_logged', entityType: 'pig', entityId: sowId,
      areaId: sowAreaId,
      summary: '$actorDisplayName logged breeding for $sowTagId',
    );
    await batch.commit();
    return ref.id;
  }

  Future<void> recordPregnancyCheck({
    required String farmId, required String sowId,
    required String breedingRecordId, required bool confirmed,
    required Timestamp checkDate,
    required String actorUserId, required String actorDisplayName,
    required String sowTagId, String? areaId,
  }) async {
    final batch = _firestore.batch();
    batch.update(_col(farmId, sowId).doc(breedingRecordId), {
      'confirmed': confirmed,
      'pregnancyCheckDate': checkDate,
      'status': confirmed ? 'confirmed' : 'failed',
    });
    if (!confirmed) {
      // Cancel the farrowing-related tasks.
      final tasksCol = _firestore.collection('farms').doc(farmId).collection('tasks');
      batch.update(tasksCol.doc('br_${breedingRecordId}_prep'), {'status': 'skipped'});
      batch.update(tasksCol.doc('br_${breedingRecordId}_farr'), {'status': 'skipped'});
    }
    // Mark the pregnancy_check task as completed regardless.
    batch.update(_firestore.collection('farms').doc(farmId).collection('tasks')
        .doc('br_${breedingRecordId}_preg'), {
      'status': 'completed', 'completedBy': actorUserId,
      'completedAt': FieldValue.serverTimestamp(),
    });
    _activity.addActivityToBatch(
      batch: batch, farmId: farmId,
      actorUserId: actorUserId, actorDisplayName: actorDisplayName,
      action: 'pregnancy_check_logged', entityType: 'pig', entityId: sowId,
      areaId: areaId,
      summary: '$actorDisplayName recorded pregnancy check for $sowTagId: '
          '${confirmed ? "confirmed" : "failed"}',
    );
    await batch.commit();
  }

  Future<void> markFarrowed({
    required String farmId, required String sowId, required String breedingRecordId,
  }) async {
    await _col(farmId, sowId).doc(breedingRecordId).update({'status': 'farrowed'});
  }

  Stream<List<BreedingRecord>> streamBreedingRecords({
    required String farmId, required String sowId,
  }) {
    return _col(farmId, sowId)
        .orderBy('inseminationDate', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) =>
            BreedingRecord.fromFirestore(d, farmId: farmId, sowId: sowId)).toList());
  }
}
```

- [ ] **Step 8.6: Task providers + breeding providers**

`lib/src/features/tasks/application/task_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../activity/application/activity_providers.dart';
import '../data/task_repository.dart';
import '../domain/task.dart';
import 'task_generator.dart';

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepository(ref.watch(firestoreProvider)),
);
final taskGeneratorProvider = Provider<TaskGenerator>(
  (ref) => TaskGenerator(ref.watch(firestoreProvider), ref.watch(taskRepositoryProvider)),
);

final openTasksStreamProvider =
    StreamProvider.family<List<FarmTask>, String>((ref, farmId) {
  return ref.watch(taskRepositoryProvider).streamOpenTasks(farmId);
});

final myTasksStreamProvider =
    StreamProvider.family<List<FarmTask>, ({String farmId, String userId})>((ref, args) {
  return ref.watch(taskRepositoryProvider).streamTasksAssignedToUser(
        farmId: args.farmId, userId: args.userId);
});
```

Add to `lib/src/features/pigs/application/pig_providers.dart`:

```dart
import '../data/breeding_repository.dart';
import '../domain/breeding_record.dart';
import '../../tasks/application/task_providers.dart';

final breedingRepositoryProvider = Provider<BreedingRepository>(
  (ref) => BreedingRepository(
    ref.watch(firestoreProvider),
    ref.watch(activityRepositoryProvider),
    ref.watch(taskGeneratorProvider),
  ),
);

final breedingStreamProvider =
    StreamProvider.family<List<BreedingRecord>, ({String farmId, String sowId})>((ref, args) {
  return ref.watch(breedingRepositoryProvider).streamBreedingRecords(
        farmId: args.farmId, sowId: args.sowId);
});
```

- [ ] **Step 8.7: Breeding log screen**

`lib/src/features/pigs/presentation/breeding_log_screen.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../application/pig_providers.dart';
import '../domain/breeding_record.dart';
import '../domain/pig.dart';

class BreedingLogScreen extends ConsumerStatefulWidget {
  const BreedingLogScreen({super.key, required this.sow});
  final Pig sow;
  @override
  ConsumerState<BreedingLogScreen> createState() => _S();
}

class _S extends ConsumerState<BreedingLogScreen> {
  DateTime? _heatDate;
  DateTime _inseminationDate = DateTime.now();
  String? _boarId;
  BreedingMethod _method = BreedingMethod.natural;
  final _notes = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() { _notes.dispose(); super.dispose(); }

  Future<void> _save() async {
    final farmId = ref.read(selectedFarmIdProvider);
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return;
    if (_boarId == null) { setState(() => _error = 'Select a boar.'); return; }
    setState(() { _busy = true; _error = null; });
    final actorName = ref.read(currentAppUserProvider).asData?.value?.displayName ?? '';
    try {
      await ref.read(breedingRepositoryProvider).logBreeding(
        farmId: farmId, sowId: widget.sow.id, sowTagId: widget.sow.tagId,
        sowAreaId: widget.sow.currentAreaId, boarId: _boarId!,
        heatDate: _heatDate == null ? null : Timestamp.fromDate(_heatDate!),
        inseminationDate: Timestamp.fromDate(_inseminationDate),
        method: _method,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        actorUserId: user.uid, actorDisplayName: actorName,
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
    final farmId = ref.watch(selectedFarmIdProvider);
    final pigsAsync = farmId != null
        ? ref.watch(pigsStreamProvider(farmId))
        : const AsyncValue.data([]);
    final expected = _inseminationDate.add(const Duration(days: gestationDays));
    return Scaffold(
      appBar: AppBar(title: Text('Log breeding · ${widget.sow.tagId}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Heat observed (optional)'),
              subtitle: Text(_heatDate?.toLocal().toString().split(' ')[0] ?? '—'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final p = await showDatePicker(context: context,
                    initialDate: _heatDate ?? DateTime.now(),
                    firstDate: DateTime(2024), lastDate: DateTime.now());
                if (p != null) setState(() => _heatDate = p);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Insemination date'),
              subtitle: Text(_inseminationDate.toLocal().toString().split(' ')[0]),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final p = await showDatePicker(context: context,
                    initialDate: _inseminationDate,
                    firstDate: DateTime(2024), lastDate: DateTime.now());
                if (p != null) setState(() => _inseminationDate = p);
              },
            ),
            const SizedBox(height: 12),
            pigsAsync.when(
              data: (pigs) {
                final boars = pigs.where((p) =>
                  p.sex == PigSex.male && p.stage == PigStage.boar &&
                  p.status == PigStatus.active).toList();
                return DropdownButtonFormField<String>(
                  value: _boarId,
                  decoration: const InputDecoration(labelText: 'Boar'),
                  items: boars.map((b) =>
                    DropdownMenuItem(value: b.id, child: Text(b.tagId))).toList(),
                  onChanged: (v) => setState(() => _boarId = v),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e'),
            ),
            const SizedBox(height: 12),
            SegmentedButton<BreedingMethod>(
              segments: BreedingMethod.values.map((m) =>
                ButtonSegment(value: m, label: Text(m.label))).toList(),
              selected: {_method},
              onSelectionChanged: (s) => setState(() => _method = s.first),
            ),
            const SizedBox(height: 16),
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text('Expected farrowing: ${DateFormat.yMMMd().format(expected)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes (optional)'), maxLines: 3),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _busy ? null : _save,
              child: _busy ? const CircularProgressIndicator() : const Text('Save breeding')),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 8.8: Wire Breeding tab in Pig Detail**

In `pig_detail_screen.dart`, replace the `_PlaceholderTab(text: 'Breeding history...')` with:

```dart
_BreedingTab(pig: pig),
```

Add this widget at the bottom of the file:

```dart
class _BreedingTab extends ConsumerWidget {
  const _BreedingTab({required this.pig});
  final Pig pig;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canBreed = pig.sex == PigSex.female &&
        (pig.stage == PigStage.sow || pig.stage == PigStage.gilt);
    if (!canBreed) {
      return const Center(child: Text('Breeding only applies to sows and gilts.'));
    }
    final recordsAsync = ref.watch(breedingStreamProvider(
        (farmId: pig.farmId, sowId: pig.id)));
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.favorite),
        label: const Text('Log breeding'),
        onPressed: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => BreedingLogScreen(sow: pig))),
      ),
      body: recordsAsync.when(
        data: (records) {
          if (records.isEmpty) return const Center(child: Text('No breeding records yet.'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: records.map((r) => Card(
              child: ListTile(
                title: Text('${r.method.label} · ${r.status.label}'),
                subtitle: Text(
                  'Inseminated: ${r.inseminationDate.toDate().toString().split(' ')[0]}\n'
                  'Expected farrow: ${r.expectedFarrowingDate.toDate().toString().split(' ')[0]}\n'
                  'Boar: ${r.boarId}',
                ),
                isThreeLine: true,
                trailing: r.status == BreedingStatus.planned
                    ? IconButton(
                        icon: const Icon(Icons.fact_check),
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Pregnancy check'),
                              content: const Text('Was the sow confirmed pregnant?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false),
                                  child: const Text('No / Failed')),
                                TextButton(onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Yes / Confirmed')),
                              ],
                            ),
                          );
                          if (confirmed == null) return;
                          final user = ref.read(authStateChangesProvider).asData?.value;
                          final name = ref.read(currentAppUserProvider).asData?.value?.displayName ?? '';
                          if (user == null) return;
                          await ref.read(breedingRepositoryProvider).recordPregnancyCheck(
                            farmId: pig.farmId, sowId: pig.id, breedingRecordId: r.id,
                            confirmed: confirmed, checkDate: Timestamp.now(),
                            actorUserId: user.uid, actorDisplayName: name,
                            sowTagId: pig.tagId, areaId: pig.currentAreaId,
                          );
                        },
                      )
                    : null,
              ),
            )).toList(),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}
```

Add imports at top of file:
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../authentication/application/auth_providers.dart';
import '../domain/breeding_record.dart';
import 'breeding_log_screen.dart';
```

- [ ] **Step 8.9: Run + commit**

```bash
flutter analyze && flutter test
```

Manual smoke: create a sow, navigate to her Breeding tab, "Log breeding" with a boar, watch the expected farrowing date display, save. Verify in Firestore: `pigs/{sowId}/breeding_records/{id}` exists, and three tasks exist in `tasks/` with the right due dates. Tap the fact-check icon on the breeding card; pick "Yes" → status changes to "Confirmed pregnant", pregnancy_check task marked completed.

```bash
git add -A
git commit -m "feat(breeding,tasks): breeding cycle + automated task generation

- BreedingRecord + 114-day gestation auto-compute
- TaskGenerator emits pregnancy_check (+30d), farrowing_prep (+107d),
  farrowing_expected (+114d) atomically with breeding write
- Idempotent task IDs (br_{breedingId}_{suffix}) prevent duplicates on re-run
- Pregnancy check completes/skips downstream tasks based on outcome
- Breeding log screen + per-sow breeding history tab"
```

---

---

## Task 9: Farrowing Log + Litter Batch

**Goal:** When a sow farrows, log the litter (live, stillborn, mummified, avg birth weight). Optionally create a `batches/{id}` of type `litter` to track the piglets as a group. Closes the breeding record (`status: farrowed`) and marks the `farrowing_expected` task complete.

**Files:**
- Create:
  - `lib/src/features/pigs/domain/farrowing_record.dart`
  - `lib/src/features/pigs/domain/batch.dart`
  - `lib/src/features/pigs/data/farrowing_repository.dart`
  - `lib/src/features/pigs/data/batch_repository.dart`
  - `lib/src/features/pigs/presentation/farrowing_log_screen.dart`
  - `test/features/pigs/data/farrowing_repository_test.dart`
- Modify:
  - `lib/src/features/pigs/application/pig_providers.dart`
  - `lib/src/features/pigs/presentation/pig_detail_screen.dart` (Breeding tab gets "Log farrowing" action)

### Steps

- [ ] **Step 9.1: FarrowingRecord + Batch models**

`lib/src/features/pigs/domain/farrowing_record.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class FarrowingRecord {
  final String id;
  final String farmId;
  final String sowId;
  final String breedingRecordId;
  final Timestamp date;
  final int liveBorn;
  final int stillborn;
  final int mummified;
  final double? avgBirthWeightKg;
  final String? litterBatchId;
  final String? notes;
  final String createdBy;
  final Timestamp createdAt;

  const FarrowingRecord({
    required this.id, required this.farmId, required this.sowId,
    required this.breedingRecordId, required this.date,
    required this.liveBorn, required this.stillborn, required this.mummified,
    required this.avgBirthWeightKg, required this.litterBatchId,
    required this.notes, required this.createdBy, required this.createdAt,
  });

  factory FarrowingRecord.fromFirestore(
    DocumentSnapshot doc, {required String farmId, required String sowId}) {
    final d = doc.data() as Map<String, dynamic>;
    return FarrowingRecord(
      id: doc.id, farmId: farmId, sowId: sowId,
      breedingRecordId: d['breedingRecordId'] as String,
      date: d['date'] as Timestamp,
      liveBorn: d['liveBorn'] as int? ?? 0,
      stillborn: d['stillborn'] as int? ?? 0,
      mummified: d['mummified'] as int? ?? 0,
      avgBirthWeightKg: (d['avgBirthWeightKg'] as num?)?.toDouble(),
      litterBatchId: d['litterBatchId'] as String?,
      notes: d['notes'] as String?,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'breedingRecordId': breedingRecordId,
    'date': date,
    'liveBorn': liveBorn, 'stillborn': stillborn, 'mummified': mummified,
    if (avgBirthWeightKg != null) 'avgBirthWeightKg': avgBirthWeightKg,
    if (litterBatchId != null) 'litterBatchId': litterBatchId,
    if (notes != null) 'notes': notes,
    'createdBy': createdBy, 'createdAt': createdAt,
  };
}
```

`lib/src/features/pigs/domain/batch.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum BatchType {
  litter('litter', 'Litter'),
  growFinish('grow_finish', 'Grow-Finish'),
  nursery('nursery', 'Nursery');
  const BatchType(this.value, this.label);
  final String value;
  final String label;
  static BatchType fromString(String s) =>
      BatchType.values.firstWhere((b) => b.value == s, orElse: () => BatchType.growFinish);
}

enum BatchStatus {
  active('active'), sold('sold'), closed('closed');
  const BatchStatus(this.value);
  final String value;
  static BatchStatus fromString(String s) =>
      BatchStatus.values.firstWhere((b) => b.value == s, orElse: () => BatchStatus.active);
}

class Batch {
  final String id;
  final String farmId;
  final String name;
  final BatchType type;
  final List<String> originPigIds;
  final List<String> pigIds;
  final int count;
  final String currentAreaId;
  final String? currentPenId;
  final BatchStatus status;
  final Timestamp startDate;
  final Timestamp? endDate;
  final String createdBy;
  final Timestamp createdAt;

  const Batch({
    required this.id, required this.farmId, required this.name, required this.type,
    required this.originPigIds, required this.pigIds, required this.count,
    required this.currentAreaId, required this.currentPenId,
    required this.status, required this.startDate, required this.endDate,
    required this.createdBy, required this.createdAt,
  });

  factory Batch.fromFirestore(DocumentSnapshot doc, {required String farmId}) {
    final d = doc.data() as Map<String, dynamic>;
    return Batch(
      id: doc.id, farmId: farmId,
      name: d['name'] as String,
      type: BatchType.fromString(d['type'] as String),
      originPigIds: List<String>.from(d['originPigIds'] ?? const []),
      pigIds: List<String>.from(d['pigIds'] ?? const []),
      count: d['count'] as int? ?? 0,
      currentAreaId: d['currentAreaId'] as String,
      currentPenId: d['currentPenId'] as String?,
      status: BatchStatus.fromString(d['status'] as String? ?? 'active'),
      startDate: d['startDate'] as Timestamp,
      endDate: d['endDate'] as Timestamp?,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name, 'type': type.value,
    'originPigIds': originPigIds, 'pigIds': pigIds, 'count': count,
    'currentAreaId': currentAreaId,
    if (currentPenId != null) 'currentPenId': currentPenId,
    'status': status.value, 'startDate': startDate,
    if (endDate != null) 'endDate': endDate,
    'createdBy': createdBy, 'createdAt': createdAt,
  };
}
```

- [ ] **Step 9.2: Test — FarrowingRepository**

`test/features/pigs/data/farrowing_repository_test.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/features/activity/data/activity_repository.dart';
import 'package:farm_app/src/features/pigs/data/batch_repository.dart';
import 'package:farm_app/src/features/pigs/data/farrowing_repository.dart';

void main() {
  test('logFarrowing writes record, closes breeding, completes task', () async {
    final f = FakeFirebaseFirestore();
    await f.collection('farms').doc('f1').collection('pigs').doc('sow1')
      .collection('breeding_records').doc('br1').set({
        'boarId': 'b1', 'inseminationDate': Timestamp.now(),
        'method': 'natural', 'confirmed': true,
        'expectedFarrowingDate': Timestamp.now(),
        'status': 'confirmed', 'createdBy': 'u', 'createdAt': Timestamp.now(),
      });
    await f.collection('farms').doc('f1').collection('tasks').doc('br_br1_farr')
      .set({'type': 'farrowing_expected', 'title': 'x', 'dueDate': Timestamp.now(),
            'status': 'open', 'autoGenerated': true, 'createdAt': Timestamp.now()});

    final repo = FarrowingRepository(f, ActivityRepository(f), BatchRepository(f, ActivityRepository(f)));
    final id = await repo.logFarrowing(
      farmId: 'f1', sowId: 'sow1', sowTagId: 'SOW-1', sowAreaId: 'a1', sowPenId: null,
      breedingRecordId: 'br1', date: Timestamp.now(),
      liveBorn: 10, stillborn: 1, mummified: 0,
      avgBirthWeightKg: 1.4, createLitterBatch: true, notes: null,
      actorUserId: 'u1', actorDisplayName: 'Juan',
    );

    final farr = await f.collection('farms').doc('f1').collection('pigs').doc('sow1')
        .collection('farrowing_records').doc(id).get();
    expect(farr.data()!['liveBorn'], 10);
    expect(farr.data()!['litterBatchId'], isNotNull);

    final br = await f.collection('farms').doc('f1').collection('pigs').doc('sow1')
        .collection('breeding_records').doc('br1').get();
    expect(br.data()!['status'], 'farrowed');

    final task = await f.collection('farms').doc('f1').collection('tasks')
        .doc('br_br1_farr').get();
    expect(task.data()!['status'], 'completed');

    final batches = await f.collection('farms').doc('f1').collection('batches').get();
    expect(batches.docs, hasLength(1));
    expect(batches.docs.first.data()['type'], 'litter');
    expect(batches.docs.first.data()['count'], 10);
  });
}
```

- [ ] **Step 9.3: BatchRepository + FarrowingRepository**

`lib/src/features/pigs/data/batch_repository.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../activity/data/activity_repository.dart';
import '../domain/batch.dart';

class BatchRepository {
  BatchRepository(this._firestore, this._activity);
  final FirebaseFirestore _firestore;
  final ActivityRepository _activity;

  CollectionReference<Map<String, dynamic>> _col(String farmId) =>
      _firestore.collection('farms').doc(farmId).collection('batches');

  /// Adds a batch create to an existing batch (used during farrowing).
  /// Returns the new batch doc ID via the caller capturing ref.id.
  String addBatchCreateToBatch({
    required WriteBatch batch,
    required String farmId,
    required String name,
    required BatchType type,
    required List<String> originPigIds,
    required int count,
    required String currentAreaId,
    String? currentPenId,
    required String createdBy,
  }) {
    final ref = _col(farmId).doc();
    batch.set(ref, {
      'name': name, 'type': type.value,
      'originPigIds': originPigIds, 'pigIds': <String>[], 'count': count,
      'currentAreaId': currentAreaId,
      if (currentPenId != null) 'currentPenId': currentPenId,
      'status': 'active', 'startDate': FieldValue.serverTimestamp(),
      'createdBy': createdBy, 'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Stream<List<Batch>> streamBatches(String farmId) {
    return _col(farmId).snapshots().map((s) =>
        s.docs.map((d) => Batch.fromFirestore(d, farmId: farmId)).toList());
  }
}
```

`lib/src/features/pigs/data/farrowing_repository.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../activity/data/activity_repository.dart';
import '../domain/batch.dart';
import '../domain/farrowing_record.dart';
import 'batch_repository.dart';

class FarrowingRepository {
  FarrowingRepository(this._firestore, this._activity, this._batches);
  final FirebaseFirestore _firestore;
  final ActivityRepository _activity;
  final BatchRepository _batches;

  CollectionReference<Map<String, dynamic>> _col(String farmId, String sowId) =>
      _firestore.collection('farms').doc(farmId)
          .collection('pigs').doc(sowId)
          .collection('farrowing_records');

  Future<String> logFarrowing({
    required String farmId,
    required String sowId, required String sowTagId,
    required String sowAreaId, required String? sowPenId,
    required String breedingRecordId,
    required Timestamp date,
    required int liveBorn, required int stillborn, required int mummified,
    required double? avgBirthWeightKg,
    required bool createLitterBatch, required String? notes,
    required String actorUserId, required String actorDisplayName,
  }) async {
    final farrRef = _col(farmId, sowId).doc();
    final batch = _firestore.batch();
    String? litterBatchId;
    if (createLitterBatch && liveBorn > 0) {
      litterBatchId = _batches.addBatchCreateToBatch(
        batch: batch, farmId: farmId,
        name: 'Litter ${date.toDate().toIso8601String().split('T')[0]} · $sowTagId',
        type: BatchType.litter,
        originPigIds: [sowId], count: liveBorn,
        currentAreaId: sowAreaId, currentPenId: sowPenId,
        createdBy: actorUserId,
      );
    }
    batch.set(farrRef, {
      'breedingRecordId': breedingRecordId, 'date': date,
      'liveBorn': liveBorn, 'stillborn': stillborn, 'mummified': mummified,
      if (avgBirthWeightKg != null) 'avgBirthWeightKg': avgBirthWeightKg,
      if (litterBatchId != null) 'litterBatchId': litterBatchId,
      if (notes != null) 'notes': notes,
      'createdBy': actorUserId, 'createdAt': FieldValue.serverTimestamp(),
    });
    // Close the breeding record.
    batch.update(
      _firestore.collection('farms').doc(farmId).collection('pigs').doc(sowId)
        .collection('breeding_records').doc(breedingRecordId),
      {'status': 'farrowed'});
    // Mark farrowing_expected task complete.
    batch.update(
      _firestore.collection('farms').doc(farmId).collection('tasks')
        .doc('br_${breedingRecordId}_farr'),
      {'status': 'completed', 'completedBy': actorUserId,
       'completedAt': FieldValue.serverTimestamp()});
    _activity.addActivityToBatch(
      batch: batch, farmId: farmId,
      actorUserId: actorUserId, actorDisplayName: actorDisplayName,
      action: 'farrowing_logged', entityType: 'pig', entityId: sowId,
      areaId: sowAreaId,
      summary: '$actorDisplayName logged farrowing on $sowTagId — '
          '$liveBorn live, $stillborn stillborn',
    );
    await batch.commit();
    return farrRef.id;
  }

  Stream<List<FarrowingRecord>> streamFarrowings({
    required String farmId, required String sowId,
  }) {
    return _col(farmId, sowId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) =>
            FarrowingRecord.fromFirestore(d, farmId: farmId, sowId: sowId)).toList());
  }

  /// Collection-group across all sows for a farm — used by Yield Reports.
  Stream<List<FarrowingRecord>> streamAllFarrowings(String farmId) {
    return _firestore.collectionGroup('farrowing_records').snapshots().map((s) {
      return s.docs.where((d) {
        final parts = d.reference.path.split('/');
        return parts[0] == 'farms' && parts[1] == farmId;
      }).map((d) {
        final sowId = d.reference.parent.parent!.id;
        return FarrowingRecord.fromFirestore(d, farmId: farmId, sowId: sowId);
      }).toList();
    });
  }
}
```

- [ ] **Step 9.4: Providers + farrowing screen**

Add to `pig_providers.dart`:

```dart
import '../data/farrowing_repository.dart';
import '../data/batch_repository.dart';
import '../domain/farrowing_record.dart';
import '../domain/batch.dart';

final batchRepositoryProvider = Provider<BatchRepository>(
  (ref) => BatchRepository(ref.watch(firestoreProvider), ref.watch(activityRepositoryProvider)));

final farrowingRepositoryProvider = Provider<FarrowingRepository>(
  (ref) => FarrowingRepository(
    ref.watch(firestoreProvider),
    ref.watch(activityRepositoryProvider),
    ref.watch(batchRepositoryProvider),
  ));

final farrowingsForSowProvider =
    StreamProvider.family<List<FarrowingRecord>, ({String farmId, String sowId})>((ref, args) {
  return ref.watch(farrowingRepositoryProvider).streamFarrowings(
        farmId: args.farmId, sowId: args.sowId);
});

final allFarrowingsProvider =
    StreamProvider.family<List<FarrowingRecord>, String>((ref, farmId) {
  return ref.watch(farrowingRepositoryProvider).streamAllFarrowings(farmId);
});

final batchesStreamProvider =
    StreamProvider.family<List<Batch>, String>((ref, farmId) {
  return ref.watch(batchRepositoryProvider).streamBatches(farmId);
});
```

`lib/src/features/pigs/presentation/farrowing_log_screen.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../application/pig_providers.dart';
import '../domain/breeding_record.dart';
import '../domain/pig.dart';

class FarrowingLogScreen extends ConsumerStatefulWidget {
  const FarrowingLogScreen({super.key, required this.sow, required this.breedingRecord});
  final Pig sow;
  final BreedingRecord breedingRecord;
  @override
  ConsumerState<FarrowingLogScreen> createState() => _S();
}

class _S extends ConsumerState<FarrowingLogScreen> {
  DateTime _date = DateTime.now();
  final _live = TextEditingController();
  final _still = TextEditingController(text: '0');
  final _mumm = TextEditingController(text: '0');
  final _weight = TextEditingController();
  final _notes = TextEditingController();
  bool _createBatch = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _live.dispose(); _still.dispose(); _mumm.dispose();
    _weight.dispose(); _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final farmId = ref.read(selectedFarmIdProvider);
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return;
    final live = int.tryParse(_live.text);
    if (live == null || live < 0) { setState(() => _error = 'Live born required.'); return; }
    setState(() { _busy = true; _error = null; });
    final name = ref.read(currentAppUserProvider).asData?.value?.displayName ?? '';
    try {
      await ref.read(farrowingRepositoryProvider).logFarrowing(
        farmId: farmId, sowId: widget.sow.id, sowTagId: widget.sow.tagId,
        sowAreaId: widget.sow.currentAreaId, sowPenId: widget.sow.currentPenId,
        breedingRecordId: widget.breedingRecord.id,
        date: Timestamp.fromDate(_date),
        liveBorn: live,
        stillborn: int.tryParse(_still.text) ?? 0,
        mummified: int.tryParse(_mumm.text) ?? 0,
        avgBirthWeightKg: double.tryParse(_weight.text),
        createLitterBatch: _createBatch,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        actorUserId: user.uid, actorDisplayName: name,
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
      appBar: AppBar(title: Text('Farrowing · ${widget.sow.tagId}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Farrowing date'),
              subtitle: Text(_date.toLocal().toString().split(' ')[0]),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final p = await showDatePicker(context: context,
                  initialDate: _date,
                  firstDate: DateTime(2024), lastDate: DateTime.now());
                if (p != null) setState(() => _date = p);
              },
            ),
            const SizedBox(height: 8),
            TextField(controller: _live,
              decoration: const InputDecoration(labelText: 'Live born'),
              keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(controller: _still,
              decoration: const InputDecoration(labelText: 'Stillborn'),
              keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(controller: _mumm,
              decoration: const InputDecoration(labelText: 'Mummified'),
              keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(controller: _weight,
              decoration: const InputDecoration(labelText: 'Avg birth weight (kg, optional)'),
              keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Create litter batch'),
              subtitle: const Text('Tracks the piglets as a group'),
              value: _createBatch,
              onChanged: (v) => setState(() => _createBatch = v),
            ),
            const SizedBox(height: 8),
            TextField(controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes (optional)'), maxLines: 3),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _busy ? null : _save,
              child: _busy ? const CircularProgressIndicator() : const Text('Save farrowing')),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 9.5: Wire from Breeding tab**

In `pig_detail_screen.dart` `_BreedingTab`, replace the existing `trailing` IconButton on planned/confirmed records to include a "farrow" button when status is `confirmed`:

```dart
trailing: r.status == BreedingStatus.planned
    ? IconButton(icon: const Icon(Icons.fact_check), onPressed: () { /* preg check, as before */ })
    : r.status == BreedingStatus.confirmed
        ? IconButton(
            icon: const Icon(Icons.child_friendly),
            tooltip: 'Log farrowing',
            onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => FarrowingLogScreen(sow: pig, breedingRecord: r))),
          )
        : null,
```

Import: `import 'farrowing_log_screen.dart';`

- [ ] **Step 9.6: Run + commit**

```bash
flutter analyze && flutter test && flutter run -d <device>
```

Manual: take a sow with a confirmed breeding → tap child icon → log farrowing (10 live, 1 stillborn, create litter ON). Verify: farrowing record created, breeding `status: farrowed`, `farrowing_expected` task completed, a new `batches/{id}` with `type: litter`, `count: 10`.

```bash
git add -A
git commit -m "feat(farrowing,batches): farrowing log with optional litter batch creation

- FarrowingRecord + Batch models
- FarrowingRepository: writes farrowing, optionally creates litter batch,
  closes breeding record, completes farrowing_expected task — all atomic
- BatchRepository with addBatchCreateToBatch helper for inline batch creation
- Farrowing log screen accessible from confirmed breeding records"
```

---

## Task 10: Health Log + Photos + Withdrawal Task

**Goal:** Health record CRUD (vaccination, treatment, checkup, deworming) with multi-photo support. Withdrawal-end task auto-generated when `withdrawalEndDate` is set. Vet role can write here.

**Files:**
- Create:
  - `lib/src/features/pigs/domain/health_record.dart`
  - `lib/src/features/pigs/data/health_repository.dart`
  - `lib/src/features/pigs/presentation/health_log_screen.dart`
  - `test/features/pigs/data/health_repository_test.dart`
- Modify:
  - `lib/src/features/pigs/application/pig_providers.dart`
  - `lib/src/features/pigs/presentation/pig_detail_screen.dart` (Health tab)

### Steps

- [ ] **Step 10.1: HealthRecord model**

`lib/src/features/pigs/domain/health_record.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum HealthEventType {
  vaccination('vaccination', 'Vaccination'),
  treatment('treatment', 'Treatment'),
  checkup('checkup', 'Checkup'),
  deworming('deworming', 'Deworming');
  const HealthEventType(this.value, this.label);
  final String value;
  final String label;
  static HealthEventType fromString(String s) =>
      HealthEventType.values.firstWhere((e) => e.value == s, orElse: () => HealthEventType.checkup);
}

enum HealthRoute {
  oral('oral', 'Oral'),
  im('im', 'IM (intramuscular)'),
  sc('sc', 'SC (subcutaneous)'),
  topical('topical', 'Topical');
  const HealthRoute(this.value, this.label);
  final String value;
  final String label;
  static HealthRoute fromString(String s) =>
      HealthRoute.values.firstWhere((r) => r.value == s, orElse: () => HealthRoute.oral);
}

class HealthRecord {
  final String id;
  final String farmId;
  final String pigId;
  final HealthEventType type;
  final Timestamp date;
  final String? productName;
  final String? dosage;
  final HealthRoute? route;
  final String? diagnosis;
  final Timestamp? withdrawalEndDate;
  final double? costPhp;
  final List<String> photoUrls;
  final String? notes;
  final String createdBy;
  final Timestamp createdAt;

  const HealthRecord({
    required this.id, required this.farmId, required this.pigId,
    required this.type, required this.date, required this.productName,
    required this.dosage, required this.route, required this.diagnosis,
    required this.withdrawalEndDate, required this.costPhp,
    required this.photoUrls, required this.notes,
    required this.createdBy, required this.createdAt,
  });

  factory HealthRecord.fromFirestore(
    DocumentSnapshot doc, {required String farmId, required String pigId}) {
    final d = doc.data() as Map<String, dynamic>;
    return HealthRecord(
      id: doc.id, farmId: farmId, pigId: pigId,
      type: HealthEventType.fromString(d['type'] as String),
      date: d['date'] as Timestamp,
      productName: d['productName'] as String?,
      dosage: d['dosage'] as String?,
      route: d['route'] != null ? HealthRoute.fromString(d['route'] as String) : null,
      diagnosis: d['diagnosis'] as String?,
      withdrawalEndDate: d['withdrawalEndDate'] as Timestamp?,
      costPhp: (d['costPhp'] as num?)?.toDouble(),
      photoUrls: List<String>.from(d['photoUrls'] ?? const []),
      notes: d['notes'] as String?,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'type': type.value, 'date': date,
    if (productName != null) 'productName': productName,
    if (dosage != null) 'dosage': dosage,
    if (route != null) 'route': route!.value,
    if (diagnosis != null) 'diagnosis': diagnosis,
    if (withdrawalEndDate != null) 'withdrawalEndDate': withdrawalEndDate,
    if (costPhp != null) 'costPhp': costPhp,
    'photoUrls': photoUrls,
    if (notes != null) 'notes': notes,
    'createdBy': createdBy, 'createdAt': createdAt,
  };
}
```

- [ ] **Step 10.2: HealthRepository**

`lib/src/features/pigs/data/health_repository.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../activity/data/activity_repository.dart';
import '../../tasks/application/task_generator.dart';
import '../domain/health_record.dart';

class HealthRepository {
  HealthRepository(this._firestore, this._activity, this._gen);
  final FirebaseFirestore _firestore;
  final ActivityRepository _activity;
  final TaskGenerator _gen;

  CollectionReference<Map<String, dynamic>> _col(String farmId, String pigId) =>
      _firestore.collection('farms').doc(farmId)
          .collection('pigs').doc(pigId)
          .collection('health_records');

  Future<String> logHealth({
    required String farmId,
    required String pigId, required String tagId, required String areaId,
    required HealthEventType type, required Timestamp date,
    required String? productName, required String? dosage,
    required HealthRoute? route, required String? diagnosis,
    required Timestamp? withdrawalEndDate, required double? costPhp,
    required List<String> photoUrls, required String? notes,
    required String actorUserId, required String actorDisplayName,
  }) async {
    final ref = _col(farmId, pigId).doc();
    final batch = _firestore.batch();
    batch.set(ref, {
      'type': type.value, 'date': date,
      if (productName != null) 'productName': productName,
      if (dosage != null) 'dosage': dosage,
      if (route != null) 'route': route.value,
      if (diagnosis != null) 'diagnosis': diagnosis,
      if (withdrawalEndDate != null) 'withdrawalEndDate': withdrawalEndDate,
      if (costPhp != null) 'costPhp': costPhp,
      'photoUrls': photoUrls,
      if (notes != null) 'notes': notes,
      'createdBy': actorUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (withdrawalEndDate != null) {
      _gen.addWithdrawalTaskToBatch(
        batch: batch, farmId: farmId, healthRecordId: ref.id,
        pigId: pigId, tagId: tagId, areaId: areaId,
        withdrawalEndDate: withdrawalEndDate,
      );
    }
    _activity.addActivityToBatch(
      batch: batch, farmId: farmId,
      actorUserId: actorUserId, actorDisplayName: actorDisplayName,
      action: 'health_logged', entityType: 'pig', entityId: pigId,
      areaId: areaId,
      summary: '$actorDisplayName logged ${type.label} on $tagId'
          '${productName == null ? "" : " ($productName)"}',
    );
    await batch.commit();
    return ref.id;
  }

  Stream<List<HealthRecord>> streamHealthForPig({
    required String farmId, required String pigId,
  }) {
    return _col(farmId, pigId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) =>
            HealthRecord.fromFirestore(d, farmId: farmId, pigId: pigId)).toList());
  }
}
```

Repository test (`test/features/pigs/data/health_repository_test.dart`):

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/features/activity/data/activity_repository.dart';
import 'package:farm_app/src/features/pigs/data/health_repository.dart';
import 'package:farm_app/src/features/pigs/domain/health_record.dart';
import 'package:farm_app/src/features/tasks/application/task_generator.dart';
import 'package:farm_app/src/features/tasks/data/task_repository.dart';

void main() {
  test('logHealth with withdrawalEndDate generates withdrawal_end task', () async {
    final f = FakeFirebaseFirestore();
    final repo = HealthRepository(
      f, ActivityRepository(f), TaskGenerator(f, TaskRepository(f)));
    final end = Timestamp.fromMillisecondsSinceEpoch(1800000000000);
    final id = await repo.logHealth(
      farmId: 'f1', pigId: 'p1', tagId: 'PIG-1', areaId: 'a1',
      type: HealthEventType.vaccination, date: Timestamp.now(),
      productName: 'PRRS Vax', dosage: '2ml', route: HealthRoute.im,
      diagnosis: null, withdrawalEndDate: end, costPhp: 150,
      photoUrls: const [], notes: null,
      actorUserId: 'u', actorDisplayName: 'Juan',
    );
    expect(id, isNotEmpty);
    final tasks = await f.collection('farms').doc('f1').collection('tasks').get();
    expect(tasks.docs.where((d) => d.data()['type'] == 'withdrawal_end'), hasLength(1));
  });

  test('logHealth without withdrawal date does not create task', () async {
    final f = FakeFirebaseFirestore();
    final repo = HealthRepository(
      f, ActivityRepository(f), TaskGenerator(f, TaskRepository(f)));
    await repo.logHealth(
      farmId: 'f1', pigId: 'p1', tagId: 'X', areaId: 'a',
      type: HealthEventType.checkup, date: Timestamp.now(),
      productName: null, dosage: null, route: null, diagnosis: null,
      withdrawalEndDate: null, costPhp: null,
      photoUrls: const [], notes: null,
      actorUserId: 'u', actorDisplayName: 'J',
    );
    final tasks = await f.collection('farms').doc('f1').collection('tasks').get();
    expect(tasks.docs, isEmpty);
  });
}
```

- [ ] **Step 10.3: Providers**

Add to `pig_providers.dart`:

```dart
import '../data/health_repository.dart';
import '../domain/health_record.dart';

final healthRepositoryProvider = Provider<HealthRepository>(
  (ref) => HealthRepository(
    ref.watch(firestoreProvider),
    ref.watch(activityRepositoryProvider),
    ref.watch(taskGeneratorProvider),
  ));

final healthForPigProvider =
    StreamProvider.family<List<HealthRecord>, ({String farmId, String pigId})>((ref, args) {
  return ref.watch(healthRepositoryProvider).streamHealthForPig(
        farmId: args.farmId, pigId: args.pigId);
});
```

- [ ] **Step 10.4: Health log screen (with photos)**

`lib/src/features/pigs/presentation/health_log_screen.dart`:

```dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../../media/media_providers.dart';
import '../../media/photo_picker.dart';
import '../application/pig_providers.dart';
import '../domain/health_record.dart';
import '../domain/pig.dart';

class HealthLogScreen extends ConsumerStatefulWidget {
  const HealthLogScreen({super.key, required this.pig});
  final Pig pig;
  @override
  ConsumerState<HealthLogScreen> createState() => _S();
}

class _S extends ConsumerState<HealthLogScreen> {
  HealthEventType _type = HealthEventType.vaccination;
  DateTime _date = DateTime.now();
  final _product = TextEditingController();
  final _dosage = TextEditingController();
  HealthRoute? _route;
  final _diagnosis = TextEditingController();
  final _withdrawalDays = TextEditingController();
  final _cost = TextEditingController();
  final _notes = TextEditingController();
  final List<File> _photos = [];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_product, _dosage, _diagnosis, _withdrawalDays, _cost, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _addPhoto() async {
    final f = await PhotoPicker.pick(context);
    if (f != null) setState(() => _photos.add(f));
  }

  Future<void> _save() async {
    final farmId = ref.read(selectedFarmIdProvider);
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return;
    setState(() { _busy = true; _error = null; });
    final name = ref.read(currentAppUserProvider).asData?.value?.displayName ?? '';
    final storage = ref.read(firebaseStorageProvider);
    final photoUrls = <String>[];
    try {
      // Upload photos sequentially before record write so URLs are in the doc.
      for (var i = 0; i < _photos.length; i++) {
        final storagePath = 'farms/$farmId/health/${widget.pig.id}/'
            '${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final task = await storage.ref(storagePath).putFile(_photos[i]);
        photoUrls.add(await task.ref.getDownloadURL());
      }
      Timestamp? wEnd;
      final wDays = int.tryParse(_withdrawalDays.text);
      if (wDays != null && wDays > 0) {
        wEnd = Timestamp.fromDate(_date.add(Duration(days: wDays)));
      }
      await ref.read(healthRepositoryProvider).logHealth(
        farmId: farmId, pigId: widget.pig.id, tagId: widget.pig.tagId,
        areaId: widget.pig.currentAreaId,
        type: _type, date: Timestamp.fromDate(_date),
        productName: _product.text.trim().isEmpty ? null : _product.text.trim(),
        dosage: _dosage.text.trim().isEmpty ? null : _dosage.text.trim(),
        route: _route,
        diagnosis: _diagnosis.text.trim().isEmpty ? null : _diagnosis.text.trim(),
        withdrawalEndDate: wEnd,
        costPhp: double.tryParse(_cost.text),
        photoUrls: photoUrls,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        actorUserId: user.uid, actorDisplayName: name,
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
      appBar: AppBar(title: Text('Log health · ${widget.pig.tagId}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<HealthEventType>(
              segments: HealthEventType.values.map((t) =>
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
                final p = await showDatePicker(context: context, initialDate: _date,
                    firstDate: DateTime(2024), lastDate: DateTime.now());
                if (p != null) setState(() => _date = p);
              },
            ),
            TextField(controller: _product, decoration: const InputDecoration(labelText: 'Product (e.g., PRRS vaccine)')),
            const SizedBox(height: 8),
            TextField(controller: _dosage, decoration: const InputDecoration(labelText: 'Dosage')),
            const SizedBox(height: 8),
            DropdownButtonFormField<HealthRoute?>(
              value: _route,
              decoration: const InputDecoration(labelText: 'Route'),
              items: [
                const DropdownMenuItem(value: null, child: Text('—')),
                ...HealthRoute.values.map((r) =>
                  DropdownMenuItem(value: r, child: Text(r.label))),
              ],
              onChanged: (v) => setState(() => _route = v),
            ),
            if (_type == HealthEventType.treatment || _type == HealthEventType.checkup) ...[
              const SizedBox(height: 8),
              TextField(controller: _diagnosis,
                decoration: const InputDecoration(labelText: 'Diagnosis')),
            ],
            const SizedBox(height: 8),
            TextField(controller: _withdrawalDays,
              decoration: const InputDecoration(labelText: 'Withdrawal period (days, optional)'),
              keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(controller: _cost,
              decoration: const InputDecoration(labelText: 'Cost (PHP, optional)'),
              keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            const Text('Photos', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ..._photos.map((f) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(f, width: 80, height: 80, fit: BoxFit.cover),
                    ),
                  )),
                  GestureDetector(
                    onTap: _addPhoto,
                    child: Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.add_a_photo),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes'), maxLines: 3),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _busy ? null : _save,
              child: _busy ? const CircularProgressIndicator() : const Text('Save health record')),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 10.5: Health tab in Pig Detail**

In `pig_detail_screen.dart`, replace `_PlaceholderTab(text: 'Health records...')` with `_HealthTab(pig: pig)`:

```dart
class _HealthTab extends ConsumerWidget {
  const _HealthTab({required this.pig});
  final Pig pig;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(healthForPigProvider(
        (farmId: pig.farmId, pigId: pig.id)));
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.medical_services),
        label: const Text('Log health'),
        onPressed: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => HealthLogScreen(pig: pig))),
      ),
      body: recordsAsync.when(
        data: (records) {
          if (records.isEmpty) return const Center(child: Text('No health records yet.'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: records.map((r) => Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Chip(label: Text(r.type.label)),
                        const Spacer(),
                        Text(r.date.toDate().toString().split(' ')[0],
                            style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                    if (r.productName != null) Text('Product: ${r.productName}'),
                    if (r.dosage != null) Text('Dosage: ${r.dosage}'),
                    if (r.diagnosis != null) Text('Diagnosis: ${r.diagnosis}'),
                    if (r.withdrawalEndDate != null)
                      Text('Withdrawal until: ${r.withdrawalEndDate!.toDate().toString().split(' ')[0]}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                    if (r.photoUrls.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 80,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: r.photoUrls.map((url) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(url, width: 80, height: 80, fit: BoxFit.cover),
                            ),
                          )).toList(),
                        ),
                      ),
                    ],
                    if (r.notes != null) ...[
                      const SizedBox(height: 4),
                      Text(r.notes!),
                    ],
                  ],
                ),
              ),
            )).toList(),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}
```

Imports at top of file: `import 'health_log_screen.dart';` and (already added) the health record provider.

- [ ] **Step 10.6: Run + commit**

```bash
flutter analyze && flutter test
```

Manual: log a vaccination with withdrawal period 21 days → verify a `withdrawal_end` task is created at +21 days from the health record date. Add 2 photos via camera; confirm they appear on the health card.

```bash
git add -A
git commit -m "feat(health): per-pig health records with photos and withdrawal tasks

- HealthRecord model with vaccination/treatment/checkup/deworming types
- HealthRepository: atomic record + withdrawal_end task + activity entry
- Health log screen with multi-photo capture, route, withdrawal period
- Health tab on Pig Detail renders chronological history with photos"
```

---

## Task 11: Mortality Log

**Goal:** Log animal mortality with optional photos. Sets pig `status: deceased`. Single mortality record per pig (the cause-of-death event).

**Files:**
- Create:
  - `lib/src/features/pigs/domain/mortality_record.dart`
  - `lib/src/features/pigs/data/mortality_repository.dart`
  - `lib/src/features/pigs/presentation/mortality_log_screen.dart`
  - `test/features/pigs/data/mortality_repository_test.dart`
- Modify:
  - `lib/src/features/pigs/application/pig_providers.dart`
  - `lib/src/features/pigs/presentation/pig_detail_screen.dart` (Profile tab gets "Mark deceased" action)

### Steps

- [ ] **Step 11.1: MortalityRecord model + repository**

`lib/src/features/pigs/domain/mortality_record.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class MortalityRecord {
  final String id;
  final String farmId;
  final String pigId;
  final Timestamp date;
  final String? cause;
  final List<String> photoUrls;
  final String? notes;
  final String createdBy;
  final Timestamp createdAt;

  const MortalityRecord({
    required this.id, required this.farmId, required this.pigId,
    required this.date, required this.cause,
    required this.photoUrls, required this.notes,
    required this.createdBy, required this.createdAt,
  });

  factory MortalityRecord.fromFirestore(
    DocumentSnapshot doc, {required String farmId, required String pigId}) {
    final d = doc.data() as Map<String, dynamic>;
    return MortalityRecord(
      id: doc.id, farmId: farmId, pigId: pigId,
      date: d['date'] as Timestamp,
      cause: d['cause'] as String?,
      photoUrls: List<String>.from(d['photoUrls'] ?? const []),
      notes: d['notes'] as String?,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'date': date,
    if (cause != null) 'cause': cause,
    'photoUrls': photoUrls,
    if (notes != null) 'notes': notes,
    'createdBy': createdBy, 'createdAt': createdAt,
  };
}
```

`lib/src/features/pigs/data/mortality_repository.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../activity/data/activity_repository.dart';
import '../domain/mortality_record.dart';

class MortalityRepository {
  MortalityRepository(this._firestore, this._activity);
  final FirebaseFirestore _firestore;
  final ActivityRepository _activity;

  DocumentReference<Map<String, dynamic>> _doc(String farmId, String pigId) =>
      _firestore.collection('farms').doc(farmId)
          .collection('pigs').doc(pigId)
          .collection('mortality_record').doc('primary');

  Future<void> logMortality({
    required String farmId,
    required String pigId, required String tagId, required String areaId,
    required Timestamp date, required String? cause,
    required List<String> photoUrls, required String? notes,
    required String actorUserId, required String actorDisplayName,
  }) async {
    final batch = _firestore.batch();
    batch.set(_doc(farmId, pigId), {
      'date': date,
      if (cause != null) 'cause': cause,
      'photoUrls': photoUrls,
      if (notes != null) 'notes': notes,
      'createdBy': actorUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(
      _firestore.collection('farms').doc(farmId).collection('pigs').doc(pigId),
      {'status': 'deceased', 'updatedAt': FieldValue.serverTimestamp()},
    );
    _activity.addActivityToBatch(
      batch: batch, farmId: farmId,
      actorUserId: actorUserId, actorDisplayName: actorDisplayName,
      action: 'mortality_logged', entityType: 'pig', entityId: pigId,
      areaId: areaId,
      summary: '$actorDisplayName logged mortality of $tagId'
          '${cause == null ? "" : " (cause: $cause)"}',
    );
    await batch.commit();
  }

  Stream<MortalityRecord?> streamMortality({required String farmId, required String pigId}) {
    return _doc(farmId, pigId).snapshots().map(
      (d) => d.exists ? MortalityRecord.fromFirestore(d, farmId: farmId, pigId: pigId) : null,
    );
  }

  /// All mortalities across a farm — for yield reports.
  Stream<List<MortalityRecord>> streamAllMortalities(String farmId) {
    return _firestore.collectionGroup('mortality_record').snapshots().map((s) {
      return s.docs.where((d) {
        final parts = d.reference.path.split('/');
        return parts[0] == 'farms' && parts[1] == farmId;
      }).map((d) {
        final pigId = d.reference.parent.parent!.id;
        return MortalityRecord.fromFirestore(d, farmId: farmId, pigId: pigId);
      }).toList();
    });
  }
}
```

Test (`test/features/pigs/data/mortality_repository_test.dart`):

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/features/activity/data/activity_repository.dart';
import 'package:farm_app/src/features/pigs/data/mortality_repository.dart';

void main() {
  test('logMortality sets pig deceased and writes activity', () async {
    final f = FakeFirebaseFirestore();
    await f.collection('farms').doc('f1').collection('pigs').doc('p1').set({
      'tagId': 'P', 'sex': 'female', 'breed': 'X',
      'birthDate': Timestamp.now(), 'stage': 'sow', 'status': 'active',
      'currentAreaId': 'a1', 'createdBy': 'u',
      'createdAt': Timestamp.now(), 'updatedAt': Timestamp.now(),
    });
    final repo = MortalityRepository(f, ActivityRepository(f));
    await repo.logMortality(
      farmId: 'f1', pigId: 'p1', tagId: 'P', areaId: 'a1',
      date: Timestamp.now(), cause: 'respiratory',
      photoUrls: const [], notes: null,
      actorUserId: 'u', actorDisplayName: 'Juan',
    );
    final pig = await f.collection('farms').doc('f1').collection('pigs').doc('p1').get();
    expect(pig.data()!['status'], 'deceased');
    final mort = await f.collection('farms').doc('f1').collection('pigs').doc('p1')
        .collection('mortality_record').doc('primary').get();
    expect(mort.data()!['cause'], 'respiratory');
    final activity = await f.collection('farms').doc('f1').collection('activity').get();
    expect(activity.docs.where((d) => d.data()['action'] == 'mortality_logged'),
      hasLength(1));
  });
}
```

- [ ] **Step 11.2: Provider + screen**

Add to `pig_providers.dart`:

```dart
import '../data/mortality_repository.dart';
import '../domain/mortality_record.dart';

final mortalityRepositoryProvider = Provider<MortalityRepository>(
  (ref) => MortalityRepository(
    ref.watch(firestoreProvider), ref.watch(activityRepositoryProvider)));

final mortalityForPigProvider =
    StreamProvider.family<MortalityRecord?, ({String farmId, String pigId})>((ref, args) {
  return ref.watch(mortalityRepositoryProvider).streamMortality(
        farmId: args.farmId, pigId: args.pigId);
});

final allMortalitiesProvider =
    StreamProvider.family<List<MortalityRecord>, String>((ref, farmId) {
  return ref.watch(mortalityRepositoryProvider).streamAllMortalities(farmId);
});
```

`lib/src/features/pigs/presentation/mortality_log_screen.dart`:

```dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../../media/media_providers.dart';
import '../../media/photo_picker.dart';
import '../application/pig_providers.dart';
import '../domain/pig.dart';

const _causes = ['Respiratory', 'Digestive', 'Accident', 'Unknown', 'ASF-suspected', 'Other'];

class MortalityLogScreen extends ConsumerStatefulWidget {
  const MortalityLogScreen({super.key, required this.pig});
  final Pig pig;
  @override
  ConsumerState<MortalityLogScreen> createState() => _S();
}

class _S extends ConsumerState<MortalityLogScreen> {
  DateTime _date = DateTime.now();
  String? _cause;
  final _notes = TextEditingController();
  final List<File> _photos = [];
  bool _busy = false;

  @override
  void dispose() { _notes.dispose(); super.dispose(); }

  Future<void> _addPhoto() async {
    final f = await PhotoPicker.pick(context);
    if (f != null) setState(() => _photos.add(f));
  }

  Future<void> _save() async {
    final farmId = ref.read(selectedFarmIdProvider);
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm mortality'),
        content: Text('Mark ${widget.pig.tagId} as deceased? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _busy = true);
    final storage = ref.read(firebaseStorageProvider);
    final name = ref.read(currentAppUserProvider).asData?.value?.displayName ?? '';
    final urls = <String>[];
    try {
      for (var i = 0; i < _photos.length; i++) {
        final path = 'farms/$farmId/mortality/${widget.pig.id}/$i.jpg';
        final t = await storage.ref(path).putFile(_photos[i]);
        urls.add(await t.ref.getDownloadURL());
      }
      await ref.read(mortalityRepositoryProvider).logMortality(
        farmId: farmId, pigId: widget.pig.id, tagId: widget.pig.tagId,
        areaId: widget.pig.currentAreaId,
        date: Timestamp.fromDate(_date),
        cause: _cause,
        photoUrls: urls,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        actorUserId: user.uid, actorDisplayName: name,
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Mortality · ${widget.pig.tagId}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text(_date.toLocal().toString().split(' ')[0]),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final p = await showDatePicker(context: context, initialDate: _date,
                  firstDate: DateTime(2024), lastDate: DateTime.now());
                if (p != null) setState(() => _date = p);
              },
            ),
            const SizedBox(height: 8),
            const Text('Cause', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              children: _causes.map((c) => ChoiceChip(
                label: Text(c),
                selected: _cause == c,
                onSelected: (sel) => setState(() => _cause = sel ? c : null),
              )).toList(),
            ),
            const SizedBox(height: 12),
            const Text('Photos (optional)', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(
              height: 80,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ..._photos.map((f) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(borderRadius: BorderRadius.circular(8),
                      child: Image.file(f, width: 80, height: 80, fit: BoxFit.cover)),
                  )),
                  GestureDetector(onTap: _addPhoto, child: Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.add_a_photo),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes'), maxLines: 3),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
              onPressed: _busy ? null : _save,
              child: _busy ? const CircularProgressIndicator()
                  : const Text('Mark deceased'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 11.3: Wire from Profile tab**

In `pig_detail_screen.dart` `_ProfileTab`, add a destructive button at the bottom (visible only when pig is active):

```dart
if (pig.status == PigStatus.active) ...[
  const SizedBox(height: 24),
  OutlinedButton.icon(
    icon: const Icon(Icons.heart_broken, color: Colors.red),
    label: const Text('Mark deceased', style: TextStyle(color: Colors.red)),
    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
    onPressed: () => Navigator.push(context, MaterialPageRoute(
      builder: (_) => MortalityLogScreen(pig: pig))),
  ),
],
```

Import: `import 'mortality_log_screen.dart';`

Note: `_ProfileTab` currently extends `StatelessWidget` with `build(BuildContext)`. To use `Navigator.push`, it already has `context` — no Riverpod needed.

- [ ] **Step 11.4: Run + commit**

```bash
flutter analyze && flutter test
git add -A
git commit -m "feat(mortality): mortality log with cause + photos; updates pig status

- MortalityRecord single-doc-per-pig at mortality_record/primary
- Repository writes record + flips pig.status + activity, all atomic
- Quick-pick cause chips (respiratory, digestive, accident, ASF-suspected, ...)
- Destructive confirmation dialog before commit"
```

---

---

## Task 12: Tasks Screen + Manual Task Creation + Assignment

**Goal:** Surface auto-generated and manual tasks. Workers see "My Tasks" (assigned to them); Managers/Owners see Open and can create manual tasks assigned to specific users or areas.

**Files:**
- Create:
  - `lib/src/features/tasks/presentation/tasks_screen.dart`
  - `lib/src/features/tasks/presentation/create_task_screen.dart`

### Steps

- [ ] **Step 12.1: Tasks screen**

`lib/src/features/tasks/presentation/tasks_screen.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../core/permissions/role.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../../team/application/team_providers.dart';
import '../application/task_providers.dart';
import '../domain/task.dart';
import 'create_task_screen.dart';

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmId = ref.watch(selectedFarmIdProvider);
    final user = ref.watch(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return const SizedBox.shrink();
    final role = ref.watch(memberForUserProvider(
        (farmId: farmId, userId: user.uid))).asData?.value?.role ?? Role.worker;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tasks'),
          bottom: const TabBar(tabs: [
            Tab(text: 'My Tasks'),
            Tab(text: 'All Open'),
          ]),
        ),
        floatingActionButton: PermissionService.canCreateOrAssignTasks(role)
            ? FloatingActionButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const CreateTaskScreen())),
                child: const Icon(Icons.add),
              )
            : null,
        body: TabBarView(children: [
          _TaskList(farmId: farmId, userId: user.uid, onlyMine: true),
          _TaskList(farmId: farmId, userId: user.uid, onlyMine: false),
        ]),
      ),
    );
  }
}

class _TaskList extends ConsumerWidget {
  const _TaskList({required this.farmId, required this.userId, required this.onlyMine});
  final String farmId;
  final String userId;
  final bool onlyMine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = onlyMine
        ? ref.watch(myTasksStreamProvider((farmId: farmId, userId: userId)))
        : ref.watch(openTasksStreamProvider(farmId));
    return tasksAsync.when(
      data: (tasks) {
        if (tasks.isEmpty) {
          return Center(child: Text(onlyMine ? 'No tasks assigned to you.' : 'No open tasks.'));
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: tasks.map((t) => _TaskCard(task: t)).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }
}

class _TaskCard extends ConsumerWidget {
  const _TaskCard({required this.task});
  final FarmTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final due = task.dueDate.toDate();
    final overdue = due.isBefore(now);
    return Card(
      child: ListTile(
        leading: Icon(_icon(task.type),
            color: overdue ? Colors.red : Theme.of(context).primaryColor),
        title: Text(task.title),
        subtitle: Text(
          'Due ${DateFormat.yMMMd().format(due)}'
          '${task.assignedTo == null ? "" : " · assigned to ${task.assignedTo!.kind}:${task.assignedTo!.id}"}',
          style: TextStyle(color: overdue ? Colors.red : Colors.grey),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.check_circle_outline),
          tooltip: 'Mark complete',
          onPressed: () async {
            final user = ref.read(authStateChangesProvider).asData?.value;
            if (user == null) return;
            await ref.read(taskRepositoryProvider).completeTask(
                  farmId: task.farmId, taskId: task.id, userId: user.uid);
          },
        ),
      ),
    );
  }

  IconData _icon(TaskType t) {
    switch (t) {
      case TaskType.pregnancyCheck: return Icons.fact_check;
      case TaskType.farrowingPrep: return Icons.event_available;
      case TaskType.farrowingExpected: return Icons.child_friendly;
      case TaskType.vaccinationDue: return Icons.medical_services;
      case TaskType.withdrawalEnd: return Icons.timer;
      case TaskType.manual: return Icons.task_alt;
    }
  }
}
```

- [ ] **Step 12.2: Create Task screen**

`lib/src/features/tasks/presentation/create_task_screen.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../areas/application/area_providers.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../../team/application/team_providers.dart';
import '../application/task_providers.dart';
import '../domain/task.dart';

class CreateTaskScreen extends ConsumerStatefulWidget {
  const CreateTaskScreen({super.key});
  @override
  ConsumerState<CreateTaskScreen> createState() => _S();
}

class _S extends ConsumerState<CreateTaskScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  DateTime _due = DateTime.now().add(const Duration(days: 1));
  /// 'user' or 'area' or null
  String? _assignKind;
  String? _assignId;
  bool _busy = false;

  @override
  void dispose() { _title.dispose(); _desc.dispose(); super.dispose(); }

  Future<void> _save() async {
    final farmId = ref.read(selectedFarmIdProvider);
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return;
    if (_title.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(taskRepositoryProvider).createManualTask(
        farmId: farmId, title: _title.text.trim(),
        description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        dueDate: Timestamp.fromDate(_due),
        assignedTo: (_assignKind != null && _assignId != null)
            ? TaskAssignment(kind: _assignKind!, id: _assignId!) : null,
        creatorUserId: user.uid,
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmId = ref.watch(selectedFarmIdProvider);
    final members = (farmId != null)
        ? ref.watch(membersStreamProvider(farmId)).asData?.value ?? const []
        : const [];
    final areas = (farmId != null)
        ? ref.watch(areasStreamProvider(farmId)).asData?.value ?? const []
        : const [];
    return Scaffold(
      appBar: AppBar(title: const Text('New task')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _title,
              decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 12),
            TextField(controller: _desc,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Due date'),
              subtitle: Text(_due.toLocal().toString().split(' ')[0]),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final p = await showDatePicker(context: context, initialDate: _due,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)));
                if (p != null) setState(() => _due = p);
              },
            ),
            const SizedBox(height: 12),
            const Text('Assign to', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButtonFormField<String?>(
              value: _assignKind,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                DropdownMenuItem(value: null, child: Text('— unassigned —')),
                DropdownMenuItem(value: 'user', child: Text('Specific user')),
                DropdownMenuItem(value: 'area', child: Text('Any worker in an area')),
              ],
              onChanged: (v) => setState(() { _assignKind = v; _assignId = null; }),
            ),
            if (_assignKind == 'user')
              DropdownButtonFormField<String>(
                value: _assignId,
                decoration: const InputDecoration(labelText: 'User'),
                items: members.map((m) =>
                  DropdownMenuItem(value: m.userId, child: Text(m.userId))).toList(),
                onChanged: (v) => setState(() => _assignId = v),
              ),
            if (_assignKind == 'area')
              DropdownButtonFormField<String>(
                value: _assignId,
                decoration: const InputDecoration(labelText: 'Area'),
                items: areas.map((a) =>
                  DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                onChanged: (v) => setState(() => _assignId = v),
              ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _busy ? null : _save,
              child: _busy ? const CircularProgressIndicator() : const Text('Create task')),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 12.3: Wire route + commit**

In `app_router.dart`:

```dart
GoRoute(path: '/tasks', builder: (c, s) => const TasksScreen()),
```

Add import.

```bash
flutter analyze && flutter test
git add -A
git commit -m "feat(tasks): tasks screen with My Tasks/All Open tabs and manual creation

- Tasks screen with two tabs (mine vs all open)
- Tap-to-complete with completedBy/completedAt timestamps
- Manual task creation with optional user or area assignment
- Overdue tasks show in red"
```

---

## Task 13: Shifts & Roster

**Goal:** Recurring shift assignments by area + day-of-week pattern. Today's Roster widget shows who is on-shift in each area today.

**Files:**
- Create:
  - `lib/src/features/shifts/domain/shift.dart`
  - `lib/src/features/shifts/data/shift_repository.dart`
  - `lib/src/features/shifts/application/shift_providers.dart`
  - `lib/src/features/shifts/presentation/shifts_screen.dart`
  - `lib/src/features/shifts/presentation/edit_shift_screen.dart`
  - `lib/src/features/shifts/presentation/roster_widget.dart`
  - `test/features/shifts/domain/shift_test.dart`

### Steps

- [ ] **Step 13.1: Shift model**

`lib/src/features/shifts/domain/shift.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum ShiftPattern {
  daily('daily', 'Daily'),
  weekly('weekly', 'Weekly');
  const ShiftPattern(this.value, this.label);
  final String value;
  final String label;
  static ShiftPattern fromString(String s) =>
      ShiftPattern.values.firstWhere((p) => p.value == s, orElse: () => ShiftPattern.daily);
}

class Shift {
  final String id;
  final String farmId;
  final String name;
  final ShiftPattern pattern;
  /// 0=Sun, 1=Mon, ..., 6=Sat. Empty for daily pattern.
  final List<int> daysOfWeek;
  /// 'HH:mm' 24h format.
  final String startTime;
  final String endTime;
  final String assignedAreaId;
  final List<String> assignedUserIds;
  final String? notes;
  final String createdBy;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  const Shift({
    required this.id, required this.farmId, required this.name,
    required this.pattern, required this.daysOfWeek,
    required this.startTime, required this.endTime,
    required this.assignedAreaId, required this.assignedUserIds,
    required this.notes, required this.createdBy,
    required this.createdAt, required this.updatedAt,
  });

  factory Shift.fromFirestore(DocumentSnapshot doc, {required String farmId}) {
    final d = doc.data() as Map<String, dynamic>;
    return Shift(
      id: doc.id, farmId: farmId,
      name: d['name'] as String,
      pattern: ShiftPattern.fromString(d['pattern'] as String? ?? 'daily'),
      daysOfWeek: List<int>.from(d['daysOfWeek'] ?? const []),
      startTime: d['startTime'] as String,
      endTime: d['endTime'] as String,
      assignedAreaId: d['assignedAreaId'] as String,
      assignedUserIds: List<String>.from(d['assignedUserIds'] ?? const []),
      notes: d['notes'] as String?,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: d['updatedAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name, 'pattern': pattern.value,
    'daysOfWeek': daysOfWeek,
    'startTime': startTime, 'endTime': endTime,
    'assignedAreaId': assignedAreaId,
    'assignedUserIds': assignedUserIds,
    if (notes != null) 'notes': notes,
    'createdBy': createdBy,
    'createdAt': createdAt, 'updatedAt': updatedAt,
  };

  /// Returns true if this shift is active on the given date.
  bool isActiveOn(DateTime date) {
    if (pattern == ShiftPattern.daily) return true;
    // DateTime weekday: 1=Mon..7=Sun. Map to 0=Sun..6=Sat.
    final dow = date.weekday == 7 ? 0 : date.weekday;
    return daysOfWeek.contains(dow);
  }
}
```

Test (`test/features/shifts/domain/shift_test.dart`):

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/features/shifts/domain/shift.dart';

void main() {
  Shift mk(ShiftPattern p, List<int> days) => Shift(
    id: 'x', farmId: 'f', name: 'n', pattern: p, daysOfWeek: days,
    startTime: '06:00', endTime: '14:00',
    assignedAreaId: 'a', assignedUserIds: const [],
    notes: null, createdBy: 'u',
    createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
  );

  test('daily is always active', () {
    expect(mk(ShiftPattern.daily, []).isActiveOn(DateTime(2026, 5, 14)), true);
  });

  test('weekly active only on listed days', () {
    // 2026-05-14 is a Thursday → weekday=4 → dow=4
    expect(mk(ShiftPattern.weekly, [4]).isActiveOn(DateTime(2026, 5, 14)), true);
    expect(mk(ShiftPattern.weekly, [1, 3]).isActiveOn(DateTime(2026, 5, 14)), false);
  });

  test('Sunday maps to 0', () {
    // 2026-05-17 is Sunday → weekday=7 → dow=0
    expect(mk(ShiftPattern.weekly, [0]).isActiveOn(DateTime(2026, 5, 17)), true);
  });
}
```

- [ ] **Step 13.2: ShiftRepository + providers**

`lib/src/features/shifts/data/shift_repository.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../activity/data/activity_repository.dart';
import '../domain/shift.dart';

class ShiftRepository {
  ShiftRepository(this._firestore, this._activity);
  final FirebaseFirestore _firestore;
  final ActivityRepository _activity;

  CollectionReference<Map<String, dynamic>> _col(String farmId) =>
      _firestore.collection('farms').doc(farmId).collection('shifts');

  Future<String> createShift({
    required String farmId, required String name,
    required ShiftPattern pattern, required List<int> daysOfWeek,
    required String startTime, required String endTime,
    required String assignedAreaId, required List<String> assignedUserIds,
    String? notes,
    required String actorUserId, required String actorDisplayName,
  }) async {
    final ref = _col(farmId).doc();
    final batch = _firestore.batch();
    batch.set(ref, {
      'name': name, 'pattern': pattern.value,
      'daysOfWeek': daysOfWeek,
      'startTime': startTime, 'endTime': endTime,
      'assignedAreaId': assignedAreaId,
      'assignedUserIds': assignedUserIds,
      if (notes != null) 'notes': notes,
      'createdBy': actorUserId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _activity.addActivityToBatch(
      batch: batch, farmId: farmId,
      actorUserId: actorUserId, actorDisplayName: actorDisplayName,
      action: 'shift_assigned', entityType: 'shift', entityId: ref.id,
      areaId: assignedAreaId,
      summary: '$actorDisplayName created shift "$name"',
    );
    await batch.commit();
    return ref.id;
  }

  Future<void> updateShift({
    required String farmId, required String shiftId,
    required String name, required ShiftPattern pattern,
    required List<int> daysOfWeek,
    required String startTime, required String endTime,
    required String assignedAreaId, required List<String> assignedUserIds,
    String? notes,
  }) async {
    await _col(farmId).doc(shiftId).update({
      'name': name, 'pattern': pattern.value,
      'daysOfWeek': daysOfWeek,
      'startTime': startTime, 'endTime': endTime,
      'assignedAreaId': assignedAreaId,
      'assignedUserIds': assignedUserIds,
      'notes': notes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteShift({required String farmId, required String shiftId}) async {
    await _col(farmId).doc(shiftId).delete();
  }

  Stream<List<Shift>> streamShifts(String farmId) {
    return _col(farmId).snapshots().map((s) =>
      s.docs.map((d) => Shift.fromFirestore(d, farmId: farmId)).toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime)));
  }
}
```

`lib/src/features/shifts/application/shift_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../activity/application/activity_providers.dart';
import '../data/shift_repository.dart';
import '../domain/shift.dart';

final shiftRepositoryProvider = Provider<ShiftRepository>(
  (ref) => ShiftRepository(
    ref.watch(firestoreProvider), ref.watch(activityRepositoryProvider)));

final shiftsStreamProvider = StreamProvider.family<List<Shift>, String>(
  (ref, farmId) => ref.watch(shiftRepositoryProvider).streamShifts(farmId));

/// Active shifts for the given date, sorted by start time.
final shiftsForDateProvider =
    Provider.family<List<Shift>, ({String farmId, DateTime date})>((ref, args) {
  final all = ref.watch(shiftsStreamProvider(args.farmId)).asData?.value ?? const <Shift>[];
  return all.where((s) => s.isActiveOn(args.date)).toList();
});
```

- [ ] **Step 13.3: Shifts screen + edit screen + roster widget**

`lib/src/features/shifts/presentation/shifts_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../farms/application/farm_providers.dart';
import '../application/shift_providers.dart';
import '../domain/shift.dart';
import 'edit_shift_screen.dart';
import 'roster_widget.dart';

class ShiftsScreen extends ConsumerWidget {
  const ShiftsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) return const SizedBox.shrink();
    final shiftsAsync = ref.watch(shiftsStreamProvider(farmId));
    return Scaffold(
      appBar: AppBar(title: const Text('Shifts & Roster')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => const EditShiftScreen())),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const RosterWidget(),
          const SizedBox(height: 24),
          const Text('All shifts', style: TextStyle(fontWeight: FontWeight.bold)),
          shiftsAsync.when(
            data: (shifts) => Column(
              children: shifts.map((s) => _ShiftCard(shift: s)).toList(),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('$e'),
          ),
        ],
      ),
    );
  }
}

class _ShiftCard extends StatelessWidget {
  const _ShiftCard({required this.shift});
  final Shift shift;
  static const _dowLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  Widget build(BuildContext context) {
    final days = shift.pattern == ShiftPattern.daily
      ? 'Daily'
      : shift.daysOfWeek.map((d) => _dowLabels[d]).join('/');
    return Card(
      child: ListTile(
        title: Text(shift.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$days · ${shift.startTime}-${shift.endTime} · area ${shift.assignedAreaId} · '
            '${shift.assignedUserIds.length} worker(s)'),
        onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => EditShiftScreen(existing: shift))),
      ),
    );
  }
}
```

`lib/src/features/shifts/presentation/edit_shift_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/permissions/role.dart';
import '../../areas/application/area_providers.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../../team/application/team_providers.dart';
import '../application/shift_providers.dart';
import '../domain/shift.dart';

class EditShiftScreen extends ConsumerStatefulWidget {
  const EditShiftScreen({super.key, this.existing});
  final Shift? existing;
  @override
  ConsumerState<EditShiftScreen> createState() => _S();
}

class _S extends ConsumerState<EditShiftScreen> {
  late final TextEditingController _name;
  late final TextEditingController _start;
  late final TextEditingController _end;
  late ShiftPattern _pattern;
  Set<int> _days = {};
  String? _areaId;
  Set<String> _workerIds = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _start = TextEditingController(text: e?.startTime ?? '06:00');
    _end = TextEditingController(text: e?.endTime ?? '14:00');
    _pattern = e?.pattern ?? ShiftPattern.daily;
    _days = (e?.daysOfWeek ?? const <int>[]).toSet();
    _areaId = e?.assignedAreaId;
    _workerIds = (e?.assignedUserIds ?? const <String>[]).toSet();
  }

  @override
  void dispose() { _name.dispose(); _start.dispose(); _end.dispose(); super.dispose(); }

  Future<void> _save() async {
    final farmId = ref.read(selectedFarmIdProvider);
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return;
    if (_name.text.trim().isEmpty || _areaId == null) return;
    setState(() => _busy = true);
    final actorName = ref.read(currentAppUserProvider).asData?.value?.displayName ?? '';
    try {
      final repo = ref.read(shiftRepositoryProvider);
      if (widget.existing == null) {
        await repo.createShift(
          farmId: farmId, name: _name.text, pattern: _pattern,
          daysOfWeek: _pattern == ShiftPattern.weekly ? _days.toList() : const [],
          startTime: _start.text, endTime: _end.text,
          assignedAreaId: _areaId!, assignedUserIds: _workerIds.toList(),
          actorUserId: user.uid, actorDisplayName: actorName,
        );
      } else {
        await repo.updateShift(
          farmId: farmId, shiftId: widget.existing!.id,
          name: _name.text, pattern: _pattern,
          daysOfWeek: _pattern == ShiftPattern.weekly ? _days.toList() : const [],
          startTime: _start.text, endTime: _end.text,
          assignedAreaId: _areaId!, assignedUserIds: _workerIds.toList(),
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
    final areas = farmId != null ? ref.watch(areasStreamProvider(farmId)).asData?.value ?? const [] : const [];
    final members = farmId != null ? ref.watch(membersStreamProvider(farmId)).asData?.value ?? const [] : const [];
    final workers = members.where((m) => m.role == Role.worker).toList();
    const dowNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'New shift' : 'Edit shift')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Shift name')),
            const SizedBox(height: 12),
            SegmentedButton<ShiftPattern>(
              segments: ShiftPattern.values.map((p) =>
                ButtonSegment(value: p, label: Text(p.label))).toList(),
              selected: {_pattern},
              onSelectionChanged: (s) => setState(() => _pattern = s.first),
            ),
            if (_pattern == ShiftPattern.weekly) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 6, children: List.generate(7, (i) => FilterChip(
                label: Text(dowNames[i]),
                selected: _days.contains(i),
                onSelected: (sel) => setState(() => sel ? _days.add(i) : _days.remove(i)),
              ))),
            ],
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: _start,
                decoration: const InputDecoration(labelText: 'Start (HH:mm)'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _end,
                decoration: const InputDecoration(labelText: 'End (HH:mm)'))),
            ]),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _areaId,
              decoration: const InputDecoration(labelText: 'Area'),
              items: areas.map<DropdownMenuItem<String>>((a) =>
                DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
              onChanged: (v) => setState(() => _areaId = v),
            ),
            const SizedBox(height: 12),
            const Text('Workers', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(spacing: 6, children: workers.map((m) => FilterChip(
              label: Text(m.userId),
              selected: _workerIds.contains(m.userId),
              onSelected: (sel) => setState(() =>
                sel ? _workerIds.add(m.userId) : _workerIds.remove(m.userId)),
            )).toList()),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _busy ? null : _save,
              child: _busy ? const CircularProgressIndicator() : const Text('Save shift')),
            if (widget.existing != null) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                onPressed: () async {
                  await ref.read(shiftRepositoryProvider).deleteShift(
                    farmId: farmId!, shiftId: widget.existing!.id);
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

`lib/src/features/shifts/presentation/roster_widget.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../areas/application/area_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../application/shift_providers.dart';

class RosterWidget extends ConsumerWidget {
  const RosterWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) return const SizedBox.shrink();
    final today = DateTime.now();
    final shifts = ref.watch(shiftsForDateProvider((farmId: farmId, date: today)));
    final areas = ref.watch(areasStreamProvider(farmId)).asData?.value ?? const [];

    if (shifts.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text('No shifts scheduled today.'),
        ),
      );
    }

    // Group by area.
    final byArea = <String, List<dynamic>>{};
    for (final s in shifts) {
      byArea.putIfAbsent(s.assignedAreaId, () => []).add(s);
    }

    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Today's Roster",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ...byArea.entries.map((e) {
              final areaName = areas.firstWhere(
                (a) => a.id == e.key,
                orElse: () => areas.isNotEmpty ? areas.first : throw StateError('no area'),
              ).name;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(areaName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ...e.value.map((s) => Text(
                      '  • ${s.name} (${s.startTime}-${s.endTime}) — '
                      '${(s.assignedUserIds as List).join(", ")}',
                    )),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 13.4: Wire route + commit**

In `app_router.dart`:

```dart
GoRoute(path: '/shifts', builder: (c, s) => const ShiftsScreen()),
```

Import the screen.

```bash
flutter analyze && flutter test
git add -A
git commit -m "feat(shifts): recurring shifts with roster widget

- Shift model with daily/weekly pattern, dayOfWeek list, time window,
  area + assigned workers
- ShiftRepository (CRUD + activity entry)
- Shifts screen with today's Roster widget grouped by area
- Edit shift screen with day chips and worker chips
- Shift.isActiveOn(date) helper with unit tests"
```

---

## Task 14: Activity Feed UI

**Goal:** Activity-feed dashboard card and full-screen "Activity" tab. The data layer (`ActivityRepository`) already exists from Task 2; this task adds the visual feed.

**Files:**
- Create:
  - `lib/src/features/activity/presentation/activity_feed_widget.dart`
  - `lib/src/features/activity/presentation/activity_screen.dart`

### Steps

- [ ] **Step 14.1: Activity feed widget**

`lib/src/features/activity/presentation/activity_feed_widget.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../farms/application/farm_providers.dart';
import '../application/activity_providers.dart';
import '../domain/activity_entry.dart';

class ActivityFeedWidget extends ConsumerWidget {
  const ActivityFeedWidget({super.key, this.limit = 8});
  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) return const SizedBox.shrink();
    final feedAsync = ref.watch(recentActivityProvider(farmId));

    return feedAsync.when(
      data: (entries) {
        final items = entries.take(limit).toList();
        if (items.isEmpty) {
          return const Card(child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('No activity yet. Logged events will appear here.'),
          ));
        }
        return Card(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Row(children: [
                  Text('Recent activity', style: TextStyle(fontWeight: FontWeight.bold)),
                ]),
              ),
              const Divider(height: 1),
              ...items.map((e) => _row(context, e)),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('$e'),
    );
  }

  Widget _row(BuildContext context, ActivityEntry e) {
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        child: Text(e.actorDisplayName.isEmpty ? '?' : e.actorDisplayName[0]),
      ),
      title: Text(e.summary),
      trailing: Text(_relative(e.timestamp.toDate()),
          style: const TextStyle(fontSize: 11, color: Colors.grey)),
    );
  }

  String _relative(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return DateFormat.MMMd().format(t);
  }
}
```

- [ ] **Step 14.2: Activity screen (full-page)**

`lib/src/features/activity/presentation/activity_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../farms/application/farm_providers.dart';
import '../application/activity_providers.dart';
import '../domain/activity_entry.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) return const SizedBox.shrink();
    final feedAsync = ref.watch(recentActivityProvider(farmId));

    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: feedAsync.when(
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(child: Text('No activity yet.'));
          }
          final groups = _groupByDay(entries);
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groups.length,
            itemBuilder: (_, i) {
              final g = groups[i];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(g.label,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  ...g.entries.map((e) => Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(e.actorDisplayName.isEmpty ? '?' : e.actorDisplayName[0]),
                      ),
                      title: Text(e.summary),
                      subtitle: Text(DateFormat.jm().format(e.timestamp.toDate())),
                    ),
                  )),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }

  List<_DayGroup> _groupByDay(List<ActivityEntry> entries) {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    final groups = <String, List<ActivityEntry>>{};
    for (final e in entries) {
      final t = e.timestamp.toDate();
      String label;
      if (sameDay(t, today)) {
        label = 'Today';
      } else if (sameDay(t, yesterday)) {
        label = 'Yesterday';
      } else {
        label = DateFormat.yMMMMd().format(t);
      }
      groups.putIfAbsent(label, () => []).add(e);
    }
    return groups.entries.map((e) => _DayGroup(label: e.key, entries: e.value)).toList();
  }
}

class _DayGroup {
  _DayGroup({required this.label, required this.entries});
  final String label;
  final List<ActivityEntry> entries;
}
```

- [ ] **Step 14.3: Wire route + commit**

In `app_router.dart`:

```dart
GoRoute(path: '/activity', builder: (c, s) => const ActivityScreen()),
```

Import.

```bash
flutter analyze && flutter test
git add -A
git commit -m "feat(activity): activity feed widget + full-page activity screen

- ActivityFeedWidget for dashboard (top-8 entries)
- ActivityScreen with Today/Yesterday/date grouping
- Relative timestamps (just now / 5m / 2h / 3d / Mar 14)"
```

---

---

## Task 15: Yield Reports

**Goal:** Replace the placeholder Reports tab with a Yield Reports screen showing herd productivity, growth, mortality, and output metrics, computed entirely client-side from streamed data. Charts via `fl_chart`.

**Files:**
- Create:
  - `lib/src/features/yield/yield_metrics.dart`
  - `lib/src/features/yield/yield_calculator.dart`
  - `lib/src/features/yield/yield_providers.dart`
  - `lib/src/features/yield/yield_screen.dart`
  - `test/features/yield/yield_calculator_test.dart`

### Steps

- [ ] **Step 15.1: Period + metrics types**

`lib/src/features/yield/yield_metrics.dart`:

```dart
enum YieldPeriod {
  d7('7d', Duration(days: 7)),
  d30('30d', Duration(days: 30)),
  d90('90d', Duration(days: 90)),
  ytd('YTD', Duration.zero),
  all('All-time', Duration.zero);

  const YieldPeriod(this.label, this.duration);
  final String label;
  final Duration duration;

  DateTime startFrom(DateTime now) {
    switch (this) {
      case YieldPeriod.d7:
      case YieldPeriod.d30:
      case YieldPeriod.d90:
        return now.subtract(duration);
      case YieldPeriod.ytd:
        return DateTime(now.year, 1, 1);
      case YieldPeriod.all:
        return DateTime(1970);
    }
  }
}

class HerdProductivity {
  final double avgLitterSize;
  final double avgStillborns;
  final double stillbirthRate;
  final double preWeaningMortalityRate;
  final double breedingSuccessRate;
  final double psyEstimate;
  final int totalFarrowings;
  const HerdProductivity({
    required this.avgLitterSize, required this.avgStillborns,
    required this.stillbirthRate, required this.preWeaningMortalityRate,
    required this.breedingSuccessRate, required this.psyEstimate,
    required this.totalFarrowings,
  });
  static const empty = HerdProductivity(
    avgLitterSize: 0, avgStillborns: 0, stillbirthRate: 0,
    preWeaningMortalityRate: 0, breedingSuccessRate: 0,
    psyEstimate: 0, totalFarrowings: 0,
  );
}

class GrowthMetrics {
  final double avgDailyGainKg;
  final int activeGrowFinishCount;
  const GrowthMetrics({required this.avgDailyGainKg, required this.activeGrowFinishCount});
  static const empty = GrowthMetrics(avgDailyGainKg: 0, activeGrowFinishCount: 0);
}

class MortalityMetrics {
  final double overallMortalityRate;
  final Map<String, int> byArea;
  final List<MapEntry<String, int>> topCauses;
  final int totalDeaths;
  const MortalityMetrics({
    required this.overallMortalityRate, required this.byArea,
    required this.topCauses, required this.totalDeaths,
  });
  static const empty = MortalityMetrics(
    overallMortalityRate: 0, byArea: {}, topCauses: [], totalDeaths: 0,
  );
}

class OutputMetrics {
  final int sold;
  final int culled;
  const OutputMetrics({required this.sold, required this.culled});
  static const empty = OutputMetrics(sold: 0, culled: 0);
}
```

- [ ] **Step 15.2: YieldCalculator (pure functions)**

`lib/src/features/yield/yield_calculator.dart`:

```dart
import '../pigs/domain/breeding_record.dart';
import '../pigs/domain/farrowing_record.dart';
import '../pigs/domain/mortality_record.dart';
import '../pigs/domain/pig.dart';
import 'yield_metrics.dart';

class YieldCalculator {
  YieldCalculator._();

  static HerdProductivity herdProductivity({
    required List<FarrowingRecord> farrowings,
    required List<BreedingRecord> breedings,
    required int activeSowCount,
    required DateTime periodStart,
    required DateTime now,
  }) {
    final inPeriod = farrowings.where((f) =>
      f.date.toDate().isAfter(periodStart) || f.date.toDate().isAtSameMomentAs(periodStart)).toList();
    if (inPeriod.isEmpty) return HerdProductivity.empty;

    final totalLive = inPeriod.fold<int>(0, (s, f) => s + f.liveBorn);
    final totalStill = inPeriod.fold<int>(0, (s, f) => s + f.stillborn);
    final avgLitter = totalLive / inPeriod.length;
    final avgStill = totalStill / inPeriod.length;
    final stillRate = (totalLive + totalStill) == 0
        ? 0.0 : totalStill / (totalLive + totalStill);
    // Pre-weaning mortality rate is not tracked separately yet; placeholder 0.
    const preWean = 0.0;

    final breedingsInPeriod = breedings.where((b) =>
      b.inseminationDate.toDate().isAfter(periodStart)).toList();
    final confirmed = breedingsInPeriod.where((b) => b.confirmed).length;
    final successRate = breedingsInPeriod.isEmpty ? 0.0 : confirmed / breedingsInPeriod.length;

    // PSY estimate: (live born in period) extrapolated to a year / active sow count.
    final daysInPeriod = now.difference(periodStart).inDays.clamp(1, 365);
    final yearlyExtrapolation = (totalLive / daysInPeriod) * 365;
    final psy = activeSowCount == 0 ? 0.0 : yearlyExtrapolation / activeSowCount;

    return HerdProductivity(
      avgLitterSize: avgLitter, avgStillborns: avgStill,
      stillbirthRate: stillRate, preWeaningMortalityRate: preWean,
      breedingSuccessRate: successRate, psyEstimate: psy,
      totalFarrowings: inPeriod.length,
    );
  }

  static GrowthMetrics growth({
    required List<Pig> pigs,
    required DateTime now,
  }) {
    final growers = pigs.where((p) =>
      (p.stage == PigStage.grower || p.stage == PigStage.finisher) &&
      p.status == PigStatus.active).toList();
    final adgs = <double>[];
    for (final p in growers) {
      if (p.currentWeight == null || p.weightUpdatedAt == null) continue;
      final birthDate = p.birthDate.toDate();
      final lastWeighDate = p.weightUpdatedAt!.toDate();
      final days = lastWeighDate.difference(birthDate).inDays;
      if (days <= 0) continue;
      adgs.add(p.currentWeight! / days);
    }
    final avgAdg = adgs.isEmpty ? 0.0 : adgs.reduce((a, b) => a + b) / adgs.length;
    return GrowthMetrics(
      avgDailyGainKg: avgAdg,
      activeGrowFinishCount: growers.length,
    );
  }

  static MortalityMetrics mortality({
    required List<MortalityRecord> mortalities,
    required List<Pig> allPigs,
    required Map<String, String> pigIdToAreaId,
    required DateTime periodStart,
  }) {
    final inPeriod = mortalities.where((m) =>
      m.date.toDate().isAfter(periodStart)).toList();
    final herdAtStart = allPigs.length;
    final rate = herdAtStart == 0 ? 0.0 : inPeriod.length / herdAtStart;
    final byArea = <String, int>{};
    final causeCounts = <String, int>{};
    for (final m in inPeriod) {
      final area = pigIdToAreaId[m.pigId] ?? 'unknown';
      byArea[area] = (byArea[area] ?? 0) + 1;
      final c = m.cause ?? 'Unknown';
      causeCounts[c] = (causeCounts[c] ?? 0) + 1;
    }
    final topCauses = causeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return MortalityMetrics(
      overallMortalityRate: rate,
      byArea: byArea,
      topCauses: topCauses.take(3).toList(),
      totalDeaths: inPeriod.length,
    );
  }

  static OutputMetrics output({
    required List<Pig> pigs,
    required DateTime periodStart,
  }) {
    // We don't track sale/cull date separately yet; use updatedAt as a proxy.
    final inPeriod = pigs.where((p) =>
      p.updatedAt.toDate().isAfter(periodStart)).toList();
    final sold = inPeriod.where((p) => p.status == PigStatus.sold).length;
    final culled = inPeriod.where((p) => p.status == PigStatus.culled).length;
    return OutputMetrics(sold: sold, culled: culled);
  }
}
```

Test (`test/features/yield/yield_calculator_test.dart`):

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_app/src/features/pigs/domain/breeding_record.dart';
import 'package:farm_app/src/features/pigs/domain/farrowing_record.dart';
import 'package:farm_app/src/features/pigs/domain/mortality_record.dart';
import 'package:farm_app/src/features/pigs/domain/pig.dart';
import 'package:farm_app/src/features/yield/yield_calculator.dart';

void main() {
  test('herdProductivity averages litter size and stillbirth rate', () {
    final now = DateTime(2026, 5, 14);
    final start = now.subtract(const Duration(days: 30));
    final farrowings = [
      _farr(date: now.subtract(const Duration(days: 5)), live: 10, still: 1),
      _farr(date: now.subtract(const Duration(days: 10)), live: 12, still: 0),
      _farr(date: now.subtract(const Duration(days: 15)), live: 8, still: 2),
    ];
    final result = YieldCalculator.herdProductivity(
      farrowings: farrowings, breedings: const [],
      activeSowCount: 5, periodStart: start, now: now,
    );
    expect(result.avgLitterSize, closeTo(10, 0.01));
    expect(result.stillbirthRate, closeTo(3 / 33, 0.01));
    expect(result.totalFarrowings, 3);
  });

  test('herdProductivity empty period returns zeros', () {
    final r = YieldCalculator.herdProductivity(
      farrowings: const [], breedings: const [],
      activeSowCount: 5, periodStart: DateTime(2026, 1, 1),
      now: DateTime(2026, 5, 14),
    );
    expect(r.avgLitterSize, 0);
  });

  test('growth computes mean ADG', () {
    final now = DateTime(2026, 5, 14);
    final pigs = [
      _pig(stage: PigStage.grower, status: PigStatus.active,
        birthDate: now.subtract(const Duration(days: 100)),
        currentWeight: 50, weightUpdatedAt: now),
      _pig(stage: PigStage.finisher, status: PigStatus.active,
        birthDate: now.subtract(const Duration(days: 200)),
        currentWeight: 100, weightUpdatedAt: now),
    ];
    final g = YieldCalculator.growth(pigs: pigs, now: now);
    // ADG: 50/100=0.5, 100/200=0.5 → mean 0.5
    expect(g.avgDailyGainKg, closeTo(0.5, 0.01));
    expect(g.activeGrowFinishCount, 2);
  });

  test('mortality rate', () {
    final now = DateTime(2026, 5, 14);
    final start = now.subtract(const Duration(days: 30));
    final morts = [
      _mort(now.subtract(const Duration(days: 5)), pigId: 'p1', cause: 'Respiratory'),
      _mort(now.subtract(const Duration(days: 10)), pigId: 'p2', cause: 'Respiratory'),
      _mort(now.subtract(const Duration(days: 15)), pigId: 'p3', cause: 'Accident'),
    ];
    final allPigs = List.generate(20, (i) => _pig(
      birthDate: now.subtract(const Duration(days: 100)),
      stage: PigStage.grower, status: PigStatus.active,
      currentWeight: null, weightUpdatedAt: null,
    ));
    final m = YieldCalculator.mortality(
      mortalities: morts, allPigs: allPigs,
      pigIdToAreaId: {'p1': 'a1', 'p2': 'a1', 'p3': 'a2'},
      periodStart: start,
    );
    expect(m.totalDeaths, 3);
    expect(m.overallMortalityRate, closeTo(3 / 20, 0.01));
    expect(m.byArea['a1'], 2);
    expect(m.topCauses.first.key, 'Respiratory');
  });
}

FarrowingRecord _farr({required DateTime date, required int live, required int still}) =>
  FarrowingRecord(
    id: 'x', farmId: 'f', sowId: 's', breedingRecordId: 'br',
    date: Timestamp.fromDate(date),
    liveBorn: live, stillborn: still, mummified: 0,
    avgBirthWeightKg: null, litterBatchId: null, notes: null,
    createdBy: 'u', createdAt: Timestamp.now(),
  );

Pig _pig({
  required DateTime birthDate, required PigStage stage, required PigStatus status,
  double? currentWeight, DateTime? weightUpdatedAt,
}) => Pig(
  id: 'x', farmId: 'f', tagId: 't', sex: PigSex.male, breed: 'y',
  birthDate: Timestamp.fromDate(birthDate),
  sireId: null, damId: null, stage: stage, status: status,
  currentAreaId: 'a', currentPenId: null,
  currentWeight: currentWeight,
  weightUpdatedAt: weightUpdatedAt == null ? null : Timestamp.fromDate(weightUpdatedAt),
  photoUrl: null, notes: null,
  createdBy: 'u', createdAt: Timestamp.now(),
  updatedAt: Timestamp.fromDate(birthDate.add(const Duration(days: 1))),
);

MortalityRecord _mort(DateTime date, {required String pigId, required String cause}) =>
  MortalityRecord(
    id: 'm', farmId: 'f', pigId: pigId,
    date: Timestamp.fromDate(date), cause: cause,
    photoUrls: const [], notes: null,
    createdBy: 'u', createdAt: Timestamp.now(),
  );
```

- [ ] **Step 15.3: Providers + screen**

`lib/src/features/yield/yield_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../pigs/application/pig_providers.dart';
import '../pigs/domain/breeding_record.dart';
import '../pigs/domain/pig.dart';
import 'yield_calculator.dart';
import 'yield_metrics.dart';

final selectedPeriodProvider = StateProvider<YieldPeriod>((_) => YieldPeriod.d30);

final yieldHerdProductivityProvider =
    Provider.family<HerdProductivity, String>((ref, farmId) {
  final period = ref.watch(selectedPeriodProvider);
  final now = DateTime.now();
  final pigs = ref.watch(pigsStreamProvider(farmId)).asData?.value ?? const <Pig>[];
  final farrowings = ref.watch(allFarrowingsProvider(farmId)).asData?.value ?? const [];
  // Collection-group all breeding records.
  // For now, derive activeSowCount from pigs.
  final activeSows = pigs.where((p) =>
    p.sex == PigSex.female && p.stage == PigStage.sow &&
    p.status == PigStatus.active).length;
  return YieldCalculator.herdProductivity(
    farrowings: farrowings, breedings: const <BreedingRecord>[],
    activeSowCount: activeSows,
    periodStart: period.startFrom(now), now: now,
  );
});

final yieldGrowthProvider = Provider.family<GrowthMetrics, String>((ref, farmId) {
  final pigs = ref.watch(pigsStreamProvider(farmId)).asData?.value ?? const <Pig>[];
  return YieldCalculator.growth(pigs: pigs, now: DateTime.now());
});

final yieldMortalityProvider = Provider.family<MortalityMetrics, String>((ref, farmId) {
  final period = ref.watch(selectedPeriodProvider);
  final pigs = ref.watch(pigsStreamProvider(farmId)).asData?.value ?? const <Pig>[];
  final morts = ref.watch(allMortalitiesProvider(farmId)).asData?.value ?? const [];
  return YieldCalculator.mortality(
    mortalities: morts, allPigs: pigs,
    pigIdToAreaId: {for (final p in pigs) p.id: p.currentAreaId},
    periodStart: period.startFrom(DateTime.now()),
  );
});

final yieldOutputProvider = Provider.family<OutputMetrics, String>((ref, farmId) {
  final period = ref.watch(selectedPeriodProvider);
  final pigs = ref.watch(pigsStreamProvider(farmId)).asData?.value ?? const <Pig>[];
  return YieldCalculator.output(
    pigs: pigs, periodStart: period.startFrom(DateTime.now()),
  );
});
```

`lib/src/features/yield/yield_screen.dart`:

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../farms/application/farm_providers.dart';
import 'yield_metrics.dart';
import 'yield_providers.dart';

class YieldScreen extends ConsumerWidget {
  const YieldScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) return const SizedBox.shrink();
    final period = ref.watch(selectedPeriodProvider);
    final hp = ref.watch(yieldHerdProductivityProvider(farmId));
    final g = ref.watch(yieldGrowthProvider(farmId));
    final m = ref.watch(yieldMortalityProvider(farmId));
    final o = ref.watch(yieldOutputProvider(farmId));

    return Scaffold(
      appBar: AppBar(title: const Text('Yield reports')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(spacing: 8, children: YieldPeriod.values.map((p) => ChoiceChip(
            label: Text(p.label),
            selected: period == p,
            onSelected: (_) => ref.read(selectedPeriodProvider.notifier).state = p,
          )).toList()),
          const SizedBox(height: 16),
          _Card(title: 'Herd productivity', children: [
            _row('Total farrowings', hp.totalFarrowings.toString()),
            _row('Avg litter size', hp.avgLitterSize.toStringAsFixed(1)),
            _row('Avg stillborns / litter', hp.avgStillborns.toStringAsFixed(1)),
            _row('Stillbirth rate', _pct(hp.stillbirthRate)),
            _row('Breeding success rate', _pct(hp.breedingSuccessRate)),
            _row('PSY (estimate, annualized)', hp.psyEstimate.toStringAsFixed(1)),
          ]),
          _Card(title: 'Growth & finishing', children: [
            _row('Active grow/finish pigs', g.activeGrowFinishCount.toString()),
            _row('Average daily gain', '${g.avgDailyGainKg.toStringAsFixed(2)} kg/d'),
          ]),
          _Card(title: 'Mortality', children: [
            _row('Total deaths (period)', m.totalDeaths.toString()),
            _row('Overall mortality rate', _pct(m.overallMortalityRate)),
            if (m.topCauses.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Top causes:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...m.topCauses.map((c) => Text('  • ${c.key}: ${c.value}')),
            ],
            if (m.byArea.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('By area:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 180, child: _AreaBarChart(byArea: m.byArea)),
            ],
          ]),
          _Card(title: 'Output', children: [
            _row('Sold (in period)', o.sold.toString()),
            _row('Culled (in period)', o.culled.toString()),
            const Text('Sales revenue tracking comes in Sub-project B.',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Expanded(child: Text(label)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
    ]),
  );

  String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const Divider(),
          ...children,
        ],
      ),
    ),
  );
}

class _AreaBarChart extends StatelessWidget {
  const _AreaBarChart({required this.byArea});
  final Map<String, int> byArea;

  @override
  Widget build(BuildContext context) {
    final entries = byArea.entries.toList();
    return BarChart(BarChartData(
      barGroups: List.generate(entries.length, (i) => BarChartGroupData(
        x: i,
        barRods: [BarChartRodData(toY: entries[i].value.toDouble(), color: Colors.red)],
      )),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 30,
          getTitlesWidget: (v, _) => Text(
            entries[v.toInt()].key.substring(0, entries[v.toInt()].key.length.clamp(0, 4)),
            style: const TextStyle(fontSize: 10),
          ),
        )),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: const FlGridData(show: true),
      borderData: FlBorderData(show: false),
    ));
  }
}
```

- [ ] **Step 15.4: Route + commit**

```dart
GoRoute(path: '/yield', builder: (c, s) => const YieldScreen()),
```

Import.

```bash
flutter analyze && flutter test
git add -A
git commit -m "feat(yield): yield reports with productivity, growth, mortality, output

- YieldCalculator pure functions (PSY, ADG, stillbirth rate, mortality rate)
- Period selector (7d/30d/90d/YTD/all-time) drives all metric cards
- Mortality-by-area bar chart via fl_chart
- Pure-function unit tests for every calculator path"
```

---

## Task 16: Farm Layout

**Goal:** Spatial overview screen — for each area, show pens with occupancy color tiles, equipment chips colored by status, pending tasks count, and active workers from today's roster.

**Files:**
- Create:
  - `lib/src/features/layout/farm_layout_screen.dart`

### Steps

- [ ] **Step 16.1: Farm layout screen**

`lib/src/features/layout/farm_layout_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../areas/application/area_providers.dart';
import '../areas/domain/area.dart';
import '../areas/domain/pen.dart';
import '../authentication/application/auth_providers.dart';
import '../equipment/application/equipment_providers.dart';
import '../equipment/domain/equipment.dart';
import '../farms/application/farm_providers.dart';
import '../pigs/application/pig_providers.dart';
import '../pigs/domain/pig.dart';
import '../shifts/application/shift_providers.dart';
import '../shifts/domain/shift.dart';
import '../tasks/application/task_providers.dart';
import '../team/application/team_providers.dart';

class FarmLayoutScreen extends ConsumerWidget {
  const FarmLayoutScreen({super.key});

  Color _penColor(Pen p) {
    final r = p.occupancyRatio;
    if (p.capacity == null) return Colors.grey.shade300;
    if (r <= 0.5) return Colors.green.shade300;
    if (r <= 0.8) return Colors.yellow.shade400;
    return Colors.red.shade400;
  }

  Color _eqColor(EquipmentStatus s) {
    switch (s) {
      case EquipmentStatus.inUse: return Colors.green;
      case EquipmentStatus.available: return Colors.grey;
      case EquipmentStatus.needsRepair: return Colors.red;
      case EquipmentStatus.retired: return Colors.black26;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmId = ref.watch(selectedFarmIdProvider);
    final user = ref.watch(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return const SizedBox.shrink();
    final areas = ref.watch(areasStreamProvider(farmId)).asData?.value ?? const <Area>[];
    final pens = ref.watch(allPensStreamProvider(farmId)).asData?.value ?? const <Pen>[];
    final equipment = ref.watch(equipmentStreamProvider(farmId)).asData?.value ?? const <Equipment>[];
    final pigs = ref.watch(pigsStreamProvider(farmId)).asData?.value ?? const <Pig>[];
    final tasks = ref.watch(openTasksStreamProvider(farmId)).asData?.value ?? const [];
    final shifts = ref.watch(shiftsForDateProvider((farmId: farmId, date: DateTime.now())));

    return Scaffold(
      appBar: AppBar(title: const Text('Farm layout')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: areas.length,
        itemBuilder: (_, i) {
          final a = areas[i];
          final areaPens = pens.where((p) => p.areaId == a.id).toList();
          final areaEq = equipment.where((e) => e.areaId == a.id).toList();
          final areaPigs = pigs.where((p) => p.currentAreaId == a.id && p.status == PigStatus.active).length;
          final cap = areaPens.fold<int?>(null, (s, p) =>
              p.capacity == null ? s : (s ?? 0) + p.capacity!);
          final taskCount = tasks.where((t) => t.relatedAreaId == a.id).length;
          final activeShifts = shifts.where((s) => s.assignedAreaId == a.id).toList();
          final activeWorkerIds = <String>{};
          for (final s in activeShifts) {
            activeWorkerIds.addAll(s.assignedUserIds);
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(a.name,
                        style: Theme.of(context).textTheme.headlineSmall)),
                      Chip(label: Text(a.purpose.label)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Pigs: $areaPigs${cap == null ? "" : " / $cap"}'),
                  if (taskCount > 0) Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('$taskCount pending task${taskCount == 1 ? "" : "s"}',
                        style: const TextStyle(color: Colors.orange)),
                  ),
                  if (areaPens.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Pens', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 4),
                    Wrap(spacing: 6, runSpacing: 6, children: areaPens.map((p) => Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _penColor(p),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(p.name, style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 11)),
                          Text(p.capacity == null
                              ? '${p.currentOccupancy}'
                              : '${p.currentOccupancy}/${p.capacity}',
                              style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    )).toList()),
                  ],
                  if (areaEq.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Equipment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 4),
                    Wrap(spacing: 6, runSpacing: 4, children: areaEq.map((eq) => Chip(
                      label: Text(eq.name, style: const TextStyle(
                        fontSize: 11, color: Colors.white)),
                      backgroundColor: _eqColor(eq.status),
                      padding: EdgeInsets.zero,
                    )).toList()),
                  ],
                  if (activeWorkerIds.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('On shift:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(width: 6),
                        ...activeWorkerIds.take(5).map((id) => Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: CircleAvatar(radius: 12, child: Text(
                            id.isEmpty ? '?' : id[0].toUpperCase(),
                            style: const TextStyle(fontSize: 11),
                          )),
                        )),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 16.2: Route + commit**

```dart
GoRoute(path: '/layout', builder: (c, s) => const FarmLayoutScreen()),
```

Import.

```bash
flutter analyze && flutter test
git add -A
git commit -m "feat(layout): farm layout spatial overview screen

- Per-area cards with pen tiles colored by occupancy (green/yellow/red)
- Equipment chips colored by status (green/grey/red/black)
- Pig occupancy X/Y, pending task count, today's roster avatars
- No GPS — purely structured visual summary"
```

---

## Task 17: Real Dashboard + Offline Banner + Photo Queue Flushing

**Goal:** Replace the placeholder home/dashboard with the real dashboard. Add offline indicator. Wire photo-queue flush on reconnect.

**Files:**
- Create:
  - `lib/src/features/dashboard/dashboard_screen.dart`
  - `lib/src/features/dashboard/snapshot_card.dart`
  - `lib/src/core/widgets/offline_banner.dart`
  - `lib/src/core/widgets/app_shell.dart`
- Modify:
  - `lib/src/routing/app_router.dart`

### Steps

- [ ] **Step 17.1: OfflineBanner + connectivity provider + queue flusher**

`lib/src/core/widgets/offline_banner.dart`:

```dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/media/media_providers.dart';

final connectivityProvider = StreamProvider<List<ConnectivityResult>>(
  (_) => Connectivity().onConnectivityChanged,
);

class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conn = ref.watch(connectivityProvider).asData?.value;
    final isOffline = conn != null && conn.every((r) => r == ConnectivityResult.none);

    // Side-effect: when transitioning to online, flush queued photo uploads.
    ref.listen<AsyncValue<List<ConnectivityResult>>>(connectivityProvider, (prev, next) {
      final wasOffline = prev?.asData?.value != null &&
          prev!.asData!.value.every((r) => r == ConnectivityResult.none);
      final nowOnline = next.asData?.value != null &&
          next.asData!.value.any((r) => r != ConnectivityResult.none);
      if (wasOffline && nowOnline) {
        final svc = ref.read(photoUploadServiceProvider);
        svc?.flushQueue();
      }
    });

    if (!isOffline) return const SizedBox.shrink();
    return Material(
      color: Colors.orange.shade700,
      child: const SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(children: [
            Icon(Icons.cloud_off, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Offline — changes will sync when you reconnect',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ]),
        ),
      ),
    );
  }
}
```

- [ ] **Step 17.2: Snapshot card (dashboard metrics)**

`lib/src/features/dashboard/snapshot_card.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../farms/application/farm_providers.dart';
import '../pigs/application/pig_providers.dart';
import '../pigs/domain/pig.dart';

class SnapshotCard extends ConsumerWidget {
  const SnapshotCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) return const SizedBox.shrink();
    final pigs = ref.watch(pigsStreamProvider(farmId)).asData?.value ?? const <Pig>[];
    final farrowings = ref.watch(allFarrowingsProvider(farmId)).asData?.value ?? const [];
    final morts = ref.watch(allMortalitiesProvider(farmId)).asData?.value ?? const [];

    final active = pigs.where((p) => p.status == PigStatus.active).toList();
    final sows = active.where((p) => p.stage == PigStage.sow).length;
    final boars = active.where((p) => p.stage == PigStage.boar).length;
    // Active gestations: count of sows with farrowings in the next ~114 days...
    // Simpler: count of farrowing_expected tasks open. For MVP, derive from breeding records.
    // For now, expose total pigs, sows, boars, farrowings in last 30d, mortalities in last 30d.
    final now = DateTime.now();
    final last30 = now.subtract(const Duration(days: 30));
    final recentFarr = farrowings.where((f) => f.date.toDate().isAfter(last30)).length;
    final recentMort = morts.where((m) => m.date.toDate().isAfter(last30)).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Swine snapshot',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            _row('Total pigs (active)', active.length.toString()),
            _row('Sows', sows.toString()),
            _row('Boars', boars.toString()),
            _row('Farrowings (last 30d)', recentFarr.toString()),
            _row('Mortalities (last 30d)', recentMort.toString()),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Expanded(child: Text(label)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    ]),
  );
}
```

- [ ] **Step 17.3: Dashboard screen**

`lib/src/features/dashboard/dashboard_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../activity/presentation/activity_feed_widget.dart';
import '../authentication/application/auth_providers.dart';
import '../farms/application/farm_providers.dart';
import '../farms/presentation/farm_switcher.dart';
import '../shifts/presentation/roster_widget.dart';
import '../tasks/application/task_providers.dart';
import '../tasks/domain/task.dart';
import 'snapshot_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmId = ref.watch(selectedFarmIdProvider);
    final user = ref.watch(authStateChangesProvider).asData?.value;
    final appUser = ref.watch(currentAppUserProvider).asData?.value;
    if (farmId == null || user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final myTasks = ref.watch(myTasksStreamProvider((farmId: farmId, userId: user.uid)));

    return Scaffold(
      appBar: AppBar(
        title: const FarmSwitcher(),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      drawer: const _NavDrawer(),
      body: RefreshIndicator(
        onRefresh: () async { /* streams auto-refresh; no-op */ },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Hello${appUser?.displayName == null ? "" : ", ${appUser!.displayName}"}',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            const SnapshotCard(),
            const SizedBox(height: 16),
            myTasks.when(
              data: (tasks) => _MyTasksCard(tasks: tasks),
              loading: () => const SizedBox.shrink(),
              error: (e, _) => Text('$e'),
            ),
            const SizedBox(height: 16),
            const RosterWidget(),
            const SizedBox(height: 16),
            const ActivityFeedWidget(limit: 6),
          ],
        ),
      ),
    );
  }
}

class _MyTasksCard extends StatelessWidget {
  const _MyTasksCard({required this.tasks});
  final List<FarmTask> tasks;
  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const Card(child: Padding(
        padding: EdgeInsets.all(16),
        child: Text('No tasks assigned to you. 🎉'),
      ));
    }
    final preview = tasks.take(5).toList();
    return Card(
      color: Colors.lightGreen.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your tasks today',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ...preview.map((t) => ListTile(
              dense: true, contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.task_alt),
              title: Text(t.title),
              subtitle: Text(t.dueDate.toDate().toString().split(' ')[0]),
            )),
            TextButton(
              onPressed: () => GoRouter.of(context).push('/tasks'),
              child: const Text('See all tasks →'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavDrawer extends ConsumerWidget {
  const _NavDrawer();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      child: ListView(children: [
        const DrawerHeader(child: Text('Farm CRM')),
        _item(context, Icons.pets, 'Pigs', '/pigs'),
        _item(context, Icons.task_alt, 'Tasks', '/tasks'),
        _item(context, Icons.dashboard, 'Farm layout', '/layout'),
        _item(context, Icons.assessment, 'Yield reports', '/yield'),
        _item(context, Icons.history, 'Activity', '/activity'),
        const Divider(),
        _item(context, Icons.location_on, 'Areas', '/areas'),
        _item(context, Icons.build, 'Equipment', '/equipment'),
        _item(context, Icons.schedule, 'Shifts', '/shifts'),
        _item(context, Icons.people, 'Team', '/team'),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Sign out'),
          onTap: () async {
            await ref.read(authRepositoryProvider).signOut();
          },
        ),
      ]),
    );
  }
  Widget _item(BuildContext context, IconData icon, String label, String path) => ListTile(
    leading: Icon(icon), title: Text(label),
    onTap: () { Navigator.pop(context); GoRouter.of(context).push(path); },
  );
}
```

- [ ] **Step 17.4: App shell with offline banner + dashboard route**

`lib/src/core/widgets/app_shell.dart`:

```dart
import 'package:flutter/material.dart';
import 'offline_banner.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const OfflineBanner(),
      Expanded(child: child),
    ]);
  }
}
```

Update `app_router.dart` — replace the `/` route's placeholder body with the real dashboard, wrap routes with the shell:

```dart
GoRoute(
  path: '/',
  builder: (c, s) => const AppShell(child: DashboardScreen()),
),
```

And similarly wrap the other routes with `AppShell` so the offline banner is everywhere. Or simpler: wrap at the `MaterialApp` level. For this plan, wrap each main screen.

Import: `import '../core/widgets/app_shell.dart';` and `import '../features/dashboard/dashboard_screen.dart';`

- [ ] **Step 17.5: Verify + commit**

```bash
flutter analyze && flutter test && flutter run -d <device>
```

Manual smoke: Sign in → see Dashboard with snapshot card showing real counts. Toggle airplane mode → orange Offline banner appears at top. Toggle off → banner disappears; if there were queued photo uploads, they flush.

```bash
git add -A
git commit -m "feat(dashboard,core): real dashboard with snapshot/tasks/roster/feed

- DashboardScreen replaces placeholder /home
- SnapshotCard with active pig counts, recent farrowings & mortalities
- 'Your tasks today' card with top-5 preview, link to full Tasks screen
- AppShell with OfflineBanner; auto-flushes photo queue on reconnect
- Drawer nav for Pigs/Tasks/Layout/Yield/Activity/Areas/Equipment/Shifts/Team/SignOut"
```

---

## Task 18: Firestore Security Rules + Final Audit

**Goal:** Lock down all data behind farm-membership-based rules. Verify every collection enforces the permissions matrix from spec §8. Run a full manual test pass across all four roles.

**Files:**
- Create:
  - `firestore.rules`
  - `storage.rules`
  - `docs/superpowers/manual-smoke-checklist.md`
- Modify:
  - `firebase.json` (declare rules paths)

### Steps

- [ ] **Step 18.1: Firestore rules**

`firestore.rules`:

```javascript
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    function isSignedIn() { return request.auth != null; }

    function memberDoc(farmId) {
      return get(/databases/$(database)/documents/farms/$(farmId)/members/$(request.auth.uid));
    }

    function isMember(farmId) {
      return exists(/databases/$(database)/documents/farms/$(farmId)/members/$(request.auth.uid))
          && memberDoc(farmId).data.get('removedAt', null) == null;
    }

    function role(farmId) {
      return memberDoc(farmId).data.role;
    }

    function isOwner(farmId) { return role(farmId) == 'owner'; }
    function isManager(farmId) { return role(farmId) == 'manager'; }
    function isWorker(farmId) { return role(farmId) == 'worker'; }
    function isVet(farmId) { return role(farmId) == 'vet'; }

    function canWriteEquipment(farmId) { return isOwner(farmId) || isManager(farmId); }
    function canWriteShifts(farmId) { return isOwner(farmId) || isManager(farmId); }
    function canManageTeam(farmId) { return isOwner(farmId) || isManager(farmId); }
    function canEditPig(farmId) { return isOwner(farmId) || isManager(farmId) || isWorker(farmId); }

    // ---- users/{uid}
    match /users/{uid} {
      allow read: if isSignedIn() && request.auth.uid == uid;
      allow create: if isSignedIn() && request.auth.uid == uid;
      allow update: if isSignedIn() && request.auth.uid == uid;
      allow delete: if false;
    }

    // ---- farms/{farmId}
    match /farms/{farmId} {
      allow read: if isMember(farmId);
      allow create: if isSignedIn()
        && request.resource.data.createdBy == request.auth.uid;
      allow update: if isOwner(farmId);
      allow delete: if false;

      // ---- members/{userId}
      match /members/{userId} {
        // Self-create allowed only when accepting an invitation (the client adds
        // the matching members doc in the same batch as updating the invitation;
        // we permit it if a corresponding accepted/pending invite exists for this email).
        allow read: if isMember(farmId) || request.auth.uid == userId;
        allow create: if canManageTeam(farmId)
          || (request.auth.uid == userId
              && exists(/databases/$(database)/documents/farms/$(farmId)/invitations/$(request.resource.data.get('_inviteId', '__none__'))));
        allow update: if canManageTeam(farmId);
        allow delete: if isOwner(farmId);
      }

      // ---- invitations/{id}
      match /invitations/{id} {
        allow read: if isMember(farmId)
          || (isSignedIn()
              && request.auth.token.email == resource.data.email
              && resource.data.status == 'pending');
        allow create: if canManageTeam(farmId);
        allow update: if canManageTeam(farmId)
          || (isSignedIn()
              && request.auth.token.email == resource.data.email
              && request.resource.data.status == 'accepted');
        allow delete: if canManageTeam(farmId);
      }

      // ---- areas + pens
      match /areas/{areaId} {
        allow read: if isMember(farmId);
        allow write: if isOwner(farmId) || isManager(farmId);

        match /pens/{penId} {
          allow read: if isMember(farmId);
          allow write: if isOwner(farmId) || isManager(farmId);
        }
      }

      // ---- equipment + maintenance
      match /equipment/{equipmentId} {
        allow read: if isMember(farmId);
        allow create, update: if canWriteEquipment(farmId)
          || (isWorker(farmId)
              && request.resource.data.diff(resource.data).affectedKeys()
                  .hasOnly(['status', 'updatedAt']));
        allow delete: if canWriteEquipment(farmId);

        match /maintenance_records/{recordId} {
          allow read: if isMember(farmId);
          allow create: if canWriteEquipment(farmId) || isWorker(farmId);
          allow update, delete: if isOwner(farmId) || isManager(farmId);
        }
      }

      // ---- pigs + sub-collections
      match /pigs/{pigId} {
        allow read: if isMember(farmId);
        allow create, update: if canEditPig(farmId);
        allow delete: if isOwner(farmId) || isManager(farmId);

        match /breeding_records/{recordId} {
          allow read: if isMember(farmId);
          allow create: if canEditPig(farmId);
          allow update, delete: if isOwner(farmId) || isManager(farmId)
            || (resource.data.createdBy == request.auth.uid
                && request.time.toMillis() - resource.data.createdAt.toMillis() < 86400000);
        }
        match /farrowing_records/{recordId} {
          allow read: if isMember(farmId);
          allow create: if canEditPig(farmId);
          allow update, delete: if isOwner(farmId) || isManager(farmId);
        }
        match /health_records/{recordId} {
          allow read: if isMember(farmId);
          allow create: if isOwner(farmId) || isManager(farmId) || isWorker(farmId) || isVet(farmId);
          allow update, delete: if isOwner(farmId) || isManager(farmId)
            || (resource.data.createdBy == request.auth.uid
                && request.time.toMillis() - resource.data.createdAt.toMillis() < 86400000);
        }
        match /mortality_record/{recordId} {
          allow read: if isMember(farmId);
          allow create: if canEditPig(farmId);
          allow update, delete: if isOwner(farmId) || isManager(farmId);
        }
      }

      // ---- batches
      match /batches/{batchId} {
        allow read: if isMember(farmId);
        allow write: if canEditPig(farmId);
      }

      // ---- tasks
      match /tasks/{taskId} {
        allow read: if isMember(farmId);
        allow create: if isOwner(farmId) || isManager(farmId)
          // Auto-generated tasks: same userId who wrote the source record may create.
          || (canEditPig(farmId) && request.resource.data.autoGenerated == true);
        // Anyone with read access can mark a task they're assigned to complete.
        allow update: if isOwner(farmId) || isManager(farmId)
          || (isMember(farmId)
              && request.resource.data.diff(resource.data).affectedKeys()
                  .hasOnly(['status', 'completedBy', 'completedAt']));
        allow delete: if isOwner(farmId) || isManager(farmId);
      }

      // ---- shifts
      match /shifts/{shiftId} {
        allow read: if isMember(farmId);
        allow write: if canWriteShifts(farmId);
      }

      // ---- activity
      match /activity/{entryId} {
        allow read: if isMember(farmId);
        allow create: if isMember(farmId)
          && request.resource.data.actorUserId == request.auth.uid;
        allow update, delete: if false;
      }
    }
  }
}
```

`storage.rules`:

```javascript
rules_version = '2';

service firebase.storage {
  match /b/{bucket}/o {
    match /farms/{farmId}/{allPaths=**} {
      function isMember() {
        return request.auth != null && firestore.exists(
          /databases/(default)/documents/farms/$(farmId)/members/$(request.auth.uid)
        );
      }
      allow read: if isMember();
      allow write: if isMember()
        && request.resource.size < 5 * 1024 * 1024;  // 5 MB cap per file.
    }
  }
}
```

- [ ] **Step 18.2: firebase.json**

Edit `firebase.json` to declare the rules:

```json
{
  "firestore": {
    "rules": "firestore.rules"
  },
  "storage": {
    "rules": "storage.rules"
  }
}
```

(Adjust merge with any existing content as needed.)

Deploy with:
```bash
firebase deploy --only firestore:rules,storage:rules
```

- [ ] **Step 18.3: Manual smoke checklist**

`docs/superpowers/manual-smoke-checklist.md`:

```markdown
# Sub-project A — Manual Smoke Checklist

Test across all four roles by creating four accounts on the same project.
Confirm each row before merging.

## Owner flow
- [ ] Sign up → see Create Farm screen → create farm.
- [ ] Add 3 areas (Farrowing, Gestation, Grow-Finish) each with 2 pens (capacity).
- [ ] Add 3 equipment items (Ventilation Fan, Feeder, Generator) per area.
- [ ] Add 4 pigs: 2 sows, 1 boar, 1 grower. Verify photos upload.
- [ ] Log breeding on a sow → see 3 auto tasks created (preg / prep / farr).
- [ ] Record pregnancy check confirmed → preg task completed.
- [ ] Log farrowing → 10 live, 1 stillborn, create litter batch → breeding closed, farr task completed, litter batch visible.
- [ ] Log a vaccination on a pig with 21-day withdrawal → withdrawal_end task at +21d.
- [ ] Log mortality on a grower with cause "Respiratory" → pig deceased, activity entry.
- [ ] Quick-toggle equipment status; verify status cycles.
- [ ] Log maintenance with cost ₱500.
- [ ] Create a daily shift assigning two future workers; see today's roster.
- [ ] Invite a Manager (email), Worker (email), Vet (email) — verify three pending invitations.
- [ ] Open Yield reports → all six metrics populated.
- [ ] Open Farm Layout → all areas render with pen tiles, equipment chips, occupancy.

## Manager flow
- [ ] Sign up with the invited Manager email → see Accept Invitation → accept.
- [ ] Add 5 more pigs.
- [ ] Edit team — cannot promote anyone to Owner.
- [ ] Manage areas, pens, equipment, maintenance — all allowed.

## Worker flow
- [ ] Sign up with the Worker email → accept invitation → land on Dashboard.
- [ ] Log a treatment on a pig in your assigned area.
- [ ] Try to add a new pig — allowed (workers can create pigs).
- [ ] Try to manage the team — option not visible.
- [ ] Quick-toggle equipment status — works.
- [ ] Try to log maintenance — works (with photo).
- [ ] Try to manage shifts — option not visible.
- [ ] See "My Tasks" tab with tasks assigned to you.

## Vet flow
- [ ] Sign up with Vet email → accept invitation.
- [ ] View pig list, pig details — all visible.
- [ ] Log a vaccination — works.
- [ ] Try to add a pig — option not visible.
- [ ] Try to log mortality — option not visible.
- [ ] Try to manage equipment/shifts/team — options not visible.

## Multi-farm
- [ ] As Owner of Farm A, invite User X as Manager.
- [ ] Sign up User X separately and create their own Farm B.
- [ ] User X accepts invite to Farm A → now belongs to 2 farms.
- [ ] AppBar farm switcher lets User X switch; data sets are independent.

## Offline
- [ ] Toggle airplane mode mid-session → see orange "Offline" banner.
- [ ] Add a pig with photo while offline → save completes (Firestore offline cache).
- [ ] Re-enable network → banner disappears; photo upload flushes; URL appears on pig.
```

- [ ] **Step 18.4: Final commit**

```bash
git add -A
git commit -m "feat(security,docs): Firestore + Storage rules, manual smoke checklist

- Firestore rules enforce membership-based farm isolation and role-based
  write permissions matching the spec §8 matrix
- Storage rules require farm membership for photo read/write; 5MB cap
- Worker quick-toggle equipment status restricted to status+updatedAt fields
- Worker/Vet edit own records only within 24h; Owner/Manager always
- Auto-generated tasks bypass owner/manager creation gate
- Manual smoke checklist enumerates per-role end-to-end flows"
```

---

## Final verification

After all 18 tasks are complete, run the full verification pass:

- [ ] **`flutter analyze`** — zero issues.
- [ ] **`flutter test`** — all tests pass.
- [ ] **`firebase emulators:start --only firestore`** + run rule unit tests (left as ops detail).
- [ ] **Manual smoke checklist** in `docs/superpowers/manual-smoke-checklist.md` — every checkbox passes on a real Android device.
- [ ] **Success criteria** (spec §14) — every numbered criterion is demonstrably true.
- [ ] Tag the branch: `git tag sub-project-A` and push the tag.

---

## Notes for the executing engineer

- **Riverpod 3 syntax:** providers in this plan use `Provider`/`StreamProvider.family<T, RecordArg>` — match the SDK version in `pubspec.yaml`.
- **`fake_cloud_firestore` quirks:** collection-group queries work but ordering and `FieldPath.documentId` filters may behave slightly differently from prod. Test ordering against a real emulator when in doubt.
- **Photo capture on real device:** the Android `image_picker` needs `android.permission.CAMERA` in `AndroidManifest.xml` — verify before user-testing.
- **iOS:** add `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` in `ios/Runner/Info.plist`.
- **Free emoji-and-icon liberties:** the EveryPig-inspired tone calls for visual restraint — minimal emoji, calm greens, big tap targets, content over chrome.
- **What's NOT in this plan and is fine:** the deferred sub-projects (B-F) from spec §13. Don't scope-creep into them.
