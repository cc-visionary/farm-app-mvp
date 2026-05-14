import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
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
    final theme = Theme.of(context);

    return memberships.when(
      data: (members) {
        final farms = members.map((m) => m.farmId).toList();
        return PopupMenuButton<String>(
          tooltip: 'Switch farm',
          position: PopupMenuPosition.under,
          onSelected: (value) async {
            if (value == '__new__') {
              context.push('/create-farm');
            } else {
              await persistSelectedFarmId(user.uid, value);
              await ref.read(authRepositoryProvider).setLastSelectedFarmId(
                    userId: user.uid,
                    farmId: value,
                  );
              ref.read(selectedFarmIdProvider.notifier).state = value;
            }
          },
          itemBuilder: (_) => [
            ...farms.map(
              (id) => PopupMenuItem(
                value: id,
                child: _FarmName(farmId: id),
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: '__new__',
              child: Row(
                children: [
                  Icon(
                    Iconsax.add_circle,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Create new farm',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  selectedFarm.asData?.value?.name ?? '—',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Iconsax.arrow_down_1,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Icon(
        Iconsax.info_circle,
        color: theme.colorScheme.error,
      ),
    );
  }
}

class _FarmName extends ConsumerWidget {
  const _FarmName({required this.farmId});
  final String farmId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final nameAsync = ref.watch(farmNameProvider(farmId));
    return Text(
      nameAsync.asData?.value ?? farmId,
      style: theme.textTheme.bodyLarge,
    );
  }
}
