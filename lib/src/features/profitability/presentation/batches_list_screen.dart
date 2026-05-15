// lib/src/features/profitability/presentation/batches_list_screen.dart
//
// Lists every batch (active + closed) for the selected farm. Tapping a row
// opens the per-batch profitability detail screen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../farms/application/farm_providers.dart';
import '../../pigs/application/pig_providers.dart';
import '../../pigs/domain/batch.dart';
import 'batch_profitability_screen.dart';

class BatchesListScreen extends ConsumerWidget {
  const BatchesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) return const SizedBox.shrink();
    final batchesAsync = ref.watch(batchesStreamProvider(farmId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.batches_list_title)),
      body: batchesAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Iconsax.element_3,
              title: l.batches_list_empty_title,
              subtitle: l.batches_list_empty_subtitle,
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final b = list[i];
              final base =
                  l.batch_card_subtitle(localizedBatchType(l, b.type), b.count);
              final subtitle = b.status == BatchStatus.active
                  ? base
                  : '$base · ${localizedBatchStatus(l, b.status)}';
              return Card(
                child: ListTile(
                  title: Text(b.name, style: theme.textTheme.titleMedium),
                  subtitle: Text(subtitle),
                  trailing: const Icon(Iconsax.arrow_right_3),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          BatchProfitabilityScreen(batchId: b.id),
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
