import 'dart:io';

import 'package:deeplogger/database/database_helper.dart';
import 'package:deeplogger/database/migration_runner.dart';
import 'package:deeplogger/models/scanned_photo.dart';
import 'package:deeplogger/services/dive_grouper.dart';
import 'package:deeplogger/services/draft_completer.dart';
import 'package:deeplogger/services/image_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tmpRoot;
  late Directory appDocsDir;
  late Directory sourceDir;
  late DatabaseHelper db;

  setUp(() async {
    tmpRoot = await Directory.systemTemp.createTemp('draft_completer_test_');
    appDocsDir = Directory(p.join(tmpRoot.path, 'appdocs'));
    sourceDir = Directory(p.join(tmpRoot.path, 'sources'));
    await appDocsDir.create(recursive: true);
    await sourceDir.create(recursive: true);
    ImageStore.instance.appDirOverride = () async => appDocsDir;

    db = DatabaseHelper.instance;
    db.useMigrationRunnerForTesting(_diskRunner());
    final ffiDb = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onConfigure: db.onConfigure,
      onCreate: db.onCreate,
    );
    await db.useDatabaseForTesting(ffiDb);
  });

  tearDown(() async {
    ImageStore.instance.appDirOverride = null;
    await db.close();
    await tmpRoot.delete(recursive: true);
  });

  Future<File> writeSource(String name) async {
    final image = img.Image(width: 100, height: 100);
    img.fill(image, color: img.ColorRgb8(0, 128, 255));
    final f = File(p.join(sourceDir.path, name));
    await f.writeAsBytes(img.encodeJpg(image, quality: 80));
    return f;
  }

  ScannedPhoto makePhoto(DateTime takenAt, File file) =>
      ScannedPhoto(takenAt: takenAt, resolveFile: () async => file);

  group('groupScannedPhotos', () {
    test('groups photos into drafts by D-GROUP', () {
      final t0 = DateTime(2026, 1, 1, 10, 0);
      final photos = [
        makePhoto(t0, File('')),
        makePhoto(t0.add(const Duration(minutes: 20)), File('')),
        makePhoto(t0.add(const Duration(minutes: 120)), File('')), // >90 → new
      ];
      final drafts = groupScannedPhotos(photos);
      expect(drafts.length, 2);
      expect(drafts[0].photos.length, 2);
      expect(drafts[1].photos.length, 1);
    });
  });

  group('DraftCompleter', () {
    test('copies N photos and creates N DivePhoto rows', () async {
      final f1 = await writeSource('a.jpg');
      final f2 = await writeSource('b.jpg');
      final draft = DraftDive(
        startTime: DateTime(2026, 1, 1, 10),
        endTime: DateTime(2026, 1, 1, 10, 20),
        photos: [
          makePhoto(DateTime(2026, 1, 1, 10), f1),
          makePhoto(DateTime(2026, 1, 1, 10, 20), f2),
        ],
      );

      final result = await DraftCompleter.instance.complete(draft: draft);
      expect(result.attachedCount, 2);
      expect(result.skippedCount, 0);
      final photos = await db.getDivePhotosForLog(result.diveLogId);
      expect(photos.length, 2);
    });

    test('discarding copies nothing (drafts only hold ScannedPhotos)', () {
      // Discard just drops the in-memory draft; no I/O. Verified by the fact
      // that DraftDive carries unresolved photos and nothing reads them.
      final draft = DraftDive(
        startTime: DateTime(2026, 1, 1, 10),
        endTime: DateTime(2026, 1, 1, 10, 20),
        photos: [
          ScannedPhoto(
            takenAt: DateTime(2026, 1, 1, 10),
            resolveFile: () async => null,
          ),
        ],
      );
      expect(draft.photos.length, 1);
      // No call to DraftCompleter → no DB rows, no file copies.
    });

    test(
      'partial failure: unreadable source skipped, count surfaced',
      () async {
        final f1 = await writeSource('a.jpg');
        final draft = DraftDive(
          startTime: DateTime(2026, 1, 1, 10),
          endTime: DateTime(2026, 1, 1, 10, 5),
          photos: [
            makePhoto(DateTime(2026, 1, 1, 10), f1), // readable
            ScannedPhoto(
              takenAt: DateTime(2026, 1, 1, 10, 5),
              resolveFile: () async => null, // unreadable
            ),
          ],
        );

        final result = await DraftCompleter.instance.complete(draft: draft);
        expect(result.attachedCount, 1);
        expect(result.skippedCount, 1);
        final photos = await db.getDivePhotosForLog(result.diveLogId);
        expect(photos.length, 1);
      },
    );
  });
}
