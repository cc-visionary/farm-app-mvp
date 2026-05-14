import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../application/pig_providers.dart';
import '../domain/breeding_record.dart';
import '../domain/pig.dart';
import 'breeding_log_screen.dart';
import 'farrowing_log_screen.dart';

class PigDetailScreen extends ConsumerWidget {
  const PigDetailScreen({super.key, required this.pigId});
  final String pigId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) return const SizedBox.shrink();
    final pigAsync =
        ref.watch(pigByIdProvider((farmId: farmId, pigId: pigId)));

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: pigAsync.maybeWhen(
            data: (p) => Text(p?.tagId ?? 'Pig'),
            orElse: () => const Text('Pig'),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Profile'),
              Tab(text: 'Breeding'),
              Tab(text: 'Health'),
              Tab(text: 'Lineage'),
            ],
          ),
        ),
        body: pigAsync.when(
          data: (pig) {
            if (pig == null) return const Center(child: Text('Not found'));
            return TabBarView(
              children: [
                _ProfileTab(pig: pig),
                _BreedingTab(pig: pig),
                const _PlaceholderTab(
                  text: 'Health records — wired in Task 10',
                ),
                _LineageTab(pig: pig),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.pig});
  final Pig pig;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (pig.photoUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              pig.photoUrl!,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                height: 200,
                color: Colors.grey.shade200,
                child: const Icon(Icons.broken_image, size: 48),
              ),
            ),
          ),
        const SizedBox(height: 16),
        _row('Tag ID', pig.tagId),
        _row('Sex', pig.sex.label),
        _row('Breed', pig.breed.isEmpty ? '—' : pig.breed),
        _row('Stage', pig.stage.label),
        _row('Status', pig.status.label),
        _row('Born', DateFormat.yMMMd().format(pig.birthDate.toDate())),
        _row('Age', pig.ageString(now)),
        if (pig.currentWeight != null)
          _row(
            'Current weight',
            '${pig.currentWeight!.toStringAsFixed(1)} kg',
          ),
        _row('Area', pig.currentAreaId),
        if (pig.currentPenId != null) _row('Pen', pig.currentPenId!),
        if (pig.notes != null && pig.notes!.trim().isNotEmpty)
          _row('Notes', pig.notes!),
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label, style: const TextStyle(color: Colors.grey)),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );
}

class _LineageTab extends ConsumerWidget {
  const _LineageTab({required this.pig});
  final Pig pig;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Parents',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            title: const Text('Sire (father)'),
            subtitle: Text(pig.sireId ?? '—'),
            trailing: pig.sireId != null
                ? const Icon(Icons.chevron_right)
                : null,
            onTap: pig.sireId != null
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PigDetailScreen(pigId: pig.sireId!),
                      ),
                    )
                : null,
          ),
        ),
        Card(
          child: ListTile(
            title: const Text('Dam (mother)'),
            subtitle: Text(pig.damId ?? '—'),
            trailing: pig.damId != null
                ? const Icon(Icons.chevron_right)
                : null,
            onTap: pig.damId != null
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PigDetailScreen(pigId: pig.damId!),
                      ),
                    )
                : null,
          ),
        ),
        // Offspring discovery is a derived query — wired in Task 8 after
        // breeding records exist.
      ],
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Center(child: Text(text));
}

class _BreedingTab extends ConsumerWidget {
  const _BreedingTab({required this.pig});
  final Pig pig;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canBreed = pig.sex == PigSex.female &&
        (pig.stage == PigStage.sow || pig.stage == PigStage.gilt);
    if (!canBreed) {
      return const Center(
        child: Text('Breeding only applies to sows and gilts.'),
      );
    }
    final recordsAsync = ref.watch(
      breedingStreamProvider((farmId: pig.farmId, sowId: pig.id)),
    );
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.favorite),
        label: const Text('Log breeding'),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BreedingLogScreen(sow: pig),
          ),
        ),
      ),
      body: recordsAsync.when(
        data: (records) {
          if (records.isEmpty) {
            return const Center(child: Text('No breeding records yet.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: records
                .map(
                  (r) => Card(
                    child: ListTile(
                      title: Row(
                        children: [
                          Expanded(child: Text(r.method.label)),
                          _StatusPill(status: r.status),
                        ],
                      ),
                      subtitle: Text(
                        'Inseminated: ${DateFormat.yMMMd().format(r.inseminationDate.toDate())}\n'
                        'Expected farrow: ${DateFormat.yMMMd().format(r.expectedFarrowingDate.toDate())}\n'
                        'Boar: ${r.boarId}',
                      ),
                      isThreeLine: true,
                      trailing: r.status == BreedingStatus.planned
                          ? IconButton(
                              icon: const Icon(Icons.fact_check),
                              tooltip: 'Pregnancy check',
                              onPressed: () =>
                                  _showPregnancyCheck(context, ref, r),
                            )
                          : r.status == BreedingStatus.confirmed
                              ? IconButton(
                                  icon: const Icon(Icons.child_friendly),
                                  tooltip: 'Log farrowing',
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => FarrowingLogScreen(
                                        sow: pig,
                                        breedingRecord: r,
                                      ),
                                    ),
                                  ),
                                )
                              : null,
                    ),
                  ),
                )
                .toList(),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }

  Future<void> _showPregnancyCheck(
    BuildContext context,
    WidgetRef ref,
    BreedingRecord r,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Pregnancy check'),
        content: const Text('Was the sow confirmed pregnant?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No / Failed'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes / Confirmed'),
          ),
        ],
      ),
    );
    if (confirmed == null) return;
    final user = ref.read(authStateChangesProvider).asData?.value;
    final name =
        ref.read(currentAppUserProvider).asData?.value?.displayName ?? '';
    if (user == null) return;
    try {
      await ref.read(breedingRepositoryProvider).recordPregnancyCheck(
            farmId: pig.farmId,
            sowId: pig.id,
            breedingRecordId: r.id,
            confirmed: confirmed,
            checkDate: Timestamp.now(),
            actorUserId: user.uid,
            actorDisplayName: name,
            sowTagId: pig.tagId,
            areaId: pig.currentAreaId,
          );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not record check: $e')),
        );
      }
    }
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final BreedingStatus status;

  Color _color() {
    switch (status) {
      case BreedingStatus.planned:
        return Colors.blue;
      case BreedingStatus.confirmed:
        return Colors.green;
      case BreedingStatus.farrowed:
        return Colors.teal;
      case BreedingStatus.failed:
        return Colors.red;
      case BreedingStatus.aborted:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 12,
          color: c,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
