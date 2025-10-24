import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import '../../animals/application/animal_providers.dart';
import '../../animals/domain/animal_model.dart';

class AnimalsListScreen extends ConsumerWidget {
  const AnimalsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final animalsAsync = ref.watch(animalsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Animals'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Search and Filter UI
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by ID or Location',
                    prefixIcon: Icon(Iconsax.search_normal),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView(
                    // In a real app, this would be dynamic
                    scrollDirection: Axis.horizontal,
                    children: [
                      FilterChip(
                        label: const Text('Animal Type: Pigs'),
                        onSelected: (b) {},
                        selected: true,
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Location: Building A'),
                        onSelected: (b) {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Animal List
          Expanded(
            child: animalsAsync.when(
              data: (animals) {
                if (animals.isEmpty)
                  return const Center(child: Text('No animals yet.'));
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: animals.length,
                  itemBuilder: (context, index) {
                    final animal = animals[index];
                    if (animal.category == AnimalCategory.individual) {
                      return _IndividualAnimalCard(animal: animal);
                    } else {
                      return _FlockAnimalCard(animal: animal);
                    }
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

// Card for single animals like pigs
class _IndividualAnimalCard extends StatelessWidget {
  final Animal animal;
  const _IndividualAnimalCard({required this.animal});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Iconsax.box, size: 32),
              title: Text(
                animal.animalId,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              subtitle: Text(
                'Location: ${animal.locationId}',
              ), // In a real app, you'd look up the name
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _InfoChip(label: 'Stage', value: animal.stage ?? 'N/A'),
                _InfoChip(label: 'Age', value: animal.age),
                _InfoChip(label: 'Weight', value: '${animal.weight ?? 0} lbs'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Card for groups like chicken flocks
class _FlockAnimalCard extends StatelessWidget {
  final Animal animal;
  const _FlockAnimalCard({required this.animal});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFF1F8E9),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Iconsax.pet, size: 32),
              title: Text(
                animal.animalId,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              subtitle: Text('Location: ${animal.locationId}'),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _InfoChip(label: 'Quantity', value: animal.quantity.toString()),
                _InfoChip(label: 'Age', value: animal.age),
                _InfoChip(
                  label: 'Eggs/day',
                  value: '~${(animal.quantity! * 0.9).round()}',
                ), // Example calculation
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Helper for the small info chips inside the cards
class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
