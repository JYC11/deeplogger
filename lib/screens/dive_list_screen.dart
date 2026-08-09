import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/dive_log.dart';
import '../providers/dive_providers.dart';
import 'certifications_screen.dart';
import 'dive_detail_screen.dart';
import 'dive_form_screen.dart';
import 'gear_list_screen.dart';
import 'scan_gallery_screen.dart';

class DiveListScreen extends ConsumerWidget {
  const DiveListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLogs = ref.watch(diveListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('DiveLogger'),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library),
            tooltip: 'Scan Gallery',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScanGalleryScreen()),
              );
              ref.invalidate(diveListProvider);
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'gear') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GearListScreen()),
                );
              } else if (value == 'certs') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CertificationsScreen(),
                  ),
                );
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
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DiveFormScreen()),
          );
          ref.invalidate(diveListProvider);
        },
        child: const Icon(Icons.add),
      ),
      body: asyncLogs.when(
        data: (logs) {
          if (logs.isEmpty) {
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
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return DiveListTile(log: log);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
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
        ref.invalidate(diveListProvider);
      },
    );
  }
}
