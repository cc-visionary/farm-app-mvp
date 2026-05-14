import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../../core/permissions/permission_service.dart';
import '../../../core/permissions/role.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../../team/application/team_providers.dart';
import '../application/inventory_providers.dart';
import '../domain/supply.dart';
import '../domain/supply_category.dart';
import '../domain/supply_movement.dart';
import 'add_edit_supply_screen.dart';

class SupplyDetailScreen extends ConsumerWidget {
  const SupplyDetailScreen({super.key, required this.supplyId});
  final String supplyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmId = ref.watch(selectedFarmIdProvider);
    final user = ref.watch(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return const SizedBox.shrink();
    final role = ref
            .watch(
              memberForUserProvider((farmId: farmId, userId: user.uid)),
            )
            .asData
            ?.value
            ?.role ??
        Role.worker;
    final canEdit = PermissionService.canEditEquipment(role);
    final supplyAsync = ref.watch(
      supplyByIdProvider((farmId: farmId, supplyId: supplyId)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Supply'),
        actions: [
          if (canEdit)
            supplyAsync.maybeWhen(
              data: (s) => s == null
                  ? const SizedBox.shrink()
                  : IconButton(
                      icon: const Icon(Iconsax.edit),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddEditSupplyScreen(existing: s),
                        ),
                      ),
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
        ],
      ),
      body: supplyAsync.when(
        data: (s) {
          if (s == null) return const Center(child: Text('Not found'));
          return _SupplyDetailBody(supply: s);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _SupplyDetailBody extends ConsumerWidget {
  const _SupplyDetailBody({required this.supply});
  final Supply supply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final formatter = NumberFormat.decimalPattern('en_PH');
    final movementsAsync = ref.watch(
      movementsForSupplyProvider(
        (farmId: supply.farmId, supplyId: supply.id),
      ),
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
                Text(supply.name, style: theme.textTheme.headlineSmall),
                Text(
                  '${supply.category.label} · ${supply.unit.label}',
                  style: theme.textTheme.bodyMedium,
                ),
                const Divider(height: 24),
                Text('Current stock', style: theme.textTheme.bodyMedium),
                Text(
                  '${formatter.format(supply.currentStock)} ${supply.unit.label}',
                  style: theme.textTheme.headlineLarge,
                ),
                if (supply.weightedAvgUnitCostPhp > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Weighted avg: ₱${supply.weightedAvgUnitCostPhp.toStringAsFixed(2)} / ${supply.unit.label}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
                if (supply.lowStockThreshold != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Low-stock alert at ${formatter.format(supply.lowStockThreshold!)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SectionHeader(title: 'STOCK HISTORY'),
        movementsAsync.when(
          data: (list) {
            if (list.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: EmptyState(
                  icon: Iconsax.box,
                  title: 'No movements yet',
                  subtitle:
                      'Stock changes will appear here once you log a purchase or consumption.',
                ),
              );
            }
            return Column(
              children: list.map((m) => _MovementCard(movement: m)).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('$e'),
        ),
      ],
    );
  }
}

class _MovementCard extends StatelessWidget {
  const _MovementCard({required this.movement});
  final SupplyMovement movement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isInflow = movement.quantity > 0;
    final color = switch (movement.type) {
      MovementType.purchase => scheme.primary,
      MovementType.consumption => scheme.onSurfaceVariant,
      MovementType.adjustment => scheme.tertiary,
      MovementType.wastage => scheme.error,
    };
    final icon = switch (movement.type) {
      MovementType.purchase => Iconsax.arrow_down_2,
      MovementType.consumption => Iconsax.arrow_up_3,
      MovementType.adjustment => Iconsax.refresh,
      MovementType.wastage => Icons.delete_outline,
    };
    final formatter = NumberFormat.decimalPattern('en_PH');
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(movement.type.label),
        subtitle: Text(
          DateFormat.yMMMd().add_jm().format(movement.createdAt.toDate()),
        ),
        trailing: Text(
          '${isInflow ? '+' : ''}${formatter.format(movement.quantity)}',
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
