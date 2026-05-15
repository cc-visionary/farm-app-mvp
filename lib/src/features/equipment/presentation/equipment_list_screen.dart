import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../core/permissions/role.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../../l10n/generated/app_localizations.dart';
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
  ConsumerState<EquipmentListScreen> createState() =>
      _EquipmentListScreenState();
}

class _EquipmentListScreenState extends ConsumerState<EquipmentListScreen> {
  EquipmentStatus? _statusFilter;
  final String? _areaFilter = null;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final farmId = ref.watch(selectedFarmIdProvider);
    final user = ref.watch(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return const SizedBox.shrink();
    final role = ref
            .watch(memberForUserProvider((farmId: farmId, userId: user.uid)))
            .asData
            ?.value
            ?.role ??
        Role.worker;
    final equipmentAsync = ref.watch(equipmentStreamProvider(farmId));

    return Scaffold(
      appBar: AppBar(title: Text(l.equipment_list_title)),
      floatingActionButton: PermissionService.canEditEquipment(role)
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddEditEquipmentScreen(),
                ),
              ),
              icon: const Icon(Iconsax.add),
              label: Text(l.equipment_list_fab_add),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: Text(l.equipment_list_filter_needs_repair),
                  selected: _statusFilter == EquipmentStatus.needsRepair,
                  onSelected: (sel) => setState(
                    () => _statusFilter =
                        sel ? EquipmentStatus.needsRepair : null,
                  ),
                ),
                FilterChip(
                  label: Text(l.equipment_list_filter_in_use),
                  selected: _statusFilter == EquipmentStatus.inUse,
                  onSelected: (sel) => setState(
                    () => _statusFilter = sel ? EquipmentStatus.inUse : null,
                  ),
                ),
                FilterChip(
                  label: Text(l.equipment_list_filter_available),
                  selected: _statusFilter == EquipmentStatus.available,
                  onSelected: (sel) => setState(
                    () =>
                        _statusFilter = sel ? EquipmentStatus.available : null,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: equipmentAsync.when(
              data: (list) {
                final filtered = list
                    .where(
                      (e) =>
                          e.status != EquipmentStatus.retired &&
                          (_statusFilter == null ||
                              e.status == _statusFilter) &&
                          (_areaFilter == null || e.areaId == _areaFilter),
                    )
                    .toList();
                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Iconsax.setting_4,
                    title: l.equipment_list_empty_title,
                    action: PermissionService.canEditEquipment(role)
                        ? FilledButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AddEditEquipmentScreen(),
                              ),
                            ),
                            icon: const Icon(Iconsax.add),
                            label: Text(l.equipment_list_fab_add),
                          )
                        : null,
                  );
                }
                // Group by type.
                final byType = <EquipmentType, List<Equipment>>{};
                for (final e in filtered) {
                  byType.putIfAbsent(e.type, () => []).add(e);
                }
                final types = byType.keys.toList()
                  ..sort((a, b) => a.index.compareTo(b.index));
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  children: [
                    for (final t in types) ...[
                      SectionHeader(title: localizedEquipmentType(l, t)),
                      ...byType[t]!.map(
                        (eq) => _EquipmentCard(
                          eq: eq,
                          role: role,
                          farmId: farmId,
                          userId: user.uid,
                        ),
                      ),
                    ],
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  'Error: $e',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EquipmentCard extends ConsumerWidget {
  const _EquipmentCard({
    required this.eq,
    required this.role,
    required this.farmId,
    required this.userId,
  });
  final Equipment eq;
  final Role role;
  final String farmId;
  final String userId;

  Color _statusFg(BuildContext context, EquipmentStatus s) {
    final cs = Theme.of(context).colorScheme;
    switch (s) {
      case EquipmentStatus.inUse:
        return cs.onPrimary;
      case EquipmentStatus.available:
        return cs.onSurface;
      case EquipmentStatus.needsRepair:
        return cs.onError;
      case EquipmentStatus.retired:
        return cs.onSurfaceVariant;
    }
  }

  Color _statusBg(BuildContext context, EquipmentStatus s) {
    final cs = Theme.of(context).colorScheme;
    switch (s) {
      case EquipmentStatus.inUse:
        return cs.primary;
      case EquipmentStatus.available:
        return cs.surfaceContainerHigh;
      case EquipmentStatus.needsRepair:
        return cs.error;
      case EquipmentStatus.retired:
        return cs.surfaceContainerHigh;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final canToggle = PermissionService.canQuickToggleEquipmentStatus(role);
    final actorName =
        ref.read(currentAppUserProvider).asData?.value?.displayName ?? '';
    final typeLabel = localizedEquipmentType(l, eq.type);
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 4,
        ),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Iconsax.setting_4,
            size: 20,
            color: colorScheme.primary,
          ),
        ),
        title: Text(eq.name, style: textTheme.titleMedium),
        subtitle: Text(
          eq.areaId == null
              ? typeLabel
              : l.equipment_card_area_with_type(typeLabel, eq.areaId!),
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: canToggle
              ? () => ref.read(equipmentRepositoryProvider).quickToggleStatus(
                    farmId: farmId,
                    equipmentId: eq.id,
                    actorUserId: userId,
                    actorDisplayName: actorName,
                  )
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _statusBg(context, eq.status),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              localizedEquipmentStatus(l, eq.status),
              style: textTheme.labelMedium?.copyWith(
                color: _statusFg(context, eq.status),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EquipmentDetailScreen(equipmentId: eq.id),
          ),
        ),
      ),
    );
  }
}
