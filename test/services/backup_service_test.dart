import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:deeplogger/database/database_helper.dart';
import 'package:deeplogger/database/migration_runner.dart';
import 'package:deeplogger/models/dive_log.dart';
import 'package:deeplogger/services/backup_service.dart';
import 'package:deeplogger/services/unit_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
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
  late Directory dbsDir;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    tmpRoot = await Directory.systemTemp.createTemp('backup_test_');
    appDocsDir = Directory(p.join(tmpRoot.path, 'appdocs'));
    dbsDir = Directory(p.join(tmpRoot.path, 'dbs'));
    final tmpDir = Directory(p.join(tmpRoot.path, 'tmp'));
    await appDocsDir.create(recursive: true);
    await dbsDir.create(recursive: true);
    await tmpDir.create(recursive: true);

    // Wire DatabaseHelper against an in-memory DB for insertions, then
    // manually write the db file to dbsDir so BackupService can read it.
    DatabaseHelper.instance.useMigrationRunnerForTesting(_diskRunner());
    DatabaseHelper.instance.databasesPathOverride = dbsDir.path;
    final ffiDb = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onConfigure: DatabaseHelper.instance.onConfigure,
      onCreate: DatabaseHelper.instance.onCreate,
    );
    await DatabaseHelper.instance.useDatabaseForTesting(ffiDb);

    BackupService.instance.appDirOverride = () async => appDocsDir;
    BackupService.instance.databasesPathOverride = () async => dbsDir.path;
    BackupService.instance.prefsInstanceOverride = () async => prefs;
    BackupService.instance.tempDirOverride = () async => tmpDir;
  });

  tearDown(() async {
    BackupService.instance.appDirOverride = null;
    BackupService.instance.databasesPathOverride = null;
    BackupService.instance.prefsInstanceOverride = null;
    BackupService.instance.tempDirOverride = null;
    DatabaseHelper.instance.databasesPathOverride = null;
    await DatabaseHelper.instance.close();
    await tmpRoot.delete(recursive: true);
  });

  /// Writes the in-memory DB's bytes to the dbsDir so BackupService can read
  /// a real file (the test DB lives in memory, not at a path).
  Future<void> persistDbToFile() async {
    final dbPath = p.join(dbsDir.path, 'deeplogger.db');
    final inMemoryDb = await DatabaseHelper.instance.database;
    // sqflite_ffi exposes the file backing the in-memory database via
    // `inMemoryDatabasePath` only for the special path; for our purposes,
    // we re-create a fresh on-disk db with the same schema + data by
    // dumping all rows. Simpler: open a file-backed db, copy rows.
    final fileDb = await openDatabase(
      dbPath,
      version: 1,
      onConfigure: DatabaseHelper.instance.onConfigure,
      onCreate: DatabaseHelper.instance.onCreate,
    );
    final tables = (await fileDb.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE "
      "'sqlite_%' AND name NOT LIKE 'android_%'",
    )).map((r) => r['name'] as String).where((t) => t != 'schema_version');
    for (final table in tables) {
      final rows = await inMemoryDb.query(table);
      for (final row in rows) {
        await fileDb.insert(table, row);
      }
    }
    await fileDb.close();
  }

  group('F7 BackupService.exportToZip', () {
    test('produces a zip with manifest + db + unit_prefs', () async {
      // Seed some data.
      await DatabaseHelper.instance.insertDiveLog(
        DiveLog(startTime: DateTime(2026, 1, 1), location: 'Reef'),
      );
      await prefs.setString(
        '${UnitPreferencesService.prefix}max_depth_m',
        'ft',
      );
      await persistDbToFile();

      final zipPath = await BackupService.instance.exportToZip();
      expect(await File(zipPath).exists(), isTrue);

      final archive = ZipDecoder().decodeBytes(
        await File(zipPath).readAsBytes(),
      );
      expect(archive.findFile('manifest.json'), isNotNull);
      expect(archive.findFile('deeplogger.db'), isNotNull);
      expect(archive.findFile('unit_prefs.json'), isNotNull);
    });

    test('manifest has the expected fields', () async {
      await persistDbToFile();
      final zipPath = await BackupService.instance.exportToZip();
      final archive = ZipDecoder().decodeBytes(
        await File(zipPath).readAsBytes(),
      );
      final manifest =
          jsonDecode(
                utf8.decode(
                  archive.findFile('manifest.json')!.content as List<int>,
                ),
              )
              as Map<String, Object?>;
      expect(manifest['format'], BackupService.kBackupFormat);
      expect(manifest['schemaVersion'], DatabaseHelper.kSchemaVersion);
      expect(manifest['exportedAt'], isA<String>());
      expect((manifest['includes'] as List).length, 3);
    });

    test('includes copied photo files under images/', () async {
      await DatabaseHelper.instance.insertDiveLog(
        DiveLog(startTime: DateTime(2026, 1, 1), location: 'Reef'),
      );
      final photosDir = Directory(p.join(appDocsDir.path, 'dive_photos'));
      await photosDir.create(recursive: true);
      await File(p.join(photosDir.path, 'photo_1.jpg')).writeAsBytes([1, 2]);
      await persistDbToFile();

      final zipPath = await BackupService.instance.exportToZip();
      final archive = ZipDecoder().decodeBytes(
        await File(zipPath).readAsBytes(),
      );
      final img = archive.findFile('images/photo_1.jpg');
      expect(img, isNotNull);
      expect(img!.content, [1, 2]);
    });

    test('excludes thumbnails (regenerable)', () async {
      await persistDbToFile();
      // Drop a fake thumbnail file — it must NOT end up in the zip.
      final thumbsDir = Directory(p.join(appDocsDir.path, 'thumbnails'));
      await thumbsDir.create(recursive: true);
      await File(p.join(thumbsDir.path, 'thumb_1.jpg')).writeAsBytes([9]);

      final zipPath = await BackupService.instance.exportToZip();
      final archive = ZipDecoder().decodeBytes(
        await File(zipPath).readAsBytes(),
      );
      expect(archive.findFile('thumbnails/thumb_1.jpg'), isNull);
      // No entry should start with 'thumbnails/'.
      for (final entry in archive) {
        expect(entry.name.startsWith('thumbnails/'), isFalse);
      }
    });

    test('unit_prefs.json snapshots unit_pref_* keys only', () async {
      await persistDbToFile();
      await prefs.setString(
        '${UnitPreferencesService.prefix}max_depth_m',
        'ft',
      );
      await prefs.setString('${UnitPreferencesService.prefix}weight_kg', 'lbs');
      // Unrelated key — must NOT be included.
      await prefs.setString('some_other_key', 'value');

      final zipPath = await BackupService.instance.exportToZip();
      final archive = ZipDecoder().decodeBytes(
        await File(zipPath).readAsBytes(),
      );
      final prefsJson =
          jsonDecode(
                utf8.decode(
                  archive.findFile('unit_prefs.json')!.content as List<int>,
                ),
              )
              as Map<String, Object?>;
      expect(prefsJson['${UnitPreferencesService.prefix}max_depth_m'], 'ft');
      expect(prefsJson['${UnitPreferencesService.prefix}weight_kg'], 'lbs');
      expect(prefsJson.containsKey('some_other_key'), isFalse);
    });

    test('export fails clearly when db file is missing', () async {
      // Don't call persistDbToFile() — no db file at dbsDir.
      expect(
        BackupService.instance.exportToZip,
        throwsA(isA<FileSystemException>()),
      );
    });
  });

  group('F7 BackupService.importFromZip', () {
    test('round-trips export → import (replace-only)', () async {
      // Seed original data.
      await DatabaseHelper.instance.insertDiveLog(
        DiveLog(
          startTime: DateTime(2026, 1, 1),
          location: 'Original Reef',
          maxDepthM: 18.0,
        ),
      );
      await prefs.setString(
        '${UnitPreferencesService.prefix}max_depth_m',
        'ft',
      );
      final photosDir = Directory(p.join(appDocsDir.path, 'dive_photos'));
      await photosDir.create(recursive: true);
      await File(p.join(photosDir.path, 'photo_1.jpg')).writeAsBytes([1, 2]);
      await persistDbToFile();

      // Export.
      final zipPath = await BackupService.instance.exportToZip();

      // Mutate state so we can prove the import replaces it.
      await DatabaseHelper.instance.insertDiveLog(
        DiveLog(
          startTime: DateTime(2026, 2, 2),
          location: 'Mutated After Export',
        ),
      );
      await prefs.setString('${UnitPreferencesService.prefix}max_depth_m', 'm');
      await File(p.join(photosDir.path, 'photo_2.jpg')).writeAsBytes([3, 4]);

      // Import.
      final manifest = await BackupService.instance.importFromZip(zipPath);

      expect(manifest.format, BackupService.kBackupFormat);
      expect(manifest.schemaVersion, DatabaseHelper.kSchemaVersion);

      // The post-export mutation must be gone (replace-only semantics).
      final logs = (await DatabaseHelper.instance.getDiveLogs()).logs;
      expect(logs.any((l) => l.location == 'Mutated After Export'), isFalse);
      expect(logs.any((l) => l.location == 'Original Reef'), isTrue);

      // The mutated unit pref must be replaced with the exported value.
      expect(
        prefs.getString('${UnitPreferencesService.prefix}max_depth_m'),
        'ft',
      );

      // The mutated photo file must be gone; the exported one restored.
      expect(
        await File(p.join(photosDir.path, 'photo_2.jpg')).exists(),
        isFalse,
      );
      expect(
        await File(p.join(photosDir.path, 'photo_1.jpg')).exists(),
        isTrue,
      );
    });

    test('rejects zip missing manifest.json', () async {
      final archive = Archive();
      archive.addFile(ArchiveFile.bytes('deeplogger.db', [0]));
      final bytes = ZipEncoder().encode(archive);
      final badPath = p.join(tmpRoot.path, 'no_manifest.zip');
      await File(badPath).writeAsBytes(bytes);

      expect(
        () => BackupService.instance.importFromZip(badPath),
        throwsA(isA<BackupManifestException>()),
      );
    });

    test('rejects zip with unsupported manifest format', () async {
      final archive = Archive();
      final manifest = jsonEncode({
        'format': 999,
        'schemaVersion': 1,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
      });
      archive.addFile(
        ArchiveFile.bytes('manifest.json', utf8.encode(manifest)),
      );
      final bytes = ZipEncoder().encode(archive);
      final badPath = p.join(tmpRoot.path, 'bad_format.zip');
      await File(badPath).writeAsBytes(bytes);

      expect(
        () => BackupService.instance.importFromZip(badPath),
        throwsA(isA<BackupManifestException>()),
      );
    });

    test('rejects zip with newer schemaVersion', () async {
      final archive = Archive();
      final manifest = jsonEncode({
        'format': BackupService.kBackupFormat,
        'schemaVersion': DatabaseHelper.kSchemaVersion + 1,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
      });
      archive.addFile(
        ArchiveFile.bytes('manifest.json', utf8.encode(manifest)),
      );
      archive.addFile(ArchiveFile.bytes('deeplogger.db', [0]));
      final bytes = ZipEncoder().encode(archive);
      final badPath = p.join(tmpRoot.path, 'newer_schema.zip');
      await File(badPath).writeAsBytes(bytes);

      expect(
        () => BackupService.instance.importFromZip(badPath),
        throwsA(isA<BackupSchemaException>()),
      );
    });

    test('rejects corrupt zip bytes', () async {
      final badPath = p.join(tmpRoot.path, 'corrupt.zip');
      await File(badPath).writeAsBytes([0, 1, 2, 3]);
      expect(
        () => BackupService.instance.importFromZip(badPath),
        throwsA(isA<Object>()),
      );
    });
  });
}
