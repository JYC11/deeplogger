import 'dart:io';

/// A photo discovered by gallery scanning, wrapped as a value-type seam
/// (D-PHOTO). Holds the timestamp needed for grouping plus a deferred file
/// resolver, so [AssetEntity] (which has no public constructor and can't be
/// mocked or cross isolates) never leaks into the grouping/test layer.
///
/// On "Complete draft", [resolveFile] is called to fetch the source bytes for
/// copying into the app directory. On "Discard", nothing is resolved.
class ScannedPhoto {
  const ScannedPhoto({required this.takenAt, required this.resolveFile});

  /// Best-available capture timestamp (native createDateTime, else EXIF
  /// DateTimeOriginal → DateTimeDigitized).
  final DateTime takenAt;

  /// Deferred fetch of the source [File]. Returns null if the underlying asset
  /// is no longer readable (deleted, permission revoked, etc.).
  final Future<File?> Function() resolveFile;
}

/// A draft dive produced by grouping scanned photos (D-PHOTO). Carries the
/// cluster's photos so "Complete draft" can copy them on demand.
class DraftDive {
  const DraftDive({
    required this.startTime,
    required this.endTime,
    required this.photos,
  });

  final DateTime startTime;
  final DateTime endTime;
  final List<ScannedPhoto> photos;
}
