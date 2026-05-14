import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../areas/application/area_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../application/shift_providers.dart';
import '../domain/shift.dart';

class RosterWidget extends ConsumerWidget {
  const RosterWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) return const SizedBox.shrink();
    final today = DateTime.now();
    final shifts =
        ref.watch(shiftsForDateProvider((farmId: farmId, date: today)));
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
    final byArea = <String, List<Shift>>{};
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
            const Text(
              "Today's Roster",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ...byArea.entries.map((e) {
              final areaName = areas
                  .where((a) => a.id == e.key)
                  .map((a) => a.name)
                  .firstOrNull ??
                  e.key;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      areaName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ...e.value.map((s) => Text(
                          '  • ${s.name} (${s.startTime}-${s.endTime}) — '
                          '${s.assignedUserIds.join(", ")}',
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
