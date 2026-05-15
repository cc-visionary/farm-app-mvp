import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/adaptive_date_picker.dart';
import '../../../core/widgets/section_header.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../areas/application/area_providers.dart';
import '../../areas/domain/area.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../application/equipment_providers.dart';
import '../domain/equipment.dart';

class AddEditEquipmentScreen extends ConsumerStatefulWidget {
  const AddEditEquipmentScreen({super.key, this.existing});
  final Equipment? existing;
  @override
  ConsumerState<AddEditEquipmentScreen> createState() =>
      _AddEditEquipmentScreenState();
}

class _AddEditEquipmentScreenState
    extends ConsumerState<AddEditEquipmentScreen> {
  late final TextEditingController _name;
  late final TextEditingController _cost;
  late final TextEditingController _notes;
  late EquipmentType _type;
  late EquipmentStatus _status;
  String? _areaId;
  DateTime? _purchaseDate;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _cost = TextEditingController(
      text: e?.purchaseCostPhp?.toStringAsFixed(0) ?? '',
    );
    _notes = TextEditingController(text: e?.notes ?? '');
    _type = e?.type ?? EquipmentType.other;
    _status = e?.status ?? EquipmentStatus.available;
    _areaId = e?.areaId;
    _purchaseDate = e?.purchaseDate?.toDate();
  }

  @override
  void dispose() {
    _name.dispose();
    _cost.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final farmId = ref.read(selectedFarmIdProvider);
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return;

    final trimmedName = _name.text.trim();
    if (trimmedName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.equipment_form_name_required)),
      );
      return;
    }

    final costText = _cost.text.trim();
    double? cost;
    if (costText.isNotEmpty) {
      cost = double.tryParse(costText);
      if (cost == null || cost < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.common_must_be_positive),
          ),
        );
        return;
      }
    }

    setState(() => _busy = true);
    final repo = ref.read(equipmentRepositoryProvider);
    final actorName =
        ref.read(currentAppUserProvider).asData?.value?.displayName ?? '';
    final purchase =
        _purchaseDate == null ? null : Timestamp.fromDate(_purchaseDate!);
    final notesText = _notes.text.trim();
    try {
      if (widget.existing == null) {
        await repo.createEquipment(
          farmId: farmId,
          name: trimmedName,
          type: _type,
          areaId: _areaId,
          status: _status,
          purchaseDate: purchase,
          purchaseCostPhp: cost,
          photoUrl: null,
          notes: notesText.isEmpty ? null : notesText,
          actorUserId: user.uid,
          actorDisplayName: actorName,
        );
      } else {
        await repo.updateEquipment(
          farmId: farmId,
          equipmentId: widget.existing!.id,
          name: trimmedName,
          type: _type,
          areaId: _areaId,
          status: _status,
          purchaseDate: purchase,
          purchaseCostPhp: cost,
          photoUrl: widget.existing!.photoUrl,
          notes: notesText.isEmpty ? null : notesText,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final farmId = ref.watch(selectedFarmIdProvider);
    final areasAsync = farmId != null
        ? ref.watch(areasStreamProvider(farmId))
        : const AsyncValue<List<Area>>.data([]);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null
              ? l.equipment_add_title
              : l.equipment_edit_title,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(title: l.equipment_form_name_label),
            TextField(
              controller: _name,
              decoration: const InputDecoration(hintText: 'e.g. Feeder A'),
            ),
            SectionHeader(title: l.equipment_form_type_label),
            DropdownButtonFormField<EquipmentType>(
              initialValue: _type,
              decoration: const InputDecoration(),
              items: EquipmentType.values
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(localizedEquipmentType(l, t)),
                    ),
                  )
                  .toList(),
              onChanged: (v) =>
                  setState(() => _type = v ?? EquipmentType.other),
            ),
            SectionHeader(title: l.equipment_form_area_label),
            areasAsync.when(
              data: (areas) => DropdownButtonFormField<String?>(
                initialValue: _areaId,
                decoration: const InputDecoration(),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(l.equipment_form_area_none),
                  ),
                  ...areas.map(
                    (a) => DropdownMenuItem<String?>(
                      value: a.id,
                      child: Text(a.name),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _areaId = v),
              ),
              loading: () => const SizedBox.shrink(),
              error: (e, _) => Text(
                'Areas error: $e',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            ),
            SectionHeader(title: l.equipment_form_status_label),
            DropdownButtonFormField<EquipmentStatus>(
              initialValue: _status,
              decoration: const InputDecoration(),
              items: EquipmentStatus.values
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(localizedEquipmentStatus(l, s)),
                    ),
                  )
                  .toList(),
              onChanged: (v) =>
                  setState(() => _status = v ?? EquipmentStatus.available),
            ),
            SectionHeader(title: l.equipment_form_purchase_date_label),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                leading: Icon(
                  Iconsax.calendar_1,
                  color: colorScheme.onSurfaceVariant,
                ),
                title: Text(
                  _purchaseDate == null
                      ? l.equipment_form_purchase_date_none
                      : DateFormat.yMMMd().format(_purchaseDate!),
                  style: _purchaseDate == null
                      ? textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        )
                      : textTheme.titleMedium,
                ),
                trailing: Icon(
                  Iconsax.arrow_right_3,
                  color: colorScheme.onSurfaceVariant,
                ),
                onTap: () async {
                  final picked = await AdaptiveDatePicker.show(
                    context: context,
                    initial: _purchaseDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => _purchaseDate = picked);
                  }
                },
              ),
            ),
            SectionHeader(title: l.equipment_form_cost_label),
            TextField(
              controller: _cost,
              decoration: InputDecoration(hintText: l.common_optional),
              keyboardType: TextInputType.number,
            ),
            SectionHeader(title: l.equipment_form_notes_label),
            TextField(
              controller: _notes,
              decoration: InputDecoration(hintText: l.common_optional),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: colorScheme.onPrimary,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(l.equipment_form_submit),
            ),
          ],
        ),
      ),
    );
  }
}
