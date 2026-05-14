import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../areas/application/area_providers.dart';
import '../../areas/domain/area.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../../team/application/team_providers.dart';
import '../../team/domain/member.dart';
import '../application/task_providers.dart';
import '../domain/task.dart';

class CreateTaskScreen extends ConsumerStatefulWidget {
  const CreateTaskScreen({super.key});
  @override
  ConsumerState<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends ConsumerState<CreateTaskScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  DateTime _due = DateTime.now().add(const Duration(days: 1));

  /// 'user' or 'area' or null
  String? _assignKind;
  String? _assignId;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final farmId = ref.read(selectedFarmIdProvider);
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return;
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(taskRepositoryProvider).createManualTask(
            farmId: farmId,
            title: _title.text.trim(),
            description:
                _desc.text.trim().isEmpty ? null : _desc.text.trim(),
            dueDate: Timestamp.fromDate(_due),
            assignedTo: (_assignKind != null && _assignId != null)
                ? TaskAssignment(kind: _assignKind!, id: _assignId!)
                : null,
            creatorUserId: user.uid,
          );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmId = ref.watch(selectedFarmIdProvider);
    final List<Member> members = (farmId != null)
        ? ref.watch(membersStreamProvider(farmId)).asData?.value ??
            const <Member>[]
        : const <Member>[];
    final List<Area> areas = (farmId != null)
        ? ref.watch(areasStreamProvider(farmId)).asData?.value ??
            const <Area>[]
        : const <Area>[];
    return Scaffold(
      appBar: AppBar(title: const Text('New task')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _desc,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Due date'),
              subtitle: Text(_due.toLocal().toString().split(' ')[0]),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final p = await showDatePicker(
                  context: context,
                  initialDate: _due,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (p != null) setState(() => _due = p);
              },
            ),
            const SizedBox(height: 12),
            const Text(
              'Assign to',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            DropdownButtonFormField<String?>(
              initialValue: _assignKind,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                DropdownMenuItem(value: null, child: Text('— unassigned —')),
                DropdownMenuItem(value: 'user', child: Text('Specific user')),
                DropdownMenuItem(
                  value: 'area',
                  child: Text('Any worker in an area'),
                ),
              ],
              onChanged: (v) => setState(() {
                _assignKind = v;
                _assignId = null;
              }),
            ),
            if (_assignKind == 'user')
              DropdownButtonFormField<String>(
                initialValue: _assignId,
                decoration: const InputDecoration(labelText: 'User'),
                items: members
                    .map((m) => DropdownMenuItem(
                          value: m.userId,
                          child: Text(m.userId),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _assignId = v),
              ),
            if (_assignKind == 'area')
              DropdownButtonFormField<String>(
                initialValue: _assignId,
                decoration: const InputDecoration(labelText: 'Area'),
                items: areas
                    .map((a) => DropdownMenuItem(
                          value: a.id,
                          child: Text(a.name),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _assignId = v),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const CircularProgressIndicator()
                  : const Text('Create task'),
            ),
          ],
        ),
      ),
    );
  }
}
