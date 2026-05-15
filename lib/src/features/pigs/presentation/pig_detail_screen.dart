import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/i18n/intl_helpers.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../authentication/application/auth_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../../sales/application/sale_providers.dart';
import '../../sales/presentation/sale_detail_screen.dart';
import '../application/pig_providers.dart';
import '../domain/breeding_record.dart';
import '../domain/health_record.dart';
import '../domain/pig.dart';
import 'breeding_log_screen.dart';
import 'farrowing_log_screen.dart';
import 'health_log_screen.dart';
import 'mortality_log_screen.dart';

class PigDetailScreen extends ConsumerWidget {
  const PigDetailScreen({super.key, required this.pigId});
  final String pigId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) return const SizedBox.shrink();
    final pigAsync =
        ref.watch(pigByIdProvider((farmId: farmId, pigId: pigId)));
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: pigAsync.maybeWhen(
            data: (p) => p == null
                ? Text(l.pig_detail_title_fallback)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(p.tagId, style: theme.textTheme.titleMedium),
                      Text(
                        localizedPigStage(l, p.stage),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
            orElse: () => Text(l.pig_detail_title_fallback),
          ),
          bottom: TabBar(
            tabs: [
              Tab(text: l.pig_detail_tab_profile),
              Tab(text: l.pig_detail_tab_breeding),
              Tab(text: l.pig_detail_tab_health),
              Tab(text: l.pig_detail_tab_lineage),
            ],
          ),
        ),
        body: pigAsync.when(
          data: (pig) {
            if (pig == null) {
              return EmptyState(
                icon: Iconsax.info_circle,
                title: l.pig_detail_not_found_title,
                subtitle: l.pig_detail_not_found_subtitle,
              );
            }
            return TabBarView(
              children: [
                _ProfileTab(pig: pig),
                _BreedingTab(pig: pig),
                _HealthTab(pig: pig),
                _LineageTab(pig: pig),
              ],
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
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.pig});
  final Pig pig;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final now = DateTime.now();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (pig.status == PigStatus.sold) _SoldBanner(pig: pig),
        _PhotoHeader(photoUrl: pig.photoUrl),
        SectionHeader(title: l.pig_detail_section_identity),
        StatTile(label: l.pig_detail_profile_tag_id, value: pig.tagId),
        StatTile(
          label: l.pig_detail_profile_sex,
          value: localizedPigSex(l, pig.sex),
        ),
        StatTile(
          label: l.pig_detail_profile_breed,
          value: pig.breed.isEmpty ? '—' : pig.breed,
        ),
        StatTile(
          label: l.pig_detail_profile_stage,
          value: localizedPigStage(l, pig.stage),
        ),
        StatTile(
          label: l.pig_detail_profile_status,
          value: localizedPigStatus(l, pig.status),
        ),
        SectionHeader(title: l.pig_detail_section_lifecycle),
        StatTile(
          label: l.pig_detail_profile_born,
          value: formatMediumDate(context, pig.birthDate.toDate()),
        ),
        StatTile(
          label: l.pig_detail_profile_age,
          value: localizedAge(l, pig, now),
        ),
        if (pig.currentWeight != null)
          StatTile(
            label: l.pig_detail_profile_current_weight,
            value: '${pig.currentWeight!.toStringAsFixed(1)} kg',
          ),
        SectionHeader(title: l.pig_detail_section_location),
        StatTile(
          label: l.pig_detail_profile_area,
          value: pig.currentAreaId.isEmpty ? '—' : pig.currentAreaId,
        ),
        StatTile(
          label: l.pig_detail_profile_pen,
          value: (pig.currentPenId == null || pig.currentPenId!.isEmpty)
              ? '—'
              : pig.currentPenId!,
        ),
        if (pig.notes != null && pig.notes!.trim().isNotEmpty) ...[
          SectionHeader(title: l.pig_detail_section_notes),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(pig.notes!, style: theme.textTheme.bodyLarge),
          ),
        ],
        if (pig.status == PigStatus.active) ...[
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              icon: Icon(Icons.heart_broken, color: theme.colorScheme.error),
              label: Text(
                l.pig_detail_profile_mark_deceased,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: theme.colorScheme.error),
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () async {
                final ok = await ConfirmDialog.show(
                  context: context,
                  title: l.pig_detail_profile_mark_deceased_confirm_title,
                  message: l.pig_detail_profile_mark_deceased_confirm_body,
                  confirmLabel: l.pig_detail_profile_mark_deceased,
                  destructive: true,
                );
                if (!ok || !context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MortalityLogScreen(pig: pig),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _PhotoHeader extends StatelessWidget {
  const _PhotoHeader({this.photoUrl});
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (photoUrl == null || photoUrl!.isEmpty) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Icon(
          Iconsax.pet,
          size: 48,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: CachedNetworkImage(
        imageUrl: photoUrl!,
        height: 220,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (_, _) => Container(
          height: 220,
          color: theme.colorScheme.surfaceContainerHigh,
        ),
        errorWidget: (_, _, _) => Container(
          height: 220,
          color: theme.colorScheme.surfaceContainerHigh,
          alignment: Alignment.center,
          child: Icon(
            Iconsax.gallery,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _LineageTab extends ConsumerWidget {
  const _LineageTab({required this.pig});
  final Pig pig;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        SectionHeader(title: l.pig_detail_section_parents),
        _ParentCard(
          role: l.pig_detail_lineage_sire,
          symbol: '♂',
          parentId: pig.sireId,
        ),
        _ParentCard(
          role: l.pig_detail_lineage_dam,
          symbol: '♀',
          parentId: pig.damId,
        ),
      ],
    );
  }
}

class _ParentCard extends ConsumerWidget {
  const _ParentCard({
    required this.role,
    required this.symbol,
    required this.parentId,
  });
  final String role;
  final String symbol;
  final String? parentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final farmId = ref.watch(selectedFarmIdProvider);
    final isFemale = symbol == '♀';
    final avatarBg = isFemale
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHigh;
    final avatarFg = isFemale
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurfaceVariant;

    if (parentId == null || parentId!.isEmpty) {
      return Card(
        child: ListTile(
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: avatarBg,
            foregroundColor: avatarFg,
            child: Text(
              symbol,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          title: Text(role, style: theme.textTheme.titleMedium),
          subtitle: Text(
            l.pig_detail_lineage_unknown,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    final pigAsync = farmId == null
        ? const AsyncValue<Pig?>.data(null)
        : ref.watch(pigByIdProvider((farmId: farmId, pigId: parentId!)));

    return Card(
      child: pigAsync.when(
        data: (parent) {
          if (parent == null) {
            return ListTile(
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: avatarBg,
                foregroundColor: avatarFg,
                child: Text(
                  symbol,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              title: Text(role, style: theme.textTheme.titleMedium),
              subtitle: Text(
                l.pig_detail_lineage_not_in_farm,
                style: theme.textTheme.bodyMedium,
              ),
            );
          }
          return ListTile(
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: avatarBg,
              foregroundColor: avatarFg,
              child: Text(
                symbol,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            title: Text(role, style: theme.textTheme.titleMedium),
            subtitle: Text(
              parent.tagId,
              style: theme.textTheme.bodyMedium,
            ),
            trailing: const Icon(Iconsax.arrow_right_3, size: 20),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PigDetailScreen(pigId: parent.id),
              ),
            ),
          );
        },
        loading: () => ListTile(
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: avatarBg,
            foregroundColor: avatarFg,
            child: Text(
              symbol,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          title: Text(role, style: theme.textTheme.titleMedium),
          subtitle: const SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (_, _) => ListTile(
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: avatarBg,
            foregroundColor: avatarFg,
            child: Text(symbol),
          ),
          title: Text(role, style: theme.textTheme.titleMedium),
          subtitle: Text(parentId!, style: theme.textTheme.bodyMedium),
        ),
      ),
    );
  }
}

class _HealthTab extends ConsumerWidget {
  const _HealthTab({required this.pig});
  final Pig pig;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final recordsAsync = ref.watch(
      healthForPigProvider((farmId: pig.farmId, pigId: pig.id)),
    );
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Iconsax.health),
        label: Text(l.pig_detail_health_fab_log),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => HealthLogScreen(pig: pig)),
        ),
      ),
      body: recordsAsync.when(
        data: (records) {
          if (records.isEmpty) {
            return EmptyState(
              icon: Iconsax.health,
              title: l.pig_detail_health_no_records_title,
              subtitle: l.pig_detail_health_no_records_subtitle,
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: records.map((r) => _HealthCard(record: r)).toList(),
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
    );
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.record});
  final HealthRecord record;

  IconData _typeIcon() {
    switch (record.type) {
      case HealthEventType.vaccination:
        return Iconsax.shield_tick;
      case HealthEventType.treatment:
        return Iconsax.hospital;
      case HealthEventType.checkup:
        return Iconsax.search_status;
      case HealthEventType.deworming:
        return Iconsax.shield_security;
    }
  }

  Color _typeColor(ColorScheme scheme) {
    switch (record.type) {
      case HealthEventType.vaccination:
        return scheme.primary;
      case HealthEventType.treatment:
        return scheme.tertiary;
      case HealthEventType.checkup:
        return scheme.onSurfaceVariant;
      case HealthEventType.deworming:
        return scheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final color = _typeColor(theme.colorScheme);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_typeIcon(), size: 20, color: color),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _localizedHealthType(l, record.type),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  formatMediumDate(context, record.date.toDate()),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (record.productName != null)
              _kv(theme, l.pig_detail_health_row_product, record.productName!),
            if (record.dosage != null)
              _kv(theme, l.pig_detail_health_row_dosage, record.dosage!),
            if (record.route != null)
              _kv(
                theme,
                l.pig_detail_health_row_route,
                _localizedHealthRoute(l, record.route!),
              ),
            if (record.diagnosis != null)
              _kv(
                theme,
                l.pig_detail_health_row_diagnosis,
                record.diagnosis!,
              ),
            if (record.costPhp != null)
              _kv(
                theme,
                l.pig_detail_health_row_cost,
                formatCurrencyPhp(context, record.costPhp!),
              ),
            if (record.withdrawalEndDate != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  l.pig_detail_health_withdrawal_until(
                    formatMediumDate(
                      context,
                      record.withdrawalEndDate!.toDate(),
                    ),
                  ),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            if (record.photoUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 80,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: record.photoUrls
                      .map(
                        (url) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: url,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              placeholder: (_, _) => Container(
                                width: 80,
                                height: 80,
                                color: theme.colorScheme.surfaceContainerHigh,
                              ),
                              errorWidget: (_, _, _) => Container(
                                width: 80,
                                height: 80,
                                color: theme.colorScheme.surfaceContainerHigh,
                                alignment: Alignment.center,
                                child: Icon(
                                  Iconsax.gallery,
                                  size: 20,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
            if (record.notes != null && record.notes!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(record.notes!, style: theme.textTheme.bodyLarge),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kv(ThemeData theme, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(label, style: theme.textTheme.bodyMedium),
            ),
            Expanded(
              child: Text(value, style: theme.textTheme.bodyLarge),
            ),
          ],
        ),
      );
}

class _BreedingTab extends ConsumerWidget {
  const _BreedingTab({required this.pig});
  final Pig pig;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final canBreed = pig.sex == PigSex.female &&
        (pig.stage == PigStage.sow || pig.stage == PigStage.gilt);
    if (!canBreed) {
      return EmptyState(
        icon: Iconsax.heart,
        title: l.pig_detail_breeding_not_applicable_title,
        subtitle: l.pig_detail_breeding_not_applicable_subtitle,
      );
    }
    final recordsAsync = ref.watch(
      breedingStreamProvider((farmId: pig.farmId, sowId: pig.id)),
    );
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Iconsax.heart),
        label: Text(l.pig_detail_breeding_fab_log),
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
            return EmptyState(
              icon: Iconsax.heart,
              title: l.pig_detail_breeding_no_records_title,
              subtitle: l.pig_detail_breeding_no_records_subtitle,
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: records
                .map(
                  (r) => _BreedingCard(
                    record: r,
                    pig: pig,
                    onPregnancyCheck: () =>
                        _showPregnancyCheck(context, ref, r),
                  ),
                )
                .toList(),
          );
        },
        loading: () => const Center(
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }

  Future<void> _showPregnancyCheck(
    BuildContext context,
    WidgetRef ref,
    BreedingRecord r,
  ) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.breeding_pregnancy_check_dialog_title),
        content: Text(l.breeding_pregnancy_check_dialog_body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.breeding_pregnancy_check_no),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.breeding_pregnancy_check_yes),
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
          SnackBar(
            content: Text(l.pig_detail_breeding_check_error(e.toString())),
          ),
        );
      }
    }
  }
}

class _BreedingCard extends StatelessWidget {
  const _BreedingCard({
    required this.record,
    required this.pig,
    required this.onPregnancyCheck,
  });

  final BreedingRecord record;
  final Pig pig;
  final VoidCallback onPregnancyCheck;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final r = record;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _localizedBreedingMethod(l, r.method),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                _StatusPill(status: r.status),
              ],
            ),
            const SizedBox(height: 12),
            _row(
              theme,
              l.pig_detail_breeding_row_inseminated,
              formatMediumDate(context, r.inseminationDate.toDate()),
            ),
            _row(
              theme,
              l.pig_detail_breeding_row_expected,
              formatMediumDate(context, r.expectedFarrowingDate.toDate()),
            ),
            _row(theme, l.pig_detail_breeding_row_boar, r.boarId),
            if (r.status == BreedingStatus.planned) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  icon: const Icon(Iconsax.calendar_tick, size: 20),
                  label: Text(l.pig_detail_breeding_action_pregnancy_check),
                  onPressed: onPregnancyCheck,
                ),
              ),
            ] else if (r.status == BreedingStatus.confirmed) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.child_friendly, size: 20),
                  label: Text(l.pig_detail_breeding_action_farrow),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FarrowingLogScreen(
                        sow: pig,
                        breedingRecord: r,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(ThemeData theme, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(label, style: theme.textTheme.bodyMedium),
            ),
            Expanded(
              child: Text(value, style: theme.textTheme.bodyLarge),
            ),
          ],
        ),
      );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final BreedingStatus status;

  Color _color(ColorScheme scheme) {
    switch (status) {
      case BreedingStatus.planned:
        return scheme.tertiary;
      case BreedingStatus.confirmed:
        return scheme.primary;
      case BreedingStatus.farrowed:
        return scheme.primary;
      case BreedingStatus.failed:
        return scheme.error;
      case BreedingStatus.aborted:
        return scheme.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final color = _color(theme.colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _localizedBreedingStatus(l, status),
        style: theme.textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SoldBanner extends ConsumerWidget {
  const _SoldBanner({required this.pig});
  final Pig pig;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final saleAsync = ref.watch(
      saleForPigProvider((farmId: pig.farmId, pigId: pig.id)),
    );
    return Card(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: Icon(Iconsax.tag, color: theme.colorScheme.primary),
        title: Text(
          l.pig_detail_sold_banner_title,
          style: theme.textTheme.titleMedium,
        ),
        subtitle: saleAsync.when(
          data: (sale) => sale == null
              ? Text(l.pig_detail_sold_banner_no_record)
              : Text(
                  l.pig_detail_sold_banner_subtitle(
                    formatMediumDate(context, sale.saleDate.toDate()),
                    sale.buyerName,
                  ),
                ),
          loading: () => Text(l.pig_detail_sold_banner_loading),
          error: (e, _) => Text('$e'),
        ),
        trailing: saleAsync.maybeWhen(
          data: (sale) => sale == null ? null : const Icon(Iconsax.arrow_right_3),
          orElse: () => null,
        ),
        onTap: () {
          final sale = saleAsync.asData?.value;
          if (sale != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SaleDetailScreen(saleId: sale.id),
              ),
            );
          }
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Enum-to-label helpers (file-private)
//
// These live next to the screen because they are pure UI mappings and the
// underlying enums are also referenced by sibling screens. We keep them as
// top-level (not extension methods on the enums) so the domain layer stays
// import-free from `AppLocalizations`.
// ---------------------------------------------------------------------------

String _localizedBreedingMethod(AppLocalizations l, BreedingMethod m) {
  switch (m) {
    case BreedingMethod.natural:
      return l.breeding_method_natural;
    case BreedingMethod.ai:
      return l.breeding_method_ai;
  }
}

String _localizedBreedingStatus(AppLocalizations l, BreedingStatus s) {
  switch (s) {
    case BreedingStatus.planned:
      return l.breeding_status_planned;
    case BreedingStatus.confirmed:
      return l.breeding_status_confirmed;
    case BreedingStatus.farrowed:
      return l.breeding_status_farrowed;
    case BreedingStatus.failed:
      return l.breeding_status_failed;
    case BreedingStatus.aborted:
      return l.breeding_status_aborted;
  }
}

String _localizedHealthType(AppLocalizations l, HealthEventType t) {
  switch (t) {
    case HealthEventType.vaccination:
      return l.health_event_type_vaccination;
    case HealthEventType.treatment:
      return l.health_event_type_treatment;
    case HealthEventType.checkup:
      return l.health_event_type_checkup;
    case HealthEventType.deworming:
      return l.health_event_type_deworming;
  }
}

String _localizedHealthRoute(AppLocalizations l, HealthRoute r) {
  switch (r) {
    case HealthRoute.oral:
      return l.health_route_oral;
    case HealthRoute.im:
      return l.health_route_im;
    case HealthRoute.sc:
      return l.health_route_sc;
    case HealthRoute.topical:
      return l.health_route_topical;
  }
}
