// lib/src/features/settings/presentation/seed_test_data_section.dart
//
// Debug-only DEVELOPER section for the Settings screen. Wraps the
// SeedDataService so a developer can:
//   1. Tap "Seed test data" to populate the current farm with a smoke-test
//      inventory (areas, pens, pigs, breedings, farrowings, health, mortality,
//      equipment, supplies, purchases, expenses, sales, shifts, tasks).
//   2. Tap "Wipe test data" to recursively delete every seeded sub-collection
//      under the farm — confirmation gated by `ConfirmDialog`.
//
// The entire widget tree is gated by `kDebugMode` at the *call site*
// (see settings_screen.dart) so release builds tree-shake this file's
// presence out — both buttons and the underlying service code.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/section_header.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../activity/application/activity_providers.dart';
import '../../areas/application/area_providers.dart';
import '../../authentication/application/auth_providers.dart';
import '../../equipment/application/equipment_providers.dart';
import '../../expenses/application/expense_providers.dart';
import '../../farms/application/farm_providers.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../pigs/application/pig_providers.dart';
import '../../purchases/application/purchase_providers.dart';
import '../../sales/application/sale_providers.dart';
import '../../shifts/application/shift_providers.dart';
import '../../tasks/application/task_providers.dart';
import '../data/seed_data_service.dart';

class SeedTestDataSection extends ConsumerStatefulWidget {
  const SeedTestDataSection({super.key});

  @override
  ConsumerState<SeedTestDataSection> createState() =>
      _SeedTestDataSectionState();
}

class _SeedTestDataSectionState extends ConsumerState<SeedTestDataSection> {
  bool _busy = false;
  String _status = '';

  SeedDataService _buildService() {
    return SeedDataService(
      firestore: ref.read(firestoreProvider),
      areaRepo: ref.read(areaRepositoryProvider),
      pigRepo: ref.read(pigRepositoryProvider),
      breedingRepo: ref.read(breedingRepositoryProvider),
      farrowingRepo: ref.read(farrowingRepositoryProvider),
      healthRepo: ref.read(healthRepositoryProvider),
      mortalityRepo: ref.read(mortalityRepositoryProvider),
      equipmentRepo: ref.read(equipmentRepositoryProvider),
      supplyRepo: ref.read(supplyRepositoryProvider),
      purchaseRepo: ref.read(purchaseRepositoryProvider),
      expenseRepo: ref.read(expenseRepositoryProvider),
      saleRepo: ref.read(saleRepositoryProvider),
      shiftRepo: ref.read(shiftRepositoryProvider),
      taskRepo: ref.read(taskRepositoryProvider),
    );
  }

  void _setStatus(String s) {
    if (!mounted) return;
    setState(() => _status = s);
  }

  Future<void> _runSeed() async {
    final l = AppLocalizations.of(context);
    final farmId = ref.read(selectedFarmIdProvider);
    final user = ref.read(authStateChangesProvider).asData?.value;
    final appUser = ref.read(currentAppUserProvider).asData?.value;
    if (farmId == null || user == null) {
      _showSnack('No farm selected.');
      return;
    }
    final displayName =
        (appUser?.displayName?.trim().isNotEmpty ?? false)
            ? appUser!.displayName!.trim()
            : (user.email ?? 'Owner');

    setState(() {
      _busy = true;
      _status = l.settings_seed_status_seeding;
    });
    try {
      final svc = _buildService();
      await svc.seedAll(
        farmId: farmId,
        ownerUserId: user.uid,
        ownerDisplayName: displayName,
        onStatus: _setStatus,
      );
      _setStatus(l.settings_seed_status_done);
      await Future<void>.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _status = '');
    } catch (e) {
      _showSnack('Seed failed: $e');
      _setStatus('');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runWipe() async {
    final l = AppLocalizations.of(context);
    final farmId = ref.read(selectedFarmIdProvider);
    if (farmId == null) {
      _showSnack('No farm selected.');
      return;
    }
    final ok = await ConfirmDialog.show(
      context: context,
      title: l.settings_seed_wipe_confirm_title,
      message: l.settings_seed_wipe_confirm_body,
      confirmLabel: l.settings_seed_button_wipe,
      destructive: true,
    );
    if (!ok) return;

    setState(() {
      _busy = true;
      _status = l.settings_seed_status_wiping;
    });
    try {
      final svc = _buildService();
      await svc.wipeAll(farmId: farmId, onStatus: _setStatus);
      _setStatus(l.settings_seed_status_done);
      await Future<void>.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _status = '');
    } catch (e) {
      _showSnack('Wipe failed: $e');
      _setStatus('');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: l.settings_seed_section_title),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: _busy ? null : _runSeed,
                icon: const Icon(Iconsax.box_add, size: 20),
                label: Text(
                  _busy ? l.settings_seed_status_seeding : l.settings_seed_button_seed,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _runWipe,
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(color: theme.colorScheme.error),
                ),
                icon: const Icon(Iconsax.trash, size: 20),
                label: Text(l.settings_seed_button_wipe),
              ),
              if (_status.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  _status,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

