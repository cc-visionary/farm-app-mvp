import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/widgets/section_header.dart';
import '../../areas/application/area_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../application/shift_providers.dart';
import '../domain/shift.dart';

class RosterWidget extends ConsumerWidget {
  const RosterWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) return const SizedBox.shrink();
    final today = DateTime.now();
    final shifts =
        ref.watch(shiftsForDateProvider((farmId: farmId, date: today)));
    final areas =
        ref.watch(areasStreamProvider(farmId)).asData?.value ?? const [];

    if (shifts.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: "Today's roster"),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No shifts scheduled today.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Group by area.
    final byArea = <String, List<Shift>>{};
    for (final s in shifts) {
      byArea.putIfAbsent(s.assignedAreaId, () => []).add(s);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: "Today's roster"),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < byArea.entries.length; i++) ...[
                  if (i > 0) const SizedBox(height: 16),
                  _AreaGroup(
                    areaId: byArea.entries.elementAt(i).key,
                    shifts: byArea.entries.elementAt(i).value,
                    areas: areas,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AreaGroup extends StatelessWidget {
  const _AreaGroup({
    required this.areaId,
    required this.shifts,
    required this.areas,
  });
  final String areaId;
  final List<Shift> shifts;
  final List areas;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final areaName = areas
            .where((a) => a.id == areaId)
            .map((a) => a.name)
            .firstOrNull ??
        areaId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Iconsax.location,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              areaName,
              style: textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final s in shifts) ...[
          Padding(
            padding: const EdgeInsets.only(left: 24, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                      children: [
                        TextSpan(
                          text: s.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(
                          text: '  ${s.startTime}–${s.endTime}',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (s.assignedUserIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 24, bottom: 8),
              child: Text(
                s.assignedUserIds.join(', '),
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ],
    );
  }
}
