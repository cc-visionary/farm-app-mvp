import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../farms/application/farm_providers.dart';
import '../application/shift_providers.dart';
import '../domain/shift.dart';
import 'edit_shift_screen.dart';
import 'roster_widget.dart';

class ShiftsScreen extends ConsumerWidget {
  const ShiftsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) return const SizedBox.shrink();
    final shiftsAsync = ref.watch(shiftsStreamProvider(farmId));
    return Scaffold(
      appBar: AppBar(title: Text(l.shifts_screen_title)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EditShiftScreen()),
        ),
        icon: const Icon(Iconsax.add),
        label: Text(l.shift_add_title),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          const RosterWidget(),
          SectionHeader(title: l.shifts_section_all_shifts),
          shiftsAsync.when(
            data: (shifts) {
              if (shifts.isEmpty) {
                return EmptyState(
                  icon: Iconsax.calendar,
                  title: 'No shifts yet',
                  subtitle:
                      'Create a shift to assign workers to areas and track who is on duty.',
                  action: FilledButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EditShiftScreen(),
                      ),
                    ),
                    icon: const Icon(Iconsax.add),
                    label: Text(l.shift_add_title),
                  ),
                );
              }
              return Column(
                children: shifts.map((s) => _ShiftCard(shift: s)).toList(),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text(
              '$e',
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShiftCard extends StatelessWidget {
  const _ShiftCard({required this.shift});
  final Shift shift;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final daysSet = shift.pattern == ShiftPattern.daily
        ? {0, 1, 2, 3, 4, 5, 6}
        : shift.daysOfWeek.toSet();
    final dowLabels = shiftDowLabels(l);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EditShiftScreen(existing: shift),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Iconsax.calendar,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(shift.name, style: textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          '${shift.startTime}–${shift.endTime} · '
                          '${shift.assignedUserIds.length} worker${shift.assignedUserIds.length == 1 ? "" : "s"}',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: List.generate(7, (i) {
                  final on = daysSet.contains(i);
                  return Container(
                    width: 28,
                    height: 28,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: on
                          ? colorScheme.primary
                          : colorScheme.surfaceContainerHigh,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      dowLabels[i],
                      style: textTheme.labelMedium?.copyWith(
                        color: on
                            ? colorScheme.onPrimary
                            : colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
