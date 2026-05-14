// lib/src/features/sales/presentation/sale_detail_screen.dart
//
// Read-only sale detail. Header card surfaces buyer, contact, date, payment
// method/status, and totals. A "LINE ITEMS" section streams per-pig cards
// (tagId, weight, price/kg, line revenue). Optional notes appear at the
// bottom when present.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/section_header.dart';
import '../../farms/application/farm_providers.dart';
import '../application/sale_providers.dart';

class SaleDetailScreen extends ConsumerWidget {
  const SaleDetailScreen({super.key, required this.saleId});
  final String saleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final saleAsync =
        ref.watch(saleByIdProvider((farmId: farmId, saleId: saleId)));
    final linesAsync =
        ref.watch(saleLineItemsProvider((farmId: farmId, saleId: saleId)));

    return Scaffold(
      appBar: AppBar(title: const Text('Sale')),
      body: saleAsync.when(
        data: (sale) {
          if (sale == null) {
            return const Center(child: Text('Sale not found'));
          }
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
                        sale.buyerName,
                        style: theme.textTheme.headlineSmall,
                      ),
                      if (sale.buyerContact != null &&
                          sale.buyerContact!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            sale.buyerContact!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          const Icon(Iconsax.calendar, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat.yMMMd().format(sale.saleDate.toDate()),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Iconsax.money_4, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            '${sale.paymentMethod.label} · '
                            '${sale.paymentStatus.label}',
                          ),
                        ],
                      ),
                      if (sale.amountPaidPhp != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Iconsax.wallet, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Paid: ₱${sale.amountPaidPhp!.toStringAsFixed(0)}',
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text('Total', style: theme.textTheme.bodyMedium),
                          const Spacer(),
                          Text(
                            '₱${sale.totalRevenuePhp.toStringAsFixed(0)}',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${sale.totalHeads} '
                        '${sale.totalHeads == 1 ? "head" : "heads"} · '
                        '${sale.totalWeightKg.toStringAsFixed(1)} kg',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SectionHeader(title: 'LINE ITEMS'),
              linesAsync.when(
                data: (lines) {
                  if (lines.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No line items.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: lines
                        .map(
                          (l) => Card(
                            child: ListTile(
                              title: Text(
                                l.pigTagId,
                                style: theme.textTheme.titleMedium,
                              ),
                              subtitle: Text(
                                '${l.finalWeightKg.toStringAsFixed(1)} kg · '
                                '₱${l.pricePerKgPhp.toStringAsFixed(0)}/kg',
                              ),
                              trailing: Text(
                                '₱${l.lineRevenuePhp.toStringAsFixed(0)}',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('$e'),
              ),
              if (sale.notes != null && sale.notes!.isNotEmpty) ...[
                const SectionHeader(title: 'NOTES'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(sale.notes!),
                  ),
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}
