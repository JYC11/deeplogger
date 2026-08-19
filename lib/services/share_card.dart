import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/dive_log.dart';
import '../models/sighting.dart';
import '../services/sac_calculator.dart';

/// A visually appealing card widget for Instagram-style sharing (PRD §5.5).
///
/// Shows: site, date, duration, max depth, SAC, ≤4-photo grid, ≤5 species.
class ShareCard extends StatelessWidget {
  const ShareCard({
    super.key,
    required this.log,
    required this.photos,
    required this.sightings,
    required this.sac,
  });

  final DiveLog log;
  final List<String> photos;
  final List<Sighting> sightings;
  final SacResult? sac;

  @override
  Widget build(BuildContext context) {
    final dateStr = log.startTime != null
        ? DateFormat.yMMMd().format(log.startTime!)
        : '';

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 1080,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.teal.shade800, Colors.teal.shade400],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              log.location ?? 'Unknown Location',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              dateStr,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                if (log.maxDepthM != null)
                  _StatChip(
                    label: 'Depth',
                    value: '${log.maxDepthM!.toStringAsFixed(1)}m',
                  ),
                if (log.durationMin != null)
                  _StatChip(
                    label: 'Duration',
                    value: '${log.durationMin!.toStringAsFixed(0)}min',
                  ),
                if (sac?.litersPerMin != null)
                  _StatChip(
                    label: 'SAC',
                    value: '${sac!.litersPerMin!.toStringAsFixed(1)} L/min',
                  )
                else if (sac != null)
                  _StatChip(
                    label: 'SAC',
                    value: '${sac!.barPerMin.toStringAsFixed(1)} bar/min',
                  ),
              ],
            ),
            if (photos.isNotEmpty) ...[
              const SizedBox(height: 24),
              _PhotoGrid(photos: photos.take(4).toList()),
            ],
            if (sightings.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Marine Life',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: sightings.take(5).map((s) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      s.commonName,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 24),
            Center(
              child: Text(
                'DeepLogger',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  /// Fixed width sized to the 1080-px canvas (F5). Using `Expanded` made
  /// each chip ~95px wide in the narrow preview dialog and wrapped the
  /// value char-by-char. A fixed width makes the layout display-independent
  /// of the surrounding constraints; the preview dialog wraps the card in a
  /// `SingleChildScrollView` so the 1080 canvas renders sanely at any size.
  static const double width = 320;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.photos});

  final List<String> photos;

  @override
  Widget build(BuildContext context) {
    if (photos.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(photos[0]),
          width: double.infinity,
          height: 400,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            height: 400,
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(photos[index]),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                Container(color: Colors.white.withValues(alpha: 0.1)),
          ),
        );
      },
    );
  }
}

/// Shows a share card preview dialog and captures it as PNG for sharing.
///
/// Usage from a [ConsumerWidget]:
/// ```dart
/// await ShareCardService.showPreviewAndShare(
///   context: context,
///   log: log,
///   photos: photoPaths,
///   sightings: sightings,
///   sac: sac,
/// );
/// ```
class ShareCardService {
  ShareCardService._internal();
  static final ShareCardService instance = ShareCardService._internal();

  /// Shows a preview dialog with the share card and a Share button.
  static Future<void> showPreviewAndShare({
    required BuildContext context,
    required DiveLog log,
    required List<String> photos,
    required List<Sighting> sightings,
    required SacResult? sac,
  }) async {
    final boundaryKey = GlobalKey();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Share Card'),
          content: SingleChildScrollView(
            child: FittedBox(
              // Scale the 1080-px card down to fit the dialog (F5). The
              // RepaintBoundary still captures at the card's intrinsic size
              // (1080 wide) because FittedBox renders its child at full
              // intrinsic size and only scales for display.
              fit: BoxFit.contain,
              alignment: Alignment.topCenter,
              child: RepaintBoundary(
                key: boundaryKey,
                child: ShareCard(
                  log: log,
                  photos: photos,
                  sightings: sightings,
                  sac: sac,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.share),
              label: const Text('Share'),
              onPressed: () async {
                await _captureAndShare(boundaryKey, log);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  /// Captures the [RepaintBoundary] as PNG and shares via share_plus.
  static Future<void> _captureAndShare(
    GlobalKey boundaryKey,
    DiveLog log,
  ) async {
    final boundary =
        boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return;

    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;

    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/dive_card_${log.id ?? 'share'}.png';
    final file = File(filePath);
    await file.writeAsBytes(byteData.buffer.asUint8List());

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath)],
          text: 'My dive at ${log.location ?? "unknown"} #DeepLogger',
        ),
      );
    } finally {
      // Clean up the temp PNG so it doesn't accumulate across shares (G2).
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {
          // Best-effort cleanup; ignore deletion failures.
        }
      }
    }
  }
}
