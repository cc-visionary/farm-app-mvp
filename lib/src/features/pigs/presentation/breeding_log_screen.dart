import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../application/pig_providers.dart';
import '../domain/breeding_record.dart';
import '../domain/pig.dart';

class BreedingLogScreen extends ConsumerStatefulWidget {
  const BreedingLogScreen({super.key, required this.sow});
  final Pig sow;

  @override
  ConsumerState<BreedingLogScreen> createState() => _BreedingLogScreenState();
}

class _BreedingLogScreenState extends ConsumerState<BreedingLogScreen> {
  DateTime? _heatDate;
  DateTime _inseminationDate = DateTime.now();
  String? _boarId;
  BreedingMethod _method = BreedingMethod.natural;
  final _notesController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final farmId = ref.read(selectedFarmIdProvider);
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return;
    if (_boarId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a boar.')),
      );
      return;
    }
    setState(() => _busy = true);
    final actorName =
        ref.read(currentAppUserProvider).asData?.value?.displayName ?? '';
    try {
      await ref.read(breedingRepositoryProvider).logBreeding(
            farmId: farmId,
            sowId: widget.sow.id,
            sowTagId: widget.sow.tagId,
            sowAreaId: widget.sow.currentAreaId,
            boarId: _boarId!,
            heatDate:
                _heatDate == null ? null : Timestamp.fromDate(_heatDate!),
            inseminationDate: Timestamp.fromDate(_inseminationDate),
            method: _method,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            actorUserId: user.uid,
            actorDisplayName: actorName,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmId = ref.watch(selectedFarmIdProvider);
    final pigsAsync = farmId != null
        ? ref.watch(pigsStreamProvider(farmId))
        : const AsyncValue<List<Pig>>.data(<Pig>[]);
    final expected =
        _inseminationDate.add(const Duration(days: gestationDays));

    return Scaffold(
      appBar: AppBar(title: Text('Log breeding · ${widget.sow.tagId}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Heat observed (optional)'),
              subtitle: Text(
                _heatDate == null
                    ? '—'
                    : DateFormat.yMMMd().format(_heatDate!),
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final p = await showDatePicker(
                  context: context,
                  initialDate: _heatDate ?? DateTime.now(),
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now(),
                );
                if (p != null) setState(() => _heatDate = p);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Insemination date'),
              subtitle:
                  Text(DateFormat.yMMMd().format(_inseminationDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final p = await showDatePicker(
                  context: context,
                  initialDate: _inseminationDate,
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now(),
                );
                if (p != null) setState(() => _inseminationDate = p);
              },
            ),
            const SizedBox(height: 12),
            pigsAsync.when(
              data: (pigs) {
                final boars = pigs
                    .where((p) =>
                        p.sex == PigSex.male &&
                        p.stage == PigStage.boar &&
                        p.status == PigStatus.active)
                    .toList();
                return DropdownButtonFormField<String>(
                  initialValue: _boarId,
                  decoration: const InputDecoration(labelText: 'Boar'),
                  items: boars
                      .map((b) => DropdownMenuItem(
                            value: b.id,
                            child: Text(b.tagId),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _boarId = v),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e'),
            ),
            const SizedBox(height: 12),
            SegmentedButton<BreedingMethod>(
              segments: BreedingMethod.values
                  .map((m) =>
                      ButtonSegment(value: m, label: Text(m.label)))
                  .toList(),
              selected: {_method},
              onSelectionChanged: (s) => setState(() => _method = s.first),
            ),
            const SizedBox(height: 16),
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Expected farrowing: ${DateFormat.yMMMd().format(expected)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration:
                  const InputDecoration(labelText: 'Notes (optional)'),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save breeding'),
            ),
          ],
        ),
      ),
    );
  }
}
