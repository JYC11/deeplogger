import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/gear_item.dart';
import '../providers/dive_providers.dart';

class GearListScreen extends ConsumerWidget {
  const GearListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncGear = ref.watch(gearListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gear')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: asyncGear.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2, size: 64),
                  SizedBox(height: 16),
                  Text('No gear items yet'),
                  SizedBox(height: 8),
                  Text('Tap + to add your gear'),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                leading: const Icon(Icons.inventory_2),
                title: Text(item.name),
                subtitle: item.typeNotes != null ? Text(item.typeNotes!) : null,
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () async {
                    await ref.read(databaseProvider).deleteGearItem(item.id!);
                    ref.invalidate(gearListProvider);
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Gear Item'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                TextFormField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                await ref
                    .read(databaseProvider)
                    .insertGearItem(
                      GearItem(
                        name: nameCtrl.text,
                        typeNotes: notesCtrl.text.isEmpty
                            ? null
                            : notesCtrl.text,
                      ),
                    );
                ref.invalidate(gearListProvider);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}
