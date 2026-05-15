// lib/src/features/sales/presentation/sale_detail_screen.dart
//
// Read-only sale detail. Header card surfaces buyer, contact, date, payment
// method/status, and totals. A "LINE ITEMS" section streams per-pig cards
// (tagId, weight, price/kg, line revenue). Optional notes appear at the
// bottom when present.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/i18n/intl_helpers.dart';
import '../../../core/widgets/section_header.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../farms/application/farm_providers.dart';
import '../application/sale_providers.dart';
import '../domain/payment_method.dart';
import '../domain/payment_status.dart';

class SaleDetailScreen extends ConsumerWidget {
  const SaleDetailScreen({super.key, required this.saleId});
  final String saleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final saleAsync =
        ref.watch(saleByIdProvider((farmId: farmId, saleId: saleId)));
    final linesAsync =
        ref.watch(saleLineItemsProvider((farmId: farmId, saleId: saleId)));

    return Scaffold(
      appBar: AppBar(title: Text(l.sale_detail_title)),
      body: saleAsync.when(
        data: (sale) {
          if (sale == null) {
            return const Center(child: SizedBox.shrink());
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
                            formatMediumDate(context, sale.saleDate.toDate()),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Iconsax.money_4, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            '${localizedPaymentMethod(l, sale.paymentMethod)} · '
                            '${localizedPaymentStatus(l, sale.paymentStatus)}',
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
                              '${l.sale_detail_amount_paid_label}: '
                              '${formatCurrencyPhp(context, sale.amountPaidPhp!)}',
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            l.sale_detail_total_label,
                            style: theme.textTheme.bodyMedium,
                          ),
                          const Spacer(),
                          Text(
                            formatCurrencyPhp(context, sale.totalRevenuePhp),
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l.sale_detail_meta_heads_weight(
                          sale.totalHeads,
                          sale.totalWeightKg.toStringAsFixed(1),
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SectionHeader(title: l.sale_detail_line_items_section),
              linesAsync.when(
                data: (lines) {
                  if (lines.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    children: lines
                        .map(
                          (li) => Card(
                            child: ListTile(
                              title: Text(
                                li.pigTagId,
                                style: theme.textTheme.titleMedium,
                              ),
                              subtitle: Text(
                                l.sale_detail_line_meta(
                                  li.finalWeightKg.toStringAsFixed(1),
                                  li.pricePerKgPhp.toStringAsFixed(0),
                                ),
                              ),
                              trailing: Text(
                                formatCurrencyPhp(
                                  context,
                                  li.lineRevenuePhp,
                                ),
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
                SectionHeader(title: l.common_notes.toUpperCase()),
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
