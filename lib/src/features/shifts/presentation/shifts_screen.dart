import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../farms/application/farm_providers.dart';
import '../application/shift_providers.dart';
import '../domain/shift.dart';
import 'edit_shift_screen.dart';
import 'roster_widget.dart';

class ShiftsScreen extends ConsumerWidget {
  const ShiftsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) return const SizedBox.shrink();
    final shiftsAsync = ref.watch(shiftsStreamProvider(farmId));
    return Scaffold(
      appBar: AppBar(title: const Text('Shifts & Roster')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EditShiftScreen()),
        ),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const RosterWidget(),
          const SizedBox(height: 24),
          const Text(
            'All shifts',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          shiftsAsync.when(
            data: (shifts) {
              if (shifts.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'No shifts yet. Tap + to create one.',
                    ),
                  ),
                );
              }
              return Column(
                children: shifts.map((s) => _ShiftCard(shift: s)).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('$e'),
          ),
        ],
      ),
    );
  }
}

class _ShiftCard extends StatelessWidget {
  const _ShiftCard({required this.shift});
  final Shift shift;
  static const _dowLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  Widget build(BuildContext context) {
    final days = shift.pattern == ShiftPattern.daily
        ? 'Daily'
        : shift.daysOfWeek.map((d) => _dowLabels[d]).join('/');
    return Card(
      child: ListTile(
        title: Text(
          shift.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '$days · ${shift.startTime}-${shift.endTime} · '
          'area ${shift.assignedAreaId} · '
          '${shift.assignedUserIds.length} worker(s)',
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EditShiftScreen(existing: shift),
          ),
        ),
      ),
    );
  }
}
