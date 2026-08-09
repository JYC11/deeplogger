import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/certification.dart';
import '../models/dive_log.dart';
import '../models/dive_photo.dart';
import '../models/gear_item.dart';
import '../models/sighting.dart';

/// Singleton wrapper around the SQLite database.
///
/// Versioned via [_version]. Migrations live in [onUpgrade].
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const int _version = 1;

  Database? _db;

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

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      p.join(dbPath, 'deeplogger.db'),
      version: _version,
      onConfigure: onConfigure,
      onCreate: onCreate,
      onUpgrade: onUpgrade,
    );
  }

  /// Enables foreign-key enforcement (required for ON DELETE CASCADE).
  /// Public so tests can reuse it with in-memory databases.
  Future<void> onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Creates the schema for a fresh database. Public so tests can reuse it
  /// with an in-memory database (no schema duplication).
  Future<void> onCreate(Database db, int version) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE dive_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_time INTEGER,
        end_time INTEGER,
        location TEXT,
        altitude TEXT,
        max_depth_m REAL,
        avg_depth_m REAL,
        duration_min REAL,
        gas_type TEXT,
        gas_other TEXT,
        tank_size TEXT,
        start_pressure_bar REAL,
        end_pressure_bar REAL,
        water_temp_c REAL,
        salinity TEXT,
        visibility_m REAL,
        weight_kg REAL,
        notes TEXT,
        is_draft INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE dive_photos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dive_log_id INTEGER,
        local_path TEXT NOT NULL,
        taken_at INTEGER,
        FOREIGN KEY (dive_log_id) REFERENCES dive_logs(id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE sightings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dive_log_id INTEGER,
        dive_photo_id INTEGER,
        common_name TEXT NOT NULL,
        FOREIGN KEY (dive_log_id) REFERENCES dive_logs(id) ON DELETE CASCADE,
        FOREIGN KEY (dive_photo_id) REFERENCES dive_photos(id) ON DELETE SET NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE certifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        org TEXT NOT NULL,
        level TEXT NOT NULL,
        issue_date INTEGER,
        photo_path TEXT
      )
    ''');

    batch.execute('''
      CREATE TABLE gear_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type_notes TEXT
      )
    ''');

    batch.execute('''
      CREATE TABLE dive_log_gear (
        dive_log_id INTEGER NOT NULL,
        gear_item_id INTEGER NOT NULL,
        PRIMARY KEY (dive_log_id, gear_item_id),
        FOREIGN KEY (dive_log_id) REFERENCES dive_logs(id) ON DELETE CASCADE,
        FOREIGN KEY (gear_item_id) REFERENCES gear_items(id) ON DELETE CASCADE
      )
    ''');

    await batch.commit(noResult: true);
  }

  Future<void> onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future migrations go here. Currently at v1.
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

  Future<List<DiveLog>> getAllDiveLogs({bool drafts = true}) async {
    final db = await database;
    final maps = await db.query('dive_logs', orderBy: 'start_time DESC');
    var results = maps.map(DiveLog.fromMap).toList();
    if (!drafts) {
      results = results.where((l) => !l.isDraft).toList();
    }
    return results;
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

  Future<List<DivePhoto>> getDivePhotosForLog(int diveLogId) async {
    final db = await database;
    final maps = await db.query(
      'dive_photos',
      where: 'dive_log_id = ?',
      whereArgs: [diveLogId],
      orderBy: 'taken_at ASC',
    );
    return maps.map(DivePhoto.fromMap).toList();
  }

  Future<int> deleteDivePhoto(int id) async {
    final db = await database;
    return db.delete('dive_photos', where: 'id = ?', whereArgs: [id]);
  }

  // --- Sighting CRUD ---

  Future<int> insertSighting(Sighting sighting) async {
    final db = await database;
    final map = sighting.toMap();
    map.remove('id');
    return db.insert('sightings', map);
  }

  Future<List<Sighting>> getSightingsForLog(int diveLogId) async {
    final db = await database;
    final maps = await db.query(
      'sightings',
      where: 'dive_log_id = ?',
      whereArgs: [diveLogId],
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

  Future<List<Certification>> getAllCertifications() async {
    final db = await database;
    final maps = await db.query(
      'certifications',
      orderBy: 'org ASC, issue_date DESC',
    );
    return maps.map(Certification.fromMap).toList();
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

  Future<List<GearItem>> getAllGearItems() async {
    final db = await database;
    final maps = await db.query('gear_items', orderBy: 'name ASC');
    return maps.map(GearItem.fromMap).toList();
  }

  Future<int> deleteGearItem(int id) async {
    final db = await database;
    return db.delete('gear_items', where: 'id = ?', whereArgs: [id]);
  }

  // --- dive_log_gear (M2M) ---

  Future<void> setGearForDive(int diveLogId, List<int> gearItemIds) async {
    final db = await database;
    await db.delete(
      'dive_log_gear',
      where: 'dive_log_id = ?',
      whereArgs: [diveLogId],
    );
    final batch = db.batch();
    for (final gearId in gearItemIds) {
      batch.insert('dive_log_gear', {
        'dive_log_id': diveLogId,
        'gear_item_id': gearId,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<GearItem>> getGearForDive(int diveLogId) async {
    final db = await database;
    final maps = await db.rawQuery(
      '''
      SELECT g.* FROM gear_items g
      INNER JOIN dive_log_gear dg ON dg.gear_item_id = g.id
      WHERE dg.dive_log_id = ?
      ORDER BY g.name ASC
    ''',
      [diveLogId],
    );
    return maps.map(GearItem.fromMap).toList();
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
