import '../models/dive_log.dart';
import '../models/scanned_photo.dart';

/// Max spacing between consecutive photos within a single dive (PRD §5.3).
const kMaxIntraDiveGap = Duration(minutes: 90);

/// Gap that starts a new dive cluster (PRD §5.3).
const kMinInterDiveGap = Duration(minutes: 60);

/// Groups a list of photo timestamps into dive clusters (D-GROUP).
///
/// Algorithm (PRD §5.3, stakeholder-approved two-threshold span-cap):
/// - Sort timestamps ascending.
/// - First photo starts a cluster.
/// - For each subsequent photo (gap = photo − previous photo):
///   - `gap > kMaxIntraDiveGap` (90 min) → new cluster (hard span ceiling).
///   - `kMinInterDiveGap < gap ≤ kMaxIntraDiveGap` (60–90 min) → extend iff
///     the new cluster span (photo − cluster.first) ≤ 90 min, else new
///     cluster (soft break for long sparse clusters).
///   - `gap ≤ kMinInterDiveGap` (60 min) → always extend.
///
/// Returns a list of clusters, each being a list of timestamps.
List<List<DateTime>> groupPhotosByDive(List<DateTime> timestamps) {
  if (timestamps.isEmpty) return [];

  final sorted = List<DateTime>.from(timestamps)..sort();

  final clusters = <List<DateTime>>[
    [sorted[0]],
  ];

  for (var i = 1; i < sorted.length; i++) {
    final gap = sorted[i].difference(sorted[i - 1]);
    final newSpan = sorted[i].difference(clusters.last.first);
    if (gap > kMaxIntraDiveGap) {
      clusters.add([sorted[i]]);
    } else if (gap > kMinInterDiveGap) {
      // 60 < gap <= 90: extend only if the cluster span stays within 90 min.
      if (newSpan <= kMaxIntraDiveGap) {
        clusters.last.add(sorted[i]);
      } else {
        clusters.add([sorted[i]]);
      }
    } else {
      // gap <= 60: always extend.
      clusters.last.add(sorted[i]);
    }
  }

  return clusters;
}

/// Creates draft [DiveLog] entries from photo timestamps (legacy, timestamps
/// only). Prefer [groupScannedPhotos] for the photo-backed draft flow.
///
/// One draft per cluster, with [DiveLog.startTime] and [DiveLog.endTime]
/// set to the first and last photo timestamps. [DiveLog.isDraft] is true.
List<DiveLog> createDraftDiveLogs(List<DateTime> timestamps) {
  final clusters = groupPhotosByDive(timestamps);
  return clusters.map((cluster) {
    return DiveLog(
      startTime: cluster.first,
      endTime: cluster.last,
      isDraft: true,
    );
  }).toList();
}

/// Groups [ScannedPhoto]s into [DraftDive]s using the D-GROUP algorithm
/// (D-PHOTO). The photos stay unresolved until "Complete draft" copies them,
/// so discarding a draft performs no file I/O.
List<DraftDive> groupScannedPhotos(List<ScannedPhoto> photos) {
  if (photos.isEmpty) return [];
  final sorted = List<ScannedPhoto>.from(photos)
    ..sort((a, b) => a.takenAt.compareTo(b.takenAt));

  final clusters = <List<ScannedPhoto>>[
    [sorted[0]],
  ];
  for (var i = 1; i < sorted.length; i++) {
    final gap = sorted[i].takenAt.difference(sorted[i - 1].takenAt);
    final newSpan = sorted[i].takenAt.difference(clusters.last.first.takenAt);
    if (gap > kMaxIntraDiveGap) {
      clusters.add([sorted[i]]);
    } else if (gap > kMinInterDiveGap) {
      if (newSpan <= kMaxIntraDiveGap) {
        clusters.last.add(sorted[i]);
      } else {
        clusters.add([sorted[i]]);
      }
    } else {
      clusters.last.add(sorted[i]);
    }
  }

  return clusters
      .map(
        (c) => DraftDive(
          startTime: c.first.takenAt,
          endTime: c.last.takenAt,
          photos: List<ScannedPhoto>.from(c),
        ),
      )
      .toList();
}
