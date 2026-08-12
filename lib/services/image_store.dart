import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Copies photos into the app's private directory and provides compression.
///
/// Per AGENTS.md: never reference the original gallery path directly —
/// always copy to prevent broken links when the user deletes the original.
///
/// Thumbnails are filesystem-only (D-THUMB): no DB column. The path is derived
/// from the photo id (`thumbnails/{photoId}.jpg`) and generated lazily on first
/// display if the file is missing.
class ImageStore {
  ImageStore._internal();
  static final ImageStore instance = ImageStore._internal();

  /// Test seam: override the app-documents-directory resolver so host tests
  /// don't need the path_provider platform channel. Set to null in
  /// production (uses [getApplicationDocumentsDirectory]).
  @visibleForTesting
  Future<Directory> Function()? appDirOverride;

  Future<Directory> _appDir() => appDirOverride != null
      ? appDirOverride!()
      : getApplicationDocumentsDirectory();

  /// Maximum dimension (width or height) of a copied photo (E3).
  static const int kMaxPhotoDim = 1600;

  /// JPEG quality for copied photos (E3).
  static const int kPhotoQuality = 85;

  /// Maximum dimension of a thumbnail (E3).
  static const int kThumbnailDim = 256;

  /// Copies a source image into the app documents directory, compressing it
  /// (max dimension [kMaxPhotoDim], JPEG quality [kPhotoQuality]) via a
  /// background isolate so the UI thread is not blocked.
  ///
  /// Returns the path of the copied file. If [sourcePath] is already inside
  /// the app directory, it is returned as-is (no duplicate copy).
  Future<String> copyToAppDir(String sourcePath) async {
    try {
      final appDir = await _appDir();
      final photosDir = Directory(p.join(appDir.path, 'dive_photos'));

      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }

      // If already in app dir, return as-is (dedup guard).
      if (p.isWithin(appDir.path, sourcePath)) {
        return sourcePath;
      }

      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        throw FileSystemException('Source file not found', sourcePath);
      }

      final bytes = await sourceFile.readAsBytes();
      final compressed = await compute(
        _compressIsolate,
        _CompressParams(bytes, kMaxPhotoDim, kPhotoQuality),
      );

      final destPath = p.join(
        photosDir.path,
        'photo_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await File(destPath).writeAsBytes(compressed);
      return destPath;
    } catch (e, st) {
      Error.throwWithStackTrace(e, st);
    }
  }

  /// Creates a compressed thumbnail of an image and saves it to the app dir.
  ///
  /// [maxSize] is the maximum width AND height in pixels (both dimensions are
  /// constrained, preserving aspect ratio — fixes the previous width-only
  /// resize bug). Runs the decode/resize/encode in a background isolate.
  Future<String> createThumbnail(
    String sourcePath, {
    int maxSize = kThumbnailDim,
  }) async {
    try {
      final appDir = await _appDir();
      final thumbsDir = Directory(p.join(appDir.path, 'thumbnails'));

      if (!await thumbsDir.exists()) {
        await thumbsDir.create(recursive: true);
      }

      final sourceFile = File(sourcePath);
      final bytes = await sourceFile.readAsBytes();
      final thumb = await compute(
        _thumbnailIsolate,
        _CompressParams(bytes, maxSize, kPhotoQuality),
      );

      final thumbPath = p.join(
        thumbsDir.path,
        'thumb_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await File(thumbPath).writeAsBytes(thumb);
      return thumbPath;
    } catch (e, st) {
      Error.throwWithStackTrace(e, st);
    }
  }

  /// Returns the canonical thumbnail path for a dive photo id (D-THUMB). Does
  /// NOT generate the thumbnail — callers should use [ensureThumbnail].
  Future<String> thumbnailPathFor(int photoId) async {
    final appDir = await _appDir();
    return p.join(appDir.path, 'thumbnails', 'thumb_$photoId.jpg');
  }

  /// Ensures a thumbnail exists for [photoId] (whose full image is at
  /// [sourcePath]). Generates it lazily if the file is missing. Returns the
  /// thumbnail path.
  Future<String> ensureThumbnail(int photoId, String sourcePath) async {
    final thumbPath = await thumbnailPathFor(photoId);
    final file = File(thumbPath);
    if (await file.exists()) return thumbPath;
    // Generate into the canonical path (not the timestamped one).
    final appDir = await _appDir();
    final thumbsDir = Directory(p.join(appDir.path, 'thumbnails'));
    if (!await thumbsDir.exists()) {
      await thumbsDir.create(recursive: true);
    }
    try {
      final bytes = await File(sourcePath).readAsBytes();
      final thumb = await compute(
        _thumbnailIsolate,
        _CompressParams(bytes, kThumbnailDim, kPhotoQuality),
      );
      await File(thumbPath).writeAsBytes(thumb);
    } catch (e, st) {
      Error.throwWithStackTrace(e, st);
    }
    return thumbPath;
  }
}

/// Parameters passed to the isolate (must be sendable).
class _CompressParams {
  const _CompressParams(this.bytes, this.maxDim, this.quality);

  final Uint8List bytes;
  final int maxDim;
  final int quality;
}

/// Top-level isolate entry: decode, resize to fit within [maxDim] (both
/// dimensions, aspect-preserving), encode JPEG at [quality]. Returns the
/// encoded bytes. If the image is already smaller than [maxDim], it is
/// re-encoded at the given quality without upscaling.
Future<Uint8List> _compressIsolate(_CompressParams params) async {
  final image = img.decodeImage(params.bytes);
  if (image == null) {
    throw FormatException('Unable to decode image');
  }
  final resized = _fitWithin(image, params.maxDim);
  return Uint8List.fromList(img.encodeJpg(resized, quality: params.quality));
}

/// Top-level isolate entry for thumbnails: same as compress but defaults are
/// supplied by the caller.
Future<Uint8List> _thumbnailIsolate(_CompressParams params) async {
  final image = img.decodeImage(params.bytes);
  if (image == null) {
    throw FormatException('Unable to decode image');
  }
  final resized = _fitWithin(image, params.maxDim);
  return Uint8List.fromList(img.encodeJpg(resized, quality: params.quality));
}

/// Resizes [image] so that neither dimension exceeds [maxDim], preserving
/// aspect ratio. No upscaling (smaller images pass through unchanged).
img.Image _fitWithin(img.Image image, int maxDim) {
  final w = image.width;
  final h = image.height;
  if (w <= maxDim && h <= maxDim) return image;
  final scale = maxDim / (w > h ? w : h);
  final newW = (w * scale).round();
  final newH = (h * scale).round();
  return img.copyResize(image, width: newW, height: newH);
}
