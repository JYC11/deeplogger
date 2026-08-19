import 'dart:io';

import 'package:deeplogger/database/database_helper.dart';
import 'package:deeplogger/database/migration_runner.dart';
import 'package:deeplogger/models/dive_log.dart';
import 'package:deeplogger/models/dive_photo.dart';
import 'package:deeplogger/models/sighting.dart';
import 'package:deeplogger/services/image_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Builds a [MigrationRunner] that reads `.sql` files directly from disk.
MigrationRunner _diskRunner() => MigrationRunner(
  discoverer: () async {
    final entries = await Directory('assets/migrations').list().toList();
    return entries
        .whereType<File>()
        .map((f) => f.path)
        .where((p) => p.endsWith('.sql'))
        .toList()
      ..sort();
  },
  loader: (path) => File(path).readAsString(),
);

/// Writes a real JPEG source file (so the image decoder in [ImageStore]
/// doesn't choke on synthetic bytes).
Future<File> _writeSourceJpeg(String path, int w, int h) async {
  final image = img.Image(width: w, height: h);
  img.fill(image, color: img.ColorRgb8(255, 0, 0));
  final bytes = img.encodeJpg(image, quality: 95);
  final f = File(path);
  await f.writeAsBytes(bytes);
  return f;
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseHelper db;
  late Directory tmpRoot;
  late Directory appDocsDir;
  late Directory sourceDir;

  setUp(() async {
    db = DatabaseHelper.instance;
    db.useMigrationRunnerForTesting(_diskRunner());
    final ffiDb = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onConfigure: db.onConfigure,
      onCreate: db.onCreate,
    );
    await db.useDatabaseForTesting(ffiDb);

    tmpRoot = await Directory.systemTemp.createTemp('dive_delete_test_');
    appDocsDir = Directory(p.join(tmpRoot.path, 'appdocs'));
    sourceDir = Directory(p.join(tmpRoot.path, 'sources'));
    await appDocsDir.create(recursive: true);
    await sourceDir.create(recursive: true);
    ImageStore.instance.appDirOverride = () async => appDocsDir;
  });

  tearDown(() async {
    ImageStore.instance.appDirOverride = null;
    await db.close();
    await tmpRoot.delete(recursive: true);
  });

  // F1: deleting a dive log must (a) cascade FK rows in the DB and (b) delete
  // the copied photo files + thumbnails from disk so they don't orphan.
  group('F1 delete dive log with file cleanup', () {
    test('cascade removes photo + sighting rows (regression)', () async {
      final diveId = await db.insertDiveLog(
        DiveLog(startTime: DateTime(2026, 1, 1), location: 'Reef'),
      );
      final photoId = await db.insertDivePhoto(
        DivePhoto(diveLogId: diveId, localPath: '/p.jpg'),
      );
      await db.insertSighting(
        Sighting(diveLogId: diveId, divePhotoId: photoId, commonName: 'Eel'),
      );

      expect(await db.getDivePhotosForLog(diveId), isNotEmpty);
      expect(await db.getSightingsForLog(diveId), isNotEmpty);

      await db.deleteDiveLog(diveId);

      expect(await db.getDiveLog(diveId), isNull);
      expect(await db.getDivePhotosForLog(diveId), isEmpty);
      expect(await db.getSightingsForLog(diveId), isEmpty);
    });

    test('deletePhotoFiles removes the copied photo + its thumbnail', () async {
      // Create a real JPEG, copy into app dir via ImageStore, then generate a
      // thumbnail — both files exist. deletePhotoFiles must remove both.
      final source = await _writeSourceJpeg(
        p.join(sourceDir.path, 'dive.jpg'),
        800,
        600,
      );
      final copiedPath = await ImageStore.instance.copyToAppDir(source.path);
      expect(await File(copiedPath).exists(), isTrue);

      final thumbPath = await ImageStore.instance.ensureThumbnail(
        101,
        copiedPath,
      );
      expect(await File(thumbPath).exists(), isTrue);

      await ImageStore.instance.deletePhotoFiles(101, copiedPath);

      expect(await File(copiedPath).exists(), isFalse);
      expect(await File(thumbPath).exists(), isFalse);
    });

    test('end-to-end: dive delete cleans up disk files', () async {
      final diveId = await db.insertDiveLog(
        DiveLog(startTime: DateTime(2026, 1, 1), location: 'Reef'),
      );

      // Copy a real JPEG into the app dir (this is what the gallery-scan
      // flow does) and insert a DivePhoto row pointing at the copied path.
      final source = await _writeSourceJpeg(
        p.join(sourceDir.path, 'dive2.jpg'),
        600,
        400,
      );
      final copiedPath = await ImageStore.instance.copyToAppDir(source.path);
      final photoId = await db.insertDivePhoto(
        DivePhoto(diveLogId: diveId, localPath: copiedPath),
      );
      // Generate the thumbnail so we can verify its deletion too.
      final thumbPath = await ImageStore.instance.ensureThumbnail(
        photoId,
        copiedPath,
      );
      expect(await File(thumbPath).exists(), isTrue);

      // Mimic the detail-screen delete flow: read photos, delete log row,
      // then clean up files per photo.
      final photos = await db.getDivePhotosForLog(diveId);
      await db.deleteDiveLog(diveId);
      for (final photo in photos) {
        await ImageStore.instance.deletePhotoFiles(photo.id, photo.localPath);
      }

      expect(await db.getDiveLog(diveId), isNull);
      expect(await db.getDivePhotosForLog(diveId), isEmpty);
      expect(await File(copiedPath).exists(), isFalse);
      expect(await File(thumbPath).exists(), isFalse);
    });
  });
}
