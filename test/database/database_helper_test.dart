import 'dart:io';

import 'package:deeplogger/database/database_helper.dart';
import 'package:deeplogger/database/migration_runner.dart';
import 'package:deeplogger/database/sort_fields.dart';
import 'package:deeplogger/models/certification.dart';
import 'package:deeplogger/models/dive_detail.dart';
import 'package:deeplogger/models/dive_log.dart';
import 'package:deeplogger/models/dive_photo.dart';
import 'package:deeplogger/models/gear_item.dart';
import 'package:deeplogger/models/gear_ref.dart';
import 'package:deeplogger/models/sighting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Builds a [MigrationRunner] that reads `.sql` files directly from disk
/// (the test host has the project's `assets/migrations/` on the filesystem).
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

  late DatabaseHelper db;

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
  });

  tearDown(() async {
    await db.close();
  });

  group('DiveLog CRUD', () {
    test('insert and retrieve by id', () async {
      final id = await db.insertDiveLog(
        DiveLog(
          startTime: DateTime(2026, 1, 1),
          location: 'Great Barrier Reef',
          maxDepthM: 18.5,
          avgDepthM: 12.0,
          durationMin: 45,
          tankSize: '12L',
          startPressureBar: 200,
          endPressureBar: 60,
        ),
      );
      expect(id, greaterThan(0));

      final retrieved = await db.getDiveLog(id);
      expect(retrieved, isNotNull);
      expect(retrieved!.location, 'Great Barrier Reef');
      expect(retrieved.maxDepthM, 18.5);
      expect(retrieved.id, id);
    });

    test('getAllDiveLogs returns sorted by start_time DESC', () async {
      await db.insertDiveLog(
        DiveLog(startTime: DateTime(2026, 1, 15), location: 'January Dive'),
      );
      await db.insertDiveLog(
        DiveLog(startTime: DateTime(2026, 3, 10), location: 'March Dive'),
      );
      await db.insertDiveLog(
        DiveLog(startTime: DateTime(2026, 2, 20), location: 'February Dive'),
      );

      final logs = await db.getAllDiveLogs();
      expect(logs.length, 3);
      expect(logs[0].location, 'March Dive');
      expect(logs[1].location, 'February Dive');
      expect(logs[2].location, 'January Dive');
    });

    test('update modifies fields', () async {
      final id = await db.insertDiveLog(
        DiveLog(
          startTime: DateTime(2026, 1, 1),
          location: 'Original',
          maxDepthM: 10,
        ),
      );
      final original = await db.getDiveLog(id);
      await db.updateDiveLog(
        original!.copyWith(location: 'Updated', maxDepthM: 25),
      );

      final updated = await db.getDiveLog(id);
      expect(updated!.location, 'Updated');
      expect(updated.maxDepthM, 25);
    });

    test('delete removes the log', () async {
      final id = await db.insertDiveLog(
        DiveLog(startTime: DateTime(2026, 1, 1), location: 'ToDelete'),
      );
      expect(await db.deleteDiveLog(id), 1);
      expect(await db.getDiveLog(id), isNull);
    });

    test('is_draft round-trips correctly', () async {
      final id = await db.insertDiveLog(
        DiveLog(
          startTime: DateTime(2026, 1, 1),
          location: 'Draft',
          isDraft: true,
        ),
      );
      final retrieved = await db.getDiveLog(id);
      expect(retrieved!.isDraft, isTrue);
    });
  });

  group('DivePhoto CRUD', () {
    test('insert and retrieve photos for a dive', () async {
      final diveId = await db.insertDiveLog(
        DiveLog(startTime: DateTime(2026, 1, 1), location: 'Photo Dive'),
      );

      await db.insertDivePhoto(
        DivePhoto(
          diveLogId: diveId,
          localPath: '/docs/photo1.jpg',
          takenAt: DateTime(2026, 1, 1, 10, 0),
        ),
      );
      await db.insertDivePhoto(
        DivePhoto(
          diveLogId: diveId,
          localPath: '/docs/photo2.jpg',
          takenAt: DateTime(2026, 1, 1, 9, 0),
        ),
      );

      final photos = await db.getDivePhotosForLog(diveId);
      expect(photos.length, 2);
      expect(photos[0].localPath, '/docs/photo2.jpg');
      expect(photos[1].localPath, '/docs/photo1.jpg');
    });

    test('delete photo removes it', () async {
      final diveId = await db.insertDiveLog(
        DiveLog(startTime: DateTime(2026, 1, 1), location: 'D'),
      );
      final photoId = await db.insertDivePhoto(
        DivePhoto(diveLogId: diveId, localPath: '/p.jpg'),
      );
      expect(await db.deleteDivePhoto(photoId), 1);
      expect(await db.getDivePhotosForLog(diveId), isEmpty);
    });
  });

  group('Sighting CRUD', () {
    test('insert and retrieve sightings for a dive', () async {
      final diveId = await db.insertDiveLog(
        DiveLog(startTime: DateTime(2026, 1, 1), location: 'Sight Dive'),
      );
      final photoId = await db.insertDivePhoto(
        DivePhoto(diveLogId: diveId, localPath: '/p.jpg'),
      );

      await db.insertSighting(
        Sighting(
          diveLogId: diveId,
          divePhotoId: photoId,
          commonName: 'Clownfish',
        ),
      );
      await db.insertSighting(
        Sighting(
          diveLogId: diveId,
          divePhotoId: photoId,
          commonName: 'Sea Turtle',
        ),
      );

      final sightings = await db.getSightingsForLog(diveId);
      expect(sightings.length, 2);
      expect(sightings.map((s) => s.commonName).toSet(), {
        'Clownfish',
        'Sea Turtle',
      });
    });

    test('delete sighting', () async {
      final diveId = await db.insertDiveLog(
        DiveLog(startTime: DateTime(2026, 1, 1), location: 'D'),
      );
      final sightingId = await db.insertSighting(
        Sighting(diveLogId: diveId, commonName: 'Octopus'),
      );
      expect(await db.deleteSighting(sightingId), 1);
      expect(await db.getSightingsForLog(diveId), isEmpty);
    });
  });

  group('Certification CRUD', () {
    test('insert and retrieve all', () async {
      await db.insertCertification(
        Certification(org: 'PADI', level: 'Open Water'),
      );
      await db.insertCertification(
        Certification(
          org: 'SSI',
          level: 'Advanced',
          issueDate: DateTime(2025, 6, 1),
        ),
      );

      final certs = await db.getAllCertifications();
      expect(certs.length, 2);
      expect(certs[0].org, 'PADI');
      expect(certs[1].org, 'SSI');
    });

    test('delete certification', () async {
      final id = await db.insertCertification(
        Certification(org: 'BSAC', level: 'Sports Diver'),
      );
      expect(await db.deleteCertification(id), 1);
      expect(await db.getAllCertifications(), isEmpty);
    });
  });

  group('GearItem CRUD', () {
    test('insert and retrieve all sorted by name', () async {
      await db.insertGearItem(GearItem(name: 'Wetsuit 5mm'));
      await db.insertGearItem(GearItem(name: 'BCD'));
      await db.insertGearItem(GearItem(name: 'Fins'));

      final items = await db.getAllGearItems();
      expect(items.length, 3);
      expect(items[0].name, 'BCD');
      expect(items[1].name, 'Fins');
      expect(items[2].name, 'Wetsuit 5mm');
    });

    test('delete gear item', () async {
      final id = await db.insertGearItem(GearItem(name: 'Regulator'));
      expect(await db.deleteGearItem(id), 1);
      expect(await db.getAllGearItems(), isEmpty);
    });
  });

  group('dive_log_gear M2M', () {
    test('set and get gear for a dive', () async {
      final diveId = await db.insertDiveLog(
        DiveLog(startTime: DateTime(2026, 1, 1), location: 'Gear Dive'),
      );
      final g1 = await db.insertGearItem(GearItem(name: 'Wetsuit 3mm'));
      final g3 = await db.insertGearItem(GearItem(name: 'Fins'));

      await db.setGearForDive(diveId, [g1, g3]);

      final gear = await db.getGearForDive(diveId);
      expect(gear.length, 2);
      expect(gear.map((g) => g.name).toSet(), {'Wetsuit 3mm', 'Fins'});
    });

    test('setGearForDive replaces previous selection', () async {
      final diveId = await db.insertDiveLog(
        DiveLog(startTime: DateTime(2026, 1, 1), location: 'D'),
      );
      final g1 = await db.insertGearItem(GearItem(name: 'Mask'));
      final g2 = await db.insertGearItem(GearItem(name: 'Snorkel'));

      await db.setGearForDive(diveId, [g1]);
      expect((await db.getGearForDive(diveId)).length, 1);

      await db.setGearForDive(diveId, [g2]);
      final gear = await db.getGearForDive(diveId);
      expect(gear.length, 1);
      expect(gear[0].name, 'Snorkel');
    });
  });

  group('cascade delete', () {
    test('deleting a dive log cascades to photos and sightings', () async {
      final diveId = await db.insertDiveLog(
        DiveLog(startTime: DateTime(2026, 1, 1), location: 'Cascade Test'),
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

      expect(await db.getDivePhotosForLog(diveId), isEmpty);
      expect(await db.getSightingsForLog(diveId), isEmpty);
    });
  });

  group('getDiveLogs pagination', () {
    Future<void> seed(int count) async {
      for (var i = 0; i < count; i++) {
        await db.insertDiveLog(
          DiveLog(
            startTime: DateTime(2026, 1, 1).add(Duration(minutes: i)),
            location: 'Dive $i',
            maxDepthM: (i + 1).toDouble(),
            durationMin: (i + 1).toDouble(),
          ),
        );
      }
    }

    test('limit + offset returns page and hasMore', () async {
      await seed(25);
      final page1 = await db.getDiveLogs(limit: 10, offset: 0);
      expect(page1.logs.length, 10);
      expect(page1.hasMore, isTrue);
      final page2 = await db.getDiveLogs(limit: 10, offset: 10);
      expect(page2.logs.length, 10);
      expect(page2.hasMore, isTrue);
      final page3 = await db.getDiveLogs(limit: 10, offset: 20);
      expect(page3.logs.length, 5);
      expect(page3.hasMore, isFalse);
    });

    test('search matches location or notes', () async {
      await db.insertDiveLog(
        DiveLog(
          startTime: DateTime(2026, 1, 1),
          location: 'Great Barrier Reef',
          notes: 'cool',
        ),
      );
      await db.insertDiveLog(
        DiveLog(
          startTime: DateTime(2026, 1, 2),
          location: 'Local Quarry',
          notes: 'turtle',
        ),
      );
      final byLoc = await db.getDiveLogs(search: 'barrier');
      expect(byLoc.logs.length, 1);
      expect(byLoc.logs.first.location, 'Great Barrier Reef');
      final byNotes = await db.getDiveLogs(search: 'turtle');
      expect(byNotes.logs.length, 1);
      expect(byNotes.logs.first.location, 'Local Quarry');
    });

    test('includeDrafts false filters drafts in SQL', () async {
      await db.insertDiveLog(
        DiveLog(startTime: DateTime(2026, 1, 1), location: 'Published'),
      );
      await db.insertDiveLog(
        DiveLog(
          startTime: DateTime(2026, 1, 2),
          location: 'Draft',
          isDraft: true,
        ),
      );
      final noDrafts = await db.getDiveLogs(includeDrafts: false);
      expect(noDrafts.logs.length, 1);
      expect(noDrafts.logs.first.location, 'Published');
      final withDrafts = await db.getDiveLogs(includeDrafts: true);
      expect(withDrafts.logs.length, 2);
    });

    test('sortField ascending and descending', () async {
      await seed(3);
      final desc = await db.getDiveLogs(
        sortField: DiveLogSortField.maxDepthM,
        sortDesc: true,
      );
      expect(desc.logs.first.maxDepthM, 3.0);
      final asc = await db.getDiveLogs(
        sortField: DiveLogSortField.maxDepthM,
        sortDesc: false,
      );
      expect(asc.logs.first.maxDepthM, 1.0);
    });
  });

  group('getCertifications pagination', () {
    test('search matches org/level/cert_id', () async {
      await db.insertCertification(
        Certification(org: 'PADI', level: 'Open Water', certId: 'A1'),
      );
      await db.insertCertification(
        Certification(org: 'SSI', level: 'Advanced', certId: 'B2'),
      );
      final r = await db.getCertifications(search: 'advanced');
      expect(r.certs.length, 1);
      expect(r.certs.first.org, 'SSI');
      final byId = await db.getCertifications(search: 'B2');
      expect(byId.certs.length, 1);
    });
  });

  group('getGearItems pagination + category', () {
    test('category filter', () async {
      await db.insertGearItem(GearItem(name: 'BCD1', category: 'BCD'));
      await db.insertGearItem(GearItem(name: 'Fin1', category: 'Fins'));
      final r = await db.getGearItems(category: 'BCD');
      expect(r.items.length, 1);
      expect(r.items.first.name, 'BCD1');
    });

    test('search + sort by category', () async {
      await db.insertGearItem(GearItem(name: 'Wetsuit', category: 'Wetsuit'));
      await db.insertGearItem(GearItem(name: 'Reg', category: 'Regulator'));
      final r = await db.getGearItems(search: 'reg');
      expect(r.items.length, 1);
      expect(r.items.first.name, 'Reg');
    });
  });

  group('getGearEntriesForDive (mixed read path)', () {
    test('returns master items and ad-hoc text rows', () async {
      final diveId = await db.insertDiveLog(
        DiveLog(startTime: DateTime(2026, 1, 1), location: 'Mixed Gear Dive'),
      );
      final gId = await db.insertGearItem(GearItem(name: 'Mask'));
      await db.setGearForDive(diveId, [gId]);
      // Insert an ad-hoc gear_text row directly.
      await (await db.database).rawInsert(
        'INSERT INTO dive_log_gear (dive_log_id, gear_text) VALUES (?, ?)',
        [diveId, 'Rentals BCD'],
      );

      final refs = await db.getGearEntriesForDive(diveId);
      expect(refs.length, 2);
      final items = refs.whereType<GearRefItem>().toList();
      final adhoc = refs.whereType<GearRefAdHoc>().toList();
      expect(items.length, 1);
      expect(items.first.item.name, 'Mask');
      expect(adhoc.length, 1);
      expect(adhoc.first.text, 'Rentals BCD');
    });

    test('ad-hoc-only dive returns only GearRefAdHoc', () async {
      final diveId = await db.insertDiveLog(
        DiveLog(startTime: DateTime(2026, 1, 1), location: 'AdHoc Only'),
      );
      await (await db.database).rawInsert(
        'INSERT INTO dive_log_gear (dive_log_id, gear_text) VALUES (?, ?)',
        [diveId, 'Spare Reg'],
      );
      final refs = await db.getGearEntriesForDive(diveId);
      expect(refs.length, 1);
      expect(refs.first, isA<GearRefAdHoc>());
    });
  });

  group('getDiveDetail', () {
    test('returns null for missing id', () async {
      expect(await db.getDiveDetail(999999), isNull);
    });

    test('loads log + photos + sightings + gear in one call', () async {
      final diveId = await db.insertDiveLog(
        DiveLog(
          startTime: DateTime(2026, 1, 1),
          location: 'Detail Dive',
          maxDepthM: 22.0,
        ),
      );
      final photoId = await db.insertDivePhoto(
        DivePhoto(diveLogId: diveId, localPath: '/p1.jpg'),
      );
      await db.insertSighting(
        Sighting(diveLogId: diveId, divePhotoId: photoId, commonName: 'Nemo'),
      );
      final gId = await db.insertGearItem(GearItem(name: 'Fins'));
      await db.setGearForDive(diveId, [gId]);

      final detail = await db.getDiveDetail(diveId);
      expect(detail, isA<DiveDetail>());
      expect(detail!.log.location, 'Detail Dive');
      expect(detail.photos.length, 1);
      expect(detail.photos.first.localPath, '/p1.jpg');
      expect(detail.sightings.length, 1);
      expect(detail.sightings.first.commonName, 'Nemo');
      expect(detail.gear.length, 1);
      expect(detail.gear.first, isA<GearRefItem>());
    });
  });
}
