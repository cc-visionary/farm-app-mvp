// lib/screens/locations/add_location_screen.dart

import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';

class AddLocationScreen extends StatefulWidget {
  const AddLocationScreen({super.key});

  @override
  State<AddLocationScreen> createState() => _AddLocationScreenState();
}

class _AddLocationScreenState extends State<AddLocationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestoreService = FirestoreService();
  String _locationName = '';
  String? _selectedLocationType;
  bool _isLoading = false;

  // This is the "fixed list" of location types for the MVP
  final List<String> _locationTypes = [
    'Livestock Pen',
    'Grazing Area',
    'Equipment Storage',
    'Main Barn',
    'Shed',
    'Pasture',
    'Building',
  ];

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() => _isLoading = true);

      try {
        await _firestoreService.addLocation(_locationName, _selectedLocationType!);
        if (mounted) {
          Navigator.of(context).pop(); // Go back to the previous screen
        }
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Location'),
        backgroundColor: const Color(0xFF388E3C),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Location Name (e.g., "Barn A")'),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Please enter a name.' : null,
                onSaved: (value) => _locationName = value!,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Location Type'),
                value: _selectedLocationType,
                items: _locationTypes.map((String type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedLocationType = newValue;
                  });
                },
                validator: (value) => value == null ? 'Please select a type.' : null,
              ),
              const SizedBox(height: 30),
              if (_isLoading)
                const Center(child: CircularProgressIndicator()),
              if (!_isLoading)
                ElevatedButton(
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Save Location', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}