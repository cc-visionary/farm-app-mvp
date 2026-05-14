// lib/src/features/sales/presentation/sales_list_screen.dart
//
// Chronological list of sales (most recent first). Each card surfaces buyer,
// date, head count, total weight, total revenue, and a payment-status pill.
// An EmptyState handles the no-sales path. The FAB opens the log-sale form.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/empty_state.dart';
import '../../farms/application/farm_providers.dart';
import '../application/sale_providers.dart';
import '../domain/payment_status.dart';
import '../domain/sale.dart';
import 'log_sale_screen.dart';
import 'sale_detail_screen.dart';

class SalesListScreen extends ConsumerWidget {
  const SalesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) return const SizedBox.shrink();
    final salesAsync = ref.watch(salesStreamProvider(farmId));

    return Scaffold(
      appBar: AppBar(title: const Text('Sales')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Iconsax.add),
        label: const Text('Log sale'),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LogSaleScreen()),
        ),
      ),
      body: salesAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Iconsax.tag,
              title: 'No sales logged',
              subtitle: 'Tap "Log sale" to record your first transaction.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: list.length,
            itemBuilder: (_, i) => _SaleCard(sale: list[i]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}

class _SaleCard extends StatelessWidget {
  const _SaleCard({required this.sale});
  final Sale sale;

  Color _statusColor(BuildContext ctx, PaymentStatus s) {
    final scheme = Theme.of(ctx).colorScheme;
    switch (s) {
      case PaymentStatus.paid:
        return scheme.primary;
      case PaymentStatus.partial:
        return scheme.tertiary;
      case PaymentStatus.unpaid:
        return scheme.error;
    }
  }

  Color _onStatusColor(BuildContext ctx, PaymentStatus s) {
    final scheme = Theme.of(ctx).colorScheme;
    switch (s) {
      case PaymentStatus.paid:
        return scheme.onPrimary;
      case PaymentStatus.partial:
        return scheme.onTertiary;
      case PaymentStatus.unpaid:
        return scheme.onError;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        title: Text(sale.buyerName, style: theme.textTheme.titleMedium),
        subtitle: Text(
          '${DateFormat.yMMMd().format(sale.saleDate.toDate())} · '
          '${sale.totalHeads} ${sale.totalHeads == 1 ? "head" : "heads"} · '
          '${sale.totalWeightKg.toStringAsFixed(1)} kg',
        ),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '₱${sale.totalRevenuePhp.toStringAsFixed(0)}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _statusColor(context, sale.paymentStatus),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                sale.paymentStatus.label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: _onStatusColor(context, sale.paymentStatus),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SaleDetailScreen(saleId: sale.id),
          ),
        ),
      ),
    );
  }
}
