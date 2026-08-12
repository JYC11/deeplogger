import 'dart:io';

import 'package:deeplogger/database/migration_runner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

/// Builds a [MigrationRunner] that reads `.sql` files directly from disk.
MigrationRunner _diskRunner() => MigrationRunner(
  discoverer: _discoverDiskMigrations,
  loader: (path) => File(path).readAsString(),
);

Future<List<String>> _discoverDiskMigrations() async {
  final dir = Directory('assets/migrations');
  final entries = await dir.list().toList();
  return entries
      .whereType<File>()
      .map((f) => f.path)
      .where((p) => p.endsWith('.sql'))
      .toList()
    ..sort();
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('parseVersion', () {
    test('parses asset-style path', () {
      expect(
        MigrationRunner.parseVersion('assets/migrations/001__init.sql'),
        1,
      );
    });

    test('parses absolute path', () {
      expect(
        MigrationRunner.parseVersion(
          '/abs/path/assets/migrations/002__add_x.sql',
        ),
        2,
      );
    });

    test('returns null for malformed names', () {
      expect(
        MigrationRunner.parseVersion('assets/migrations/readme.txt'),
        isNull,
      );
      expect(
        MigrationRunner.parseVersion('assets/migrations/init.sql'),
        isNull,
      );
    });
  });

  group('fresh install (onCreate)', () {
    late Database db;
    final runner = _diskRunner();

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
        onCreate: runner.onCreate,
      );
    });

    tearDown(() async => db.close());

    test('reaches schema_version 1 with one row', () async {
      final rows = await db.query('schema_version');
      expect(rows.length, 1);
      expect(rows.first['version'], 1);
      expect(rows.first['applied_at'], isA<String>());
    });

    test('all tables present', () async {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
      );
      final names = tables.map((r) => r['name'] as String).toSet();
      expect(
        names,
        containsAll([
          'dive_logs',
          'dive_photos',
          'sightings',
          'certifications',
          'gear_items',
          'dive_log_gear',
          'schema_version',
        ]),
      );
    });

    test('dive_logs has new tank volume + NOT NULL start_time', () async {
      final cols = await db.rawQuery('PRAGMA table_info(dive_logs)');
      final byName = {for (final c in cols) c['name'] as String: c};
      expect(byName.containsKey('tank_volume_value'), isTrue);
      expect(byName.containsKey('tank_volume_unit'), isTrue);
      expect(byName['start_time']!['notnull'], 1);
    });

    test('certifications has cert_id column', () async {
      final cols = await db.rawQuery('PRAGMA table_info(certifications)');
      final names = cols.map((c) => c['name'] as String).toSet();
      expect(names, contains('cert_id'));
    });

    test('gear_items has category column', () async {
      final cols = await db.rawQuery('PRAGMA table_info(gear_items)');
      final names = cols.map((c) => c['name'] as String).toSet();
      expect(names, contains('category'));
    });

    test(
      'dive_log_gear has surrogate id + nullable gear_item_id + gear_text',
      () async {
        final cols = await db.rawQuery('PRAGMA table_info(dive_log_gear)');
        final byName = {for (final c in cols) c['name'] as String: c};
        expect(byName.containsKey('id'), isTrue);
        expect(byName['id']!['pk'], 1);
        expect(byName.containsKey('gear_text'), isTrue);
        expect(byName['gear_item_id']!['notnull'], 0);
      },
    );

    test('indexes present', () async {
      final idx = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' ORDER BY name",
      );
      final names = idx.map((r) => r['name'] as String).toSet();
      expect(
        names,
        containsAll([
          'idx_photos_log',
          'idx_sightings_log',
          'idx_sightings_photo',
          'idx_logs_start',
          'idx_certs_org',
          'idx_log_gear_pair',
        ]),
      );
    });
  });

  group('idempotency', () {
    test(
      're-running 001__init.sql via onCreate twice does not error',
      () async {
        final runner = _diskRunner();
        final db = await openDatabase(
          inMemoryDatabasePath,
          version: 1,
          onCreate: runner.onCreate,
        );
        // Second pass: simulate re-open at same version (no onUpgrade called).
        // Just re-apply the runner manually to prove idempotency.
        await runner.onCreate(db, 1);
        final rows = await db.query('schema_version');
        expect(rows.length, 1);
        expect(rows.first['version'], 1);
        await db.close();
      },
    );
  });

  group('downgrade rejection', () {
    test('opening with version lower than user_version throws', () async {
      final runner = _diskRunner();
      final tmpDir = await Directory.systemTemp.createTemp('mig_test_');
      final dbPath = p.join(tmpDir.path, 'test.db');
      addTearDown(() async => tmpDir.delete(recursive: true));

      final db = await openDatabase(
        dbPath,
        version: 1,
        onCreate: runner.onCreate,
      );
      await db.execute('PRAGMA user_version = 2');
      await db.close();

      expect(
        () => openDatabase(
          dbPath,
          version: 1,
          // Route downgrade through the runner so it rejects old > new.
          onDowngrade: (d, old, newV) => runner.onUpgrade(d, old, newV),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('onUpgrade with old > new throws StateError', () async {
      final runner = _diskRunner();
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: runner.onCreate,
      );
      expect(() => runner.onUpgrade(db, 3, 1), throwsA(isA<StateError>()));
      await db.close();
    });
  });

  group('upgrade from v0', () {
    test(
      'version 0 -> open at 1 is an upgrade that succeeds idempotently',
      () async {
        final runner = _diskRunner();
        final db = await openDatabase(
          inMemoryDatabasePath,
          version: 1,
          onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
          onUpgrade: runner.onUpgrade,
          onCreate: runner.onCreate,
        );
        final rows = await db.query('schema_version');
        expect(rows.length, 1);
        expect(rows.first['version'], 1);
        // Sanity: dive_logs exists.
        final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='dive_logs'",
        );
        expect(tables.length, 1);
        await db.close();
      },
    );
  });
}
