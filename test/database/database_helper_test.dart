import 'package:divelogger/database/database_helper.dart';
import 'package:divelogger/models/certification.dart';
import 'package:divelogger/models/dive_log.dart';
import 'package:divelogger/models/dive_photo.dart';
import 'package:divelogger/models/gear_item.dart';
import 'package:divelogger/models/sighting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseHelper db;

  setUp(() async {
    db = DatabaseHelper.instance;
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
        DiveLog(location: 'Original', maxDepthM: 10),
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
      final id = await db.insertDiveLog(DiveLog(location: 'ToDelete'));
      expect(await db.deleteDiveLog(id), 1);
      expect(await db.getDiveLog(id), isNull);
    });

    test('is_draft round-trips correctly', () async {
      final id = await db.insertDiveLog(
        DiveLog(location: 'Draft', isDraft: true),
      );
      final retrieved = await db.getDiveLog(id);
      expect(retrieved!.isDraft, isTrue);
    });
  });

  group('DivePhoto CRUD', () {
    test('insert and retrieve photos for a dive', () async {
      final diveId = await db.insertDiveLog(DiveLog(location: 'Photo Dive'));

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
      final diveId = await db.insertDiveLog(DiveLog(location: 'D'));
      final photoId = await db.insertDivePhoto(
        DivePhoto(diveLogId: diveId, localPath: '/p.jpg'),
      );
      expect(await db.deleteDivePhoto(photoId), 1);
      expect(await db.getDivePhotosForLog(diveId), isEmpty);
    });
  });

  group('Sighting CRUD', () {
    test('insert and retrieve sightings for a dive', () async {
      final diveId = await db.insertDiveLog(DiveLog(location: 'Sight Dive'));
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
      final diveId = await db.insertDiveLog(DiveLog(location: 'D'));
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
      final diveId = await db.insertDiveLog(DiveLog(location: 'Gear Dive'));
      final g1 = await db.insertGearItem(GearItem(name: 'Wetsuit 3mm'));
      final g3 = await db.insertGearItem(GearItem(name: 'Fins'));

      await db.setGearForDive(diveId, [g1, g3]);

      final gear = await db.getGearForDive(diveId);
      expect(gear.length, 2);
      expect(gear.map((g) => g.name).toSet(), {'Wetsuit 3mm', 'Fins'});
    });

    test('setGearForDive replaces previous selection', () async {
      final diveId = await db.insertDiveLog(DiveLog(location: 'D'));
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
      final diveId = await db.insertDiveLog(DiveLog(location: 'Cascade Test'));
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
}
