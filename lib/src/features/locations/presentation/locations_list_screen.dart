import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/location_providers.dart';

class LocationsListScreen extends ConsumerWidget {
  const LocationsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationsAsync = ref.watch(locationsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Locations')),
      body: locationsAsync.when(
        data: (locations) => ListView.builder(
          itemCount: locations.length,
          itemBuilder: (context, index) {
            final location = locations[index];
            return ListTile(
              title: Text(location.name),
              subtitle: Text(location.type.name),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Navigate to Add Location Screen
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}