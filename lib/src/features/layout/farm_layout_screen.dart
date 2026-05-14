import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/widgets/empty_state.dart';
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
import '../tasks/application/task_providers.dart';

class FarmLayoutScreen extends ConsumerWidget {
  const FarmLayoutScreen({super.key});

  Color _penColor(BuildContext context, Pen p) {
    final cs = Theme.of(context).colorScheme;
    if (p.capacity == null) return cs.surfaceContainerHigh;
    final r = p.occupancyRatio;
    if (r <= 0.5) return cs.primaryContainer;
    if (r <= 0.8) return cs.tertiaryContainer;
    return cs.errorContainer;
  }

  Color _penFg(BuildContext context, Pen p) {
    final cs = Theme.of(context).colorScheme;
    if (p.capacity == null) return cs.onSurface;
    final r = p.occupancyRatio;
    if (r <= 0.5) return cs.onPrimaryContainer;
    if (r <= 0.8) return cs.onTertiaryContainer;
    return cs.onErrorContainer;
  }

  Color _eqStatusDot(BuildContext context, EquipmentStatus s) {
    final cs = Theme.of(context).colorScheme;
    switch (s) {
      case EquipmentStatus.inUse:
        return cs.primary;
      case EquipmentStatus.available:
        return cs.outline;
      case EquipmentStatus.needsRepair:
        return cs.error;
      case EquipmentStatus.retired:
        return cs.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final farmId = ref.watch(selectedFarmIdProvider);
    final user = ref.watch(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return const SizedBox.shrink();

    final areas = ref.watch(areasStreamProvider(farmId)).asData?.value ??
        const <Area>[];
    final pens = ref.watch(allPensStreamProvider(farmId)).asData?.value ??
        const <Pen>[];
    final equipment = ref.watch(equipmentStreamProvider(farmId)).asData?.value ??
        const <Equipment>[];
    final pigs =
        ref.watch(pigsStreamProvider(farmId)).asData?.value ?? const <Pig>[];
    final tasks = ref.watch(openTasksStreamProvider(farmId)).asData?.value ??
        const [];
    final shifts = ref
        .watch(shiftsForDateProvider((farmId: farmId, date: DateTime.now())));

    return Scaffold(
      appBar: AppBar(title: const Text('Farm layout')),
      body: areas.isEmpty
          ? const EmptyState(
              icon: Iconsax.element_3,
              title: 'No areas yet',
              subtitle:
                  'Add areas and pens to see your farm laid out at a glance.',
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: areas.length,
              itemBuilder: (_, i) {
                final a = areas[i];
                final areaPens =
                    pens.where((p) => p.areaId == a.id).toList();
                final areaEq =
                    equipment.where((e) => e.areaId == a.id).toList();
                final areaPigs = pigs
                    .where(
                      (p) =>
                          p.currentAreaId == a.id &&
                          p.status == PigStatus.active,
                    )
                    .length;
                final cap = areaPens.fold<int?>(
                  null,
                  (s, p) => p.capacity == null ? s : (s ?? 0) + p.capacity!,
                );
                final taskCount =
                    tasks.where((t) => t.relatedAreaId == a.id).length;
                final activeShifts =
                    shifts.where((s) => s.assignedAreaId == a.id).toList();
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
                            Expanded(
                              child: Text(
                                a.name,
                                style: textTheme.headlineSmall,
                              ),
                            ),
                            Chip(
                              label: Text(a.purpose.label),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Iconsax.pet,
                              size: 16,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$areaPigs / ${cap ?? "—"} pigs',
                              style: textTheme.bodyMedium,
                            ),
                          ],
                        ),
                        if (taskCount > 0) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Iconsax.task_square,
                                size: 16,
                                color: colorScheme.tertiary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$taskCount pending task${taskCount == 1 ? "" : "s"}',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.tertiary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (areaPens.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            'PENS',
                            style: textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: areaPens
                                .map(
                                  (p) => Container(
                                    width: 88,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _penColor(context, p),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.name,
                                          style: textTheme.labelLarge?.copyWith(
                                            color: _penFg(context, p),
                                            fontWeight: FontWeight.w700,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          p.capacity == null
                                              ? '${p.currentOccupancy}'
                                              : '${p.currentOccupancy}/${p.capacity}',
                                          style: textTheme.bodyMedium?.copyWith(
                                            color: _penFg(context, p),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                        if (areaEq.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            'EQUIPMENT',
                            style: textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: areaEq
                                .map(
                                  (eq) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.surface,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: colorScheme.outline,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: _eqStatusDot(
                                              context,
                                              eq.status,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          eq.name,
                                          style: textTheme.labelMedium,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                        if (activeWorkerIds.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Text(
                                'ON SHIFT',
                                style: textTheme.labelMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(width: 12),
                              ...activeWorkerIds.take(5).map(
                                    (id) => Padding(
                                      padding:
                                          const EdgeInsets.only(right: 4),
                                      child: CircleAvatar(
                                        radius: 12,
                                        backgroundColor:
                                            colorScheme.primaryContainer,
                                        child: Text(
                                          id.isEmpty
                                              ? '?'
                                              : id[0].toUpperCase(),
                                          style:
                                              textTheme.labelMedium?.copyWith(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
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
