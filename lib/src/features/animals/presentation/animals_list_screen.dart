import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../application/animal_providers.dart';
import '../domain/animal_model.dart';

class AnimalsListScreen extends ConsumerWidget {
  const AnimalsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the stream provider to get live updates of the animal list.
    final animalsAsync = ref.watch(animalsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Animals'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Iconsax.search_normal),
            onPressed: () {
              // TODO: Implement animal search functionality
            },
          ),
          IconButton(
            icon: const Icon(Iconsax.filter),
            onPressed: () {
              // TODO: Implement animal filtering functionality
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: animalsAsync.when(
        // The data has been successfully loaded.
        data: (animals) {
          // If the list is empty, show a helpful message.
          if (animals.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Iconsax.pet, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No animals found.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tap the + button to add your first animal.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          // If there are animals, display them in a list.
          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: animals.length,
            itemBuilder: (context, index) {
              final animal = animals[index];
              return _AnimalListItem(animal: animal);
            },
          );
        },
        // The data is still loading.
        loading: () => const Center(child: CircularProgressIndicator()),
        // An error occurred while fetching the data.
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add-animal'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// A reusable widget to display a single animal's information in a card.
class _AnimalListItem extends StatelessWidget {
  const _AnimalListItem({required this.animal});

  final Animal animal;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withOpacity(0.1),
          foregroundColor: Theme.of(context).colorScheme.primary,
          child: const Icon(Iconsax.pet),
        ),
        title: Text(
          animal.animalId, // e.g., "SOW-001"
          style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          // Using the intl package for nice date formatting.
          'Born: ${DateFormat.yMMMd().format(animal.birthDate)}',
          style: textTheme.bodyMedium,
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () {
          // TODO: Navigate to the specific animal's profile screen
          // Example: context.push('/animal-profile/${animal.id}');
        },
      ),
    );
  }
}
