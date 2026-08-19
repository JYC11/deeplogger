import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../database/sort_fields.dart';
import '../models/dive_log.dart';
import '../providers/dive_providers.dart';
import '../providers/list_providers.dart';
import '../services/backup_service.dart';
import 'certifications_screen.dart';
import 'dive_detail_screen.dart';
import 'dive_form_screen.dart';
import 'gear_list_screen.dart';
import 'scan_gallery_screen.dart';

class DiveListScreen extends ConsumerStatefulWidget {
  const DiveListScreen({super.key});

  @override
  ConsumerState<DiveListScreen> createState() => _DiveListScreenState();
}

class _DiveListScreenState extends ConsumerState<DiveListScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  bool _searchVisible = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Debounces search input so a DB query doesn't fire per keystroke.
  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(diveListNotifierProvider.notifier).setSearch(v);
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll - currentScroll < 200) {
      unawaited(ref.read(diveListNotifierProvider.notifier).loadMore());
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(diveListNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('DeepLogger'),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library),
            tooltip: 'Scan Gallery',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScanGalleryScreen()),
              );
              unawaited(ref.read(diveListNotifierProvider.notifier).refresh());
            },
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            onPressed: () => _showSortMenu(context, ref),
          ),
          IconButton(
            icon: Icon(_searchVisible ? Icons.search_off : Icons.search),
            tooltip: 'Search',
            onPressed: () => setState(() => _searchVisible = !_searchVisible),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'gear':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GearListScreen()),
                  );
                case 'certs':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CertificationsScreen(),
                    ),
                  );
                case 'backup':
                  unawaited(_exportBackup(context));
                case 'restore':
                  unawaited(_importBackup(context, ref));
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'gear',
                child: ListTile(
                  leading: Icon(Icons.inventory_2),
                  title: Text('Gear'),
                ),
              ),
              const PopupMenuItem(
                value: 'certs',
                child: ListTile(
                  leading: Icon(Icons.card_membership),
                  title: Text('Certifications'),
                ),
              ),
              const PopupMenuItem(
                value: 'backup',
                child: ListTile(
                  leading: Icon(Icons.file_upload_outlined),
                  title: Text('Backup'),
                ),
              ),
              const PopupMenuItem(
                value: 'restore',
                child: ListTile(
                  leading: Icon(Icons.file_download_outlined),
                  title: Text('Restore'),
                ),
              ),
            ],
          ),
        ],
        bottom: _searchVisible
            ? PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search location or notes...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
              )
            : null,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DiveFormScreen()),
          );
          unawaited(ref.read(diveListNotifierProvider.notifier).refresh());
        },
        child: const Icon(Icons.add),
      ),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (state) {
          if (state.logs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pool, size: 64),
                  SizedBox(height: 16),
                  Text('No dives yet'),
                  SizedBox(height: 8),
                  Text('Tap + to add your first dive'),
                ],
              ),
            );
          }
          return ListView.builder(
            controller: _scrollController,
            itemCount: state.logs.length + (state.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == state.logs.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return DiveListTile(log: state.logs[index]);
            },
          );
        },
      ),
    );
  }

  void _showSortMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        final current = ref.read(diveListNotifierProvider).requireValue;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(title: const Text('Sort field')),
              for (final field in DiveLogSortField.values)
                // ignore: deprecated_member_use
                RadioListTile<DiveLogSortField>(
                  value: field,
                  // ignore: deprecated_member_use
                  groupValue: current.sortField,
                  title: Text(_sortFieldLabel(field)),
                  // ignore: deprecated_member_use
                  onChanged: (v) {
                    if (v == null) return;
                    ref
                        .read(diveListNotifierProvider.notifier)
                        .setSort(v, current.sortDesc);
                    Navigator.pop(context);
                  },
                ),
              const Divider(),
              SwitchListTile(
                title: Text(current.sortDesc ? 'Descending' : 'Ascending'),
                value: current.sortDesc,
                onChanged: (v) {
                  ref
                      .read(diveListNotifierProvider.notifier)
                      .setSort(current.sortField, v);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _sortFieldLabel(DiveLogSortField f) {
    switch (f) {
      case DiveLogSortField.startTime:
        return 'Start time';
      case DiveLogSortField.location:
        return 'Location';
      case DiveLogSortField.maxDepthM:
        return 'Max depth';
      case DiveLogSortField.durationMin:
        return 'Duration';
    }
  }

  /// F7: build the backup zip in a temp dir and surface the iOS/Android
  /// share sheet so the user can save it to Files / drive / etc.
  Future<void> _exportBackup(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final zipPath = await BackupService.instance.exportToZip();
      await SharePlus.instance.share(
        ShareParams(files: [XFile(zipPath)], text: 'DeepLogger backup'),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Backup failed: $e')));
    }
  }

  /// F7: pick a backup zip, confirm the destructive replace, restore it,
  /// then refresh the dive list so the imported data shows up.
  Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    if (picked == null || picked.path == null) return;
    final zipPath = picked.path!;

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore backup?'),
        content: const Text(
          'This permanently replaces ALL current data (dives, photos, gear, '
          'certifications, unit preferences) with the contents of the backup '
          'file. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final manifest = await BackupService.instance.importFromZip(zipPath);
      // Refresh the dive list so imported rows appear.
      await ref.read(diveListNotifierProvider.notifier).refresh();
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Restored backup from ${DateFormat.yMMMd().format(manifest.exportedAt)} '
            '(${manifest.includes.length} components)',
          ),
        ),
      );
    } on BackupManifestException catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Backup invalid: ${e.message}')),
      );
    } on BackupSchemaException catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Cannot import: ${e.message}')),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Restore failed: $e')));
    }
  }
}

class DiveListTile extends ConsumerWidget {
  const DiveListTile({super.key, required this.log});

  final DiveLog log;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateStr = log.startTime != null
        ? DateFormat.yMMMd().format(log.startTime!)
        : 'No date';
    final sac = ref.watch(sacProvider(log));

    return ListTile(
      leading: log.isDraft
          ? const Icon(Icons.edit_note, color: Colors.orange)
          : const Icon(Icons.scuba_diving),
      title: Text(log.location ?? 'Unknown location'),
      subtitle: Text(
        '$dateStr'
        '${log.maxDepthM != null ? '  •  ${log.maxDepthM!.toStringAsFixed(1)}m' : ''}'
        '${log.durationMin != null ? '  •  ${log.durationMin!.toStringAsFixed(0)}min' : ''}'
        '${sac?.litersPerMin != null ? '  •  ${sac!.litersPerMin!.toStringAsFixed(1)} L/min' : ''}',
      ),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DiveDetailScreen(diveId: log.id!)),
        );
        unawaited(ref.read(diveListNotifierProvider.notifier).refresh());
      },
    );
  }
}
