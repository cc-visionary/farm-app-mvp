import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  void dispose() { _name.dispose(); _notes.dispose(); super.dispose(); }

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
          farmId: farmId, name: _name.text, purpose: _purpose,
          notes: _notes.text.trim().isEmpty ? null : _notes.text,
        );
        setState(() => _savedAreaId = id);
      } else {
        await repo.updateArea(
          farmId: farmId, areaId: _savedAreaId!,
          name: _name.text, purpose: _purpose,
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
              TextField(controller: nameCtl, decoration: const InputDecoration(labelText: 'Pen name')),
              TextField(controller: capCtl, decoration: const InputDecoration(labelText: 'Capacity (optional)'),
                  keyboardType: TextInputType.number),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
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
              const SnackBar(content: Text('Capacity must be a positive whole number.')),
            );
          }
          return;
        }
        await ref.read(areaRepositoryProvider).createPen(
              farmId: farmId, areaId: _savedAreaId!,
              name: name, capacity: cap, notes: null,
            );
      }
    } finally {
      nameCtl.dispose();
      capCtl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmId = ref.watch(selectedFarmIdProvider);
    return Scaffold(
      appBar: AppBar(title: Text(_savedAreaId == null ? 'New area' : 'Edit area')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 16),
            DropdownButtonFormField<AreaPurpose>(
              initialValue: _purpose,
              decoration: const InputDecoration(labelText: 'Purpose'),
              items: AreaPurpose.values.map((p) =>
                DropdownMenuItem(value: p, child: Text(p.label))).toList(),
              onChanged: (v) => setState(() => _purpose = v ?? AreaPurpose.other),
            ),
            const SizedBox(height: 16),
            TextField(controller: _notes,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
                maxLines: 3),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _busy ? null : _save,
                child: Text(_savedAreaId == null ? 'Save area' : 'Save changes')),
            if (_savedAreaId != null && farmId != null) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  const Text('Pens', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.add), onPressed: _addPen),
                ],
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
    final pens = ref.watch(pensStreamProvider((farmId: farmId, areaId: areaId)));
    return pens.when(
      data: (list) => Column(
        children: list.map((p) => Card(
          child: ListTile(
            title: Text(p.name),
            subtitle: Text(p.capacity == null
                ? 'Capacity: —'
                : 'Occupancy: ${p.currentOccupancy} / ${p.capacity}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => ref.read(areaRepositoryProvider).deletePen(
                    farmId: farmId, areaId: areaId, penId: p.id,
                  ),
            ),
          ),
        )).toList(),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
    );
  }
}
