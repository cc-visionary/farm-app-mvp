import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../../team/application/team_providers.dart';
import '../application/pig_providers.dart';
import '../domain/pig.dart';
import 'add_edit_pig_screen.dart';
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

  bool get _hasActiveFilters =>
      _stageFilter.isNotEmpty ||
      _onlyMyAreas ||
      _search.text.trim().isNotEmpty;

  void _clearFilters() {
    setState(() {
      _stageFilter.clear();
      _onlyMyAreas = false;
      _search.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
        title: Text(l.pigs_list_title),
        actions: [
          IconButton(
            icon: Icon(_showInactive ? Iconsax.eye : Iconsax.eye_slash),
            tooltip: _showInactive
                ? l.pigs_list_filter_hide_inactive
                : l.pigs_list_filter_show_inactive,
            onPressed: () => setState(() => _showInactive = !_showInactive),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddEditPigScreen()),
        ),
        icon: const Icon(Iconsax.add),
        label: Text(l.pigs_list_fab_add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: l.pigs_list_search_hint,
                prefixIcon: const Icon(Iconsax.search_normal, size: 20),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...PigStage.values.map(
                  (s) => FilterChip(
                    label: Text(localizedPigStage(l, s)),
                    selected: _stageFilter.contains(s),
                    onSelected: (sel) => setState(() => sel
                        ? _stageFilter.add(s)
                        : _stageFilter.remove(s)),
                  ),
                ),
                FilterChip(
                  label: Text(l.pigs_list_filter_my_areas),
                  selected: _onlyMyAreas,
                  onSelected: (sel) => setState(() => _onlyMyAreas = sel),
                ),
              ],
            ),
          ),
          Expanded(
            child: pigsAsync.when(
              data: (all) {
                final list = _filter(all, assigned);
                if (list.isEmpty) {
                  if (all.isEmpty) {
                    return EmptyState(
                      icon: Iconsax.pet,
                      title: l.pigs_list_empty_title,
                      subtitle: l.pigs_list_empty_subtitle,
                      action: FilledButton.icon(
                        icon: const Icon(Iconsax.add, size: 20),
                        label: Text(l.pigs_list_fab_add),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddEditPigScreen(),
                          ),
                        ),
                      ),
                    );
                  }
                  return EmptyState(
                    icon: Iconsax.search_status,
                    title: l.pigs_list_no_match_title,
                    subtitle: l.pigs_list_no_match_subtitle,
                    action: _hasActiveFilters
                        ? OutlinedButton(
                            onPressed: _clearFilters,
                            child: Text(l.pigs_list_filter_clear),
                          )
                        : null,
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
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                  itemCount: stages.length,
                  itemBuilder: (_, si) {
                    final s = stages[si];
                    final pigs = byStage[s]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionHeader(
                          title: l.pigs_list_section_with_count(
                            localizedPigStage(l, s),
                            pigs.length,
                          ),
                        ),
                        ...pigs.map((p) => _PigCard(pig: p)),
                      ],
                    );
                  },
                );
              },
              loading: () => const Center(
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
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
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final now = DateTime.now();
    final breed = pig.breed.isEmpty ? '—' : pig.breed;
    final subtitleParts = [
      breed,
      localizedPigStage(l, pig.stage),
      localizedAge(l, pig, now),
    ];
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: pig.sex == PigSex.female
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHigh,
          foregroundColor: pig.sex == PigSex.female
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onSurfaceVariant,
          child: Text(
            pig.sex == PigSex.female ? '♀' : '♂',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        title: Text(
          pig.tagId,
          style: theme.textTheme.titleMedium,
        ),
        subtitle: Text(
          subtitleParts.join(' · '),
          style: theme.textTheme.bodyMedium,
        ),
        trailing: pig.currentWeight != null
            ? RichText(
                text: TextSpan(
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  children: [
                    TextSpan(text: pig.currentWeight!.toStringAsFixed(0)),
                    TextSpan(
                      text: ' kg',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              )
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
