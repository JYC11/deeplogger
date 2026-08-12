import 'package:exif/exif.dart';
import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/scanned_photo.dart';
import 'image_store.dart';

/// Scans the device gallery for photos and extracts timestamps for dive grouping.
///
/// Permission flow (PRD §5.3):
/// - iOS: handles limited-access mode (PHPhotoLibrary_AccessLimited).
/// - Android: READ_MEDIA_IMAGES (API 33+) / READ_EXTERNAL_STORAGE (≤ 32).
class GalleryScanner {
  GalleryScanner._internal();
  static final GalleryScanner instance = GalleryScanner._internal();

  static const _permOption = PermissionRequestOption(
    // iOS PhotoKit offers only `addOnly` (write-only) and `readWrite` (read+
    // write); there is no read-only access level. We request `readWrite`
    // because read access is required for gallery scanning, but we never
    // call any write APIs (no saves/deletes) — so this is read-only in
    // practice. (Plan E4 aimed for readOnly, which doesn't exist in
    // photo_manager / PHAccessLevel.)
    iosAccessLevel: IosAccessLevel.readWrite,
    androidPermission: AndroidPermission(
      type: RequestType.image,
      mediaLocation: false,
    ),
  );

  /// Requests gallery access permission.
  ///
  /// Returns true if permission was granted (or already had it).
  Future<bool> requestPermission() async {
    final state = await PhotoManager.requestPermissionExtend(
      requestOption: _permOption,
    );
    return state.isAuth;
  }

  /// Checks current permission state without requesting.
  Future<bool> hasPermission() async {
    final state = await PhotoManager.getPermissionState(
      requestOption: _permOption,
    );
    return state.isAuth;
  }

  /// Scans the gallery for photos and their timestamps (D-PHOTO).
  ///
  /// Returns a list of [ScannedPhoto] values sorted ascending by capture
  /// time. Each value carries a deferred [ScannedPhoto.resolveFile] closure
  /// wrapping [AssetEntity.originFile] (the [AssetEntity] itself is never
  /// held — it can't be mocked or cross isolates).
  ///
  /// Uses native [AssetEntity.createDateTime] first for speed (avoids per-asset
  /// EXIF reads); falls back to EXIF DateTimeOriginal → DateTimeDigitized when
  /// the native timestamp is missing or clearly invalid.
  ///
  /// Perf: batches asset list queries; avoids per-asset full EXIF reads
  /// unless necessary (PRD NFR-2: 1,000 photos < 3 s).
  Future<List<ScannedPhoto>> scanGalleryTimestamps({
    int maxAssets = 5000,
  }) async {
    if (!await hasPermission()) {
      final granted = await requestPermission();
      if (!granted) return [];
    }

    final assetPaths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );

    if (assetPaths.isEmpty) return [];

    final allPath = assetPaths.first;
    final assets = await allPath.getAssetListRange(start: 0, end: maxAssets);

    // Parallelize per-asset timestamp extraction in chunks (G1). AssetEntity
    // is a platform-channel handle and cannot cross isolates, so we chunk
    // Future.wait on the platform thread (8 at a time) rather than using
    // compute(). The dominant cost is sequential originFile/EXIF I/O that
    // chunking addresses.
    const chunkSize = 8;
    final photos = <ScannedPhoto>[];
    for (var i = 0; i < assets.length; i += chunkSize) {
      final end = (i + chunkSize > assets.length)
          ? assets.length
          : i + chunkSize;
      final chunk = assets.sublist(i, end);
      final results = await Future.wait(
        chunk.map(
          (asset) => _extractTimestamp(asset).then(
            (ts) => ts == null
                ? null
                : ScannedPhoto(
                    takenAt: ts,
                    resolveFile: () => asset.originFile,
                  ),
          ),
        ),
      );
      for (final p in results) {
        if (p != null) photos.add(p);
      }
    }

    photos.sort((a, b) => a.takenAt.compareTo(b.takenAt));
    return photos;
  }

  /// Extracts the best-available timestamp from an asset.
  ///
  /// Priority: native createDateTime → EXIF DateTimeOriginal →
  /// DateTimeDigitized → null.
  Future<DateTime?> _extractTimestamp(AssetEntity asset) async {
    // Fast path: use the native createDateTime (no EXIF read needed)
    final nativeDate = asset.createDateTime;
    if (nativeDate.year > 2000) {
      return nativeDate;
    }

    // Slow path: fall back to EXIF
    try {
      final file = await asset.originFile;
      if (file == null || !await file.exists()) return null;

      final bytes = await file.readAsBytes();
      final data = await readExifFromBytes(bytes);

      final dateTimeOriginal = data['EXIF DateTimeOriginal']?.toString();
      if (dateTimeOriginal != null) {
        final parsed = _parseExifDate(dateTimeOriginal);
        if (parsed != null) return parsed;
      }

      final dateTimeDigitized = data['EXIF DateTimeDigitized']?.toString();
      if (dateTimeDigitized != null) {
        final parsed = _parseExifDate(dateTimeDigitized);
        if (parsed != null) return parsed;
      }
    } catch (e) {
      debugPrint('EXIF read failed for asset ${asset.id}: $e');
    }

    return null;
  }

  /// Parses an EXIF date string like '2026:01:15 10:30:00'.
  DateTime? _parseExifDate(String exifDate) {
    try {
      final parts = exifDate.split(' ');
      if (parts.length != 2) return null;

      final dateParts = parts[0].split(':');
      final timeParts = parts[1].split(':');

      if (dateParts.length != 3 || timeParts.length != 3) return null;

      return DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
        int.parse(timeParts[2]),
      );
    } catch (_) {
      return null;
    }
  }

  /// Copies a gallery asset into the app's private directory.
  ///
  /// Returns the local path of the copied file, or null if the asset
  /// couldn't be loaded.
  Future<String?> copyAssetToAppDir(AssetEntity asset) async {
    final file = await asset.originFile;
    if (file == null || !await file.exists()) return null;

    return ImageStore.instance.copyToAppDir(file.path);
  }
}
