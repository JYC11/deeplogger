import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/certification.dart';
import '../models/dive_detail.dart';
import '../models/dive_log.dart';
import '../models/dive_photo.dart';
import '../models/gear_item.dart';
import '../models/gear_ref.dart';
import '../models/sighting.dart';
import 'migration_runner.dart';
import 'sort_fields.dart';

/// Singleton wrapper around the SQLite database.
///
/// Schema is managed by [MigrationRunner] via SQL files in
/// `assets/migrations/`. To add a migration, drop a new `002__*.sql` file
/// into that folder and bump [_version].
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  /// Current schema version (drives `onCreate`/`onUpgrade` and backup
  /// manifest validation — `BackupService` rejects zips whose
  /// `schemaVersion` is greater than this).
  static const int kSchemaVersion = 1;

  static const int _version = kSchemaVersion;

  Database? _db;
  MigrationRunner? _migrationRunner;

  /// Returns the database, opening it if necessary.
  ///
  /// For host-side tests, call [useDatabaseForTesting] to inject an in-memory
  /// database instead of opening the on-device file.
  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  /// Injects a database instance for testing (e.g. in-memory via
  /// `sqflite_common_ffi`). Caller is responsible for closing it.
  @visibleForTesting
  Future<void> useDatabaseForTesting(FutureOr<Database> db) async {
    _db = await db;
  }

  /// Injects a [MigrationRunner] for testing (e.g. one that reads `.sql` files
  /// directly from disk instead of via `rootBundle`). Must be called before the
  /// database is opened or before [onCreate]/[onUpgrade] are used directly.
  @visibleForTesting
  void useMigrationRunnerForTesting(MigrationRunner runner) {
    _migrationRunner = runner;
  }

  /// Test seam: override the databases directory (returned by
  /// `getDatabasesPath()` in production) so tests can point the helper at a
  /// temp dir without mocking the sqflite platform channel. Must be set
  /// before the database is (re)opened to take effect.
  @visibleForTesting
  String? databasesPathOverride;

  Future<String> _databasesPath() async =>
      databasesPathOverride ?? await getDatabasesPath();

  MigrationRunner get _runner => _migrationRunner ??= MigrationRunner();

  Future<Database> _open() async {
    final dbPath = await _databasesPath();
    return openDatabase(
      p.join(dbPath, 'deeplogger.db'),
      version: _version,
      onConfigure: onConfigure,
      onCreate: onCreate,
      onUpgrade: onUpgrade,
      onDowngrade: (db, oldVersion, newVersion) =>
          onUpgrade(db, oldVersion, newVersion),
    );
  }

  /// Enables foreign-key enforcement (required for ON DELETE CASCADE).
  /// Public so tests can reuse it with in-memory databases.
  Future<void> onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Creates the schema for a fresh database via [MigrationRunner]. Public so
  /// tests can reuse it with an in-memory database (no schema duplication).
  Future<void> onCreate(Database db, int version) async {
    await _runner.onCreate(db, version);
  }

  Future<void> onUpgrade(Database db, int oldVersion, int newVersion) async {
    await _runner.onUpgrade(db, oldVersion, newVersion);
  }

  // --- DiveLog CRUD ---

  Future<int> insertDiveLog(DiveLog log) async {
    final db = await database;
    final map = log.toMap();
    map.remove('id');
    map['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    return db.insert('dive_logs', map);
  }

  Future<DiveLog?> getDiveLog(int id) async {
    final db = await database;
    final maps = await db.query('dive_logs', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return DiveLog.fromMap(maps.first);
  }

  /// Paginated, searchable, sortable dive-log query.
  ///
  /// [search] matches `location` or `notes` (case-insensitive LIKE). When
  /// [includeDrafts] is false, drafts are filtered in SQL (previously done in
  /// Dart). [sortField] is a whitelisted enum to prevent ORDER BY injection.
  /// Returns the page plus [hasMore] (true if more rows match the filter than
  /// `offset + limit`).
  Future<({List<DiveLog> logs, bool hasMore})> getDiveLogs({
    int limit = 20,
    int offset = 0,
    String? search,
    DiveLogSortField sortField = DiveLogSortField.startTime,
    bool sortDesc = true,
    bool includeDrafts = true,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <Object?>[];
    if (!includeDrafts) {
      where.add('is_draft = 0');
    }
    if (search != null && search.isNotEmpty) {
      where.add('(location LIKE ? OR notes LIKE ?)');
      final pattern = '%$search%';
      args.addAll([pattern, pattern]);
    }
    final whereClause = where.isEmpty ? null : where.join(' AND ');
    final order = '${sortField.column} ${sortDesc ? 'DESC' : 'ASC'}';
    final maps = await db.query(
      'dive_logs',
      where: whereClause,
      whereArgs: args.isEmpty ? null : args,
      orderBy: order,
      limit: limit,
      offset: offset,
    );
    final countRows = whereClause == null
        ? await db.rawQuery('SELECT COUNT(*) AS c FROM dive_logs')
        : await db.rawQuery(
            'SELECT COUNT(*) AS c FROM dive_logs WHERE $whereClause',
            args,
          );
    final total = countRows.first['c'] as int;
    return (
      logs: maps.map(DiveLog.fromMap).toList(),
      hasMore: total > offset + limit,
    );
  }

  Future<int> updateDiveLog(DiveLog log) async {
    final db = await database;
    final map = log.toMap();
    map['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    return db.update('dive_logs', map, where: 'id = ?', whereArgs: [log.id]);
  }

  Future<int> deleteDiveLog(int id) async {
    final db = await database;
    return db.delete('dive_logs', where: 'id = ?', whereArgs: [id]);
  }

  // --- DivePhoto CRUD ---

  Future<int> insertDivePhoto(DivePhoto photo) async {
    final db = await database;
    final map = photo.toMap();
    map.remove('id');
    return db.insert('dive_photos', map);
  }

  Future<List<DivePhoto>> getDivePhotosForLog(
    int diveLogId, {
    int limit = 200,
  }) async {
    final db = await database;
    final maps = await db.query(
      'dive_photos',
      where: 'dive_log_id = ?',
      whereArgs: [diveLogId],
      orderBy: 'taken_at ASC',
      limit: limit,
    );
    return maps.map(DivePhoto.fromMap).toList();
  }

  // --- Sighting CRUD ---

  Future<int> insertSighting(Sighting sighting) async {
    final db = await database;
    final map = sighting.toMap();
    map.remove('id');
    return db.insert('sightings', map);
  }

  Future<List<Sighting>> getSightingsForLog(
    int diveLogId, {
    int limit = 200,
  }) async {
    final db = await database;
    final maps = await db.query(
      'sightings',
      where: 'dive_log_id = ?',
      whereArgs: [diveLogId],
      limit: limit,
    );
    return maps.map(Sighting.fromMap).toList();
  }

  Future<int> deleteSighting(int id) async {
    final db = await database;
    return db.delete('sightings', where: 'id = ?', whereArgs: [id]);
  }

  // --- Certification CRUD ---

  Future<int> insertCertification(Certification cert) async {
    final db = await database;
    final map = cert.toMap();
    map.remove('id');
    return db.insert('certifications', map);
  }

  Future<Certification?> getCertification(int id) async {
    final db = await database;
    final maps = await db.query(
      'certifications',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Certification.fromMap(maps.first);
  }

  Future<({List<Certification> certs, bool hasMore})> getCertifications({
    int limit = 20,
    int offset = 0,
    String? search,
    CertificationSortField sortField = CertificationSortField.org,
    bool sortDesc = false,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <Object?>[];
    if (search != null && search.isNotEmpty) {
      where.add('(org LIKE ? OR level LIKE ? OR cert_id LIKE ?)');
      final pattern = '%$search%';
      args.addAll([pattern, pattern, pattern]);
    }
    final whereClause = where.isEmpty ? null : where.join(' AND ');
    // issue_date DESC on NULL values: NULLs sort first in SQLite; keep stable
    // by adding id as a tiebreaker.
    final order = '${sortField.column} ${sortDesc ? 'DESC' : 'ASC'}, id ASC';
    final maps = await db.query(
      'certifications',
      where: whereClause,
      whereArgs: args.isEmpty ? null : args,
      orderBy: order,
      limit: limit,
      offset: offset,
    );
    final countRows = whereClause == null
        ? await db.rawQuery('SELECT COUNT(*) AS c FROM certifications')
        : await db.rawQuery(
            'SELECT COUNT(*) AS c FROM certifications WHERE $whereClause',
            args,
          );
    final total = countRows.first['c'] as int;
    return (
      certs: maps.map(Certification.fromMap).toList(),
      hasMore: total > offset + limit,
    );
  }

  Future<int> deleteCertification(int id) async {
    final db = await database;
    return db.delete('certifications', where: 'id = ?', whereArgs: [id]);
  }

  // --- GearItem CRUD ---

  Future<int> insertGearItem(GearItem item) async {
    final db = await database;
    final map = item.toMap();
    map.remove('id');
    return db.insert('gear_items', map);
  }

  Future<GearItem?> getGearItem(int id) async {
    final db = await database;
    final maps = await db.query('gear_items', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return GearItem.fromMap(maps.first);
  }

  Future<({List<GearItem> items, bool hasMore})> getGearItems({
    int limit = 20,
    int offset = 0,
    String? search,
    String? category,
    GearSortField sortField = GearSortField.name,
    bool sortDesc = false,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <Object?>[];
    if (search != null && search.isNotEmpty) {
      where.add('(name LIKE ? OR type_notes LIKE ?)');
      final pattern = '%$search%';
      args.addAll([pattern, pattern]);
    }
    if (category != null && category.isNotEmpty) {
      where.add('category = ?');
      args.add(category);
    }
    final whereClause = where.isEmpty ? null : where.join(' AND ');
    final order = '${sortField.column} ${sortDesc ? 'DESC' : 'ASC'}, id ASC';
    final maps = await db.query(
      'gear_items',
      where: whereClause,
      whereArgs: args.isEmpty ? null : args,
      orderBy: order,
      limit: limit,
      offset: offset,
    );
    final countRows = whereClause == null
        ? await db.rawQuery('SELECT COUNT(*) AS c FROM gear_items')
        : await db.rawQuery(
            'SELECT COUNT(*) AS c FROM gear_items WHERE $whereClause',
            args,
          );
    final total = countRows.first['c'] as int;
    return (
      items: maps.map(GearItem.fromMap).toList(),
      hasMore: total > offset + limit,
    );
  }

  /// Back-compat wrapper around [getGearItems].
  Future<List<GearItem>> getAllGearItems() async {
    final result = await getGearItems(limit: 100000);
    return result.items;
  }

  Future<int> deleteGearItem(int id) async {
    final db = await database;
    return db.delete('gear_items', where: 'id = ?', whereArgs: [id]);
  }

  // --- dive_log_gear (M2M) ---

  /// Replaces all gear entries for a dive with the given mixed set of master
  /// gear-item ids and ad-hoc free-text names. Rows with a null [gearItemIds]
  /// entry use [adHocGearTexts]. The partial unique index on
  /// `(dive_log_id, gear_item_id)` prevents duplicate master-item rows.
  ///
  /// Runs inside a transaction so the delete + inserts are atomic — a failure
  /// mid-write can't leave the dive with no gear.
  Future<void> setGearEntriesForDive(
    int diveLogId, {
    List<int> gearItemIds = const [],
    List<String> adHocGearTexts = const [],
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'dive_log_gear',
        where: 'dive_log_id = ?',
        whereArgs: [diveLogId],
      );
      final batch = txn.batch();
      for (final gearId in gearItemIds) {
        batch.insert('dive_log_gear', {
          'dive_log_id': diveLogId,
          'gear_item_id': gearId,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final text in adHocGearTexts) {
        if (text.trim().isEmpty) continue;
        batch.insert('dive_log_gear', {
          'dive_log_id': diveLogId,
          'gear_item_id': null,
          'gear_text': text.trim(),
        });
      }
      await batch.commit(noResult: true);
    });
  }

  /// Returns gear entries for a dive as [GearRef] values, preserving ad-hoc
  /// free-text rows (which an INNER JOIN would drop). Master
  /// items and ad-hoc entries are ordered together by display name.
  Future<List<GearRef>> getGearEntriesForDive(int diveLogId) async {
    final db = await database;
    final maps = await db.rawQuery(
      '''
      SELECT dg.gear_text AS ad_hoc_text, g.*
      FROM dive_log_gear dg
      LEFT JOIN gear_items g ON g.id = dg.gear_item_id
      WHERE dg.dive_log_id = ?
      ORDER BY COALESCE(g.name, dg.gear_text) ASC
    ''',
      [diveLogId],
    );
    return maps.map(_rowToGearRef).toList();
  }

  GearRef _rowToGearRef(Map<String, Object?> row) {
    final hasItem = row['id'] != null;
    if (hasItem) {
      // Rebuild a gear_items-shaped map for GearItem.fromMap.
      final itemMap = <String, Object?>{
        'id': row['id'],
        'name': row['name'],
        'type_notes': row['type_notes'],
        'category': row['category'],
      };
      return GearRef.item(GearItem.fromMap(itemMap));
    }
    return GearRef.adHoc((row['ad_hoc_text'] as String?) ?? '');
  }

  /// Loads a dive log plus its photos, sightings, and gear entries in one
  /// round trip (parallel queries on a single DB handle — sqflite serializes
  /// internally). Returns null if the log does not exist.
  Future<DiveDetail?> getDiveDetail(int id) async {
    final db = await database;
    final logMaps = await db.query(
      'dive_logs',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (logMaps.isEmpty) return null;
    final log = DiveLog.fromMap(logMaps.first);

    final results = await Future.wait([
      db.query(
        'dive_photos',
        where: 'dive_log_id = ?',
        whereArgs: [id],
        orderBy: 'taken_at ASC',
      ),
      db.query('sightings', where: 'dive_log_id = ?', whereArgs: [id]),
      getGearEntriesForDive(id),
    ]);

    return DiveDetail(
      log: log,
      photos: (results[0] as List<Map<String, Object?>>)
          .map(DivePhoto.fromMap)
          .toList(),
      sightings: (results[1] as List<Map<String, Object?>>)
          .map(Sighting.fromMap)
          .toList(),
      gear: results[2] as List<GearRef>,
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
