import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/permissions/role.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../application/team_providers.dart';

class InviteMemberScreen extends ConsumerStatefulWidget {
  const InviteMemberScreen({super.key});
  @override
  ConsumerState<InviteMemberScreen> createState() => _S();
}

class _S extends ConsumerState<InviteMemberScreen> {
  final _email = TextEditingController();
  Role _role = Role.worker;
  bool _busy = false;
  String? _error;

  @override
  void dispose() { _email.dispose(); super.dispose(); }

  Future<void> _send() async {
    final farmId = ref.read(selectedFarmIdProvider);
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return;
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'Email required.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await ref.read(teamRepositoryProvider).createInvitation(
            farmId: farmId, email: _email.text,
            role: _role, assignedAreaIds: const [],
            invitedBy: user.uid,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invite member')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 16),
            DropdownButtonFormField<Role>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: const [
                DropdownMenuItem(value: Role.manager, child: Text('Manager')),
                DropdownMenuItem(value: Role.worker, child: Text('Worker')),
                DropdownMenuItem(value: Role.vet, child: Text('Veterinarian')),
              ],
              onChanged: (v) => setState(() => _role = v ?? Role.worker),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _busy ? null : _send,
              child: _busy ? const CircularProgressIndicator() : const Text('Send invitation'),
            ),
          ],
        ),
      ),
    );
  }
}
