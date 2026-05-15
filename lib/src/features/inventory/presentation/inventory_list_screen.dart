import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/i18n/intl_helpers.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../core/permissions/role.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../../team/application/team_providers.dart';
import '../application/inventory_providers.dart';
import '../domain/supply.dart';
import '../domain/supply_category.dart';
import 'add_edit_supply_screen.dart';
import 'supply_detail_screen.dart';

enum _StockFilter { all, low, out }

class InventoryListScreen extends ConsumerStatefulWidget {
  const InventoryListScreen({super.key});
  @override
  ConsumerState<InventoryListScreen> createState() =>
      _InventoryListScreenState();
}

class _InventoryListScreenState extends ConsumerState<InventoryListScreen> {
  _StockFilter _filter = _StockFilter.all;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final farmId = ref.watch(selectedFarmIdProvider);
    final user = ref.watch(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return const SizedBox.shrink();

    final role =
        ref
            .watch(
              memberForUserProvider((farmId: farmId, userId: user.uid)),
            )
            .asData
            ?.value
            ?.role ??
        Role.worker;
    final canEdit = PermissionService.canEditEquipment(role);
    final suppliesAsync = ref.watch(suppliesStreamProvider(farmId));

    return Scaffold(
      appBar: AppBar(title: Text(l.inventory_list_title)),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              icon: const Icon(Iconsax.add),
              label: Text(l.inventory_fab_add),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddEditSupplyScreen(),
                ),
              ),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: Text(l.inventory_filter_all),
                  selected: _filter == _StockFilter.all,
                  onSelected: (_) =>
                      setState(() => _filter = _StockFilter.all),
                ),
                FilterChip(
                  label: Text(l.inventory_filter_low),
                  selected: _filter == _StockFilter.low,
                  onSelected: (_) =>
                      setState(() => _filter = _StockFilter.low),
                ),
                FilterChip(
                  label: Text(l.inventory_filter_out),
                  selected: _filter == _StockFilter.out,
                  onSelected: (_) =>
                      setState(() => _filter = _StockFilter.out),
                ),
              ],
            ),
          ),
          Expanded(
            child: suppliesAsync.when(
              data: (supplies) {
                final filtered = supplies.where((s) {
                  switch (_filter) {
                    case _StockFilter.all:
                      return true;
                    case _StockFilter.low:
                      return s.isLowStock;
                    case _StockFilter.out:
                      return s.isOutOfStock;
                  }
                }).toList();
                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Iconsax.box,
                    title: supplies.isEmpty
                        ? l.inventory_empty_title
                        : l.inventory_no_match_title,
                    subtitle: supplies.isEmpty
                        ? l.inventory_empty_subtitle
                        : l.inventory_no_match_subtitle,
                  );
                }
                final byCategory = <SupplyCategory, List<Supply>>{};
                for (final s in filtered) {
                  byCategory.putIfAbsent(s.category, () => []).add(s);
                }
                final cats = byCategory.keys.toList()
                  ..sort((a, b) => a.index.compareTo(b.index));
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  itemCount: cats.length,
                  itemBuilder: (_, i) {
                    final c = cats[i];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionHeader(
                          title: localizedSupplyCategory(l, c).toUpperCase(),
                        ),
                        ...byCategory[c]!.map(
                          (s) => _SupplyCard(supply: s),
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

class _SupplyCard extends StatelessWidget {
  const _SupplyCard({required this.supply});
  final Supply supply;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unitLabel = localizedSupplyUnit(l, supply.unit);
    String pillLabel;
    Color pillFg;
    Color pillBg;
    if (supply.isOutOfStock) {
      pillLabel = l.inventory_status_out;
      pillFg = scheme.onError;
      pillBg = scheme.error;
    } else if (supply.isLowStock) {
      pillLabel = l.inventory_status_low;
      pillFg = scheme.onTertiary;
      pillBg = scheme.tertiary;
    } else {
      pillLabel = l.inventory_status_ok;
      pillFg = scheme.onPrimary;
      pillBg = scheme.primary;
    }

    return Card(
      child: ListTile(
        title: Text(supply.name, style: theme.textTheme.titleMedium),
        subtitle: Text(
          '${formatDecimal(context, supply.currentStock)} $unitLabel'
          '${supply.weightedAvgUnitCostPhp > 0 ? ' · ${formatCurrencyPhp(context, supply.weightedAvgUnitCostPhp)} / $unitLabel' : ''}',
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: pillBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            pillLabel,
            style: theme.textTheme.labelMedium?.copyWith(
              color: pillFg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SupplyDetailScreen(supplyId: supply.id),
          ),
        ),
      ),
    );
  }
}
