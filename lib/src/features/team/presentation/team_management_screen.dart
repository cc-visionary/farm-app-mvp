import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../../core/permissions/role.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../farms/application/farm_providers.dart';
import '../application/team_providers.dart';
import 'invite_member_screen.dart';

class TeamManagementScreen extends ConsumerWidget {
  const TeamManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Team')),
        body: const EmptyState(
          icon: Iconsax.people,
          title: 'No farm selected',
        ),
      );
    }
    final membersAsync = ref.watch(membersStreamProvider(farmId));
    final invitationsAsync = ref.watch(invitationsStreamProvider(farmId));

    return Scaffold(
      appBar: AppBar(title: const Text('Team')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Iconsax.user_add),
        label: const Text('Invite'),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const InviteMemberScreen()),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          const SectionHeader(title: 'Members'),
          membersAsync.when(
            data: (members) {
              if (members.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No members yet.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }
              return Column(
                children: members
                    .map(
                      (m) => Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Consumer(
                                  builder: (context, ref, _) {
                                    final nameAsync = ref.watch(
                                      userDisplayNameProvider(m.userId),
                                    );
                                    final name = nameAsync.asData?.value ?? '';
                                    final initial = name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?';
                                    return Text(
                                      initial,
                                      style: textTheme.titleMedium?.copyWith(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Consumer(
                                      builder: (context, ref, _) {
                                        final nameAsync = ref.watch(
                                          userDisplayNameProvider(m.userId),
                                        );
                                        return Text(
                                          nameAsync.asData?.value ?? m.userId,
                                          style: textTheme.titleMedium,
                                        );
                                      },
                                    ),
                                    Text(
                                      m.role.value,
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DropdownButton<Role>(
                                value: m.role,
                                underline: const SizedBox.shrink(),
                                onChanged: (v) {
                                  if (v != null) {
                                    ref
                                        .read(teamRepositoryProvider)
                                        .updateMemberRole(
                                          farmId: farmId,
                                          userId: m.userId,
                                          newRole: v,
                                        );
                                  }
                                },
                                items: Role.values
                                    .map(
                                      (r) => DropdownMenuItem(
                                        value: r,
                                        child: Text(r.value),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text(
              'Error: $e',
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
            ),
          ),
          invitationsAsync.when(
            data: (invs) {
              final pending =
                  invs.where((i) => i.status.value == 'pending').toList();
              if (pending.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionHeader(title: 'Pending invitations'),
                  ...pending.map(
                    (inv) => Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Iconsax.sms,
                              size: 20,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    inv.email,
                                    style: textTheme.titleMedium,
                                  ),
                                  Text(
                                    '${inv.role.value} · expires ${DateFormat.MMMd().format(inv.expiresAt.toDate())}',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Iconsax.close_circle,
                                color: colorScheme.error,
                              ),
                              tooltip: 'Revoke invitation',
                              onPressed: () async {
                                final ok = await ConfirmDialog.show(
                                  context: context,
                                  title: 'Revoke invitation?',
                                  message:
                                      'Revoke the invitation for ${inv.email}? They will not be able to join with this link.',
                                  confirmLabel: 'Revoke',
                                  destructive: true,
                                );
                                if (ok) {
                                  await ref
                                      .read(teamRepositoryProvider)
                                      .revokeInvitation(
                                        farmId: farmId,
                                        invitationId: inv.id,
                                      );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (e, _) => Text(
              'Error: $e',
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
