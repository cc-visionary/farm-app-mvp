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
final initialFarmResolverProvider = Provider<void>((ref) {
  final user = ref.watch(authStateChangesProvider).asData?.value;
  if (user == null) return;
  final memberships = ref.watch(userMembershipsProvider(user.uid)).asData?.value;
  if (memberships == null || memberships.isEmpty) return;
  final current = ref.read(selectedFarmIdProvider);
  if (current != null && memberships.any((m) => m.farmId == current)) return;

  SharedPreferences.getInstance().then((prefs) {
    final stored = prefs.getString('lastSelectedFarmId_${user.uid}');
    final pick = stored != null && memberships.any((m) => m.farmId == stored)
        ? stored
        : memberships.first.farmId;
    ref.read(selectedFarmIdProvider.notifier).state = pick;
  });
});

Future<void> persistSelectedFarmId(String userId, String farmId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('lastSelectedFarmId_$userId', farmId);
}
