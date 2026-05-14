import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/widgets/adaptive_date_picker.dart';
import '../../../core/widgets/section_header.dart';
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
    final farmId = ref.read(selectedFarmIdProvider);
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return;

    if (_vendor.text.trim().isEmpty) {
      _snack('Vendor name is required.');
      return;
    }

    final inputs = <PurchaseLineItemInput>[];
    for (var i = 0; i < _lines.length; i++) {
      final r = _lines[i];
      if (r.supplyId == null) {
        _snack('Line ${i + 1}: supply not picked.');
        return;
      }
      final q = num.tryParse(r.qty.text.trim());
      final c = double.tryParse(r.unitCost.text.trim());
      if (q == null || q <= 0) {
        _snack('Line ${i + 1}: quantity must be positive.');
        return;
      }
      if (c == null || c < 0) {
        _snack('Line ${i + 1}: unit cost must be a number.');
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
    final theme = Theme.of(context);
    final farmId = ref.watch(selectedFarmIdProvider);
    final supplies = farmId == null
        ? const <Supply>[]
        : ref.watch(suppliesStreamProvider(farmId)).asData?.value ??
            const <Supply>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Log purchase')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(
              title: 'VENDOR',
              padding: EdgeInsets.only(bottom: 8),
            ),
            TextField(
              controller: _vendor,
              decoration: const InputDecoration(
                hintText: 'Who you bought from',
              ),
            ),
            const SectionHeader(title: 'PURCHASE DATE'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
              ),
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
            const SectionHeader(title: 'REFERENCE'),
            TextField(
              controller: _reference,
              decoration: const InputDecoration(
                hintText: 'Receipt or invoice no. (optional)',
              ),
            ),
            const SectionHeader(title: 'LINE ITEMS'),
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
                            'Line ${i + 1}',
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
                        decoration: const InputDecoration(
                          hintText: 'Pick supply',
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
                              decoration: const InputDecoration(
                                labelText: 'Quantity',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: r.unitCost,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Unit cost ₱',
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
                            'Line: ₱${r.lineTotal.toStringAsFixed(0)}',
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
              label: const Text('Add line'),
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
                    'Grand total',
                    style: theme.textTheme.titleMedium,
                  ),
                  const Spacer(),
                  Text(
                    '₱${_grandTotal.toStringAsFixed(0)}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SectionHeader(title: 'NOTES'),
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
                  : const Text('Save purchase'),
            ),
          ],
        ),
      ),
    );
  }
}
