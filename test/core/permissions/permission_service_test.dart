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
