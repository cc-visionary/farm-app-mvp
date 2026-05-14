import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../activity/application/activity_providers.dart';
import '../../authentication/application/auth_providers.dart';
import '../../team/application/team_providers.dart';
import '../data/farm_repository.dart';
import '../domain/farm_model.dart';

final farmRepositoryProvider = Provider<FarmRepository>(
  (ref) => FarmRepository(ref.watch(firestoreProvider)),
);

/// The user's currently selected farm.
/// - If user has a stored preference matching a farm they belong to, use it.
/// - Else use the first membership.
/// - Returns null if user has no memberships (triggers create-first-farm flow).
final selectedFarmIdProvider = StateProvider<String?>((ref) => null);

final selectedFarmProvider = StreamProvider<Farm?>((ref) {
  final farmId = ref.watch(selectedFarmIdProvider);
  if (farmId == null) return const Stream.empty();
  return ref.watch(farmRepositoryProvider).streamFarm(farmId);
});

/// Resolves the initial selected farm from user memberships + stored preference.
/// Called once at app start when memberships first load.
final initialFarmResolverProvider = FutureProvider<void>((ref) async {
  final user = ref.watch(authStateChangesProvider).asData?.value;
  if (user == null) return;
  final memberships = ref.watch(userMembershipsProvider(user.uid)).asData?.value;
  if (memberships == null || memberships.isEmpty) return;
  final current = ref.read(selectedFarmIdProvider);
  if (current != null && memberships.any((m) => m.farmId == current)) return;

  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getString('lastSelectedFarmId_${user.uid}');
  final pick = stored != null && memberships.any((m) => m.farmId == stored)
      ? stored
      : memberships.first.farmId;
  ref.read(selectedFarmIdProvider.notifier).state = pick;
});

Future<void> persistSelectedFarmId(String userId, String farmId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('lastSelectedFarmId_$userId', farmId);
}

/// Fetches a farm's display name once, falling back to the farmId.
/// Used by FarmSwitcher and anywhere we need to show a farm name without
/// streaming the entire farm doc.
final farmNameProvider =
    FutureProvider.family<String, String>((ref, farmId) async {
  final snap = await ref
      .read(firestoreProvider)
      .collection('farms')
      .doc(farmId)
      .get();
  return (snap.data()?['name'] as String?) ?? farmId;
});

/// Fetches a user's display name (or email fallback) for showing in member lists.
final userDisplayNameProvider =
    FutureProvider.family<String, String>((ref, userId) async {
  final snap = await ref
      .read(firestoreProvider)
      .collection('users')
      .doc(userId)
      .get();
  final d = snap.data();
  return (d?['displayName'] as String?) ??
      (d?['email'] as String?) ??
      userId;
});
