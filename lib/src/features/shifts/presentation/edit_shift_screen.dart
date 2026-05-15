import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/permissions/role.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/section_header.dart';
import '../../../l10n/generated/app_localizations.dart';
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
    final l = AppLocalizations.of(context);
    final farmId = ref.read(selectedFarmIdProvider);
    if (farmId == null || widget.existing == null) return;
    final ok = await ConfirmDialog.show(
      context: context,
      title: 'Delete shift?',
      message:
          'Delete "${widget.existing!.name}"? Workers will no longer be assigned to it.',
      confirmLabel: l.common_delete,
      destructive: true,
    );
    if (!ok) return;
    await ref.read(shiftRepositoryProvider).deleteShift(
          farmId: farmId,
          shiftId: widget.existing!.id,
        );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final farmId = ref.read(selectedFarmIdProvider);
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return;

    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.shift_form_name_required)),
      );
      return;
    }
    if (_areaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.shift_form_area_required)),
      );
      return;
    }
    if (_pattern == ShiftPattern.weekly && _days.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.shift_form_days_required),
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
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final farmId = ref.watch(selectedFarmIdProvider);
    final areas = farmId != null
        ? ref.watch(areasStreamProvider(farmId)).asData?.value ?? const []
        : const [];
    final members = farmId != null
        ? ref.watch(membersStreamProvider(farmId)).asData?.value ?? const []
        : const [];
    final workers = members.where((m) => m.role == Role.worker).toList();
    final dowNames = shiftDowLabels(l);

    // Guard the dropdown initialValue against an area that no longer exists.
    final dropdownValue =
        _areaId != null && areas.any((a) => a.id == _areaId) ? _areaId : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? l.shift_add_title : l.shift_edit_title,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(title: l.shift_form_name_label),
            TextField(
              controller: _name,
              decoration: const InputDecoration(hintText: 'e.g. Morning crew'),
            ),
            SectionHeader(title: l.shift_form_pattern_label),
            SegmentedButton<ShiftPattern>(
              segments: ShiftPattern.values
                  .map(
                    (p) => ButtonSegment(
                      value: p,
                      label: Text(localizedShiftPattern(l, p)),
                    ),
                  )
                  .toList(),
              selected: {_pattern},
              onSelectionChanged: (s) => setState(() => _pattern = s.first),
            ),
            if (_pattern == ShiftPattern.weekly) ...[
              const SectionHeader(title: 'Days'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
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
            const SectionHeader(title: 'Hours'),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _start,
                    decoration: InputDecoration(
                      labelText: l.shift_form_start_label,
                      hintText: 'HH:mm',
                      prefixIcon: const Icon(Iconsax.clock),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _end,
                    decoration: InputDecoration(
                      labelText: l.shift_form_end_label,
                      hintText: 'HH:mm',
                      prefixIcon: const Icon(Iconsax.clock),
                    ),
                  ),
                ),
              ],
            ),
            SectionHeader(title: l.shift_form_area_label),
            DropdownButtonFormField<String>(
              initialValue: dropdownValue,
              decoration: const InputDecoration(hintText: 'Select area'),
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
            SectionHeader(title: l.shift_form_workers_label),
            if (workers.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No workers in this farm yet.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
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
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: colorScheme.onPrimary,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(l.shift_form_submit),
            ),
            if (widget.existing != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.error,
                  side: BorderSide(color: colorScheme.error),
                ),
                onPressed: _delete,
                icon: const Icon(Iconsax.trash),
                label: Text(l.shift_form_delete),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
