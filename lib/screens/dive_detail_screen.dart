import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/dive_log.dart';
import '../models/dive_photo.dart';
import '../models/sighting.dart';
import '../providers/dive_providers.dart';
import '../services/sac_calculator.dart';
import '../services/share_card.dart';
import 'dive_form_screen.dart';

class DiveDetailScreen extends ConsumerWidget {
  const DiveDetailScreen({super.key, required this.diveId});

  final int diveId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLog = ref.watch(diveDetailProvider(diveId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dive Detail'),
        actions: [
          asyncLog.maybeWhen(
            data: (log) => log != null
                ? Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.share),
                        tooltip: 'Share',
                        onPressed: () async {
                          final photos = await ref
                              .read(databaseProvider)
                              .getDivePhotosForLog(diveId);
                          final sightings = await ref
                              .read(databaseProvider)
                              .getSightingsForLog(diveId);
                          final sac = ref.read(sacProvider(log));
                          if (context.mounted) {
                            await ShareCardService.showPreviewAndShare(
                              context: context,
                              log: log,
                              photos: photos.map((p) => p.localPath).toList(),
                              sightings: sightings,
                              sac: sac,
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DiveFormScreen(existingLog: log),
                            ),
                          );
                          ref.invalidate(diveDetailProvider(diveId));
                        },
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: asyncLog.when(
        data: (log) {
          if (log == null) {
            return const Center(child: Text('Dive not found'));
          }
          return DiveDetailView(diveId: diveId, log: log);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }
}

class DiveDetailView extends ConsumerWidget {
  const DiveDetailView({super.key, required this.diveId, required this.log});

  final int diveId;
  final DiveLog log;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sac = ref.watch(sacProvider(log));
    final asyncGear = ref.watch(diveGearProvider(diveId));
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (log.isDraft)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Draft — complete the details'),
          ),
        const SizedBox(height: 16),
        Text(
          log.location ?? 'Unknown location',
          style: theme.textTheme.headlineSmall,
        ),
        if (log.startTime != null)
          Text(DateFormat.yMMMd().add_Hm().format(log.startTime!)),
        const SizedBox(height: 24),

        // Primary stats
        _PrimaryStatsRow(log: log, sac: sac),

        const SizedBox(height: 24),

        // SAC detail
        if (sac != null) ...[
          Text('SAC Rate', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (sac.litersPerMin != null)
            _StatRow('L/min', sac.litersPerMin!.toStringAsFixed(1)),
          _StatRow('bar/min', sac.barPerMin.toStringAsFixed(2)),
          if (sac.psiPerMin != null)
            _StatRow('psi/min', sac.psiPerMin!.toStringAsFixed(1)),
          if (sac.cubicFtPerMin != null)
            _StatRow('cu ft/min', sac.cubicFtPerMin!.toStringAsFixed(2)),
          if (!sac.hasFullSac)
            const Text(
              'Tank volume unknown — showing bar/min only',
              style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
            ),
          const SizedBox(height: 24),
        ],

        // Expandable secondary stats
        ExpansionTile(
          title: const Text('Details'),
          children: [
            _StatRow('Tank Size', log.tankSize ?? '—'),
            _StatRow('Gas', _gasLabel(log)),
            _StatRow('Start Pressure', '${log.startPressureBar ?? '—'} bar'),
            _StatRow('End Pressure', '${log.endPressureBar ?? '—'} bar'),
            _StatRow('Water Temp', '${log.waterTempC ?? '—'} °C'),
            _StatRow('Salinity', log.salinity ?? '—'),
            _StatRow('Altitude', log.altitude ?? '—'),
            _StatRow('Visibility', '${log.visibilityM ?? '—'} m'),
            _StatRow('Weight', '${log.weightKg ?? '—'} kg'),
            if (log.notes != null && log.notes!.isNotEmpty) ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(log.notes!),
              ),
            ],
            asyncGear.when(
              data: (gear) => gear.isEmpty
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Gear', style: theme.textTheme.titleSmall),
                          ...gear.map((g) => Text('• ${g.name}')),
                        ],
                      ),
                    ),
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Loading gear...'),
              ),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Marine life sightings
        _SightingsSection(diveId: diveId),
      ],
    );
  }

  String _gasLabel(DiveLog log) {
    if (log.gasType == null) return '—';
    if (log.gasType == 'Other' && log.gasOther != null) {
      return 'Other: ${log.gasOther}';
    }
    return log.gasType!;
  }
}

