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
