import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../authentication/application/auth_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Reusable menu item widget for a clean look
          _SettingsMenuItem(
            icon: Iconsax.user,
            title: 'My Profile',
            onTap: () {
              // TODO: Navigate to Profile Screen
            },
          ),
          _SettingsMenuItem(
            icon: Iconsax.building,
            title: 'Farm Settings',
            onTap: () {
              // TODO: Navigate to Farm Settings Screen
            },
          ),
          _SettingsMenuItem(
            icon: Iconsax.user,
            title: 'Manage Members',
            onTap: () {
              // TODO: Navigate to Members Screen
            },
          ),
          _SettingsMenuItem(
            icon: Iconsax.cpu_setting,
            title: 'Farm Automations',
            onTap: () {
              // TODO: Navigate to Automations Screen
            },
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          // Special menu item for the logout action
          _SettingsMenuItem(
            icon: Iconsax.logout,
            title: 'Logout',
            // Use the theme's error color for a distinct look
            iconColor: Theme.of(context).colorScheme.error,
            textColor: Theme.of(context).colorScheme.error,
            onTap: () async {
              // Call the signOut method from your repository
              await ref.read(authRepositoryProvider).signOut();
              // GoRouter's redirect logic will automatically handle
              // navigating the user to the login screen.
            },
          ),
        ],
      ),
    );
  }
}

/// A reusable widget for displaying a single item in the settings menu.
class _SettingsMenuItem extends StatelessWidget {
  const _SettingsMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor,
    this.textColor,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? Theme.of(context).colorScheme.primary;

    return Card(
      // Using Card for elevation and consistent styling
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16.0,
          color: Colors.grey,
        ),
      ),
    );
  }
}