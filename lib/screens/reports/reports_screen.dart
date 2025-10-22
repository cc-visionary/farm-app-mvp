// lib/screens/reports/reports_screen.dart

import 'package:flutter/material.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: const Center(
        child: Text('Reports Management Screen - Coming Soon!', style: TextStyle(fontSize: 18)),
      ),
    );
  }
}