import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/application/auth_providers.dart';
import '../../team/application/team_providers.dart';
import '../../team/presentation/accept_invitation_screen.dart';
import 'create_farm_screen.dart';

class FarmSetupScreen extends ConsumerWidget {
  const FarmSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentAppUserProvider).asData?.value;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final invitationsAsync = ref.watch(_pendingInvitationsProvider(user.email));
    return invitationsAsync.when(
      data: (invs) => invs.isNotEmpty
          ? AcceptInvitationScreen(invitations: invs)
          : const CreateFarmScreen(),
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}

final _pendingInvitationsProvider = FutureProvider.family((ref, String email) {
  return ref.watch(teamRepositoryProvider).findPendingInvitationsForEmail(email);
});
