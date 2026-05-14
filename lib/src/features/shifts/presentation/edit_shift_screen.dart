import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/permissions/role.dart';
import '../../areas/application/area_providers.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../../team/application/team_providers.dart';
import '../application/shift_providers.dart';
import '../domain/shift.dart';

class EditShiftScreen extends ConsumerStatefulWidget {
  const EditShiftScreen({super.key, this.existing});
  final Shift? existing;

  @override
  ConsumerState<EditShiftScreen> createState() => _EditShiftScreenState();
}

class _EditShiftScreenState extends ConsumerState<EditShiftScreen> {
  late final TextEditingController _name;
  late final TextEditingController _start;
  late final TextEditingController _end;
  late ShiftPattern _pattern;
  Set<int> _days = {};
  String? _areaId;
  Set<String> _workerIds = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _start = TextEditingController(text: e?.startTime ?? '06:00');
    _end = TextEditingController(text: e?.endTime ?? '14:00');
    _pattern = e?.pattern ?? ShiftPattern.daily;
    _days = (e?.daysOfWeek ?? const <int>[]).toSet();
    _areaId = e?.assignedAreaId;
    _workerIds = (e?.assignedUserIds ?? const <String>[]).toSet();
  }

  @override
  void dispose() {
    _name.dispose();
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final farmId = ref.read(selectedFarmIdProvider);
    if (farmId == null || widget.existing == null) return;
    await ref.read(shiftRepositoryProvider).deleteShift(
          farmId: farmId,
          shiftId: widget.existing!.id,
        );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _save() async {
    final farmId = ref.read(selectedFarmIdProvider);
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return;

    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shift name is required.')),
      );
      return;
    }
    if (_areaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an area.')),
      );
      return;
    }
    if (_pattern == ShiftPattern.weekly && _days.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pick at least one day for a weekly shift.'),
        ),
      );
      return;
    }

    setState(() => _busy = true);
    final actorName =
        ref.read(currentAppUserProvider).asData?.value?.displayName ?? '';
    try {
      final repo = ref.read(shiftRepositoryProvider);
      if (widget.existing == null) {
        await repo.createShift(
          farmId: farmId,
          name: _name.text.trim(),
          pattern: _pattern,
          daysOfWeek:
              _pattern == ShiftPattern.weekly ? _days.toList() : const [],
          startTime: _start.text.trim(),
          endTime: _end.text.trim(),
          assignedAreaId: _areaId!,
          assignedUserIds: _workerIds.toList(),
          actorUserId: user.uid,
          actorDisplayName: actorName,
        );
      } else {
        await repo.updateShift(
          farmId: farmId,
          shiftId: widget.existing!.id,
          name: _name.text.trim(),
          pattern: _pattern,
          daysOfWeek:
              _pattern == ShiftPattern.weekly ? _days.toList() : const [],
          startTime: _start.text.trim(),
          endTime: _end.text.trim(),
          assignedAreaId: _areaId!,
          assignedUserIds: _workerIds.toList(),
        );
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmId = ref.watch(selectedFarmIdProvider);
    final areas = farmId != null
        ? ref.watch(areasStreamProvider(farmId)).asData?.value ?? const []
        : const [];
    final members = farmId != null
        ? ref.watch(membersStreamProvider(farmId)).asData?.value ?? const []
        : const [];
    final workers = members.where((m) => m.role == Role.worker).toList();
    const dowNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    // Guard the dropdown initialValue against an area that no longer exists.
    final dropdownValue =
        _areaId != null && areas.any((a) => a.id == _areaId) ? _areaId : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New shift' : 'Edit shift'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Shift name'),
            ),
            const SizedBox(height: 12),
            SegmentedButton<ShiftPattern>(
              segments: ShiftPattern.values
                  .map(
                    (p) => ButtonSegment(value: p, label: Text(p.label)),
                  )
                  .toList(),
              selected: {_pattern},
              onSelectionChanged: (s) => setState(() => _pattern = s.first),
            ),
            if (_pattern == ShiftPattern.weekly) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: List.generate(
                  7,
                  (i) => FilterChip(
                    label: Text(dowNames[i]),
                    selected: _days.contains(i),
                    onSelected: (sel) => setState(
                      () => sel ? _days.add(i) : _days.remove(i),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _start,
                    decoration: const InputDecoration(
                      labelText: 'Start (HH:mm)',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _end,
                    decoration: const InputDecoration(
                      labelText: 'End (HH:mm)',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: dropdownValue,
              decoration: const InputDecoration(labelText: 'Area'),
              items: areas
                  .map<DropdownMenuItem<String>>(
                    (a) => DropdownMenuItem(
                      value: a.id,
                      child: Text(a.name),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _areaId = v),
            ),
            const SizedBox(height: 12),
            const Text(
              'Workers',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            if (workers.isEmpty)
              const Text(
                'No workers in this farm yet.',
                style: TextStyle(color: Colors.grey),
              )
            else
              Wrap(
                spacing: 6,
                children: workers
                    .map(
                      (m) => FilterChip(
                        label: Text(m.userId),
                        selected: _workerIds.contains(m.userId),
                        onSelected: (sel) => setState(
                          () => sel
                              ? _workerIds.add(m.userId)
                              : _workerIds.remove(m.userId),
                        ),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const CircularProgressIndicator()
                  : const Text('Save shift'),
            ),
            if (widget.existing != null) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                ),
                onPressed: _delete,
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
