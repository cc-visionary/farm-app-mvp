// lib/src/features/sales/presentation/log_sale_screen.dart
//
// Multi-pig sale entry form. Sections: BUYER / DATE / PIGS IN SALE /
// PAYMENT / NOTES. The "Add pigs" button opens a DraggableScrollableSheet
// with a search-filterable multi-select over active grower/finisher pigs;
// newly added rows pre-fill weight from `pig.currentWeight` and inherit the
// first row's price/kg (the "apply first price to all" UX). Live totals
// (heads · weight · revenue) update on every edit. Each row has a delete
// icon. Payment method uses a SegmentedButton, status uses ChoiceChips; the
// amount-paid field appears only when status is `partial`. Save validates
// inputs (buyer non-empty, at least one pig, weight & price positive, and
// partial-payment within bounds), then calls `SaleRepository.logSale`.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/i18n/intl_helpers.dart';
import '../../../core/widgets/adaptive_date_picker.dart';
import '../../../core/widgets/section_header.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../../pigs/application/pig_providers.dart';
import '../../pigs/domain/pig.dart';
import '../application/sale_providers.dart';
import '../data/sale_repository.dart';
import '../domain/payment_method.dart';
import '../domain/payment_status.dart';

/// A single pig row in the log-sale form. Owns its own weight + price
/// controllers; the form is responsible for calling [dispose] for each row
/// when removed and at form teardown.
class _PigRow {
  _PigRow({
    required this.pig,
    required this.weight,
    required this.pricePerKg,
  });
  final Pig pig;
  final TextEditingController weight;
  final TextEditingController pricePerKg;

  void dispose() {
    weight.dispose();
    pricePerKg.dispose();
  }

  double get lineRevenue {
    final w = double.tryParse(weight.text.trim()) ?? 0;
    final p = double.tryParse(pricePerKg.text.trim()) ?? 0;
    return w * p;
  }
}

class LogSaleScreen extends ConsumerStatefulWidget {
  const LogSaleScreen({super.key});

  @override
  ConsumerState<LogSaleScreen> createState() => _LogSaleScreenState();
}

class _LogSaleScreenState extends ConsumerState<LogSaleScreen> {
  final _buyer = TextEditingController();
  final _contact = TextEditingController();
  final _notes = TextEditingController();
  final _amountPaid = TextEditingController();
  DateTime _date = DateTime.now();
  PaymentMethod _method = PaymentMethod.cash;
  PaymentStatus _status = PaymentStatus.paid;
  final List<_PigRow> _rows = [];
  bool _busy = false;

