// lib/src/features/farms/presentation/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../animals/application/animal_providers.dart';
import '../../animals/presentation/animals_list_screen.dart';
import '../../locations/presentation/locations_list_screen.dart';
import '../application/farm_providers.dart';

/// This is the main screen that holds the bottom navigation bar and pages.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // The pages that correspond to the bottom navigation bar items.
  static const List<Widget> _widgetOptions = <Widget>[
    DashboardView(),
    AnimalsListScreen(), // Your new screen for listing animals
    LocationsListScreen(),
    Text('Reports Screen'), // Placeholder for reports
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
      // The floating action button for quick adds.
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigates to the 'add animal' screen using GoRouter.
          context.push('/add-animal');
        },
        shape: const CircleBorder(),
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      // The bottom navigation bar with a notch for the FAB.
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(icon: Iconsax.home, label: 'Home', index: 0),
            _buildNavItem(icon: Iconsax.pet, label: 'Animals', index: 1),
            const SizedBox(width: 40), // The space for the FAB
            _buildNavItem(
              icon: Iconsax.discover,
              label: 'Locations',
              index: 2,
            ), // Changed from Inventory for now
            _buildNavItem(icon: Iconsax.status_up, label: 'Reports', index: 3),
          ],
        ),
      ),
    );
  }

  /// A helper widget to build each navigation item.
  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;
    final color = isSelected ? Theme.of(context).primaryColor : Colors.grey;
    return InkWell(
      onTap: () => _onItemTapped(index),
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, color: color)),
          ],
        ),
      ),
    );
  }
}

// --- Dashboard View ---

/// This is the main dashboard content displayed on the Home tab.
class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the stream of animals to get real-time data.
    final farmAsyncValue = ref.watch(currentFarmProvider);
    final animalsAsync = ref.watch(animalsStreamProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Iconsax.setting_2),
          onPressed: () {
            // Navigate to the settings screen
            context.push('/settings');
          },
        ),
        title: farmAsyncValue.when(
          data: (farm) =>
              Text(farm?.name ?? 'Dashboard'), // Display farm name or a default
          loading: () => const Text('Loading...'),
          error: (_, __) => const Text('Farm Error'),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Badge(
              label: Text('2'), // Example notification count
              child: Icon(Icons.notifications_none, size: 28),
            ),
            onPressed: () {
              /* Handle notification tap */
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
            // Dashboard Header
            Text('Dashboard', style: textTheme.headlineLarge),
            const SizedBox(height: 16),

            // Swine Overview Card (Now with live data)
            animalsAsync.when(
              data: (animals) => _buildOverviewCard(
                context: context,
                title: 'Swine Overview',
                data: {
                  'Total Hogs': animals.length.toString(),
                  // These would be calculated from animal properties in a real scenario
                  'Pregnant Sows': '16',
                  'Upcoming Farrowing': '3',
                },
              ),
              loading: () => const Card(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (err, stack) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Error loading animals: $err'),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tasks Card
            _buildTasksCard(context),
            const SizedBox(height: 16),

            // Low Inventory Card
            _buildLowInventoryCard(context),
          ],
        ),
      ),
    );
  }

  // --- Reusable Widget Builders ---

  Widget _buildOverviewCard({
    required BuildContext context,
    required String title,
    required Map<String, String> data,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
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

  Widget _buildTasksCard(BuildContext context) {
    // In a real app, this state would be managed by a provider
    final tasks = {'Vaccinate batch B-12': false, 'Move sow #5': true};
    return Card(
      color: const Color(0xFFF1F8E9), // Light green background
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tasks For You Today',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            ...tasks.entries.map((task) {
              return CheckboxListTile(
                title: Text(task.key),
                value: task.value,
                onChanged: (bool? value) {
                  /* Handle task state change */
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

  Widget _buildLowInventoryCard(BuildContext context) {
    return Card(
      color: const Color(0xFFFFF8E1), // Light yellow background
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Low Inventory',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            _buildInventoryItem(
              context,
              'Sow Feed',
              '2 bags left',
              Colors.red.shade700,
            ),
            const SizedBox(height: 8),
            _buildInventoryItem(
              context,
              'Heat Lamps',
              '5 units left',
              Colors.orange.shade800,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryItem(
    BuildContext context,
    String title,
    String subtitle,
    Color textColor,
  ) {
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
}
