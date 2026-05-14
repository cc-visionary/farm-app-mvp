import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../activity/application/activity_providers.dart';
import '../data/team_repository.dart';
import '../domain/invitation.dart';
import '../domain/member.dart';

final teamRepositoryProvider = Provider<TeamRepository>(
  (ref) => TeamRepository(ref.watch(firestoreProvider)),
);

final membersStreamProvider =
    StreamProvider.family<List<Member>, String>((ref, farmId) {
  return ref.watch(teamRepositoryProvider).streamMembers(farmId);
});

final memberForUserProvider =
    StreamProvider.family<Member?, ({String farmId, String userId})>((ref, args) {
  return ref.watch(teamRepositoryProvider).streamMember(
        farmId: args.farmId,
        userId: args.userId,
      );
});

final invitationsStreamProvider =
    StreamProvider.family<List<Invitation>, String>((ref, farmId) {
  return ref.watch(teamRepositoryProvider).streamInvitations(farmId);
});

final userMembershipsProvider =
    StreamProvider.family<List<Member>, String>((ref, userId) {
  return ref.watch(teamRepositoryProvider).streamUserMemberships(userId);
});
