import 'dart:io';
import 'dart:typed_data';

import 'package:deeplogger/services/image_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

void main() {
  late Directory tmpRoot;
  late Directory sourceDir;
  late Directory appDocsDir;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    tmpRoot = await Directory.systemTemp.createTemp('image_store_test_');
    sourceDir = Directory(p.join(tmpRoot.path, 'sources'));
    appDocsDir = Directory(p.join(tmpRoot.path, 'appdocs'));
    await sourceDir.create(recursive: true);
    await appDocsDir.create(recursive: true);
    // Inject a test app-documents directory so no platform channel is needed.
    ImageStore.instance.appDirOverride = () async => appDocsDir;
  });

  tearDown(() async {
    ImageStore.instance.appDirOverride = null;
    await tmpRoot.delete(recursive: true);
  });
  img.Image makeImage(int w, int h) {
    final image = img.Image(width: w, height: h);
    img.fill(image, color: img.ColorRgb8(255, 0, 0));
    return image;
  }

  Future<File> writeSource(String name, int w, int h) async {
    final bytes = Uint8List.fromList(
      img.encodeJpg(makeImage(w, h), quality: 95),
    );
    final f = File(p.join(sourceDir.path, name));
    await f.writeAsBytes(bytes);
    return f;
  }

  group('copyToAppDir (E3)', () {
    test('compresses: output file smaller than source', () async {
      final source = await writeSource('big.jpg', 3000, 2000);
      final destPath = await ImageStore.instance.copyToAppDir(source.path);
      final destFile = File(destPath);
      expect(await destFile.exists(), isTrue);
      final sourceLen = await source.length();
      final destLen = await destFile.length();
      expect(
        destLen,
        lessThan(sourceLen),
        reason: 'compressed copy should be smaller than high-q source',
      );
    });

    test('resized to fit within 1600px max dimension', () async {
      final source = await writeSource('wide.jpg', 3000, 1000);
      final destPath = await ImageStore.instance.copyToAppDir(source.path);
      final decoded = img.decodeImage(await File(destPath).readAsBytes());
      expect(decoded, isNotNull);
      expect(decoded!.width, lessThanOrEqualTo(ImageStore.kMaxPhotoDim));
      expect(decoded.height, lessThanOrEqualTo(ImageStore.kMaxPhotoDim));
    });

    test('already-in-app-dir path returned as-is (dedup guard)', () async {
      final destPath = await ImageStore.instance.copyToAppDir(
        (await writeSource('a.jpg', 800, 600)).path,
      );
      final second = await ImageStore.instance.copyToAppDir(destPath);
      expect(second, destPath);
    });

    test('missing source throws (preserves stack trace)', () async {
      expect(
        () => ImageStore.instance.copyToAppDir('/nonexistent/nope.jpg'),
        throwsA(isA<Object>()),
      );
    });

    test('small image not upscaled', () async {
      final source = await writeSource('tiny.jpg', 200, 150);
      final destPath = await ImageStore.instance.copyToAppDir(source.path);
      final decoded = img.decodeImage(await File(destPath).readAsBytes());
      expect(decoded, isNotNull);
      expect(decoded!.width, lessThanOrEqualTo(200));
    });
  });

  group('ensureThumbnail (D-THUMB lazy)', () {
    test('generates missing thumbnail at canonical path', () async {
      final source = await writeSource('x.jpg', 1000, 1000);
      final path = await ImageStore.instance.ensureThumbnail(42, source.path);
      expect(await File(path).exists(), isTrue);
      expect(p.basename(path), 'thumb_42.jpg');
    });

    test('returns existing thumbnail without regenerating', () async {
      final source = await writeSource('y.jpg', 1000, 1000);
      final path1 = await ImageStore.instance.ensureThumbnail(7, source.path);
      final mtime1 = await File(path1).lastModified();
      // Second call should not rewrite.
      final path2 = await ImageStore.instance.ensureThumbnail(7, source.path);
      expect(path2, path1);
      final mtime2 = await File(path2).lastModified();
      expect(mtime2, mtime1);
    });
  });

  // F1: dive delete must clean up the copied photo file + thumbnail so they
  // don't orphan on disk after the FK cascade removes the DB rows.
  group('deletePhotoFiles (F1 cleanup)', () {
    test('deletes copied photo + its thumbnail', () async {
      final source = await writeSource('d.jpg', 800, 600);
      final copied = await ImageStore.instance.copyToAppDir(source.path);
      expect(await File(copied).exists(), isTrue);

      // Generate a thumbnail for photoId 11 at the canonical path.
      final thumb = await ImageStore.instance.ensureThumbnail(11, copied);
      expect(await File(thumb).exists(), isTrue);

      await ImageStore.instance.deletePhotoFiles(11, copied);

      expect(await File(copied).exists(), isFalse);
      expect(await File(thumb).exists(), isFalse);
    });

    test(
      'null photoId skips thumbnail deletion but still drops the file',
      () async {
        final source = await writeSource('noid.jpg', 800, 600);
        final copied = await ImageStore.instance.copyToAppDir(source.path);
        await ImageStore.instance.deletePhotoFiles(null, copied);
        expect(await File(copied).exists(), isFalse);
      },
    );

    test('missing files are not an error (idempotent)', () async {
      // No file was ever created at this path; the call must not throw.
      await ImageStore.instance.deletePhotoFiles(99, '/no/such/file.jpg');
    });
  });
}
