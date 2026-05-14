import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/adaptive_date_picker.dart';
import '../../../core/widgets/section_header.dart';
import '../../areas/application/area_providers.dart';
import '../../areas/domain/area.dart';
import '../../areas/domain/pen.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../../media/media_providers.dart';
import '../../media/photo_picker.dart';
import '../application/pig_providers.dart';
import '../domain/pig.dart';

const _breedSeed = <String>[
  'Yorkshire',
  'Duroc',
  'Landrace',
  'Hampshire',
  'Pietrain',
  'Native',
];

class AddEditPigScreen extends ConsumerStatefulWidget {
  const AddEditPigScreen({super.key, this.existing});
  final Pig? existing;
  @override
  ConsumerState<AddEditPigScreen> createState() => _AddEditPigScreenState();
}

class _AddEditPigScreenState extends ConsumerState<AddEditPigScreen> {
  late final TextEditingController _tag;
  late final TextEditingController _breed;
  late final TextEditingController _weight;
  late final TextEditingController _notes;
  PigSex _sex = PigSex.female;
  PigStage _stage = PigStage.grower;
  String? _areaId;
  String? _penId;
  DateTime? _birthDate;
  String? _sireId;
  String? _damId;
  File? _photoFile;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _tag = TextEditingController(text: e?.tagId ?? '');
    _breed = TextEditingController(text: e?.breed ?? '');
    _weight = TextEditingController(
      text: e?.currentWeight?.toStringAsFixed(0) ?? '',
    );
    _notes = TextEditingController(text: e?.notes ?? '');
    _sex = e?.sex ?? PigSex.female;
    _stage = e?.stage ?? PigStage.grower;
    _areaId = e?.currentAreaId;
    _penId = e?.currentPenId;
    _birthDate = e?.birthDate.toDate();
    _sireId = e?.sireId;
    _damId = e?.damId;
  }

  @override
  void dispose() {
    _tag.dispose();
    _breed.dispose();
    _weight.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await PhotoPicker.pick(context);
    if (file != null && mounted) setState(() => _photoFile = file);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    final farmId = ref.read(selectedFarmIdProvider);
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return;

    final tagText = _tag.text.trim();
    final breedText = _breed.text.trim();
    if (tagText.isEmpty) {
      _snack('Tag ID is required.');
      return;
    }
    if (breedText.isEmpty) {
      _snack('Breed is required.');
      return;
    }
    if (_birthDate == null) {
      _snack('Birth date is required.');
      return;
    }
    if (_areaId == null || _areaId!.isEmpty) {
      _snack('Area is required.');
      return;
    }

    final weightText = _weight.text.trim();
    double? weightValue;
    if (weightText.isNotEmpty) {
      weightValue = double.tryParse(weightText);
      if (weightValue == null || weightValue < 0) {
        _snack('Weight must be a non-negative number.');
        return;
      }
    }

    setState(() => _busy = true);
    final repo = ref.read(pigRepositoryProvider);
    final photoService = ref.read(photoUploadServiceProvider);
    final actorName =
        ref.read(currentAppUserProvider).asData?.value?.displayName ?? '';
    final notesText = _notes.text.trim();
    try {
      String pigId;
      if (widget.existing == null) {
        pigId = await repo.createPig(
          farmId: farmId,
          tagId: tagText,
          sex: _sex,
          breed: breedText,
          birthDate: Timestamp.fromDate(_birthDate!),
          sireId: _sireId,
          damId: _damId,
          stage: _stage,
          currentAreaId: _areaId!,
          currentPenId: _penId,
          currentWeight: weightValue,
          photoUrl: null,
          notes: notesText.isEmpty ? null : notesText,
          actorUserId: user.uid,
          actorDisplayName: actorName,
        );
      } else {
        pigId = widget.existing!.id;
        await repo.updatePig(
          farmId: farmId,
          pigId: pigId,
          tagId: tagText,
          sex: _sex,
          breed: breedText,
          birthDate: Timestamp.fromDate(_birthDate!),
          sireId: _sireId,
          damId: _damId,
          stage: _stage,
          currentAreaId: _areaId!,
          currentPenId: _penId,
          currentWeight: weightValue,
          photoUrl: widget.existing!.photoUrl,
          notes: notesText.isEmpty ? null : notesText,
        );
      }
      if (_photoFile != null && photoService != null) {
        await photoService.uploadAndAttach(
          file: _photoFile!,
          storagePath: 'farms/$farmId/pigs/$pigId/cover.jpg',
          recordPath: 'farms/$farmId/pigs/$pigId',
          fieldName: 'photoUrl',
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _snack('Save failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmId = ref.watch(selectedFarmIdProvider);
    final theme = Theme.of(context);
    final isEditing = widget.existing != null;
    final areasAsync = farmId != null
        ? ref.watch(areasStreamProvider(farmId))
        : const AsyncValue<List<Area>>.data([]);
    final pensAsync = (farmId != null && _areaId != null)
        ? ref.watch(pensStreamProvider((farmId: farmId, areaId: _areaId!)))
        : const AsyncValue<List<Pen>>.data([]);
    final pigsAsync = farmId != null
        ? ref.watch(pigsStreamProvider(farmId))
        : const AsyncValue<List<Pig>>.data([]);

    final currentBreed = _breed.text.trim();
    final breedDropdownValue =
        _breedSeed.contains(currentBreed) ? currentBreed : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit pig' : 'Add pig'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(
              title: 'Photo',
              padding: EdgeInsets.only(top: 8, bottom: 8),
            ),
            _PhotoPicker(
              photoFile: _photoFile,
              existingUrl: widget.existing?.photoUrl,
              onTap: _pickPhoto,
            ),
            const SectionHeader(title: 'Basic info'),
            TextField(
              controller: _tag,
              decoration: const InputDecoration(labelText: 'Tag ID'),
            ),
            const SizedBox(height: 12),
            SegmentedButton<PigSex>(
              segments: const [
                ButtonSegment(value: PigSex.female, label: Text('Female')),
                ButtonSegment(value: PigSex.male, label: Text('Male')),
              ],
              selected: {_sex},
              onSelectionChanged: (s) => setState(() => _sex = s.first),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: breedDropdownValue,
              decoration: const InputDecoration(labelText: 'Breed'),
              items: _breedSeed
                  .map(
                    (b) => DropdownMenuItem(value: b, child: Text(b)),
                  )
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _breed.text = v);
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _breed,
              decoration: const InputDecoration(
                labelText: 'Breed (custom)',
                hintText: 'Type a custom breed or pick a common one above',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PigStage>(
              initialValue: _stage,
              decoration: const InputDecoration(labelText: 'Stage'),
              items: PigStage.values
                  .map(
                    (s) => DropdownMenuItem(value: s, child: Text(s.label)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _stage = v ?? PigStage.grower),
            ),
            const SizedBox(height: 12),
            _DateField(
              label: 'Birth date',
              value: _birthDate,
              onTap: () async {
                final picked = await AdaptiveDatePicker.show(
                  context: context,
                  initial: _birthDate ?? DateTime.now(),
                  firstDate: DateTime(2015),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _birthDate = picked);
              },
            ),
            const SectionHeader(title: 'Location'),
            areasAsync.when(
              data: (areas) {
                final knownIds = areas.map((a) => a.id).toSet();
                final value = (_areaId != null && knownIds.contains(_areaId))
                    ? _areaId
                    : null;
                return DropdownButtonFormField<String>(
                  initialValue: value,
                  decoration: const InputDecoration(labelText: 'Area'),
                  items: areas
                      .map<DropdownMenuItem<String>>(
                        (a) => DropdownMenuItem(
                          value: a.id,
                          child: Text(a.name),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() {
                    _areaId = v;
                    _penId = null;
                  }),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(
                'Areas error: $e',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
            const SizedBox(height: 12),
            pensAsync.when(
              data: (pens) {
                final knownIds = pens.map((p) => p.id).toSet();
                final value = (_penId != null && knownIds.contains(_penId))
                    ? _penId
                    : null;
                return DropdownButtonFormField<String?>(
                  initialValue: value,
                  decoration: const InputDecoration(
                    labelText: 'Pen (optional)',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('— none —'),
                    ),
                    ...pens.map<DropdownMenuItem<String?>>(
                      (p) => DropdownMenuItem<String?>(
                        value: p.id,
                        child: Text(p.name),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _penId = v),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (e, _) => Text(
                'Pens error: $e',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
            const SectionHeader(title: 'Weight'),
            TextField(
              controller: _weight,
              decoration: const InputDecoration(
                labelText: 'Current weight',
                hintText: 'kg (optional)',
              ),
              keyboardType: TextInputType.number,
            ),
            const SectionHeader(title: 'Lineage'),
            pigsAsync.when(
              data: (pigs) {
                final pigId = widget.existing?.id;
                final sires = pigs
                    .where((p) => p.sex == PigSex.male && p.id != pigId)
                    .toList();
                final dams = pigs
                    .where((p) => p.sex == PigSex.female && p.id != pigId)
                    .toList();
                final sireIds = sires.map((p) => p.id).toSet();
                final damIds = dams.map((p) => p.id).toSet();
                final sireValue =
                    (_sireId != null && sireIds.contains(_sireId))
                        ? _sireId
                        : null;
                final damValue =
                    (_damId != null && damIds.contains(_damId)) ? _damId : null;
                return Column(
                  children: [
                    DropdownButtonFormField<String?>(
                      initialValue: sireValue,
                      decoration: const InputDecoration(
                        labelText: 'Sire (optional)',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('— unknown —'),
                        ),
                        ...sires.map<DropdownMenuItem<String?>>(
                          (p) => DropdownMenuItem<String?>(
                            value: p.id,
                            child: Text(p.tagId),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _sireId = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: damValue,
                      decoration: const InputDecoration(
                        labelText: 'Dam (optional)',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('— unknown —'),
                        ),
                        ...dams.map<DropdownMenuItem<String?>>(
                          (p) => DropdownMenuItem<String?>(
                            value: p.id,
                            child: Text(p.tagId),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _damId = v),
                    ),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (e, _) => Text(
                'Pigs error: $e',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
            const SectionHeader(title: 'Notes'),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(isEditing ? 'Save changes' : 'Add pig'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.photoFile,
    required this.existingUrl,
    required this.onTap,
  });

  final File? photoFile;
  final String? existingUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPhoto = photoFile != null || (existingUrl != null);
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
              image: photoFile != null
                  ? DecorationImage(
                      image: FileImage(photoFile!),
                      fit: BoxFit.cover,
                    )
                  : existingUrl != null
                      ? DecorationImage(
                          image: NetworkImage(existingUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
            ),
            child: hasPhoto
                ? null
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Iconsax.gallery_add,
                          size: 40,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add photo',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
          ),
          if (hasPhoto)
            Positioned(
              right: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: theme.colorScheme.outline),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Iconsax.camera,
                      size: 16,
                      color: theme.colorScheme.onSurface,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Change photo',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: Icon(
            Iconsax.calendar,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        child: Text(
          value == null
              ? 'Select'
              : DateFormat.yMMMd().format(value!),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: value == null
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
