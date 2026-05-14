import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/section_header.dart';
import '../../farms/application/farm_providers.dart';
import '../application/area_providers.dart';
import '../domain/area.dart';

class EditAreaScreen extends ConsumerStatefulWidget {
  const EditAreaScreen({super.key, this.existing});
  final Area? existing;
  @override
  ConsumerState<EditAreaScreen> createState() => _S();
}

class _S extends ConsumerState<EditAreaScreen> {
  late final TextEditingController _name;
  late final TextEditingController _notes;
  late AreaPurpose _purpose;
  bool _busy = false;
  String? _savedAreaId;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _notes = TextEditingController(text: widget.existing?.notes ?? '');
    _purpose = widget.existing?.purpose ?? AreaPurpose.other;
    _savedAreaId = widget.existing?.id;
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final farmId = ref.read(selectedFarmIdProvider);
    if (farmId == null) return;
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Area name is required.')),
      );
      return;
    }
    setState(() => _busy = true);
    final repo = ref.read(areaRepositoryProvider);
    try {
      if (_savedAreaId == null) {
        final id = await repo.createArea(
          farmId: farmId,
          name: _name.text,
          purpose: _purpose,
          notes: _notes.text.trim().isEmpty ? null : _notes.text,
        );
        setState(() => _savedAreaId = id);
      } else {
        await repo.updateArea(
          farmId: farmId,
          areaId: _savedAreaId!,
          name: _name.text,
          purpose: _purpose,
          notes: _notes.text.trim().isEmpty ? null : _notes.text,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addPen() async {
    if (_savedAreaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Save area first before adding pens.')),
      );
      return;
    }
    final farmId = ref.read(selectedFarmIdProvider)!;
    final nameCtl = TextEditingController();
    final capCtl = TextEditingController();
    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Add pen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtl,
                decoration: const InputDecoration(labelText: 'Pen name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: capCtl,
                decoration: const InputDecoration(
                  labelText: 'Capacity (optional)',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add'),
            ),
          ],
        ),
      );
      if (result == true) {
        final name = nameCtl.text.trim();
        if (name.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Pen name is required.')),
            );
          }
          return;
        }
        final cap = int.tryParse(capCtl.text.trim());
        if (capCtl.text.trim().isNotEmpty && (cap == null || cap < 1)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Capacity must be a positive whole number.'),
              ),
            );
          }
          return;
        }
        await ref.read(areaRepositoryProvider).createPen(
              farmId: farmId,
              areaId: _savedAreaId!,
              name: name,
              capacity: cap,
              notes: null,
            );
      }
    } finally {
      nameCtl.dispose();
      capCtl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final farmId = ref.watch(selectedFarmIdProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(_savedAreaId == null ? 'New area' : 'Edit area'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(title: 'Name'),
            TextField(
              controller: _name,
              decoration: const InputDecoration(hintText: 'e.g. Gestation A'),
            ),
            const SectionHeader(title: 'Purpose'),
            DropdownButtonFormField<AreaPurpose>(
              initialValue: _purpose,
              decoration: const InputDecoration(),
              items: AreaPurpose.values
                  .map(
                    (p) =>
                        DropdownMenuItem(value: p, child: Text(p.label)),
                  )
                  .toList(),
              onChanged: (v) =>
                  setState(() => _purpose = v ?? AreaPurpose.other),
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
                  : Text(_savedAreaId == null ? 'Save area' : 'Save changes'),
            ),
            if (_savedAreaId != null && farmId != null) ...[
              SectionHeader(
                title: 'Pens',
                trailing: IconButton(
                  icon: const Icon(Iconsax.add),
                  tooltip: 'Add pen',
                  onPressed: _addPen,
                ),
              ),
              _PenList(farmId: farmId, areaId: _savedAreaId!),
            ],
          ],
        ),
      ),
    );
  }
}

class _PenList extends ConsumerWidget {
  const _PenList({required this.farmId, required this.areaId});
  final String farmId;
  final String areaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final pens = ref.watch(pensStreamProvider((farmId: farmId, areaId: areaId)));
    return pens.when(
      data: (list) {
        if (list.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No pens yet. Tap + to add one.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }
        return Column(
          children: list
              .map(
                (p) => Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    title: Text(p.name, style: textTheme.titleMedium),
                    subtitle: Text(
                      p.capacity == null
                          ? 'Capacity: —'
                          : 'Occupancy: ${p.currentOccupancy} / ${p.capacity}',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        Iconsax.trash,
                        color: colorScheme.error,
                      ),
                      tooltip: 'Delete pen',
                      onPressed: () async {
                        final ok = await ConfirmDialog.show(
                          context: context,
                          title: 'Delete pen?',
                          message:
                              'Delete pen "${p.name}"? This cannot be undone.',
                          confirmLabel: 'Delete',
                          destructive: true,
                        );
                        if (ok) {
                          await ref.read(areaRepositoryProvider).deletePen(
                                farmId: farmId,
                                areaId: areaId,
                                penId: p.id,
                              );
                        }
                      },
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text(
        'Error: $e',
        style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
      ),
    );
  }
}
