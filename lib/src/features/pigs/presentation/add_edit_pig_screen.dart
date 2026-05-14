import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        title: Text(widget.existing == null ? 'Add pig' : 'Edit pig'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                  image: _photoFile != null
                      ? DecorationImage(
                          image: FileImage(_photoFile!),
                          fit: BoxFit.cover,
                        )
                      : widget.existing?.photoUrl != null
                          ? DecorationImage(
                              image: NetworkImage(widget.existing!.photoUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                ),
                child: _photoFile == null && widget.existing?.photoUrl == null
                    ? const Center(
                        child: Icon(
                          Icons.add_a_photo,
                          size: 48,
                          color: Colors.grey,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tag,
              decoration: const InputDecoration(labelText: 'Tag ID'),
            ),
            const SizedBox(height: 12),
            SegmentedButton<PigSex>(
              segments: PigSex.values
                  .map(
                    (s) => ButtonSegment(value: s, label: Text(s.label)),
                  )
                  .toList(),
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
                labelText: 'Breed (or type custom)',
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
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Birth date'),
              subtitle: Text(
                _birthDate?.toLocal().toString().split(' ')[0] ?? 'Select',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _birthDate ?? DateTime.now(),
                  firstDate: DateTime(2015),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _birthDate = picked);
              },
            ),
            areasAsync.when(
              data: (areas) {
                // Guard against stale _areaId not present in the current
                // areas list (e.g. area was deleted after the pig was
                // created). Setting a non-matching initialValue throws.
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
              error: (e, _) => Text('Areas error: $e'),
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
              error: (e, _) => Text('Pens error: $e'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _weight,
              decoration: const InputDecoration(
                labelText: 'Weight (kg, optional)',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
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
              error: (e, _) => Text('Pigs error: $e'),
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
