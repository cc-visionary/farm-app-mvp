import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/section_header.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../areas/application/area_providers.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../../team/application/team_providers.dart';
import '../application/inventory_providers.dart';
import '../domain/supply.dart';
import '../domain/supply_category.dart';

class LogConsumptionScreen extends ConsumerStatefulWidget {
  const LogConsumptionScreen({super.key, this.initialSupplyId});
  final String? initialSupplyId;
  @override
  ConsumerState<LogConsumptionScreen> createState() => _State();
}

class _State extends ConsumerState<LogConsumptionScreen> {
  String? _supplyId;
  String? _penId;
  bool _showAllPens = false;
  final _quantity = TextEditingController();
  final _notes = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _supplyId = widget.initialSupplyId;
  }

  @override
  void dispose() {
    _quantity.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final farmId = ref.read(selectedFarmIdProvider);
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return;
    if (_supplyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.consumption_log_pick_supply)),
      );
      return;
    }
    final qty = num.tryParse(_quantity.text.trim());
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.consumption_log_quantity_required)),
      );
      return;
    }
    setState(() => _busy = true);
    final actorName =
        ref.read(currentAppUserProvider).asData?.value?.displayName ?? '';
    final supply = await ref.read(
      supplyByIdProvider((farmId: farmId, supplyId: _supplyId!)).future,
    );
    if (supply == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.consumption_log_supply_not_found)),
        );
        setState(() => _busy = false);
      }
      return;
    }
    String? derivedBatchId;
    if (_penId != null) {
      derivedBatchId = ref.read(
        primaryBatchForPenProvider((farmId: farmId, penId: _penId!)),
      );
    }
    try {
      await ref.read(supplyRepositoryProvider).logConsumption(
            farmId: farmId,
            supplyId: _supplyId!,
            supplyName: supply.name,
            quantity: qty,
            penId: _penId,
            derivedBatchId: derivedBatchId,
            healthRecordId: null,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            actorUserId: user.uid,
            actorDisplayName: actorName,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) return const SizedBox.shrink();
    final user = ref.watch(authStateChangesProvider).asData?.value;
    final supplies =
        ref.watch(suppliesStreamProvider(farmId)).asData?.value ??
        const <Supply>[];
    final pens =
        ref.watch(allPensStreamProvider(farmId)).asData?.value ?? const [];
    final member = user == null
        ? null
        : ref
              .watch(
                memberForUserProvider((farmId: farmId, userId: user.uid)),
              )
              .asData
              ?.value;
    final assignedAreas = member?.assignedAreaIds ?? const <String>[];
    final visiblePens = (assignedAreas.isEmpty || _showAllPens)
        ? pens
        : pens.where((p) => assignedAreas.contains(p.areaId)).toList();

    final selectedSupply = _supplyId == null
        ? null
        : supplies.firstWhere(
            (s) => s.id == _supplyId,
            orElse: () => supplies.first,
          );
    final selectedSupplyUnitLabel = selectedSupply == null
        ? null
        : localizedSupplyUnit(l, selectedSupply.unit);

    return Scaffold(
      appBar: AppBar(title: Text(l.consumption_log_title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: l.consumption_log_supply_section,
              padding: const EdgeInsets.only(bottom: 8),
            ),
            DropdownButtonFormField<String>(
              initialValue: _supplyId,
              decoration: InputDecoration(
                hintText: l.consumption_log_supply_hint,
              ),
              items: supplies
                  .map(
                    (s) => DropdownMenuItem(
                      value: s.id,
                      child: Text(
                        '${s.name} (${s.currentStock} ${localizedSupplyUnit(l, s.unit)})',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _supplyId = v),
            ),
            SectionHeader(title: l.consumption_log_quantity_section),
            TextField(
              controller: _quantity,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: l.consumption_log_quantity_hint,
                suffixText: selectedSupplyUnitLabel,
              ),
            ),
            SectionHeader(title: l.consumption_log_pen_section),
            DropdownButtonFormField<String?>(
              initialValue: _penId,
              decoration: InputDecoration(
                hintText: l.consumption_log_pen_hint,
              ),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(l.consumption_log_pen_unattributed),
                ),
                ...visiblePens.map(
                  (p) => DropdownMenuItem(
                    value: p.id,
                    child: Text(
                      l.consumption_log_pen_with_count(
                        p.name,
                        p.currentOccupancy,
                      ),
                    ),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _penId = v),
            ),
            if (assignedAreas.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SwitchListTile(
                  title: Text(l.consumption_log_show_all_pens_title),
                  subtitle: Text(l.consumption_log_show_all_pens_subtitle),
                  value: _showAllPens,
                  onChanged: (v) => setState(() {
                    _showAllPens = v;
                    _penId = null;
                  }),
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
                  : Text(l.consumption_log_submit),
            ),
          ],
        ),
      ),
    );
  }
}
