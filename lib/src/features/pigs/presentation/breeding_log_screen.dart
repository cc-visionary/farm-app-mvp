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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final farmId = ref.watch(selectedFarmIdProvider);
    final pigsAsync = farmId != null
        ? ref.watch(pigsStreamProvider(farmId))
        : const AsyncValue<List<Pig>>.data(<Pig>[]);
    final expected =
        _inseminationDate.add(const Duration(days: gestationDays));

    Widget dateTile({
      required IconData icon,
      required String text,
      required VoidCallback onTap,
      bool isHint = false,
    }) =>
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: Icon(icon, color: colorScheme.onSurfaceVariant),
            title: Text(
              text,
              style: isHint
                  ? textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    )
                  : textTheme.titleMedium,
            ),
            trailing: Icon(
              Iconsax.arrow_right_3,
              color: colorScheme.onSurfaceVariant,
            ),
            onTap: onTap,
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text('Log breeding · ${widget.sow.tagId}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(title: 'Heat observed'),
            dateTile(
              icon: Iconsax.calendar_1,
              text: _heatDate == null
                  ? 'Optional'
                  : DateFormat.yMMMd().format(_heatDate!),
              isHint: _heatDate == null,
              onTap: () async {
                final p = await AdaptiveDatePicker.show(
                  context: context,
                  initial: _heatDate ?? DateTime.now(),
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now(),
                );
                if (p != null) setState(() => _heatDate = p);
              },
            ),
            const SectionHeader(title: 'Insemination date'),
            dateTile(
              icon: Iconsax.calendar_1,
              text: DateFormat.yMMMd().format(_inseminationDate),
              onTap: () async {
                final p = await AdaptiveDatePicker.show(
                  context: context,
                  initial: _inseminationDate,
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now(),
                );
                if (p != null) setState(() => _inseminationDate = p);
              },
            ),
            const SectionHeader(title: 'Boar'),
            pigsAsync.when(
              data: (pigs) {
                final boars = pigs
                    .where(
                      (p) =>
                          p.sex == PigSex.male &&
                          p.stage == PigStage.boar &&
                          p.status == PigStatus.active,
                    )
                    .toList();
                return DropdownButtonFormField<String>(
                  initialValue: _boarId,
                  decoration: const InputDecoration(hintText: 'Select boar'),
                  items: boars
                      .map(
                        (b) => DropdownMenuItem(
                          value: b.id,
                          child: Text(b.tagId),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _boarId = v),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(
                '$e',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            ),
            const SectionHeader(title: 'Method'),
            SegmentedButton<BreedingMethod>(
              segments: BreedingMethod.values
                  .map(
                    (m) =>
                        ButtonSegment(value: m, label: Text(m.label)),
                  )
                  .toList(),
              selected: {_method},
              onSelectionChanged: (s) => setState(() => _method = s.first),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Iconsax.heart, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Expected farrowing',
                          style: textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat.yMMMd().format(expected),
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                  : const Text('Save breeding'),
            ),
          ],
        ),
      ),
    );
  }
}
