import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../farms/application/farm_providers.dart';
import '../application/pig_providers.dart';
import '../domain/pig.dart';

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
                const _PlaceholderTab(
                  text: 'Breeding history — wired in Task 8',
                ),
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
