import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../farms/application/farm_providers.dart';
import '../application/area_providers.dart';
import '../domain/area.dart';
import 'edit_area_screen.dart';

class AreasListScreen extends ConsumerWidget {
  const AreasListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) return const SizedBox.shrink();
    final areasAsync = ref.watch(areasStreamProvider(farmId));

    return Scaffold(
      appBar: AppBar(title: const Text('Areas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EditAreaScreen()),
        ),
        icon: const Icon(Iconsax.add),
        label: const Text('New area'),
      ),
      body: areasAsync.when(
        data: (areas) {
          if (areas.isEmpty) {
            return EmptyState(
              icon: Iconsax.location,
              title: 'No areas yet',
              subtitle:
                  'Areas group pens by purpose — gestation, farrowing, nursery. Add your first one to start tracking.',
              action: FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditAreaScreen()),
                ),
                icon: const Icon(Iconsax.add),
                label: const Text('Add area'),
              ),
            );
          }

          // Group by purpose
          final byPurpose = <AreaPurpose, List<Area>>{};
          for (final a in areas) {
            byPurpose.putIfAbsent(a.purpose, () => []).add(a);
          }
          final purposes = byPurpose.keys.toList()
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            children: [
              for (final p in purposes) ...[
                SectionHeader(title: p.label),
                ...byPurpose[p]!.map(
                  (a) => Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Iconsax.location,
                          size: 20,
                          color: colorScheme.primary,
                        ),
                      ),
                      title: Text(a.name, style: textTheme.titleMedium),
                      subtitle: Text(
                        a.purpose.label,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: Icon(
                        Iconsax.arrow_right_3,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditAreaScreen(existing: a),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Error: $e',
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
          ),
        ),
      ),
    );
  }
}
