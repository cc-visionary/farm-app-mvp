import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/permissions/role.dart';
import '../../farms/application/farm_providers.dart';
import '../application/team_providers.dart';
import 'invite_member_screen.dart';

class TeamManagementScreen extends ConsumerWidget {
  const TeamManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) {
      return const Scaffold(body: Center(child: Text('No farm selected')));
    }
    final membersAsync = ref.watch(membersStreamProvider(farmId));
    final invitationsAsync = ref.watch(invitationsStreamProvider(farmId));

    return Scaffold(
      appBar: AppBar(title: const Text('Team')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add),
        label: const Text('Invite'),
        onPressed: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => const InviteMemberScreen()),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Members', style: TextStyle(fontWeight: FontWeight.bold)),
          membersAsync.when(
            data: (members) => Column(
              children: members.map((m) => Card(
                child: ListTile(
                  title: Text(m.userId),
                  subtitle: Text('Role: ${m.role.value}'),
                  trailing: DropdownButton<Role>(
                    value: m.role,
                    onChanged: (v) {
                      if (v != null) {
                        ref.read(teamRepositoryProvider).updateMemberRole(
                              farmId: farmId, userId: m.userId, newRole: v,
                            );
                      }
                    },
                    items: Role.values.map((r) =>
                      DropdownMenuItem(value: r, child: Text(r.value))).toList(),
                  ),
                ),
              )).toList(),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
          const SizedBox(height: 24),
          const Text('Pending invitations', style: TextStyle(fontWeight: FontWeight.bold)),
          invitationsAsync.when(
            data: (invs) => Column(
              children: invs.where((i) => i.status.value == 'pending').map((inv) => Card(
                child: ListTile(
                  title: Text(inv.email),
                  subtitle: Text('${inv.role.value} · expires ${inv.expiresAt.toDate().toLocal()}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.cancel),
                    onPressed: () => ref.read(teamRepositoryProvider)
                        .revokeInvitation(farmId: farmId, invitationId: inv.id),
                  ),
                ),
              )).toList(),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}
