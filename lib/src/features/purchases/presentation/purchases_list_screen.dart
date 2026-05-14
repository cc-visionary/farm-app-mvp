import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/empty_state.dart';
import '../../farms/application/farm_providers.dart';
import '../application/purchase_providers.dart';
import 'log_purchase_screen.dart';

class PurchasesListScreen extends ConsumerWidget {
  const PurchasesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final purchasesAsync = ref.watch(purchasesStreamProvider(farmId));

    return Scaffold(
      appBar: AppBar(title: const Text('Purchases')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Iconsax.add),
        label: const Text('Log purchase'),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LogPurchaseScreen()),
        ),
      ),
      body: purchasesAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Iconsax.receipt_2,
              title: 'No purchases logged',
              subtitle:
                  'Tap "Log purchase" to record your first delivery.',
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
                    '${DateFormat.yMMMd().format(p.purchaseDate.toDate())}'
                    '${p.referenceNo != null ? " · ${p.referenceNo}" : ""}',
                  ),
                  trailing: Text(
                    '₱${p.totalCostPhp.toStringAsFixed(0)}',
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
