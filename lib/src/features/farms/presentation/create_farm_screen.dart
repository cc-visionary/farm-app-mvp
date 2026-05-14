import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/section_header.dart';
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

  Future<void> _submit() async {
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (user == null) return;
    if (_displayName.text.trim().isEmpty || _farmName.text.trim().isEmpty) {
      setState(() => _error = 'Both fields are required.');
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

    return Scaffold(
      appBar: AppBar(title: const Text('Set up your farm')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Welcome",
              style: textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            Text(
              "Tell us a bit about you and your farm.",
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SectionHeader(title: 'About you'),
            TextField(
              controller: _displayName,
              decoration: const InputDecoration(hintText: 'Your name'),
            ),
            const SectionHeader(title: 'Your farm'),
            TextField(
              controller: _farmName,
              decoration: const InputDecoration(hintText: 'Farm name'),
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
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: colorScheme.onPrimary,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text('Create farm'),
            ),
          ],
        ),
      ),
    );
  }
}
