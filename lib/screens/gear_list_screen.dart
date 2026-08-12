import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/gear_item.dart';
import '../providers/dive_providers.dart';
import '../providers/gear_form_provider.dart';

class GearListScreen extends ConsumerStatefulWidget {
  const GearListScreen({super.key});

  @override
  ConsumerState<GearListScreen> createState() => _GearListScreenState();
}

class _GearListScreenState extends ConsumerState<GearListScreen> {
  String? _categoryFilter;

  @override
  Widget build(BuildContext context) {
    final asyncGear = ref.watch(gearListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gear')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showGearDialog(context, ref, null),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: DropdownButtonFormField<String?>(
              initialValue: _categoryFilter,
              decoration: const InputDecoration(
                labelText: 'Filter by category',
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All categories'),
                ),
                ...kDefaultGearCategories.map(
                  (c) => DropdownMenuItem<String?>(value: c, child: Text(c)),
                ),
              ],
              onChanged: (v) => setState(() => _categoryFilter = v),
            ),
          ),
          Expanded(
            child: asyncGear.when(
              data: (items) {
                final filtered = _categoryFilter == null
                    ? items
                    : items
                          .where((g) => g.category == _categoryFilter)
                          .toList();
                if (filtered.isEmpty) {
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
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return ListTile(
                      leading: const Icon(Icons.inventory_2),
                      title: Text(item.name),
                      subtitle: _gearSubtitle(item),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () =>
                                _showGearDialog(context, ref, item.id),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () async {
                              await ref
                                  .read(databaseProvider)
                                  .deleteGearItem(item.id!);
                              ref.invalidate(gearListProvider);
                            },
                          ),
                        ],
                      ),
                      onTap: () => _showGearDialog(context, ref, item.id),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _gearSubtitle(GearItem item) {
    final hasNotes = item.typeNotes != null && item.typeNotes!.isNotEmpty;
    final hasCategory = item.category != null && item.category!.isNotEmpty;
    if (!hasNotes && !hasCategory) return null;
    if (hasNotes && hasCategory) {
      return Text('${item.category} · ${item.typeNotes}');
    }
    return Text(hasCategory ? item.category! : item.typeNotes!);
  }

  void _showGearDialog(BuildContext context, WidgetRef ref, int? existingId) {
    showDialog(
      context: context,
      builder: (context) => _GearDialog(existingId: existingId),
    );
  }
}

class _GearDialog extends ConsumerWidget {
  const _GearDialog({required this.existingId});

  final int? existingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(gearFormProvider(existingId));
    return AlertDialog(
      title: Text(existingId == null ? 'Add Gear Item' : 'Edit Gear Item'),
      content: async.when(
        loading: () => const SizedBox(
          height: 60,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Text('Error: $e'),
        data: (state) {
          final notifier = ref.read(gearFormProvider(existingId).notifier);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: state.name,
                decoration: InputDecoration(
                  labelText: 'Name',
                  errorText: state.validationErrors['name'],
                ),
                onChanged: notifier.setName,
              ),
              TextFormField(
                initialValue: state.typeNotes,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                ),
                onChanged: notifier.setTypeNotes,
              ),
              DropdownButtonFormField<String?>(
                initialValue: state.category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('— none —'),
                  ),
                  ...kDefaultGearCategories.map(
                    (c) => DropdownMenuItem<String?>(value: c, child: Text(c)),
                  ),
                ],
                onChanged: notifier.setCategory,
              ),
              if (state.saveError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Save failed: ${state.saveError}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final notifier = ref.read(gearFormProvider(existingId).notifier);
            final ok = await notifier.save();
            if (ok) {
              ref.invalidate(gearListProvider);
              if (context.mounted) Navigator.pop(context);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
