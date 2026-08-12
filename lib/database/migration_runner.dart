import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite/sqflite.dart';

/// Loads the SQL text for a given migration asset path.
typedef SqlFileLoader = Future<String> Function(String assetPath);

/// Discovers the ordered list of migration asset paths.
typedef MigrationDiscoverer = Future<List<String>> Function();

/// Runs versioned SQL migrations bundled as Flutter assets.
///
/// Migrations live under `assets/migrations/` and are named `NNN__name.sql`
/// where `NNN` is a zero-padded integer version. Files are applied in ascending
/// version order. A `schema_version` meta table records applied versions.
///
/// DDL should use `IF NOT EXISTS` so migrations are idempotent. Statements are
/// split on `;` — keep migrations simple statement sequences with no semicolons
/// inside string literals (the runner ships no SQL parser).
///
/// Downgrades are rejected. To add a migration, drop a new `002__*.sql` file
/// into `assets/migrations/`, bump [_version] in `DatabaseHelper`, and rerun.
class MigrationRunner {
  MigrationRunner({MigrationDiscoverer? discoverer, SqlFileLoader? loader})
    : _discoverer = discoverer ?? _defaultDiscoverer,
      _loader = loader ?? _defaultLoader;

  final MigrationDiscoverer _discoverer;
  final SqlFileLoader _loader;

  static const String migrationsDir = 'assets/migrations';
  static const String metaTable = 'schema_version';

  /// The ordered list of migration SQL asset paths, newest last.
  ///
  /// This is the single source of truth for which migration files exist.
  /// When adding a migration, drop the `.sql` file into `assets/migrations/`,
  /// add its path here, and bump `DatabaseHelper._version`.
  ///
  /// We maintain an explicit list rather than discovering via
  /// `AssetManifest.json` because modern Flutter (3.16+) generates
  /// `AssetManifest.bin` (binary protobuf) instead of the JSON text file.
  static const List<String> migrationAssets = [
    'assets/migrations/001__init.sql',
  ];

  static Future<List<String>> _defaultDiscoverer() async => migrationAssets;

  static Future<String> _defaultLoader(String path) =>
      rootBundle.loadString(path);

  /// Parse a migration file name like `assets/migrations/001__init.sql`
  /// (or `/abs/path/001__init.sql`) into its integer version (1).
  /// Returns null if the name is malformed.
  @visibleForTesting
  static int? parseVersion(String path) {
    final name = path.split('/').last;
    final match = RegExp(r'^(\d{3,})__').firstMatch(name);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  /// Apply all migrations in order inside a single transaction (fresh install).
  Future<void> onCreate(Database db, int version) async {
    final sorted = _sortByVersion(await _discoverer());
    await _ensureMetaTable(db);
    await db.transaction((txn) async {
      for (final path in sorted) {
        final sql = await _loader(path);
        await _applySql(txn, sql);
        await _recordVersion(txn, path);
      }
    });
  }

  /// Apply migrations `old+1..new` in order, each in its own transaction
  /// (upgrade). Rejects downgrades.
  Future<void> onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion > newVersion) {
      throw StateError(
        'Migration downgrade not supported (from v$oldVersion to v$newVersion).',
      );
    }
    if (oldVersion == newVersion) return;
    final sorted = _sortByVersion(await _discoverer());
    await _ensureMetaTable(db);
    for (final path in sorted) {
      final v = parseVersion(path)!;
      if (v <= oldVersion) continue;
      if (v > newVersion) break;
      final sql = await _loader(path);
      await db.transaction((txn) async {
        await _applySql(txn, sql);
        await _recordVersion(txn, path);
      });
    }
  }

  Future<void> _ensureMetaTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $metaTable (
        version INTEGER PRIMARY KEY,
        applied_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _recordVersion(DatabaseExecutor db, String path) async {
    final v = parseVersion(path)!;
    await db.insert(metaTable, {
      'version': v,
      'applied_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  List<String> _sortByVersion(List<String> paths) {
    final withVersions = paths
        .map((p) => (p, parseVersion(p)))
        .where((e) => e.$2 != null)
        .toList();
    withVersions.sort((a, b) => a.$2!.compareTo(b.$2!));
    return withVersions.map((e) => e.$1).toList();
  }

  Future<void> _applySql(DatabaseExecutor db, String sql) async {
    final cleaned = sql
        .split('\n')
        .map((line) => line.split('--').first)
        .join('\n')
        .trim();
    if (cleaned.isEmpty) return;
    final statements = cleaned
        .split(';')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);
    for (final stmt in statements) {
      await db.execute(stmt);
    }
  }
}
