import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/adaptive_date_picker.dart';
import '../../../core/widgets/section_header.dart';
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    return Scaffold(
      appBar: AppBar(title: Text('Farrowing · ${widget.sow.tagId}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(title: 'Farrowing date'),
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
                  final p = await AdaptiveDatePicker.show(
                    context: context,
                    initial: _date,
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now(),
                  );
                  if (p != null) setState(() => _date = p);
                },
              ),
            ),
            const SectionHeader(title: 'Counts'),
            TextField(
              controller: _liveController,
              decoration: const InputDecoration(labelText: 'Live born'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _stillController,
              decoration: const InputDecoration(labelText: 'Stillborn'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _mummController,
              decoration: const InputDecoration(labelText: 'Mummified'),
              keyboardType: TextInputType.number,
            ),
            const SectionHeader(title: 'Average birth weight'),
            TextField(
              controller: _weightController,
              decoration: const InputDecoration(hintText: 'kg (optional)'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                title: Text(
                  'Create litter batch',
                  style: textTheme.titleMedium,
                ),
                subtitle: Text(
                  'Tracks the piglets as a group',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                value: _createBatch,
                onChanged: (v) => setState(() => _createBatch = v),
              ),
            ),
            const SectionHeader(title: 'Notes'),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(hintText: 'Optional'),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: colorScheme.onPrimary,
                      ),
                    )
                  : const Text('Save farrowing'),
            ),
          ],
        ),
      ),
    );
  }
}
