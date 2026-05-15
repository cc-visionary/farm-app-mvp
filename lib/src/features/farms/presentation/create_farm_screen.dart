import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/section_header.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../authentication/application/auth_providers.dart';
import '../application/farm_providers.dart';

class CreateFarmScreen extends ConsumerStatefulWidget {
  const CreateFarmScreen({super.key});
  @override
  ConsumerState<CreateFarmScreen> createState() => _CreateFarmScreenState();
}

class _CreateFarmScreenState extends ConsumerState<CreateFarmScreen> {
  final _displayName = TextEditingController();
  final _farmName = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _displayName.dispose();
    _farmName.dispose();
    super.dispose();
  }

  Future<void> _submit(AppLocalizations l) async {
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (user == null) return;
    if (_displayName.text.trim().isEmpty || _farmName.text.trim().isEmpty) {
      setState(() => _error = l.farm_setup_both_fields_required);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).setDisplayName(
            userId: user.uid,
            displayName: _displayName.text.trim(),
          );
      final farmId = await ref.read(farmRepositoryProvider).createFarmWithOwner(
            name: _farmName.text.trim(),
            ownerUserId: user.uid,
          );
      await ref.read(authRepositoryProvider).setLastSelectedFarmId(
            userId: user.uid,
            farmId: farmId,
          );
      await persistSelectedFarmId(user.uid, farmId);
      ref.read(selectedFarmIdProvider.notifier).state = farmId;
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.farm_setup_create_title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.farm_setup_create_title,
              style: textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            Text(
              l.auth_login_subtitle,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            SectionHeader(title: l.farm_setup_create_display_name_label),
            TextField(
              controller: _displayName,
              decoration: InputDecoration(
                  hintText: l.farm_setup_create_display_name_label),
            ),
            SectionHeader(title: l.farm_setup_create_farm_name_label),
            TextField(
              controller: _farmName,
              decoration: InputDecoration(
                  hintText: l.farm_setup_create_farm_name_label),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _loading ? null : () => _submit(l),
              child: _loading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: colorScheme.onPrimary,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(l.farm_setup_create_submit),
            ),
          ],
        ),
      ),
    );
  }
}
