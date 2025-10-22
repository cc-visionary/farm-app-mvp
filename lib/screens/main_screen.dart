// lib/screens/main_screen.dart

import 'package:flutter/material.dart';
import 'dashboard/dashboard_screen.dart';
import 'animals/animals_screen.dart';
import 'inventory/inventory_screen.dart';
import 'reports/reports_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0; // Index for the current tab

  // List of the screens to be displayed for each tab
  static const List<Widget> _widgetOptions = <Widget>[
    DashboardScreen(),
    AnimalsScreen(),
    InventoryScreen(),
    ReportsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: _widgetOptions.elementAt(_selectedIndex)),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Define what happens when '+' is tapped
        },
        // Use the primary color from our theme
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 2.0,
        shape: const CircleBorder(),
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      // The updated BottomAppBar
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: Colors.white, // Set a solid white background color
        elevation: 10.0, // Give it a subtle shadow
        child: SizedBox(
          height: 65, // Increased height for better touch targets and padding
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              // Left side icons
              Row(
                children: [
                  const SizedBox(width: 12), // Padding from the edge
                  _buildNavItem(Icons.home_filled, 'Home', 0),
                  const SizedBox(width: 12), // Padding from the edge
                  _buildNavItem(Icons.pets, 'Animals', 1),
                ],
              ),
              // Right side icons
              Row(
                children: [
                  _buildNavItem(Icons.inventory_2_outlined, 'Inventory', 2),
                  const SizedBox(width: 12), // Padding from the edge
                  _buildNavItem(Icons.bar_chart, 'Reports', 3),
                  const SizedBox(width: 12), // Padding from the edge
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    // Use colors from our app's theme for consistency
    final color = isSelected
        ? Theme.of(context).colorScheme.primary
        : Colors.grey.shade600;

    return InkWell(
      onTap: () => _onItemTapped(index),
      borderRadius: BorderRadius.circular(30), // Rounded splash effect
      child: Container(
        width: 75, // Fixed width for each item
        padding: const EdgeInsets.symmetric(vertical: 6),
        // This decoration creates the pill shape for the selected item
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).scaffoldBackgroundColor
              : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                // Make the text bold if selected
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
