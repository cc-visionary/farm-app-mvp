import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../core/permissions/role.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../../team/application/team_providers.dart';
import '../application/equipment_providers.dart';
import '../domain/equipment.dart';
import '../domain/maintenance_record.dart';
import 'add_edit_equipment_screen.dart';
import 'log_maintenance_screen.dart';

class EquipmentDetailScreen extends ConsumerWidget {
  const EquipmentDetailScreen({super.key, required this.equipmentId});
  final String equipmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
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
        title: Text(l.equipment_detail_title),
        actions: [
          if (PermissionService.canEditEquipment(role))
            eqAsync.maybeWhen(
              data: (eq) => eq == null
                  ? const SizedBox.shrink()
                  : IconButton(
                      icon: const Icon(Iconsax.edit),
                      tooltip: l.common_edit,
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
              icon: const Icon(Iconsax.setting_4),
              label: Text(l.equipment_detail_fab_log),
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
          if (eq == null) {
            return Center(
              child: Text(
                'Not found',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          final maintList = maintAsync.asData?.value ?? const <MaintenanceRecord>[];
          final totalCost = maintList.fold<double>(
            0,
            (sum, m) => sum + (m.costPhp ?? 0),
          );
          final currencyFmt = NumberFormat.currency(
            locale: 'en_PH',
            symbol: 'PHP ',
            decimalDigits: 0,
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            children: [
              const SectionHeader(title: 'Profile'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(eq.name, style: textTheme.headlineSmall),
                      const SizedBox(height: 16),
                      StatTile(
                        label: l.equipment_form_type_label,
                        value: localizedEquipmentType(l, eq.type),
                      ),
                      StatTile(
                        label: l.equipment_form_status_label,
                        value: localizedEquipmentStatus(l, eq.status),
                      ),
                      if (eq.purchaseDate != null)
                        StatTile(
                          label: l.equipment_form_purchase_date_label,
                          value: DateFormat.yMMMd()
                              .format(eq.purchaseDate!.toDate()),
                        ),
                      if (eq.purchaseCostPhp != null)
                        StatTile(
                          label: l.equipment_form_cost_label,
                          value: currencyFmt.format(eq.purchaseCostPhp),
                        ),
                      if (eq.notes != null && eq.notes!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          eq.notes!,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SectionHeader(
                title: l.equipment_detail_maintenance_history,
                trailing: maintList.isEmpty
                    ? null
                    : Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          l.equipment_detail_total_label(
                            currencyFmt.format(totalCost),
                          ),
                          style: textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
              ),
              maintAsync.when(
                data: (list) {
                  if (list.isEmpty) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          l.equipment_detail_no_maintenance,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: list
                        .map(
                          (m) => Card(
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
                                  _iconFor(m.type.value),
                                  size: 20,
                                  color: colorScheme.primary,
                                ),
                              ),
                              title: Text(
                                localizedMaintenanceType(l, m.type),
                                style: textTheme.titleMedium,
                              ),
                              subtitle: Text(
                                DateFormat.yMMMd().format(m.date.toDate()) +
                                    (m.performedBy != null
                                        ? ' · ${m.performedBy}'
                                        : ''),
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              trailing: m.costPhp != null
                                  ? Text(
                                      currencyFmt.format(m.costPhp),
                                      style: textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text(
                  '$e',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Error: $e',
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String t) {
    switch (t) {
      case 'preventive':
        return Iconsax.tick_circle;
      case 'repair':
        return Iconsax.setting_4;
      case 'inspection':
        return Iconsax.search_normal;
      default:
        return Iconsax.info_circle;
    }
  }
}
