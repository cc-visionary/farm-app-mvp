import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/adaptive_date_picker.dart';
import '../../../core/widgets/section_header.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../application/equipment_providers.dart';
import '../domain/maintenance_record.dart';

class LogMaintenanceScreen extends ConsumerStatefulWidget {
  const LogMaintenanceScreen({super.key, required this.equipmentId});
  final String equipmentId;
  @override
  ConsumerState<LogMaintenanceScreen> createState() =>
      _LogMaintenanceScreenState();
}

class _LogMaintenanceScreenState extends ConsumerState<LogMaintenanceScreen> {
  final _performedBy = TextEditingController();
  final _parts = TextEditingController();
  final _cost = TextEditingController();
  final _notes = TextEditingController();
  MaintenanceType _type = MaintenanceType.repair;
  DateTime _date = DateTime.now();
  bool _busy = false;

  @override
  void dispose() {
    _performedBy.dispose();
    _parts.dispose();
    _cost.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final farmId = ref.read(selectedFarmIdProvider);
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return;

    final costText = _cost.text.trim();
    double? cost;
    if (costText.isNotEmpty) {
      cost = double.tryParse(costText);
      if (cost == null || cost < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cost must be a non-negative number.'),
          ),
        );
        return;
      }
    }

    setState(() => _busy = true);
    final repo = ref.read(equipmentRepositoryProvider);
    final actorName =
        ref.read(currentAppUserProvider).asData?.value?.displayName ?? '';
    final eq = await ref.read(
      equipmentByIdProvider(
        (farmId: farmId, equipmentId: widget.equipmentId),
      ).future,
    );
    if (eq == null) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Equipment no longer exists.')),
        );
      }
      return;
    }
    try {
      await repo.logMaintenance(
        farmId: farmId,
        equipmentId: widget.equipmentId,
        equipmentName: eq.name,
        type: _type,
        date: Timestamp.fromDate(_date),
        performedBy:
            _performedBy.text.trim().isEmpty ? null : _performedBy.text.trim(),
        partsReplaced:
            _parts.text.trim().isEmpty ? null : _parts.text.trim(),
        costPhp: cost,
        photoUrls: const [], // Photo capture comes in Task 7.
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        actorUserId: user.uid,
        actorDisplayName: actorName,
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Log maintenance')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(title: 'Type'),
            SegmentedButton<MaintenanceType>(
              segments: MaintenanceType.values
                  .map(
                    (t) => ButtonSegment(value: t, label: Text(t.label)),
                  )
                  .toList(),
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SectionHeader(title: 'Date'),
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
                  DateFormat.yMMMd().format(_date),
                  style: textTheme.titleMedium,
                ),
                trailing: Icon(
                  Iconsax.arrow_right_3,
                  color: colorScheme.onSurfaceVariant,
                ),
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
            ),
            const SectionHeader(title: 'Performed by'),
            TextField(
              controller: _performedBy,
              decoration:
                  const InputDecoration(hintText: 'Technician name (optional)'),
            ),
            const SectionHeader(title: 'Parts replaced'),
            TextField(
              controller: _parts,
              decoration: const InputDecoration(hintText: 'Optional'),
            ),
            const SectionHeader(title: 'Cost (PHP)'),
            TextField(
              controller: _cost,
              decoration: const InputDecoration(hintText: 'Optional'),
              keyboardType: TextInputType.number,
            ),
            const SectionHeader(title: 'Notes'),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(hintText: 'Optional'),
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
                  : const Text('Save maintenance'),
            ),
          ],
        ),
      ),
    );
  }
}
