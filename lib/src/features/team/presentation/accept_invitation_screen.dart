import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../application/team_providers.dart';
import '../domain/invitation.dart';

class AcceptInvitationScreen extends ConsumerStatefulWidget {
  const AcceptInvitationScreen({super.key, required this.invitations});
  final List<Invitation> invitations;
  @override
  ConsumerState<AcceptInvitationScreen> createState() => _State();
}

class _State extends ConsumerState<AcceptInvitationScreen> {
  bool _busy = false;

  Future<void> _accept(Invitation inv) async {
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (user == null || user.email == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(teamRepositoryProvider).acceptInvitation(
            farmId: inv.farmId,
            invitationId: inv.id,
            userId: user.uid,
            userEmail: user.email!,
          );
      await persistSelectedFarmId(user.uid, inv.farmId);
      ref.read(selectedFarmIdProvider.notifier).state = inv.farmId;
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("You're invited")),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: widget.invitations.length,
        itemBuilder: (_, i) {
          final inv = widget.invitations[i];
          return Card(
            child: ListTile(
              title: Text('Farm ${inv.farmId}'),
              subtitle: Text('Role: ${inv.role.value}'),
              trailing: ElevatedButton(
                onPressed: _busy ? null : () => _accept(inv),
                child: const Text('Accept'),
              ),
            ),
          );
        },
      ),
    );
  }
}
