import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

/// Copies photos into the app's private directory and provides compression.
///
/// Per AGENTS.md: never reference the original gallery path directly —
/// always copy to prevent broken links when the user deletes the original.
class ImageStore {
  ImageStore._internal();
  static final ImageStore instance = ImageStore._internal();

  /// Copies a source image into the app documents directory.
  ///
  /// Returns the path of the copied file. If [sourcePath] is already inside
  /// the app directory, it is returned as-is (no duplicate copy).
  Future<String> copyToAppDir(String sourcePath) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory(p.join(appDir.path, 'dive_photos'));

      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }

      // If already in app dir, return as-is
      if (p.isWithin(appDir.path, sourcePath)) {
        return sourcePath;
      }

      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        throw FileSystemException('Source file not found', sourcePath);
      }

      final ext = p.extension(sourcePath);
      final destPath = p.join(
        photosDir.path,
        'photo_${DateTime.now().microsecondsSinceEpoch}$ext',
      );

      await sourceFile.copy(destPath);
      return destPath;
    } catch (e) {
      throw Exception('Failed to copy image: $e');
    }
  }

  /// Creates a compressed thumbnail of an image and saves it to the app dir.
  ///
  /// [maxSize] is the maximum width/height in pixels. Returns the path of
  /// the thumbnail file.
  Future<String> createThumbnail(String sourcePath, {int maxSize = 256}) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final thumbsDir = Directory(p.join(appDir.path, 'thumbnails'));

      if (!await thumbsDir.exists()) {
        await thumbsDir.create(recursive: true);
      }

      final sourceFile = File(sourcePath);
      final bytes = await sourceFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        throw Exception('Unable to decode image');
      }

      final thumbnail = img.copyResize(image, width: maxSize);

      final thumbPath = p.join(
        thumbsDir.path,
        'thumb_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );

      final thumbFile = File(thumbPath);
      await thumbFile.writeAsBytes(img.encodeJpg(thumbnail, quality: 85));

      return thumbPath;
    } catch (e) {
      throw Exception('Failed to create thumbnail: $e');
    }
  }
}
