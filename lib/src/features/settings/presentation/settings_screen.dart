import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/locale/locale_providers.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/section_header.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../authentication/application/auth_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left_2),
          onPressed: () => context.pop(),
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const SectionHeader(title: 'Account'),
          _SettingsMenuItem(
            icon: Iconsax.user,
            title: 'My profile',
            onTap: () {
              // TODO: Navigate to Profile Screen
            },
          ),
          const SectionHeader(title: 'Farm'),
          _SettingsMenuItem(
            icon: Iconsax.building,
            title: 'Farm settings',
            onTap: () {
              // TODO: Navigate to Farm Settings Screen
            },
          ),
          _SettingsMenuItem(
            icon: Iconsax.people,
            title: 'Manage members',
            onTap: () {
              // TODO: Navigate to Members Screen
            },
          ),
          const SectionHeader(title: 'App'),
          _SettingsMenuItem(
            icon: Iconsax.cpu_setting,
            title: 'Farm automations',
            onTap: () {
              // TODO: Navigate to Automations Screen
            },
          ),
          _LanguageSection(),
          const SizedBox(height: 32),
          _SettingsMenuItem(
            icon: Iconsax.logout,
            title: 'Sign out',
            destructive: true,
            onTap: () async {
              final ok = await ConfirmDialog.show(
                context: context,
                title: 'Sign out?',
                message: "You'll need to sign back in to access your farm.",
                confirmLabel: 'Sign out',
                destructive: true,
              );
              if (!ok) return;
              await ref.read(authRepositoryProvider).signOut();
              // GoRouter's redirect logic handles navigation to login.
            },
          ),
        ],
      ),
    );
  }
}

/// Language selector — three ChoiceChips wired to the localePreferenceProvider.
/// Tapping a chip persists the selection via [setLocalePreference] and the
/// app re-renders with the new locale.
class _LanguageSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final current = ref.watch(localePreferenceProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: l.settings_language_section_title),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text(l.settings_language_choice_system),
                selected: current == null,
                onSelected: (_) => setLocalePreference(ref, null),
              ),
              ChoiceChip(
                label: Text(l.settings_language_choice_english),
                selected: current?.languageCode == 'en',
                onSelected: (_) =>
                    setLocalePreference(ref, const Locale('en')),
              ),
              ChoiceChip(
                label: Text(l.settings_language_choice_filipino),
                selected: current?.languageCode == 'fil',
                onSelected: (_) =>
                    setLocalePreference(ref, const Locale('fil')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A reusable widget for displaying a single item in the settings menu.
class _SettingsMenuItem extends StatelessWidget {
  const _SettingsMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final fg = destructive ? colorScheme.error : colorScheme.primary;
    final discBg = destructive
        ? colorScheme.errorContainer
        : colorScheme.primaryContainer;
    final titleColor =
        destructive ? colorScheme.error : colorScheme.onSurface;

    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: discBg,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: fg, size: 20),
        ),
        title: Text(
          title,
          style: textTheme.titleMedium?.copyWith(color: titleColor),
        ),
        trailing: Icon(
          Iconsax.arrow_right_3,
          size: 20,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
