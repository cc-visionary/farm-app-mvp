// lib/screens/auth/setup_farm_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';
import 'package:farm_app/screens/main_screen.dart';

class SetupFarmScreen extends StatefulWidget {
  const SetupFarmScreen({super.key});

  @override
  State<SetupFarmScreen> createState() => _SetupFarmScreenState();
}

class _SetupFarmScreenState extends State<SetupFarmScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestoreService = FirestoreService();
  String _farmName = '';

  void _createFarm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Error: No user is signed in.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Dialog(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("Setting up your farm..."),
              ],
            ),
          ),
        );
      },
    );

    try {
      await _firestoreService.createFarmForNewUser(user, _farmName);

      // Wait a moment for effect before closing dialog
      await Future.delayed(const Duration(seconds: 2));

      // Close the loading dialog
      Navigator.of(context, rootNavigator: true).pop();

      // Navigate to the home screen and remove all previous screens from the stack
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MainScreen()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      // Close the loading dialog
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to create farm: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "Let's Set Up Your Farm",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 40),
                  TextFormField(
                    key: const ValueKey('farmName'),
                    decoration: const InputDecoration(
                      labelText: 'Farm Name',
                      hintText: 'e.g. Sunny Meadows Farm',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a farm name.';
                      }
                      return null;
                    },
                    onSaved: (value) => _farmName = value!,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _createFarm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF388E3C), // Darker green
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Create Farm & Get Started',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}