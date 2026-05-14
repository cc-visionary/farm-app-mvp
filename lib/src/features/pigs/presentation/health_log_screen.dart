import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/adaptive_date_picker.dart';
import '../../../core/widgets/section_header.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../../media/media_providers.dart';
import '../../media/photo_picker.dart';
import '../application/pig_providers.dart';
import '../domain/health_record.dart';
import '../domain/pig.dart';

class HealthLogScreen extends ConsumerStatefulWidget {
  const HealthLogScreen({super.key, required this.pig});
  final Pig pig;

  @override
  ConsumerState<HealthLogScreen> createState() => _HealthLogScreenState();
}

class _HealthLogScreenState extends ConsumerState<HealthLogScreen> {
  HealthEventType _type = HealthEventType.vaccination;
  DateTime _date = DateTime.now();
  final _productController = TextEditingController();
  final _dosageController = TextEditingController();
  HealthRoute? _route;
  final _diagnosisController = TextEditingController();
  final _withdrawalDaysController = TextEditingController();
  final _costController = TextEditingController();
  final _notesController = TextEditingController();
  final List<File> _photos = [];
  bool _busy = false;

  @override
  void dispose() {
    _productController.dispose();
    _dosageController.dispose();
    _diagnosisController.dispose();
    _withdrawalDaysController.dispose();
    _costController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _addPhoto() async {
    final f = await PhotoPicker.pick(context);
    if (f != null && mounted) setState(() => _photos.add(f));
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  Future<void> _save() async {
    final farmId = ref.read(selectedFarmIdProvider);
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return;

    final wDaysText = _withdrawalDaysController.text.trim();
    int? wDays;
    if (wDaysText.isNotEmpty) {
      wDays = int.tryParse(wDaysText);
      if (wDays == null || wDays <= 0) {
        _snack('Withdrawal period must be a positive number of days.');
        return;
      }
    }

    final costText = _costController.text.trim();
    double? cost;
    if (costText.isNotEmpty) {
      cost = double.tryParse(costText);
      if (cost == null || cost < 0) {
        _snack('Cost must be a non-negative number.');
        return;
      }
    }

    setState(() => _busy = true);
    final actorName =
        ref.read(currentAppUserProvider).asData?.value?.displayName ?? '';
    final storage = ref.read(firebaseStorageProvider);

    try {
      // Upload photos SEQUENTIALLY before the record write so URLs land in
      // the same document. This is different from the pig profile photo,
      // which uses the offline-capable PhotoUploadService.
      final photoUrls = <String>[];
      for (var i = 0; i < _photos.length; i++) {
        final storagePath =
            'farms/$farmId/health/${widget.pig.id}/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final task = await storage.ref(storagePath).putFile(_photos[i]);
        photoUrls.add(await task.ref.getDownloadURL());
      }

      Timestamp? withdrawalEnd;
      if (wDays != null && wDays > 0) {
        withdrawalEnd = Timestamp.fromDate(_date.add(Duration(days: wDays)));
      }

      await ref.read(healthRepositoryProvider).logHealth(
            farmId: farmId,
            pigId: widget.pig.id,
            tagId: widget.pig.tagId,
            areaId: widget.pig.currentAreaId,
            type: _type,
            date: Timestamp.fromDate(_date),
            productName: _productController.text.trim().isEmpty
                ? null
                : _productController.text.trim(),
            dosage: _dosageController.text.trim().isEmpty
                ? null
                : _dosageController.text.trim(),
            route: _route,
            diagnosis: _diagnosisController.text.trim().isEmpty
                ? null
                : _diagnosisController.text.trim(),
            withdrawalEndDate: withdrawalEnd,
            costPhp: cost,
            photoUrls: photoUrls,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            actorUserId: user.uid,
            actorDisplayName: actorName,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _snack('Could not save: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final showDiagnosis = _type == HealthEventType.treatment ||
        _type == HealthEventType.checkup;
    final wDays = int.tryParse(_withdrawalDaysController.text.trim());
    final showWithdrawalPreview = wDays != null && wDays > 0;

    return Scaffold(
      appBar: AppBar(title: Text('Log health · ${widget.pig.tagId}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(title: 'Type'),
            SegmentedButton<HealthEventType>(
              segments: HealthEventType.values
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
            const SectionHeader(title: 'Product'),
            TextField(
              controller: _productController,
              decoration: const InputDecoration(
                hintText: 'e.g. PRRS vaccine',
              ),
            ),
            const SectionHeader(title: 'Dosage'),
            TextField(
              controller: _dosageController,
              decoration: const InputDecoration(hintText: 'Optional'),
            ),
            const SectionHeader(title: 'Route'),
            DropdownButtonFormField<HealthRoute?>(
              initialValue: _route,
              decoration: const InputDecoration(),
              items: [
                const DropdownMenuItem(value: null, child: Text('—')),
                ...HealthRoute.values.map(
                  (r) => DropdownMenuItem(value: r, child: Text(r.label)),
                ),
              ],
              onChanged: (v) => setState(() => _route = v),
            ),
            if (showDiagnosis) ...[
              const SectionHeader(title: 'Diagnosis'),
              TextField(
                controller: _diagnosisController,
                decoration: const InputDecoration(),
              ),
            ],
            const SectionHeader(title: 'Withdrawal period'),
            TextField(
              controller: _withdrawalDaysController,
              decoration: const InputDecoration(
                hintText: 'Days (optional)',
                helperText:
                    'Auto-generates a reminder task when withdrawal ends.',
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
            if (showWithdrawalPreview) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Withdrawal ends ${DateFormat.yMMMd().format(_date.add(Duration(days: wDays)))}',
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SectionHeader(title: 'Cost (PHP)'),
            TextField(
              controller: _costController,
              decoration: const InputDecoration(hintText: 'Optional'),
              keyboardType: TextInputType.number,
            ),
            const SectionHeader(title: 'Photos'),
            SizedBox(
              height: 96,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (var i = 0; i < _photos.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _photos[i],
                              width: 88,
                              height: 88,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => _removePhoto(i),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: colorScheme.surface
                                      .withValues(alpha: 0.9),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Iconsax.close_circle,
                                  size: 16,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _addPhoto,
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Iconsax.gallery_add,
                        color: colorScheme.onSurfaceVariant,
                      ),
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
                  : const Text('Save health record'),
            ),
          ],
        ),
      ),
    );
  }
}
