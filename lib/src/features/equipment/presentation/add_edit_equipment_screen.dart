import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final farmId = ref.read(selectedFarmIdProvider);
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return;

    final trimmedName = _name.text.trim();
    if (trimmedName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Equipment name is required.')),
      );
      return;
    }

    final costText = _cost.text.trim();
    double? cost;
    if (costText.isNotEmpty) {
      cost = double.tryParse(costText);
      if (cost == null || cost < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase cost must be a non-negative number.'),
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
        );
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmId = ref.watch(selectedFarmIdProvider);
    final areasAsync = farmId != null
        ? ref.watch(areasStreamProvider(farmId))
        : const AsyncValue<List<Area>>.data([]);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New equipment' : 'Edit equipment'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<EquipmentType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: EquipmentType.values
                  .map((t) =>
                      DropdownMenuItem(value: t, child: Text(t.label)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _type = v ?? EquipmentType.other),
            ),
            const SizedBox(height: 12),
            areasAsync.when(
              data: (areas) => DropdownButtonFormField<String?>(
                initialValue: _areaId,
                decoration:
                    const InputDecoration(labelText: 'Area (optional)'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('— no area —'),
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
              error: (e, _) => Text('Areas error: $e'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<EquipmentStatus>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: EquipmentStatus.values
                  .map((s) =>
                      DropdownMenuItem(value: s, child: Text(s.label)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _status = v ?? EquipmentStatus.available),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Purchase date (optional)'),
              subtitle: Text(
                _purchaseDate?.toLocal().toString().split(' ')[0] ?? '—',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _purchaseDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => _purchaseDate = picked);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cost,
              decoration: const InputDecoration(
                labelText: 'Purchase cost (PHP, optional)',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              decoration:
                  const InputDecoration(labelText: 'Notes (optional)'),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const CircularProgressIndicator()
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
