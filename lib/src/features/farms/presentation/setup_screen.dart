import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/application/auth_providers.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _displayNameController = TextEditingController();
  final _farmNameController = TextEditingController();
  bool _isLoading = false;

  // State for module selection
  final Map<String, bool> _modules = {
    'Swine Management': true,
    'Poultry & Egg Tracking': false,
    'Inventory Control': true,
    'Health Monitoring': false,
  };

  Future<void> _submitSetup() async {
    setState(() => _isLoading = true);
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return; // Should not happen if on this screen

    final selectedModules = _modules.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    try {
      await ref
          .read(authRepositoryProvider)
          .completeSetup(
            userId: user.uid,
            displayName: _displayNameController.text,
            farmName: _farmNameController.text,
            selectedModules: selectedModules,
          );
      // GoRouter redirect will handle navigation automatically after this
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to complete setup: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome! Let\'s Get Started')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Step 1: Your Profile',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _displayNameController,
              decoration: const InputDecoration(labelText: 'Your Name'),
            ),
            const SizedBox(height: 24),

            const Text(
              'Step 2: Your Farm',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _farmNameController,
              decoration: const InputDecoration(labelText: 'Farm Name'),
            ),
            const SizedBox(height: 24),

            const Text(
              'Step 3: Choose Your Modules',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ..._modules.keys.map((String key) {
              return CheckboxListTile(
                title: Text(key),
                value: _modules[key],
                onChanged: (bool? value) {
                  setState(() {
                    _modules[key] = value!;
                  });
                },
              );
            }).toList(),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _isLoading ? null : _submitSetup,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Complete Setup'),
            ),
          ],
        ),
      ),
    );
  }
}
