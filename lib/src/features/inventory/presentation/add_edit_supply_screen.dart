import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/section_header.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../application/inventory_providers.dart';
import '../domain/supply.dart';
import '../domain/supply_category.dart';

class AddEditSupplyScreen extends ConsumerStatefulWidget {
  const AddEditSupplyScreen({super.key, this.existing});
  final Supply? existing;
  @override
  ConsumerState<AddEditSupplyScreen> createState() => _State();
}

class _State extends ConsumerState<AddEditSupplyScreen> {
  late final TextEditingController _name;
  late final TextEditingController _unitsPerPackage;
  late final TextEditingController _lowStock;
  late final TextEditingController _notes;
  late SupplyCategory _category;
  late SupplyUnit _unit;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _unitsPerPackage =
        TextEditingController(text: e?.unitsPerPackage?.toString() ?? '');
    _lowStock =
        TextEditingController(text: e?.lowStockThreshold?.toString() ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _category = e?.category ?? SupplyCategory.feed;
    _unit = e?.unit ?? SupplyUnit.sack;
  }

  @override
  void dispose() {
    _name.dispose();
    _unitsPerPackage.dispose();
    _lowStock.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final farmId = ref.read(selectedFarmIdProvider);
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required.')),
      );
      return;
    }
    setState(() => _busy = true);
    final repo = ref.read(supplyRepositoryProvider);
    final actorName =
        ref.read(currentAppUserProvider).asData?.value?.displayName ?? '';
    final unitsPerPackage = int.tryParse(_unitsPerPackage.text.trim());
    final lowStock = num.tryParse(_lowStock.text.trim());
    final notes = _notes.text.trim().isEmpty ? null : _notes.text.trim();
    try {
      if (widget.existing == null) {
        await repo.createSupply(
          farmId: farmId,
          name: name,
          category: _category,
          unit: _unit,
          unitsPerPackage: unitsPerPackage,
          lowStockThreshold: lowStock,
          notes: notes,
          actorUserId: user.uid,
          actorDisplayName: actorName,
        );
      } else {
        await repo.updateSupply(
          farmId: farmId,
          supplyId: widget.existing!.id,
          name: name,
          category: _category,
          unit: _unit,
          unitsPerPackage: unitsPerPackage,
          lowStockThreshold: lowStock,
          notes: notes,
        );
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New supply' : 'Edit supply'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(
              title: 'NAME',
              padding: EdgeInsets.only(bottom: 8),
            ),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                hintText: 'e.g., Pigrolac Grower',
              ),
            ),
            const SectionHeader(title: 'CATEGORY'),
            SegmentedButton<SupplyCategory>(
              segments: SupplyCategory.values
                  .map((c) => ButtonSegment(value: c, label: Text(c.label)))
                  .toList(),
              selected: {_category},
              onSelectionChanged: (s) => setState(() => _category = s.first),
            ),
            const SectionHeader(title: 'UNIT'),
            DropdownButtonFormField<SupplyUnit>(
              initialValue: _unit,
              items: SupplyUnit.values
                  .map((u) => DropdownMenuItem(value: u, child: Text(u.label)))
                  .toList(),
              onChanged: (v) => setState(() => _unit = v ?? SupplyUnit.unit),
            ),
            const SectionHeader(title: 'PACKAGE & THRESHOLDS'),
            TextField(
              controller: _unitsPerPackage,
              decoration: const InputDecoration(
                labelText: 'Units per package (optional)',
                helperText: 'e.g., 50 if a sack is 50 kg',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lowStock,
              decoration: const InputDecoration(
                labelText: 'Low-stock alert threshold (optional)',
              ),
              keyboardType: TextInputType.number,
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
                  : Text(
                      widget.existing == null ? 'Add supply' : 'Save changes',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
