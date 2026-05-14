import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../../team/application/team_providers.dart';
import '../application/pig_providers.dart';
import '../domain/pig.dart';
import 'pig_detail_screen.dart';

class PigsListScreen extends ConsumerStatefulWidget {
  const PigsListScreen({super.key});
  @override
  ConsumerState<PigsListScreen> createState() => _PigsListScreenState();
}

class _PigsListScreenState extends ConsumerState<PigsListScreen> {
  final _search = TextEditingController();
  final Set<PigStage> _stageFilter = {};
  bool _showInactive = false;
  bool _onlyMyAreas = false;
  bool _appliedMyAreasDefault = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Pig> _filter(List<Pig> all, List<String> assignedAreaIds) {
    final q = _search.text.trim().toLowerCase();
    return all.where((p) {
      if (!_showInactive && p.status != PigStatus.active) return false;
      if (_stageFilter.isNotEmpty && !_stageFilter.contains(p.stage)) {
        return false;
      }
      if (_onlyMyAreas &&
          assignedAreaIds.isNotEmpty &&
          !assignedAreaIds.contains(p.currentAreaId)) {
        return false;
      }
      if (q.isNotEmpty && !p.tagId.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final farmId = ref.watch(selectedFarmIdProvider);
    final user = ref.watch(authStateChangesProvider).asData?.value;
    if (farmId == null || user == null) return const SizedBox.shrink();
    final pigsAsync = ref.watch(pigsStreamProvider(farmId));
    final member = ref
        .watch(memberForUserProvider((farmId: farmId, userId: user.uid)))
        .asData
        ?.value;
    final assigned = member?.assignedAreaIds ?? const <String>[];

    // Pre-apply "My areas only" once for workers with assigned areas.
    if (!_appliedMyAreasDefault &&
        member != null &&
        member.role.value == 'worker' &&
        assigned.isNotEmpty) {
      _appliedMyAreasDefault = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _onlyMyAreas = true);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pigs'),
        actions: [
          IconButton(
            icon: Icon(_showInactive ? Icons.visibility : Icons.visibility_off),
            tooltip: _showInactive ? 'Hide inactive' : 'Show inactive',
            onPressed: () => setState(() => _showInactive = !_showInactive),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search by tag ID',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              children: [
                ...PigStage.values.map((s) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(s.label),
                        selected: _stageFilter.contains(s),
                        onSelected: (sel) => setState(() => sel
                            ? _stageFilter.add(s)
                            : _stageFilter.remove(s)),
                      ),
                    )),
                Padding(
                  padding: const EdgeInsets.only(right: 8, left: 4),
                  child: FilterChip(
                    label: const Text('My areas only'),
                    selected: _onlyMyAreas,
                    onSelected: (sel) =>
                        setState(() => _onlyMyAreas = sel),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: pigsAsync.when(
              data: (all) {
                final list = _filter(all, assigned);
                if (list.isEmpty) {
                  return const Center(
                    child: Text('No pigs match the current filters.'),
                  );
                }
                // Group by stage with collapsible sections.
                final byStage = <PigStage, List<Pig>>{};
                for (final p in list) {
                  byStage.putIfAbsent(p.stage, () => []).add(p);
                }
                final stages = byStage.keys.toList()
                  ..sort((a, b) => a.index.compareTo(b.index));
                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: stages.length,
                  itemBuilder: (_, si) {
                    final s = stages[si];
                    final pigs = byStage[s]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                              top: 12, bottom: 4, left: 4),
                          child: Text(
                            '${s.label} · ${pigs.length}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        ...pigs.map((p) => _PigCard(pig: p)),
                      ],
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _PigCard extends StatelessWidget {
  const _PigCard({required this.pig});
  final Pig pig;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: pig.sex == PigSex.female
              ? Colors.pink.shade100
              : Colors.blue.shade100,
          child: Text(pig.sex == PigSex.female ? '♀' : '♂'),
        ),
        title: Text(
          pig.tagId,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${pig.breed.isEmpty ? '—' : pig.breed} · ${pig.stage.label} · ${pig.ageString(now)}',
        ),
        trailing: pig.currentWeight != null
            ? Text('${pig.currentWeight!.toStringAsFixed(0)} kg')
            : null,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PigDetailScreen(pigId: pig.id),
          ),
        ),
      ),
    );
  }
}
