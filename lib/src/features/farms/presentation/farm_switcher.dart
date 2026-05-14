import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../authentication/application/auth_providers.dart';
import '../../team/application/team_providers.dart';
import '../application/farm_providers.dart';

class FarmSwitcher extends ConsumerWidget {
  const FarmSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateChangesProvider).asData?.value;
    if (user == null) return const SizedBox.shrink();
    final memberships = ref.watch(userMembershipsProvider(user.uid));
    final selectedFarm = ref.watch(selectedFarmProvider);

    return memberships.when(
      data: (members) {
        final farms = members.map((m) => m.farmId).toList();
        return PopupMenuButton<String>(
          tooltip: 'Switch farm',
          onSelected: (value) async {
            if (value == '__new__') {
              context.push('/create-farm');
            } else {
              await persistSelectedFarmId(user.uid, value);
              await ref.read(authRepositoryProvider).setLastSelectedFarmId(
                    userId: user.uid, farmId: value,
                  );
              ref.read(selectedFarmIdProvider.notifier).state = value;
            }
          },
          itemBuilder: (_) => [
            ...farms.map((id) => PopupMenuItem(value: id, child: Text('Farm $id'))),
            const PopupMenuDivider(),
            const PopupMenuItem(value: '__new__', child: Text('+ Create new farm')),
          ],
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(selectedFarm.asData?.value?.name ?? '—',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const Icon(Icons.error),
    );
  }
}
