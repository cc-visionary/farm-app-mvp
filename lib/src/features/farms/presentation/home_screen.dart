// lib/src/features/farms/presentation/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart'; // For modern icons
import '../../authentication/application/auth_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0; // To track active tab in bottom nav

  // Placeholder for task state
  final Map<String, bool> _tasks = {
    'Vaccinate batch B-12': false,
    'Move sow #5 to farrowing pen': true,
    'Check chicken feeder levels': false,
  };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.only(left: 8.0),
          child: Icon(Icons.menu),
        ),
        title: const Text('Green Valley Farm'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Badge(
              label: Text('2'), // Example notification count
              child: Icon(Icons.notifications_none, size: 28),
            ),
            onPressed: () {
              // TODO: Handle notification tap
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ## 1. Dashboard Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Dashboard', style: textTheme.headlineLarge),
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Customize'),
                  onPressed: () {
                    // TODO: Handle dashboard customization
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ## 2. Overview Cards
            _buildOverviewCard(
              icon: Iconsax.box,
              title: 'Swine Overview',
              data: {
                'Total Hogs': '124',
                'Pregnant Sows': '16',
                'Upcoming Farrowing': '3',
              },
            ),
            const SizedBox(height: 16),
            _buildOverviewCard(
              icon: Iconsax.wind, // Using a different icon for variety
              title: 'Poultry Overview',
              data: {
                'Total Birds': '850',
                'Daily Egg Count': '723',
                'Feed Ratio': '2.1',
              },
            ),
            const SizedBox(height: 16),

            // ## 3. Tasks Card
            _buildTasksCard(),
            const SizedBox(height: 16),

            // ## 4. "Needs Attention" Card (Low Inventory)
            _buildLowInventoryCard(),
            const SizedBox(height: 16),
            // ## BONUS: Financial Overview Card (As requested)
            _buildOverviewCard(
              icon: Iconsax.dollar_circle,
              title: 'Financial Overview',
              data: {
                'Gross Revenue (MTD)': '\$12,450',
                'Expenses (MTD)': '\$7,890',
                'Net Profit': '\$4,560',
              },
            ),
          ],
        ),
      ),

      // ## 5. Bottom Navigation & Floating Action Button
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Handle quick-add action
        },
        shape: const CircleBorder(),
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(icon: Iconsax.home, label: 'Home', index: 0),
            _buildNavItem(icon: Iconsax.pet, label: 'Animals', index: 1),
            const SizedBox(width: 40), // The space for the FAB
            _buildNavItem(icon: Iconsax.box_1, label: 'Inventory', index: 2),
            _buildNavItem(icon: Iconsax.status_up, label: 'Reports', index: 3),
          ],
        ),
      ),
    );
  }

  // ### Reusable Widget Builders ###

  Widget _buildOverviewCard({
    required IconData icon,
    required String title,
    required Map<String, String> data,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                Icon(Iconsax.category),
              ],
            ),
            const Divider(height: 24),
            ...data.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.key,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      entry.value,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksCard() {
    return Card(
      color: const Color(0xFFF1F8E9), // Light green background
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tasks For You Today',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Icon(Iconsax.category),
              ],
            ),
            const SizedBox(height: 8),
            ..._tasks.entries.map((task) {
              return CheckboxListTile(
                title: Text(task.key),
                value: task.value,
                onChanged: (bool? value) {
                  setState(() {
                    _tasks[task.key] = value!;
                  });
                },
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: Theme.of(context).primaryColor,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildLowInventoryCard() {
    return Card(
      color: const Color(0xFFFFF8E1), // Light yellow background
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Low Inventory',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Icon(Iconsax.category),
              ],
            ),
            const SizedBox(height: 12),
            _buildInventoryItem('Sow Feed', '2 bags left', Colors.red.shade700),
            const SizedBox(height: 8),
            _buildInventoryItem(
              'Heat Lamps',
              '5 units left',
              Colors.orange.shade800,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryItem(String title, String subtitle, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24),
            ),
            child: const Text('Reorder'),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
