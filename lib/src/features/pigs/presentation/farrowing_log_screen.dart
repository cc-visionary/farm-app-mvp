import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../application/pig_providers.dart';
import '../domain/breeding_record.dart';
import '../domain/pig.dart';

class FarrowingLogScreen extends ConsumerStatefulWidget {
  const FarrowingLogScreen({
    super.key,
    required this.sow,
    required this.breedingRecord,
  });
  final Pig sow;
  final BreedingRecord breedingRecord;

  @override
  ConsumerState<FarrowingLogScreen> createState() => _FarrowingLogScreenState();
}

class _FarrowingLogScreenState extends ConsumerState<FarrowingLogScreen> {
  DateTime _date = DateTime.now();
  final _liveController = TextEditingController();
  final _stillController = TextEditingController(text: '0');
  final _mummController = TextEditingController(text: '0');
  final _weightController = TextEditingController();
  final _notesController = TextEditingController();
  bool _createBatch = true;
  bool _busy = false;

  @override
  void dispose() {
    _liveController.dispose();
    _stillController.dispose();
    _mummController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final farmId = ref.read(selectedFarmIdProvider);
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return;

    final live = int.tryParse(_liveController.text.trim());
    if (live == null || live < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Live born is required (0 or more).')),
      );
      return;
    }
    final still = int.tryParse(_stillController.text.trim()) ?? 0;
    final mumm = int.tryParse(_mummController.text.trim()) ?? 0;
    if (still < 0 || mumm < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stillborn and mummified must be 0 or more.'),
        ),
      );
      return;
    }

    setState(() => _busy = true);
    final actorName =
        ref.read(currentAppUserProvider).asData?.value?.displayName ?? '';
    try {
      await ref.read(farrowingRepositoryProvider).logFarrowing(
            farmId: farmId,
            sowId: widget.sow.id,
            sowTagId: widget.sow.tagId,
            sowAreaId: widget.sow.currentAreaId,
            sowPenId: widget.sow.currentPenId,
            breedingRecordId: widget.breedingRecord.id,
            date: Timestamp.fromDate(_date),
            liveBorn: live,
            stillborn: still,
            mummified: mumm,
            avgBirthWeightKg: double.tryParse(_weightController.text.trim()),
            createLitterBatch: _createBatch,
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
          SnackBar(content: Text('Could not save farrowing: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Farrowing · ${widget.sow.tagId}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Farrowing date'),
              subtitle: Text(DateFormat.yMMMd().format(_date)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final p = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now(),
                );
                if (p != null) setState(() => _date = p);
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _liveController,
              decoration: const InputDecoration(labelText: 'Live born'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _stillController,
              decoration: const InputDecoration(labelText: 'Stillborn'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _mummController,
              decoration: const InputDecoration(labelText: 'Mummified'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _weightController,
              decoration: const InputDecoration(
                labelText: 'Avg birth weight (kg, optional)',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Create litter batch'),
              subtitle: const Text('Tracks the piglets as a group'),
              value: _createBatch,
              onChanged: (v) => setState(() => _createBatch = v),
            ),
            const SizedBox(height: 8),
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
                  : const Text('Save farrowing'),
            ),
          ],
        ),
      ),
    );
  }
}
