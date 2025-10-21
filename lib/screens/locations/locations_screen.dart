// lib/screens/locations/locations_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/location.dart';
import '../../services/firestore_service.dart';
import 'add_location_screen.dart';

class LocationsScreen extends StatefulWidget {
  const LocationsScreen({super.key});

  @override
  State<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<LocationsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  String _searchQuery = '';

  // Helper function to get an icon based on location type
  IconData _getIconForLocationType(String type) {
    switch (type.toLowerCase()) {
      case 'building':
      case 'main barn':
      case 'livestock pen':
        return Icons.home_work_outlined;
      case 'pen':
        return Icons.grid_on_sharp;
      case 'pasture':
      case 'grazing area':
        return Icons.grass;
      case 'shed':
      case 'equipment storage':
        return Icons.inventory_2_outlined;
      default:
        return Icons.location_pin;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Locations'),
        backgroundColor: const Color(0xFF388E3C), // Dark green
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search locations',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 15.0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          // Location List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestoreService.getLocations(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No locations yet.\nTap the + button to add one!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  );
                }

                // Filter the locations based on the search query
                final filteredDocs = snapshot.data!.docs.where((doc) {
                  final location = Location.fromFirestore(doc);
                  return location.name.toLowerCase().contains(_searchQuery);
                }).toList();

                if (filteredDocs.isEmpty) {
                    return const Center(child: Text('No locations match your search.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final location = Location.fromFirestore(filteredDocs[index]);
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.shade100,
                          child: Icon(
                            _getIconForLocationType(location.type),
                            color: const Color(0xFF388E3C),
                          ),
                        ),
                        title: Text(location.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(location.type),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                        onTap: () {
                          // TODO: Navigate to a location detail screen in the future
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (ctx) => const AddLocationScreen()),
          );
        },
        backgroundColor: const Color(0xFF388E3C), // Dark green
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}