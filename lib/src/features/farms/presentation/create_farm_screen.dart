// lib/src/features/farms/presentation/create_farm_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../authentication/application/auth_providers.dart';

class CreateFarmScreen extends ConsumerWidget {
  const CreateFarmScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmNameController = TextEditingController();
    // Get current user's ID
    final user = ref.watch(authStateChangesProvider).asData?.value;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Your Farm')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: farmNameController, decoration: const InputDecoration(labelText: 'Farm Name')),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (user == null) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You are not logged in!')));
                   return;
                }
                try {
                  await ref.read(authRepositoryProvider).createFarm(
                        farmName: farmNameController.text,
                        ownerId: user.uid,
                      );
                  if (context.mounted) context.go('/');
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              },
              child: const Text('Create Farm'),
            ),
          ],
        ),
      ),
    );
  }
}