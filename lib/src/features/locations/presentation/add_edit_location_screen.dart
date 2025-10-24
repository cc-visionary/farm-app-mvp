import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../authentication/application/auth_providers.dart';
import '../../locations/application/location_providers.dart';
import '../../locations/domain/location_model.dart';

class AddEditLocationScreen extends ConsumerStatefulWidget {
  final Location? location; // Pass a location to edit, or null to add
  const AddEditLocationScreen({super.key, this.location});

  @override
  ConsumerState<AddEditLocationScreen> createState() => _AddEditLocationScreenState();
}

class _AddEditLocationScreenState extends ConsumerState<AddEditLocationScreen> {
  final _nameController = TextEditingController();
  LocationType _selectedType = LocationType.building;
  bool get _isEditing => widget.location != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameController.text = widget.location!.name;
      _selectedType = widget.location!.type;
    }
  }

  Future<void> _saveLocation() async {
    final farmId = ref.read(currentFarmIdProvider);
    if (farmId == null) return;

    final newLocation = Location(
      id: _isEditing ? widget.location!.id : '',
      name: _nameController.text,
      type: _selectedType,
      farmId: farmId,
    );

    final repo = ref.read(locationRepositoryProvider);
    if (_isEditing) {
      await repo.updateLocation(newLocation);
    } else {
      await repo.addLocation(newLocation);
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Location' : 'Add New Location'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Location Name'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<LocationType>(
              value: _selectedType,
              decoration: const InputDecoration(labelText: 'Location Type'),
              items: LocationType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.name[0].toUpperCase() + type.name.substring(1)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _selectedType = value);
              },
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _saveLocation,
              child: const Text('Save Location'),
            ),
          ],
        ),
      ),
    );
  }
}