// lib/screens/settings/settings_screen.dart

import 'package:firebase_auth/firebase_auth.dart'; // 1. Import FirebaseAuth
import 'package:flutter/material.dart';
import '../auth/auth_screen.dart'; // 2. Import the AuthScreen for navigation

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSettingsItem(
              context,
              icon: Icons.person_outline,
              title: 'My Profile',
              onTap: () {
                /* TODO: Navigate to Profile Screen */
              },
            ),
            const SizedBox(height: 12),
            _buildSettingsItem(
              context,
              icon: Icons.agriculture_outlined,
              title: 'Farm Settings',
              onTap: () {
                /* TODO: Navigate to Farm Settings Screen */
              },
            ),
            const SizedBox(height: 12),
            _buildSettingsItem(
              context,
              icon: Icons.group_outlined,
              title: 'Manage Members',
              onTap: () {
                /* TODO: Navigate to Members Screen */
              },
            ),
            const SizedBox(height: 12),
            _buildSettingsItem(
              context,
              icon: Icons.smart_toy_outlined,
              title: 'Farm Automations',
              onTap: () {
                /* TODO: Navigate to Automations Screen */
              },
            ),

            // This pushes the logout button to the bottom
            const Spacer(),

            // The new Logout Button
            _buildLogoutItem(context),

            const SizedBox(height: 20), // Padding at the very bottom
          ],
        ),
      ),
    );
  }

  // This helper widget for standard items remains the same
  Widget _buildSettingsItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withOpacity(0.1),
          foregroundColor: Theme.of(context).colorScheme.primary,
          child: Icon(icon),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Widget _buildLogoutItem(BuildContext context) {
    // Using a different color to indicate a final action
    final Color destructiveColor = Colors.red.shade700;

    return Card(
      color: Colors.red.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        // Add a subtle border to make it stand out
        side: BorderSide(color: Colors.red.shade100, width: 1),
      ),
      child: ListTile(
        leading: Icon(Icons.logout, color: destructiveColor),
        title: Text(
          'Log Out',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: destructiveColor,
          ),
        ),
        onTap: () async {
          // Sign out from Firebase
          await FirebaseAuth.instance.signOut();

          // After signing out, navigate to the AuthScreen and remove all
          // previous screens from the navigation stack.
          if (context.mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const AuthScreen()),
              (Route<dynamic> route) => false,
            );
          }
        },
      ),
    );
  }
}
