// lib/screens/animals/animals_screen.dart

import 'package:flutter/material.dart';

class AnimalsScreen extends StatelessWidget {
  const AnimalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Animals')),
      body: const Center(
        child: Text('Animal Management Screen - Coming Soon!', style: TextStyle(fontSize: 18)),
      ),
    );
  }
}