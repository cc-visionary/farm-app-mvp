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
import '../tasks/application/task_providers.dart';

class FarmLayoutScreen extends ConsumerWidget {
  const FarmLayoutScreen({super.key});

  Color _penColor(Pen p) {
    if (p.capacity == null) return Colors.grey.shade300;
    final r = p.occupancyRatio;
    if (r <= 0.5) return Colors.green.shade300;
    if (r <= 0.8) return Colors.yellow.shade400;
    return Colors.red.shade400;
  }

  Color _eqColor(EquipmentStatus s) {
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
          ? const Center(child: Text('No areas yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: areas.length,
              itemBuilder: (_, i) {
                final a = areas[i];
                final areaPens =
                    pens.where((p) => p.areaId == a.id).toList();
                final areaEq =
                    equipment.where((e) => e.areaId == a.id).toList();
                final areaPigs = pigs
                    .where((p) =>
                        p.currentAreaId == a.id &&
                        p.status == PigStatus.active)
                    .length;
                final cap = areaPens.fold<int?>(
                    null,
                    (s, p) =>
                        p.capacity == null ? s : (s ?? 0) + p.capacity!);
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
                                style:
                                    Theme.of(context).textTheme.headlineSmall,
                              ),
                            ),
                            Chip(label: Text(a.purpose.label)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Pigs: $areaPigs / ${cap ?? "—"}',
                        ),
                        if (taskCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '$taskCount pending task${taskCount == 1 ? "" : "s"}',
                              style: const TextStyle(color: Colors.orange),
                            ),
                          ),
                        if (areaPens.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Pens',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: areaPens
                                .map(
                                  (p) => Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _penColor(p),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          p.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                        Text(
                                          p.capacity == null
                                              ? '${p.currentOccupancy}'
                                              : '${p.currentOccupancy}/${p.capacity}',
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                        if (areaEq.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Equipment',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: areaEq
                                .map(
                                  (eq) => Chip(
                                    label: Text(
                                      eq.name,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.white,
                                      ),
                                    ),
                                    backgroundColor: _eqColor(eq.status),
                                    padding: EdgeInsets.zero,
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                        if (activeWorkerIds.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Text(
                                'On shift:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 6),
                              ...activeWorkerIds.take(5).map(
                                    (id) => Padding(
                                      padding:
                                          const EdgeInsets.only(right: 4),
                                      child: CircleAvatar(
                                        radius: 12,
                                        child: Text(
                                          id.isEmpty
                                              ? '?'
                                              : id[0].toUpperCase(),
                                          style:
                                              const TextStyle(fontSize: 11),
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
