import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/stat_tile.dart';
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
                ? const Text('Pig')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(p.tagId, style: theme.textTheme.titleMedium),
                      Text(
                        p.stage.label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
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
            if (pig == null) {
              return const EmptyState(
                icon: Iconsax.info_circle,
                title: 'Pig not found',
                subtitle: 'It may have been removed.',
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
    final now = DateTime.now();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (pig.status == PigStatus.sold) _SoldBanner(pig: pig),
        _PhotoHeader(photoUrl: pig.photoUrl),
        const SectionHeader(title: 'Identity'),
        StatTile(label: 'Tag ID', value: pig.tagId),
        StatTile(label: 'Sex', value: pig.sex.label),
        StatTile(label: 'Breed', value: pig.breed.isEmpty ? '—' : pig.breed),
        StatTile(label: 'Stage', value: pig.stage.label),
        StatTile(label: 'Status', value: pig.status.label),
        const SectionHeader(title: 'Lifecycle'),
        StatTile(
          label: 'Born',
          value: DateFormat.yMMMd().format(pig.birthDate.toDate()),
        ),
        StatTile(label: 'Age', value: pig.ageString(now)),
        if (pig.currentWeight != null)
          StatTile(
            label: 'Current weight',
            value: '${pig.currentWeight!.toStringAsFixed(1)} kg',
          ),
        const SectionHeader(title: 'Location'),
        StatTile(
          label: 'Area',
          value: pig.currentAreaId.isEmpty ? '—' : pig.currentAreaId,
        ),
        StatTile(
          label: 'Pen',
          value: (pig.currentPenId == null || pig.currentPenId!.isEmpty)
              ? '—'
              : pig.currentPenId!,
        ),
        if (pig.notes != null && pig.notes!.trim().isNotEmpty) ...[
          const SectionHeader(title: 'Notes'),
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
                'Mark deceased',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: theme.colorScheme.error),
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () async {
                final ok = await ConfirmDialog.show(
                  context: context,
                  title: 'Mark deceased?',
                  message:
                      'This cannot be undone. The pig will be moved out of active herd.',
                  confirmLabel: 'Mark deceased',
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const SectionHeader(title: 'Parents'),
        _ParentCard(
          role: 'Sire',
          symbol: '♂',
          parentId: pig.sireId,
        ),
        _ParentCard(
          role: 'Dam',
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
            'Unknown',
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
                'Not in this farm',
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
    final recordsAsync = ref.watch(
      healthForPigProvider((farmId: pig.farmId, pigId: pig.id)),
    );
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Iconsax.health),
        label: const Text('Log health'),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => HealthLogScreen(pig: pig)),
        ),
      ),
      body: recordsAsync.when(
        data: (records) {
          if (records.isEmpty) {
            return const EmptyState(
              icon: Iconsax.health,
              title: 'No health records yet',
              subtitle: 'Tap "Log health" to record a treatment or check.',
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
                    record.type.label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat.yMMMd().format(record.date.toDate()),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (record.productName != null)
              _kv(theme, 'Product', record.productName!),
            if (record.dosage != null) _kv(theme, 'Dosage', record.dosage!),
            if (record.route != null) _kv(theme, 'Route', record.route!.label),
            if (record.diagnosis != null)
              _kv(theme, 'Diagnosis', record.diagnosis!),
            if (record.costPhp != null)
              _kv(theme, 'Cost', '₱${record.costPhp!.toStringAsFixed(2)}'),
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
                  'Withdrawal until '
                  '${DateFormat.yMMMd().format(record.withdrawalEndDate!.toDate())}',
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
    final canBreed = pig.sex == PigSex.female &&
        (pig.stage == PigStage.sow || pig.stage == PigStage.gilt);
    if (!canBreed) {
      return const EmptyState(
        icon: Iconsax.heart,
        title: 'Breeding does not apply',
        subtitle: 'Only sows and gilts can be bred.',
      );
    }
    final recordsAsync = ref.watch(
      breedingStreamProvider((farmId: pig.farmId, sowId: pig.id)),
    );
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Iconsax.heart),
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
            return const EmptyState(
              icon: Iconsax.heart,
              title: 'No breeding records yet',
              subtitle: 'Tap "Log breeding" to record an insemination.',
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
                    r.method.label,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                _StatusPill(status: r.status),
              ],
            ),
            const SizedBox(height: 12),
            _row(theme, 'Inseminated',
                DateFormat.yMMMd().format(r.inseminationDate.toDate())),
            _row(theme, 'Expected farrow',
                DateFormat.yMMMd().format(r.expectedFarrowingDate.toDate())),
            _row(theme, 'Boar', r.boarId),
            if (r.status == BreedingStatus.planned) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  icon: const Icon(Iconsax.calendar_tick, size: 20),
                  label: const Text('Pregnancy check'),
                  onPressed: onPregnancyCheck,
                ),
              ),
            ] else if (r.status == BreedingStatus.confirmed) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.child_friendly, size: 20),
                  label: const Text('Log farrowing'),
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
    final color = _color(theme.colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.label,
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
    final saleAsync = ref.watch(
      saleForPigProvider((farmId: pig.farmId, pigId: pig.id)),
    );
    return Card(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: Icon(Iconsax.tag, color: theme.colorScheme.primary),
        title: Text('Sold', style: theme.textTheme.titleMedium),
        subtitle: saleAsync.when(
          data: (sale) => sale == null
              ? const Text('— no sale record found —')
              : Text(
                  '${DateFormat.yMMMd().format(sale.saleDate.toDate())} · ${sale.buyerName}',
                ),
          loading: () => const Text('Loading sale details…'),
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