  @override
  void dispose() {
    _buyer.dispose();
    _contact.dispose();
    _notes.dispose();
    _amountPaid.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  double get _totalRevenue =>
      _rows.fold(0.0, (s, r) => s + r.lineRevenue);

  double get _totalWeight => _rows.fold(
        0.0,
        (s, r) => s + (double.tryParse(r.weight.text.trim()) ?? 0),
      );

  void _snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  Future<void> _addPigs() async {
    final l = AppLocalizations.of(context);
    final farmId = ref.read(selectedFarmIdProvider);
    if (farmId == null) return;
    final allPigs =
        ref.read(pigsStreamProvider(farmId)).asData?.value ?? const <Pig>[];
    final addedIds = _rows.map((r) => r.pig.id).toSet();
    final pool = allPigs
        .where(
          (p) =>
              p.status == PigStatus.active &&
              (p.stage == PigStage.grower ||
                  p.stage == PigStage.finisher) &&
              !addedIds.contains(p.id),
        )
        .toList();
    if (pool.isEmpty) {
      _snack(l.sale_log_no_eligible_pigs);
      return;
    }
    final picked = await showModalBottomSheet<List<Pig>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _PigPicker(pool: pool),
    );
    if (picked == null || picked.isEmpty) return;
    // "Apply first price to all" UX: when there's already at least one
    // row, new rows inherit the first row's current price/kg text.
    final defaultPrice =
        _rows.isNotEmpty ? _rows.first.pricePerKg.text : '';
    setState(() {
      for (final p in picked) {
        _rows.add(
          _PigRow(
            pig: p,
            weight: TextEditingController(
              text: p.currentWeight?.toStringAsFixed(1) ?? '',
            ),
            pricePerKg: TextEditingController(text: defaultPrice),
          ),
        );
      }
    });
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final farmId = ref.read(selectedFarmIdProvider);
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return;

    final buyer = _buyer.text.trim();
    if (buyer.isEmpty) {
      _snack(l.sale_log_buyer_required);
      return;
    }
    if (_rows.isEmpty) {
      _snack(l.sale_log_pigs_required);
      return;
    }

    final inputs = <SaleLineItemInput>[];
    for (final r in _rows) {
      final w = double.tryParse(r.weight.text.trim());
      final p = double.tryParse(r.pricePerKg.text.trim());
      if (w == null || w <= 0) {
        _snack(l.sale_log_weight_required(r.pig.tagId));
        return;
      }
      if (p == null || p <= 0) {
        _snack(l.sale_log_price_required(r.pig.tagId));
        return;
      }
      inputs.add(
        SaleLineItemInput(
          pigId: r.pig.id,
          pigTagId: r.pig.tagId,
          finalWeightKg: w,
          pricePerKgPhp: p,
        ),
      );
    }

    double? paid;
    if (_status == PaymentStatus.partial) {
      paid = double.tryParse(_amountPaid.text.trim());
      if (paid == null || paid <= 0 || paid >= _totalRevenue) {
        _snack(l.sale_log_partial_amount_invalid);
        return;
      }
    }

    setState(() => _busy = true);
    final actorName =
        ref.read(currentAppUserProvider).asData?.value?.displayName ?? '';
    try {
      await ref.read(saleRepositoryProvider).logSale(
            farmId: farmId,
            buyerName: buyer,
            buyerContact:
                _contact.text.trim().isEmpty ? null : _contact.text.trim(),
            saleDate: Timestamp.fromDate(_date),
            paymentMethod: _method,
            paymentStatus: _status,
            amountPaidPhp: paid,
            lineItems: inputs,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            actorUserId: user.uid,
            actorDisplayName: actorName,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.sale_log_title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: l.sale_log_section_buyer,
              padding: const EdgeInsets.only(bottom: 8),
            ),
            TextField(
              controller: _buyer,
              decoration: InputDecoration(hintText: l.sale_log_buyer_hint),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contact,
              decoration:
                  InputDecoration(hintText: l.sale_log_buyer_contact_hint),
            ),
            SectionHeader(title: l.sale_log_section_date),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(formatMediumDate(context, _date)),
              trailing: const Icon(Iconsax.calendar),
              onTap: () async {
                final picked = await AdaptiveDatePicker.show(
                  context: context,
                  initial: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            SectionHeader(title: l.sale_log_section_pigs),
            ..._rows.asMap().entries.map((entry) {
              final i = entry.key;
              final r = entry.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            r.pig.tagId,
                            style: theme.textTheme.titleMedium,
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Iconsax.trash),
                            tooltip: l.common_remove,
                            onPressed: () => setState(() {
                              _rows.removeAt(i).dispose();
                            }),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: r.weight,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                labelText: l.sale_log_row_weight_label,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: r.pricePerKg,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                labelText: l.sale_log_row_price_label,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          l.sale_log_row_line(
                            r.lineRevenue.toStringAsFixed(0),
                          ),
                          style: theme.textTheme.labelLarge,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            OutlinedButton.icon(
              icon: const Icon(Iconsax.add),
              label: Text(l.sale_log_add_pigs),
              onPressed: _addPigs,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        l.sale_log_totals_heads_weight(
                          _rows.length,
                          _totalWeight.toStringAsFixed(1),
                        ),
                        style: theme.textTheme.bodyMedium,
                      ),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        l.sale_log_total_revenue_label,
                        style: theme.textTheme.titleMedium,
                      ),
                      const Spacer(),
                      Text(
                        formatCurrencyPhp(context, _totalRevenue),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SectionHeader(title: l.sale_log_section_payment),
            SizedBox(
              width: double.infinity,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<PaymentMethod>(
                  segments: PaymentMethod.values
                      .map(
                        (m) => ButtonSegment(
                          value: m,
                          label: Text(localizedPaymentMethod(l, m)),
                        ),
                      )
                      .toList(),
                  selected: {_method},
                  onSelectionChanged: (s) =>
                      setState(() => _method = s.first),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: PaymentStatus.values
                  .map(
                    (s) => ChoiceChip(
                      label: Text(localizedPaymentStatus(l, s)),
                      selected: _status == s,
                      onSelected: (_) => setState(() => _status = s),
                    ),
                  )
                  .toList(),
            ),
            if (_status == PaymentStatus.partial) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _amountPaid,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l.sale_log_amount_paid_label,
                ),
              ),
            ],
            SectionHeader(title: l.common_notes.toUpperCase()),
            TextField(controller: _notes, maxLines: 3),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Text(l.sale_log_submit),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal bottom sheet that lets the user multi-select pigs from a pre-
/// filtered pool (active grower/finisher pigs not already in the sale).
class _PigPicker extends StatefulWidget {
  const _PigPicker({required this.pool});
  final List<Pig> pool;

  @override
  State<_PigPicker> createState() => _PigPickerState();
}

class _PigPickerState extends State<_PigPicker> {
  final Set<String> _selected = {};
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final query = _search.trim().toLowerCase();
    final filtered = query.isEmpty
        ? widget.pool
        : widget.pool
            .where((p) => p.tagId.toLowerCase().contains(query))
            .toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, scroll) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  l.sale_log_picker_title,
                  style: theme.textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () {
                          Navigator.of(context).pop(
                            widget.pool
                                .where((p) => _selected.contains(p.id))
                                .toList(),
                          );
                        },
                  child: Text(
                    l.sale_log_picker_add_button(_selected.length),
                  ),
                ),
              ],
            ),
            TextField(
              decoration: InputDecoration(
                hintText: l.sale_log_picker_search_hint,
                prefixIcon: const Icon(Iconsax.search_normal),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        l.pigs_list_no_match_title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: scroll,
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final p = filtered[i];
                        return CheckboxListTile(
                          title: Text(p.tagId),
                          subtitle: Text(
                            l.sale_log_picker_subtitle(
                              localizedPigStage(l, p.stage),
                              p.currentWeight?.toStringAsFixed(1) ?? '—',
                            ),
                          ),
                          value: _selected.contains(p.id),
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _selected.add(p.id);
                            } else {
                              _selected.remove(p.id);
                            }
                          }),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
