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
import '../../inventory/application/inventory_providers.dart';
import '../../inventory/domain/supply.dart';
import '../application/purchase_providers.dart';
import '../data/purchase_repository.dart';

class LogPurchaseScreen extends ConsumerStatefulWidget {
  const LogPurchaseScreen({super.key});

  @override
  ConsumerState<LogPurchaseScreen> createState() => _LogPurchaseScreenState();
}

class _LineRow {
  String? supplyId;
  final TextEditingController qty = TextEditingController();
  final TextEditingController unitCost = TextEditingController();

  void dispose() {
    qty.dispose();
    unitCost.dispose();
  }

  double get lineTotal {
    final q = num.tryParse(qty.text.trim()) ?? 0;
    final c = double.tryParse(unitCost.text.trim()) ?? 0;
    return (q * c).toDouble();
  }
}

class _LogPurchaseScreenState extends ConsumerState<LogPurchaseScreen> {
  final _vendor = TextEditingController();
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  DateTime _date = DateTime.now();
  final List<_LineRow> _lines = [_LineRow()];
  bool _busy = false;

  @override
  void dispose() {
    _vendor.dispose();
    _reference.dispose();
    _notes.dispose();
    for (final r in _lines) {
      r.dispose();
    }
    super.dispose();
  }

  double get _grandTotal => _lines.fold(0.0, (s, r) => s + r.lineTotal);

  void _snack(String s) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
    }
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final farmId = ref.read(selectedFarmIdProvider);
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return;

    if (_vendor.text.trim().isEmpty) {
      _snack(l.purchase_log_vendor_required);
      return;
    }

    final inputs = <PurchaseLineItemInput>[];
    for (var i = 0; i < _lines.length; i++) {
      final r = _lines[i];
      if (r.supplyId == null) {
        _snack(l.purchase_log_line_supply_required(i + 1));
        return;
      }
      final q = num.tryParse(r.qty.text.trim());
      final c = double.tryParse(r.unitCost.text.trim());
      if (q == null || q <= 0) {
        _snack(l.purchase_log_line_quantity_required(i + 1));
        return;
      }
      if (c == null || c < 0) {
        _snack(l.purchase_log_line_unit_cost_required(i + 1));
        return;
      }
      inputs.add(
        PurchaseLineItemInput(
          supplyId: r.supplyId!,
          quantity: q,
          unitCostPhp: c,
        ),
      );
    }

    setState(() => _busy = true);
    final actorName =
        ref.read(currentAppUserProvider).asData?.value?.displayName ?? '';
    try {
      await ref.read(purchaseRepositoryProvider).logPurchase(
            farmId: farmId,
            vendorName: _vendor.text,
            purchaseDate: Timestamp.fromDate(_date),
            referenceNo: _reference.text.trim().isEmpty
                ? null
                : _reference.text.trim(),
            lineItems: inputs,
            receiptPhotoUrl: null,
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
    final farmId = ref.watch(selectedFarmIdProvider);
    final supplies = farmId == null
        ? const <Supply>[]
        : ref.watch(suppliesStreamProvider(farmId)).asData?.value ??
            const <Supply>[];

    return Scaffold(
      appBar: AppBar(title: Text(l.purchase_log_title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: l.purchase_log_section_vendor,
              padding: const EdgeInsets.only(bottom: 8),
            ),
            TextField(
              controller: _vendor,
              decoration: InputDecoration(
                hintText: l.purchase_log_vendor_hint,
              ),
            ),
            SectionHeader(title: l.purchase_log_section_date),
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
            SectionHeader(title: l.purchase_log_section_reference),
            TextField(
              controller: _reference,
              decoration: InputDecoration(
                hintText: l.purchase_log_reference_hint,
              ),
            ),
            SectionHeader(title: l.purchase_log_section_line_items),
            ..._lines.asMap().entries.map((entry) {
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
                            l.purchase_log_line_number(i + 1),
                            style: theme.textTheme.labelLarge,
                          ),
                          const Spacer(),
                          if (_lines.length > 1)
                            IconButton(
                              icon: const Icon(Iconsax.trash),
                              onPressed: () => setState(() {
                                _lines.removeAt(i).dispose();
                              }),
                            ),
                        ],
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: r.supplyId,
                        decoration: InputDecoration(
                          hintText: l.purchase_log_pick_supply,
                        ),
                        items: supplies
                            .map(
                              (s) => DropdownMenuItem(
                                value: s.id,
                                child: Text(s.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => r.supplyId = v),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: r.qty,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: l.purchase_log_quantity_label,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: r.unitCost,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: l.purchase_log_unit_cost_label,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            l.purchase_log_line_total(
                              r.lineTotal.toStringAsFixed(0),
                            ),
                            style: theme.textTheme.labelLarge,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
            OutlinedButton.icon(
              icon: const Icon(Iconsax.add),
              label: Text(l.purchase_log_add_line),
              onPressed: () => setState(() => _lines.add(_LineRow())),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(
                    l.purchase_log_grand_total,
                    style: theme.textTheme.titleMedium,
                  ),
                  const Spacer(),
                  Text(
                    formatCurrencyPhp(context, _grandTotal),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            SectionHeader(title: l.supply_form_section_notes),
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
                  : Text(l.purchase_log_submit),
            ),
          ],
        ),
      ),
    );
  }
}