class _PrimaryStatsRow extends StatelessWidget {
  const _PrimaryStatsRow({required this.log, required this.sac});

  final DiveLog log;
  final SacResult? sac;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (log.maxDepthM != null)
          _PrimaryStat(
            icon: Icons.arrow_downward,
            label: 'Max Depth',
            value: '${log.maxDepthM!.toStringAsFixed(1)} m',
          ),
        if (log.durationMin != null)
          _PrimaryStat(
            icon: Icons.timer,
            label: 'Duration',
            value: '${log.durationMin!.toStringAsFixed(0)} min',
          ),
        if (sac?.litersPerMin != null)
          _PrimaryStat(
            icon: Icons.air,
            label: 'SAC',
            value: '${sac!.litersPerMin!.toStringAsFixed(1)} L/min',
          )
        else if (sac != null)
          _PrimaryStat(
            icon: Icons.air,
            label: 'SAC',
            value: '${sac!.barPerMin.toStringAsFixed(1)} bar/min',
          ),
      ],
    );
  }
}

class _PrimaryStat extends StatelessWidget {
  const _PrimaryStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, size: 28, color: theme.colorScheme.primary),
              const SizedBox(height: 4),
              Text(value, style: theme.textTheme.titleMedium),
              Text(label, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _SightingsSection extends ConsumerWidget {
  const _SightingsSection({required this.diveId});

  final int diveId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSightings = ref.watch(sightingsProvider(diveId));
    final asyncPhotos = ref.watch(divePhotosProvider(diveId));

    return ExpansionTile(
      title: const Text('Marine Life'),
      trailing: asyncPhotos.maybeWhen(
        data: (photos) => photos.isEmpty
            ? const SizedBox.shrink()
            : IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => _showAddSightingDialog(context, ref, photos),
              ),
        orElse: () => const SizedBox.shrink(),
      ),
      children: [
        asyncSightings.when(
          data: (sightings) {
            if (sightings.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No sightings recorded'),
              );
            }

            final photoMap = <int, DivePhoto>{};
            asyncPhotos.maybeWhen(
              data: (photos) {
                for (final p in photos) {
                  if (p.id != null) photoMap[p.id!] = p;
                }
              },
              orElse: () {},
            );

            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sightings.map((s) {
                final photo = s.divePhotoId != null
                    ? photoMap[s.divePhotoId!]
                    : null;
                return Chip(
                  avatar: photo != null
                      ? CircleAvatar(
                          backgroundImage: FileImage(File(photo.localPath)),
                        )
                      : const CircleAvatar(child: Icon(Icons.eco)),
                  label: Text(s.commonName),
                  onDeleted: () async {
                    await ref.read(databaseProvider).deleteSighting(s.id!);
                    ref.invalidate(sightingsProvider(diveId));
                  },
                );
              }).toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Loading sightings...'),
          ),
          error: (_, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  void _showAddSightingDialog(
    BuildContext context,
    WidgetRef ref,
    List<DivePhoto> photos,
  ) {
    final nameCtrl = TextEditingController();
    DivePhoto? selectedPhoto;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Sighting'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Common Name'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<DivePhoto>(
                    initialValue: selectedPhoto,
                    decoration: const InputDecoration(labelText: 'Photo'),
                    items: photos
                        .map(
                          (p) => DropdownMenuItem(
                            value: p,
                            child: Text(p.localPath.split('/').last),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => selectedPhoto = v),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (nameCtrl.text.isEmpty) return;
                    await ref
                        .read(databaseProvider)
                        .insertSighting(
                          Sighting(
                            diveLogId: diveId,
                            divePhotoId: selectedPhoto?.id,
                            commonName: nameCtrl.text,
                          ),
                        );
                    ref.invalidate(sightingsProvider(diveId));
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
