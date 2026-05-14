import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../../media/media_providers.dart';
import '../../media/photo_picker.dart';
import '../application/pig_providers.dart';
import '../domain/pig.dart';

const _causes = <String>[
  'Respiratory',
  'Digestive',
  'Accident',
  'Unknown',
  'ASF-suspected',
  'Other',
];

class MortalityLogScreen extends ConsumerStatefulWidget {
  const MortalityLogScreen({super.key, required this.pig});
  final Pig pig;

  @override
  ConsumerState<MortalityLogScreen> createState() => _MortalityLogScreenState();
}

class _MortalityLogScreenState extends ConsumerState<MortalityLogScreen> {
  DateTime _date = DateTime.now();
  String? _cause;
  final _notesController = TextEditingController();
  final List<File> _photos = [];
  bool _busy = false;

  @override
  void dispose() {
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
    if (farmId == null || user == null) {
      _snack('Cannot save: missing farm or user.');
      return;
    }

    // Destructive confirmation BEFORE any uploads/writes.
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm mortality'),
        content: Text(
          'Mark ${widget.pig.tagId} as deceased? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    if (!mounted) return;
    setState(() => _busy = true);
    final storage = ref.read(firebaseStorageProvider);
    final actorName =
        ref.read(currentAppUserProvider).asData?.value?.displayName ?? '';

    try {
      // Sequential upload — same pattern as health records so URLs land
      // in the same document write.
      final photoUrls = <String>[];
      for (var i = 0; i < _photos.length; i++) {
        final path =
            'farms/$farmId/mortality/${widget.pig.id}/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final task = await storage.ref(path).putFile(_photos[i]);
        photoUrls.add(await task.ref.getDownloadURL());
      }

      await ref.read(mortalityRepositoryProvider).logMortality(
            farmId: farmId,
            pigId: widget.pig.id,
            tagId: widget.pig.tagId,
            areaId: widget.pig.currentAreaId,
            date: Timestamp.fromDate(_date),
            cause: _cause,
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
    return Scaffold(
      appBar: AppBar(title: Text('Mortality · ${widget.pig.tagId}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
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
            const Text(
              'Cause',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _causes
                  .map(
                    (c) => ChoiceChip(
                      label: Text(c),
                      selected: _cause == c,
                      onSelected: (sel) =>
                          setState(() => _cause = sel ? c : null),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            const Text(
              'Photos (optional)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 88,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (var i = 0; i < _photos.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _photos[i],
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: InkWell(
                              onTap: () => _removePhoto(i),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  GestureDetector(
                    onTap: _addPhoto,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.add_a_photo),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.heart_broken),
              label: Text(_busy ? 'Saving…' : 'Mark deceased'),
              onPressed: _busy ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
