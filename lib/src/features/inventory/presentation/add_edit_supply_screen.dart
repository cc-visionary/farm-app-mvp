import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/section_header.dart';
import '../../../l10n/generated/app_localizations.dart';
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
    final l = AppLocalizations.of(context);
    final farmId = ref.read(selectedFarmIdProvider);
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.supply_form_name_required)),
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
          actorUserId: user.uid,
          actorDisplayName: actorName,
        );
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? l.supply_add_title : l.supply_edit_title,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: l.supply_form_section_name,
              padding: const EdgeInsets.only(bottom: 8),
            ),
            TextField(
              controller: _name,
              decoration: InputDecoration(
                hintText: l.supply_form_name_hint,
              ),
            ),
            SectionHeader(title: l.supply_form_section_category),
            SegmentedButton<SupplyCategory>(
              segments: SupplyCategory.values
                  .map(
                    (c) => ButtonSegment(
                      value: c,
                      label: Text(localizedSupplyCategory(l, c)),
                    ),
                  )
                  .toList(),
              selected: {_category},
              onSelectionChanged: (s) => setState(() => _category = s.first),
            ),
            SectionHeader(title: l.supply_form_section_unit),
            DropdownButtonFormField<SupplyUnit>(
              initialValue: _unit,
              items: SupplyUnit.values
                  .map(
                    (u) => DropdownMenuItem(
                      value: u,
                      child: Text(localizedSupplyUnit(l, u)),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _unit = v ?? SupplyUnit.unit),
            ),
            SectionHeader(title: l.supply_form_section_thresholds),
            TextField(
              controller: _unitsPerPackage,
              decoration: InputDecoration(
                labelText: l.supply_form_units_per_package_label,
                helperText: l.supply_form_units_per_package_helper,
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lowStock,
              decoration: InputDecoration(
                labelText: l.supply_form_low_stock_label,
              ),
              keyboardType: TextInputType.number,
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
                  : Text(
                      widget.existing == null
                          ? l.supply_form_submit_add
                          : l.supply_form_submit_edit,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
