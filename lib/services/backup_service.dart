import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import 'unit_preferences.dart';

/// Manual offline backup / import (F7).
///
/// Per AGENTS.md: offline-only, no cloud, no sign-in. All data lives in:
/// - a single SQLite file at `<databasesPath>/deeplogger.db`,
/// - copied images at `<appDocs>/dive_photos/`,
/// - thumbnails at `<appDocs>/thumbnails/` (regenerable, NOT backed up),
/// - per-field unit prefs in `SharedPreferences` (keys prefixed
///   `unit_pref_`).
///
/// Export produces `deeplogger_backup_<timestamp>.zip` containing:
///   - `deeplogger.db`           — the SQLite file
///   - `images/`                 — copied dive + cert photos
///   - `manifest.json`           — `{format, schemaVersion, exportedAt}`
///   - `unit_prefs.json`         — display-unit preferences
///
/// Import is replace-only v1 (no merge): the existing DB + images dir +
/// SharedPreferences are wiped and replaced with the zip's contents. The DB
/// is closed across the swap so SQLite doesn't hold a stale file handle.
class BackupService {
  BackupService._internal();
  static final BackupService instance = BackupService._internal();

  /// Backup format version — bumped only on breaking changes to the zip
  /// layout. Import rejects zips whose `format` differs from this.
  static const int kBackupFormat = 1;

  /// Test seam: override the databases-path resolver so host tests don't
  /// need the sqflite platform channel. Defaults to [getDatabasesPath].
  Future<String> Function()? databasesPathOverride;

  /// Test seam: override the app-documents-directory resolver. Defaults to
  /// [getApplicationDocumentsDirectory].
  Future<Directory> Function()? appDirOverride;

  /// Test seam: override the OS-temp-directory resolver used for the output
  /// zip path. Defaults to [getTemporaryDirectory].
  Future<Directory> Function()? tempDirOverride;

  Future<Directory> _tempDir() =>
      tempDirOverride != null ? tempDirOverride!() : getTemporaryDirectory();

  Future<String> _dbPath() async {
    final dir = databasesPathOverride != null
        ? await databasesPathOverride!()
        : await getDatabasesPath();
    return p.join(dir, 'deeplogger.db');
  }

  Future<Directory> _appDir() => appDirOverride != null
      ? appDirOverride!()
      : getApplicationDocumentsDirectory();

  /// Test seam: inject a [SharedPreferences] instance so host tests don't
  /// need the platform channel. Defaults to [SharedPreferences.getInstance].
  Future<SharedPreferences> Function()? prefsInstanceOverride;

  Future<SharedPreferences> _prefsInstance() => prefsInstanceOverride != null
      ? prefsInstanceOverride!()
      : SharedPreferences.getInstance();

