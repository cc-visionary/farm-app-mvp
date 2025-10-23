import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../locations/application/location_providers.dart';

class AddAnimalScreen extends ConsumerWidget {
  const AddAnimalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationsAsync = ref.watch(locationsStreamProvider);
    // TODO: Add controllers and form logic

    return Scaffold(
      appBar: AppBar(title: const Text('Add New Animal')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const TextField(
              decoration: InputDecoration(labelText: 'Animal ID'),
            ),
            const SizedBox(height: 16),
            // Location Dropdown
            locationsAsync.when(
              data: (locations) => DropdownButtonFormField(
                items: locations.map((loc) {
                  return DropdownMenuItem(
                    value: loc.id,
                    child: Text(loc.name),
                  );
                }).toList(),
                onChanged: (value) {},
                decoration: const InputDecoration(labelText: 'Location'),
              ),
              loading: () => const CircularProgressIndicator(),
              error: (e, s) => const Text('Could not load locations'),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {},
              child: const Text('Save Animal'),
            )
          ],
        ),
      ),
    );
  }
}