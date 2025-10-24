import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import '../application/location_providers.dart';
import '../domain/location_model.dart';
import './add_edit_location_screen.dart';

class LocationsListScreen extends ConsumerWidget {
  const LocationsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationsAsync = ref.watch(locationsStreamProvider);

    IconData _getIconForType(LocationType type) {
      switch (type) {
        case LocationType.building:
          return Iconsax.building;
        case LocationType.pen:
          return Iconsax.box_1;
        case LocationType.pasture:
          return Iconsax.wind;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Locations'), automaticallyImplyLeading: false),
      body: locationsAsync.when(
        data: (locations) => ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: locations.length,
          itemBuilder: (context, index) {
            final location = locations[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: ListTile(
                leading: CircleAvatar(
                  child: Icon(_getIconForType(location.type)),
                ),
                title: Text(location.name),
                subtitle: Text('${location.type.name} - 2 Locations'), // Placeholder
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/edit-location', extra: location),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add-location'),
        child: const Icon(Icons.add),
      ),
    );
  }
}