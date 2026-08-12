import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/scanned_photo.dart';
import '../providers/list_providers.dart';
import '../services/dive_grouper.dart';
import '../services/draft_completer.dart';
import '../services/gallery_scanner.dart';
import 'dive_form_screen.dart';

/// Screen for scanning the gallery and reviewing auto-generated draft dives.
class ScanGalleryScreen extends ConsumerStatefulWidget {
  const ScanGalleryScreen({super.key});

  @override
  ConsumerState<ScanGalleryScreen> createState() => _ScanGalleryScreenState();
}

class _ScanGalleryScreenState extends ConsumerState<ScanGalleryScreen> {
  bool _scanning = false;
  String? _error;
  List<DraftDive> _drafts = [];

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _error = null;
      _drafts = [];
    });

    try {
      final scanner = GalleryScanner.instance;
      final hasPermission = await scanner.hasPermission();
      if (!hasPermission) {
        final granted = await scanner.requestPermission();
        if (!granted) {
          setState(() {
            _scanning = false;
            _error =
                'Gallery permission denied. '
                'Enable photo access in Settings to use this feature.';
          });
          return;
        }
      }

      final photos = await scanner.scanGalleryTimestamps();
      if (photos.isEmpty) {
        setState(() {
          _scanning = false;
          _error = 'No photos with timestamps found in your gallery.';
        });
        return;
      }

      final drafts = groupScannedPhotos(photos);

      setState(() {
        _scanning = false;
        _drafts = drafts;
      });
    } catch (e) {
      setState(() {
        _scanning = false;
        _error = 'Scan failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Gallery')),
      body: _scanning
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Scanning gallery...'),
                ],
              ),
            )
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _scan, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_drafts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.photo_library, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Scan your gallery to automatically create draft dive logs '
                'from your photos.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _scan,
                icon: const Icon(Icons.search),
                label: const Text('Scan Gallery'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '${_drafts.length} draft dive${_drafts.length == 1 ? '' : 's'} found',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        ..._drafts.map(
          (draft) => _DraftTile(
            draft: draft,
            photoCount: draft.photos.length,
            onComplete: () => _completeDraft(draft),
            onDiscard: () => _discardDraft(draft),
          ),
        ),
      ],
    );
  }

  Future<void> _completeDraft(DraftDive draft) async {
    final result = await DraftCompleter.instance.complete(draft: draft);
    if (!mounted) return;
    // Surface partial-failure counts (E2).
    if (result.skippedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result.attachedCount} of ${draft.photos.length} photos attached',
          ),
        ),
      );
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DiveFormScreen(existingLogId: result.diveLogId),
      ),
    );
    unawaited(ref.read(diveListNotifierProvider.notifier).refresh());
  }

  void _discardDraft(DraftDive draft) {
    setState(() {
      _drafts.remove(draft);
    });
  }
}

class _DraftTile extends StatelessWidget {
  const _DraftTile({
    required this.draft,
    required this.photoCount,
    required this.onComplete,
    required this.onDiscard,
  });

  final DraftDive draft;
  final int photoCount;
  final VoidCallback onComplete;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final start = draft.startTime;
    final end = draft.endTime;
    final duration = end.difference(start);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.edit_note, color: Colors.orange),
        title: Text('${start.day}/${start.month}/${start.year}'),
        subtitle: Text(
          '${start.toString().split(' ').last.split('.').first} - '
          '${end.toString().split(' ').last.split('.').first}'
          '${duration.inMinutes > 0 ? ' (${duration.inMinutes} min)' : ''}'
          ' · $photoCount photo${photoCount == 1 ? '' : 's'}',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'complete') onComplete();
            if (value == 'discard') onDiscard();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'complete', child: Text('Complete')),
            const PopupMenuItem(value: 'discard', child: Text('Discard')),
          ],
        ),
      ),
    );
  }
}
