import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Log maintenance')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<MaintenanceType>(
              segments: MaintenanceType.values
                  .map(
                    (t) => ButtonSegment(value: t, label: Text(t.label)),
                  )
                  .toList(),
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text(_date.toLocal().toString().split(' ')[0]),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            TextField(
              controller: _performedBy,
              decoration: const InputDecoration(
                labelText: 'Performed by (technician name, optional)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _parts,
              decoration: const InputDecoration(
                labelText: 'Parts replaced (optional)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cost,
              decoration: const InputDecoration(
                labelText: 'Cost (PHP, optional)',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes'),
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
