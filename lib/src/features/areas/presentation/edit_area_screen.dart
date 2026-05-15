import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/section_header.dart';
import '../../../l10n/generated/app_localizations.dart';
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
    final l = AppLocalizations.of(context);
    final farmId = ref.read(selectedFarmIdProvider);
    if (farmId == null) return;
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.area_form_name_required)),
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
    final l = AppLocalizations.of(context);
    if (_savedAreaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.area_form_save_first_for_pens)),
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
          title: Text(l.pen_dialog_title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtl,
                decoration: InputDecoration(labelText: l.pen_dialog_name_label),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: capCtl,
                decoration: InputDecoration(
                  labelText: l.pen_dialog_capacity_label,
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.common_cancel),
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
              SnackBar(content: Text(l.pen_dialog_name_required)),
            );
          }
          return;
        }
        final cap = int.tryParse(capCtl.text.trim());
        if (capCtl.text.trim().isNotEmpty && (cap == null || cap < 1)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l.pen_dialog_capacity_positive),
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
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final farmId = ref.watch(selectedFarmIdProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(_savedAreaId == null ? l.area_add_title : l.area_edit_title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(title: l.area_form_name_label),
            TextField(
              controller: _name,
              decoration: const InputDecoration(hintText: 'e.g. Gestation A'),
            ),
            SectionHeader(title: l.area_form_purpose_label),
            DropdownButtonFormField<AreaPurpose>(
              initialValue: _purpose,
              decoration: const InputDecoration(),
              items: AreaPurpose.values
                  .map(
                    (p) => DropdownMenuItem(
                      value: p,
                      child: Text(localizedAreaPurpose(l, p)),
                    ),
                  )
                  .toList(),
              onChanged: (v) =>
                  setState(() => _purpose = v ?? AreaPurpose.other),
            ),
            SectionHeader(title: l.area_form_notes_label),
            TextField(
              controller: _notes,
              decoration: InputDecoration(hintText: l.common_optional),
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
                  : Text(
                      _savedAreaId == null
                          ? l.area_form_submit_add
                          : l.area_form_submit_edit,
                    ),
            ),
            if (_savedAreaId != null && farmId != null) ...[
              SectionHeader(
                title: l.area_form_pens_section,
                trailing: IconButton(
                  icon: const Icon(Iconsax.add),
                  tooltip: l.pen_dialog_title,
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
    final l = AppLocalizations.of(context);
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
                          ? l.pen_card_capacity_unknown
                          : l.pen_card_occupancy(
                              p.currentOccupancy,
                              p.capacity!,
                            ),
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        Iconsax.trash,
                        color: colorScheme.error,
                      ),
                      tooltip: l.common_delete,
                      onPressed: () async {
                        final ok = await ConfirmDialog.show(
                          context: context,
                          title: 'Delete pen?',
                          message:
                              'Delete pen "${p.name}"? This cannot be undone.',
                          confirmLabel: l.common_delete,
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
