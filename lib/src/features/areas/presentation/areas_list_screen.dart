import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../farms/application/farm_providers.dart';
import '../application/area_providers.dart';
import 'edit_area_screen.dart';

class AreasListScreen extends ConsumerWidget {
  const AreasListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmId = ref.watch(selectedFarmIdProvider);
    if (farmId == null) return const SizedBox.shrink();
    final areasAsync = ref.watch(areasStreamProvider(farmId));

    return Scaffold(
      appBar: AppBar(title: const Text('Areas')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const EditAreaScreen())),
        child: const Icon(Icons.add),
      ),
      body: areasAsync.when(
        data: (areas) {
          if (areas.isEmpty) {
            return const Center(child: Text('No areas yet. Tap + to add one.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: areas.length,
            itemBuilder: (_, i) {
              final a = areas[i];
              return Card(
                child: ListTile(
                  title: Text(a.name),
                  subtitle: Text(a.purpose.label),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => EditAreaScreen(existing: a))),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
