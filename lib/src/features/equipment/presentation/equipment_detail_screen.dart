import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../core/permissions/role.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../../team/application/team_providers.dart';
import '../application/equipment_providers.dart';
import 'add_edit_equipment_screen.dart';
import 'log_maintenance_screen.dart';

class EquipmentDetailScreen extends ConsumerWidget {
  const EquipmentDetailScreen({super.key, required this.equipmentId});
  final String equipmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmId = ref.watch(selectedFarmIdProvider);
    final user = ref.watch(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return const SizedBox.shrink();
    final eqAsync = ref.watch(
      equipmentByIdProvider((farmId: farmId, equipmentId: equipmentId)),
    );
    final maintAsync = ref.watch(
      maintenanceStreamProvider((farmId: farmId, equipmentId: equipmentId)),
    );
    final role = ref
            .watch(memberForUserProvider((farmId: farmId, userId: user.uid)))
            .asData
            ?.value
            ?.role ??
        Role.worker;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Equipment'),
        actions: [
          if (PermissionService.canEditEquipment(role))
            eqAsync.maybeWhen(
              data: (eq) => eq == null
                  ? const SizedBox.shrink()
                  : IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AddEditEquipmentScreen(existing: eq),
                        ),
                      ),
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
        ],
      ),
      floatingActionButton: PermissionService.canLogMaintenance(role)
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.build),
              label: const Text('Log maintenance'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      LogMaintenanceScreen(equipmentId: equipmentId),
                ),
              ),
            )
          : null,
      body: eqAsync.when(
        data: (eq) {
          if (eq == null) return const Center(child: Text('Not found'));
          final maintList = maintAsync.asData?.value ?? const [];
          final totalCost = maintList.fold<double>(
            0,
            (sum, m) => sum + (m.costPhp ?? 0),
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eq.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text('Type: ${eq.type.label}'),
                      Text('Status: ${eq.status.label}'),
                      if (eq.purchaseDate != null)
                        Text(
                          'Purchased: ${DateFormat.yMMMd().format(eq.purchaseDate!.toDate())}',
                        ),
                      if (eq.purchaseCostPhp != null)
                        Text(
                          'Purchase cost: PHP ${eq.purchaseCostPhp!.toStringAsFixed(0)}',
                        ),
                      if (eq.notes != null) ...[
                        const SizedBox(height: 8),
                        Text(eq.notes!),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    'Maintenance history',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text('Total: PHP ${totalCost.toStringAsFixed(0)}'),
                ],
              ),
              const SizedBox(height: 8),
              maintAsync.when(
                data: (list) {
                  if (list.isEmpty) {
                    return const Text('No maintenance logged yet.');
                  }
                  return Column(
                    children: list
                        .map(
                          (m) => Card(
                            child: ListTile(
                              leading: Icon(_iconFor(m.type.value)),
                              title: Text(m.type.label),
                              subtitle: Text(
                                DateFormat.yMMMd().format(m.date.toDate()) +
                                    (m.performedBy != null
                                        ? ' - ${m.performedBy}'
                                        : ''),
                              ),
                              trailing: m.costPhp != null
                                  ? Text(
                                      'PHP ${m.costPhp!.toStringAsFixed(0)}',
                                    )
                                  : null,
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('$e'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  IconData _iconFor(String t) {
    switch (t) {
      case 'preventive':
        return Icons.check_circle;
      case 'repair':
        return Icons.build;
      case 'inspection':
        return Icons.visibility;
      default:
        return Icons.help_outline;
    }
  }
}
