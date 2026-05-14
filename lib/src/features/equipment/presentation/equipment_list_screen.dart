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
  ConsumerState<EquipmentListScreen> createState() => _EquipmentListScreenState();
}

class _EquipmentListScreenState extends ConsumerState<EquipmentListScreen> {
  EquipmentStatus? _statusFilter;
  String? _areaFilter;

  @override
  Widget build(BuildContext context) {
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
          ? FloatingActionButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddEditEquipmentScreen(),
                ),
              ),
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
                  onSelected: (sel) => setState(
                    () => _statusFilter = sel ? EquipmentStatus.needsRepair : null,
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
                    () => _statusFilter = sel ? EquipmentStatus.available : null,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: equipmentAsync.when(
              data: (list) {
                final filtered = list.where((e) =>
                    e.status != EquipmentStatus.retired &&
                    (_statusFilter == null || e.status == _statusFilter) &&
                    (_areaFilter == null || e.areaId == _areaFilter)).toList();
                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('No equipment matches filters.'),
                  );
                }
                // Group by type.
                final byType = <EquipmentType, List<Equipment>>{};
                for (final e in filtered) {
                  byType.putIfAbsent(e.type, () => []).add(e);
                }
                final types = byType.keys.toList()
                  ..sort((a, b) => a.index.compareTo(b.index));
                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: types.length,
                  itemBuilder: (_, ti) {
                    final t = types[ti];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 4),
                          child: Text(
                            t.label,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        ...byType[t]!.map(
                          (eq) => _EquipmentCard(
                            eq: eq,
                            role: role,
                            farmId: farmId,
                            userId: user.uid,
                          ),
                        ),
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

  Color _statusColor(EquipmentStatus s) {
    switch (s) {
      case EquipmentStatus.inUse:
        return Colors.green;
      case EquipmentStatus.available:
        return Colors.grey;
      case EquipmentStatus.needsRepair:
        return Colors.red;
      case EquipmentStatus.retired:
        return Colors.black26;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canToggle = PermissionService.canQuickToggleEquipmentStatus(role);
    final actorName =
        ref.read(currentAppUserProvider).asData?.value?.displayName ?? '';
    return Card(
      child: ListTile(
        title: Text(eq.name),
        subtitle: Text(
          eq.areaId == null ? eq.type.label : '${eq.type.label} - area ${eq.areaId}',
        ),
        trailing: GestureDetector(
          onTap: canToggle
              ? () => ref.read(equipmentRepositoryProvider).quickToggleStatus(
                    farmId: farmId,
                    equipmentId: eq.id,
                    actorUserId: userId,
                    actorDisplayName: actorName,
                  )
              : null,
          child: Chip(
            label: Text(
              eq.status.label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: _statusColor(eq.status),
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
