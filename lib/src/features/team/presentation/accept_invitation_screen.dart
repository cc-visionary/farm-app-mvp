import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../application/team_providers.dart';
import '../domain/invitation.dart';

String _roleLabel(AppLocalizations l, String roleValue) {
  switch (roleValue) {
    case 'manager':
      return l.invitation_role_manager;
    case 'worker':
      return l.invitation_role_worker;
    case 'vet':
      return l.invitation_role_vet;
    default:
      return roleValue;
  }
}

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.invitation_accept_title)),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: widget.invitations.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final inv = widget.invitations[i];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Iconsax.people,
                          size: 20,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Consumer(
                              builder: (context, ref, _) {
                                final nameAsync =
                                    ref.watch(farmNameProvider(inv.farmId));
                                return Text(
                                  nameAsync.asData?.value ?? inv.farmId,
                                  style: textTheme.titleMedium,
                                );
                              },
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l.invitation_accept_role_label(
                                  _roleLabel(l, inv.role.value)),
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : () => _accept(inv),
                    child: Text(l.invitation_accept_button),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
