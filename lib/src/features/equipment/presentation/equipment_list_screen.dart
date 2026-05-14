import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../core/permissions/role.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
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
      appBar: AppBar(title: const Text('Equipment')),
      floatingActionButton: PermissionService.canEditEquipment(role)
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddEditEquipmentScreen(),
                ),
              ),
              icon: const Icon(Iconsax.add),
              label: const Text('New'),
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
                  label: const Text('Needs repair'),
                  selected: _statusFilter == EquipmentStatus.needsRepair,
                  onSelected: (sel) => setState(
                    () => _statusFilter =
                        sel ? EquipmentStatus.needsRepair : null,
                  ),
                ),
                FilterChip(
                  label: const Text('In use'),
                  selected: _statusFilter == EquipmentStatus.inUse,
                  onSelected: (sel) => setState(
                    () => _statusFilter = sel ? EquipmentStatus.inUse : null,
                  ),
                ),
                FilterChip(
                  label: const Text('Available'),
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
                    title: list.isEmpty
                        ? 'No equipment yet'
                        : 'No equipment matches filters',
                    subtitle: list.isEmpty
                        ? 'Track feeders, fans, and tools so you know what works and what needs repair.'
                        : null,
                    action: list.isEmpty &&
                            PermissionService.canEditEquipment(role)
                        ? FilledButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AddEditEquipmentScreen(),
                              ),
                            ),
                            icon: const Icon(Iconsax.add),
                            label: const Text('Add equipment'),
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
                      SectionHeader(title: t.label),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final canToggle = PermissionService.canQuickToggleEquipmentStatus(role);
    final actorName =
        ref.read(currentAppUserProvider).asData?.value?.displayName ?? '';
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
              ? eq.type.label
              : '${eq.type.label} · area ${eq.areaId}',
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
              eq.status.label,
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
