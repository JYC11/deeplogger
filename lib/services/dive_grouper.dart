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
  return _groupClusters(timestamps, (t) => t);
}

/// Groups [ScannedPhoto]s into [DraftDive]s using the D-GROUP algorithm
/// (D-PHOTO). The photos stay unresolved until "Complete draft" copies them,
/// so discarding a draft performs no file I/O.
List<DraftDive> groupScannedPhotos(List<ScannedPhoto> photos) {
  return _groupClusters(photos, (p) => p.takenAt)
      .map(
        (c) => DraftDive(
          startTime: c.first.takenAt,
          endTime: c.last.takenAt,
          photos: List<ScannedPhoto>.from(c),
        ),
      )
      .toList();
}

/// Shared D-GROUP clustering over any item type with an extractable
/// timestamp (avoids duplicating the two-threshold span-cap logic).
List<List<T>> _groupClusters<T>(List<T> items, DateTime Function(T) timestamp) {
  if (items.isEmpty) return [];

  final sorted = List<T>.from(items)
    ..sort((a, b) => timestamp(a).compareTo(timestamp(b)));

  final clusters = <List<T>>[
    [sorted[0]],
  ];

  for (var i = 1; i < sorted.length; i++) {
    final gap = timestamp(sorted[i]).difference(timestamp(sorted[i - 1]));
    final newSpan = timestamp(
      sorted[i],
    ).difference(timestamp(clusters.last.first));
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