  /// Builds the backup zip in the OS temp directory and returns its path.
  /// The caller is responsible for sharing it (e.g. via `share_plus`).
  ///
  /// Thumbnails are excluded — they're regenerable via
  /// `ImageStore.ensureThumbnail` once the dive photos are restored.
  Future<String> exportToZip() async {
    final archive = Archive();

    // 1. SQLite db file.
    final dbPath = await _dbPath();
    final dbFile = File(dbPath);
    if (!await dbFile.exists()) {
      throw FileSystemException('Database file not found', dbPath);
    }
    archive.addFile(
      ArchiveFile.bytes('deeplogger.db', await dbFile.readAsBytes()),
    );

    // 2. Copied images (dive_photos/). Skip thumbnails/ (regenerable).
    final appDir = await _appDir();
    final photosDir = Directory(p.join(appDir.path, 'dive_photos'));
    if (await photosDir.exists()) {
      await for (final entity in photosDir.list(recursive: false)) {
        if (entity is! File) continue;
        final relPath = p.relative(entity.path, from: photosDir.path);
        archive.addFile(
          ArchiveFile.bytes('images/$relPath', await entity.readAsBytes()),
        );
      }
    }

    // 3. Unit display preferences (SharedPreferences).
    final prefsJson = await _readUnitPrefsJson();
    archive.addFile(
      ArchiveFile.bytes('unit_prefs.json', utf8.encode(jsonEncode(prefsJson))),
    );

    // 4. Manifest — written last so it reflects what's actually in the zip.
    final manifest = {
      'format': kBackupFormat,
      'schemaVersion': DatabaseHelper.kSchemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'includes': const ['db', 'images', 'unit_prefs'],
    };
    archive.addFile(
      ArchiveFile.bytes('manifest.json', utf8.encode(jsonEncode(manifest))),
    );

    final bytes = ZipEncoder().encode(archive);
    final tmpDir = await _tempDir();
    final stamp = DateTime.now().toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '-',
    );
    final outPath = p.join(tmpDir.path, 'deeplogger_backup_$stamp.zip');
    final outFile = File(outPath);
    await outFile.writeAsBytes(bytes);
    return outPath;
  }

  /// Reads all `unit_pref_*` SharedPreferences entries as a JSON-encodable
  /// map (`{key: value}`).
  Future<Map<String, String>> _readUnitPrefsJson() async {
    final prefs = await _prefsInstance();
    final result = <String, String>{};
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(UnitPreferencesService.prefix)) continue;
      final value = prefs.getString(key);
      if (value != null) result[key] = value;
    }
    return result;
  }

  /// Restores the backup zip at [zipPath] into the app's data directory.
  /// Replace-only: the existing DB file, `dive_photos/` dir, and unit
  /// prefs are wiped and replaced.
  ///
  /// Returns the manifest of the imported zip (for surfacing to the UI).
  ///
  /// Throws [BackupManifestException] for malformed manifests,
  /// [BackupSchemaException] for incompatible schema versions, and
  /// [FormatException] for corrupt zips.
  Future<BackupManifest> importFromZip(String zipPath) async {
    final zipFile = File(zipPath);
    if (!await zipFile.exists()) {
      throw FileSystemException('Backup zip not found', zipPath);
    }
    final archive = ZipDecoder().decodeBytes(await zipFile.readAsBytes());

    final manifestFile = archive.findFile('manifest.json');
    if (manifestFile == null) {
      throw BackupManifestException('manifest.json missing in backup zip');
    }
    final manifestJson =
        jsonDecode(utf8.decode(manifestFile.content as List<int>))
            as Map<String, Object?>;
    final manifest = BackupManifest.fromJson(manifestJson);

    if (manifest.format != kBackupFormat) {
      throw BackupManifestException(
        'Unsupported backup format ${manifest.format} (expected '
        '$kBackupFormat)',
      );
    }
    if (manifest.schemaVersion > DatabaseHelper.kSchemaVersion) {
      throw BackupSchemaException(
        'Backup schemaVersion ${manifest.schemaVersion} is newer than the '
        'app supports (${DatabaseHelper.kSchemaVersion}). Update the app '
        'before importing.',
      );
    }

    final dbEntry = archive.findFile('deeplogger.db');
    if (dbEntry == null) {
      throw BackupManifestException('deeplogger.db missing in backup zip');
    }

    // --- Close DB so SQLite releases the file handle before we replace it.
    await DatabaseHelper.instance.close();

    // --- Wipe + replace the dive_photos dir.
    final appDir = await _appDir();
    final photosDir = Directory(p.join(appDir.path, 'dive_photos'));
    if (await photosDir.exists()) {
      await photosDir.delete(recursive: true);
    }
    await photosDir.create(recursive: true);
    for (final entry in archive) {
      if (!entry.name.startsWith('images/')) continue;
      final relPath = entry.name.substring('images/'.length);
      if (relPath.isEmpty) continue;
      final outPath = p.join(photosDir.path, relPath);
      await Directory(p.dirname(outPath)).create(recursive: true);
      await File(outPath).writeAsBytes(entry.content as List<int>);
    }

    // --- Replace the db file.
    final dbPath = await _dbPath();
    await Directory(p.dirname(dbPath)).create(recursive: true);
    await File(dbPath).writeAsBytes(dbEntry.content as List<int>);

    // --- Restore unit prefs.
    final prefsEntry = archive.findFile('unit_prefs.json');
    if (prefsEntry != null) {
      await _restoreUnitPrefs(utf8.decode(prefsEntry.content as List<int>));
    }

    // --- Drop the singleton's cached handle so the next `database` getter
    //     reopens with the new file (close() already nulled _db; this is a
    //     defensive no-op if close() ran).
    await DatabaseHelper.instance.database;

    return manifest;
  }

  /// Replaces all `unit_pref_*` SharedPreferences entries with those from
  /// the [json] payload. Existing unit prefs are cleared first.
  Future<void> _restoreUnitPrefs(String json) async {
    final prefs = await _prefsInstance();
    // Clear existing unit_pref_* keys.
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith(UnitPreferencesService.prefix)) {
        await prefs.remove(key);
      }
    }
    // Restore from payload.
    final map = jsonDecode(json) as Map<String, Object?>;
    for (final entry in map.entries) {
      if (entry.value is String) {
        await prefs.setString(entry.key, entry.value as String);
      }
    }
  }
}

/// Parsed backup manifest (`manifest.json` inside the zip).
class BackupManifest {
  const BackupManifest({
    required this.format,
    required this.schemaVersion,
    required this.exportedAt,
    this.includes = const [],
  });

  final int format;
  final int schemaVersion;
  final DateTime exportedAt;
  final List<String> includes;

  factory BackupManifest.fromJson(Map<String, Object?> json) {
    final format = json['format'];
    final schemaVersion = json['schemaVersion'];
    final exportedAt = json['exportedAt'];
    if (format is! int) {
      throw BackupManifestException('manifest.format missing or not an int');
    }
    if (schemaVersion is! int) {
      throw BackupManifestException(
        'manifest.schemaVersion missing or not an int',
      );
    }
    if (exportedAt is! String) {
      throw BackupManifestException(
        'manifest.exportedAt missing or not a string',
      );
    }
    final includes =
        (json['includes'] as List<Object?>?)?.whereType<String>().toList() ??
        const <String>[];
    return BackupManifest(
      format: format,
      schemaVersion: schemaVersion,
      exportedAt: DateTime.parse(exportedAt),
      includes: includes,
    );
  }
}

/// Thrown when the backup zip's manifest is missing, malformed, or has an
/// unsupported format version.
class BackupManifestException implements Exception {
  BackupManifestException(this.message);
  final String message;

  @override
  String toString() => 'BackupManifestException: $message';
}

/// Thrown when the backup's schemaVersion is newer than the app supports.
class BackupSchemaException implements Exception {
  BackupSchemaException(this.message);
  final String message;

  @override
  String toString() => 'BackupSchemaException: $message';
}
