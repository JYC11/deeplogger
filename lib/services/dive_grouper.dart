import '../models/dive_log.dart';

/// Max spacing between consecutive photos within a single dive (PRD §5.3).
const kMaxIntraDiveGap = Duration(minutes: 90);

/// Gap that starts a new dive cluster (PRD §5.3).
const kMinInterDiveGap = Duration(minutes: 60);

/// Groups a list of photo timestamps into dive clusters.
///
/// Algorithm (PRD §5.3, stakeholder-approved):
/// - Sort timestamps ascending.
/// - First photo starts a cluster.
/// - Extend the cluster while gap to previous photo ≤ [kMinInterDiveGap].
/// - Any gap > [kMinInterDiveGap] starts a new cluster.
///   (Since kMinInterDiveGap < kMaxIntraDiveGap, gaps > 90 min always do.)
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
    if (gap > kMinInterDiveGap) {
      clusters.add([sorted[i]]);
    } else {
      clusters.last.add(sorted[i]);
    }
  }

  return clusters;
}

/// Creates draft [DiveLog] entries from photo timestamps.
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
