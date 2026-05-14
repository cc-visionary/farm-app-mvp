import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/widgets/section_header.dart';
import '../../core/widgets/stat_tile.dart';
import '../farms/application/farm_providers.dart';
import '../pigs/application/pig_providers.dart';
import '../pigs/domain/farrowing_record.dart';
import '../pigs/domain/mortality_record.dart';
import '../pigs/domain/pig.dart';

/// Dashboard card summarising the swine herd: active head count, breeders,
/// and recent farrowings / mortalities for the currently selected farm.
class SnapshotCard extends ConsumerWidget {
  const SnapshotCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) return const SizedBox.shrink();

    final pigs =
        ref.watch(pigsStreamProvider(farmId)).asData?.value ?? const <Pig>[];
    final farrowings = ref.watch(allFarrowingsProvider(farmId)).asData?.value ??
        const <FarrowingRecord>[];
    final morts = ref.watch(allMortalitiesProvider(farmId)).asData?.value ??
        const <MortalityRecord>[];

    final active = pigs.where((p) => p.status == PigStatus.active).toList();
    final sows = active.where((p) => p.stage == PigStage.sow).length;
    final boars = active.where((p) => p.stage == PigStage.boar).length;

    final now = DateTime.now();
    final last30 = now.subtract(const Duration(days: 30));
    final recentFarr =
        farrowings.where((f) => f.date.toDate().isAfter(last30)).length;
    final recentMort =
        morts.where((m) => m.date.toDate().isAfter(last30)).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Swine snapshot',
              padding: EdgeInsets.only(bottom: 8),
            ),
            const Divider(height: 1),
            const SizedBox(height: 4),
            StatTile(
              label: 'Total pigs (active)',
              value: active.length.toString(),
              icon: Iconsax.pet,
            ),
            StatTile(
              label: 'Sows',
              value: sows.toString(),
              icon: Iconsax.heart,
            ),
            StatTile(
              label: 'Boars',
              value: boars.toString(),
              icon: Iconsax.heart,
            ),
            StatTile(
              label: 'Farrowings (last 30d)',
              value: recentFarr.toString(),
              icon: Icons.child_friendly,
            ),
            StatTile(
              label: 'Mortalities (last 30d)',
              value: recentMort.toString(),
              icon: Icons.heart_broken,
            ),
          ],
        ),
      ),
    );
  }
}
