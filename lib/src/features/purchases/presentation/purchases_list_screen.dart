import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/i18n/intl_helpers.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../farms/application/farm_providers.dart';
import '../application/purchase_providers.dart';
import 'log_purchase_screen.dart';

class PurchasesListScreen extends ConsumerWidget {
  const PurchasesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final purchasesAsync = ref.watch(purchasesStreamProvider(farmId));

    return Scaffold(
      appBar: AppBar(title: Text(l.purchases_list_title)),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Iconsax.add),
        label: Text(l.purchases_list_fab_log),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LogPurchaseScreen()),
        ),
      ),
      body: purchasesAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Iconsax.receipt_2,
              title: l.purchases_list_empty_title,
              subtitle: l.purchases_list_empty_subtitle,
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final p = list[i];
              return Card(
                child: ListTile(
                  title: Text(
                    p.vendorName,
                    style: theme.textTheme.titleMedium,
                  ),
                  subtitle: Text(
                    '${formatMediumDate(context, p.purchaseDate.toDate())}'
                    '${p.referenceNo != null ? " · ${p.referenceNo}" : ""}',
                  ),
                  trailing: Text(
                    formatCurrencyPhp(context, p.totalCostPhp),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}
