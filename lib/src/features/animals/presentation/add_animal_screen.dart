import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../animals/application/animal_providers.dart';
import '../../animals/domain/animal_model.dart';
import '../../farms/application/farm_providers.dart';
import '../../locations/application/location_providers.dart';

// A simple map to hold breed data. In a real app, this might come from Firestore.
const Map<String, List<String>> breedOptions = {
  'Swine Management': ['Yorkshire', 'Duroc', 'Landrace', 'Hampshire'],
  'Poultry & Egg Tracking': ['Rhode Island Red', 'Leghorn', 'Plymouth Rock'],
};

class AddAnimalScreen extends ConsumerStatefulWidget {
  const AddAnimalScreen({super.key});

  @override
  ConsumerState<AddAnimalScreen> createState() => _AddAnimalScreenState();
}

class _AddAnimalScreenState extends ConsumerState<AddAnimalScreen> {
  DateTime? _birthDate;
  String? _selectedAnimalType;
  String? _selectedBreed;
  String? _selectedLocationId;
  bool _isFlock = false;

  @override
  Widget build(BuildContext context) {
    final locationsAsync = ref.watch(locationsStreamProvider);
    final farmAsync = ref.watch(currentFarmProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Add New Animal')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: farmAsync.when(
          data: (farm) {
            // Filter the available animal types based on the farm's enabled modules
            final availableTypes = breedOptions.keys
                .where((type) => farm?.enabledModules.contains(type) ?? false)
                .toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Animal Type Dropdown (based on farm modules)
                DropdownButtonFormField<String>(
                  value: _selectedAnimalType,
                  decoration: const InputDecoration(labelText: 'Animal Type'),
                  items: availableTypes.map((type) {
                    return DropdownMenuItem(value: type, child: Text(type));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedAnimalType = value;
                      _selectedBreed = null; // Reset breed selection
                      _isFlock = value == 'Poultry & Egg Tracking';
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Breed Dropdown (dynamic based on type)
                if (_selectedAnimalType != null)
                  DropdownButtonFormField<String>(
                    value: _selectedBreed,
                    decoration: const InputDecoration(labelText: 'Breed'),
                    items: (breedOptions[_selectedAnimalType] ?? []).map((breed) {
                      return DropdownMenuItem(value: breed, child: Text(breed));
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedBreed = value),
                  ),
                const SizedBox(height: 16),

                // Date Picker
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'Birth Date'),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_birthDate?.toLocal().toString().split(' ')[0] ?? 'Select Date'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) setState(() => _birthDate = date);
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Location Dropdown
                locationsAsync.when(
                  data: (locations) => DropdownButtonFormField<String>(
                    value: _selectedLocationId,
                    decoration: const InputDecoration(labelText: 'Location'),
                    items: locations.map((loc) {
                      return DropdownMenuItem(value: loc.id, child: Text(loc.name));
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedLocationId = value),
                  ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => const Text('Could not load locations'),
                ),
                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: () { /* TODO: Implement save logic */ },
                  child: const Text('Save Animal'),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => const Center(child: Text('Could not load farm data.')),
        ),
      ),
    );
  }
}