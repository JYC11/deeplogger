import '../database/database_helper.dart';
import '../models/dive_log.dart';
import '../models/dive_photo.dart';
import '../models/scanned_photo.dart';
import 'image_store.dart';

/// Result of completing a draft dive (D-PHOTO): how many photos were attached
/// vs skipped (deleted/unreadable sources).
class CompleteDraftResult {
  const CompleteDraftResult({
    required this.diveLogId,
    required this.attachedCount,
    required this.skippedCount,
  });

  final int diveLogId;
  final int attachedCount;
  final int skippedCount;
}

/// Completes a draft dive by inserting the [DiveLog] and copying the cluster's
/// photos into the app directory, inserting a [DivePhoto] per successful copy
/// (D-PHOTO). Deleted/unreadable sources are skipped-and-counted rather than
/// aborting the whole completion.
class DraftCompleter {
  DraftCompleter._internal();
  static final DraftCompleter instance = DraftCompleter._internal();

  Future<CompleteDraftResult> complete({
    required DraftDive draft,
    bool isDraft = true,
  }) async {
    final db = DatabaseHelper.instance;
    final log = DiveLog(
      startTime: draft.startTime,
      endTime: draft.endTime,
      isDraft: isDraft,
    );
    final logId = await db.insertDiveLog(log);

    var attached = 0;
    var skipped = 0;
    for (final photo in draft.photos) {
      final sourceFile = await photo.resolveFile();
      if (sourceFile == null || !await sourceFile.exists()) {
        skipped++;
        continue;
      }
      try {
        final destPath = await ImageStore.instance.copyToAppDir(
          sourceFile.path,
        );
        await db.insertDivePhoto(
          DivePhoto(
            diveLogId: logId,
            localPath: destPath,
            takenAt: photo.takenAt,
          ),
        );
        attached++;
      } catch (_) {
        // Skip-and-count on copy failure (partial-failure policy, E2).
        skipped++;
      }
    }
    return CompleteDraftResult(
      diveLogId: logId,
      attachedCount: attached,
      skippedCount: skipped,
    );
  }
}
