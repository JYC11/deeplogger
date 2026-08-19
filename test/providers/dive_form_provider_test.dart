import 'dart:io';

import 'package:deeplogger/database/database_helper.dart';
import 'package:deeplogger/database/migration_runner.dart';
import 'package:deeplogger/models/dive_log.dart';
import 'package:deeplogger/models/gear_item.dart';
import 'package:deeplogger/models/gear_ref.dart';
import 'package:deeplogger/providers/dive_form_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseHelper db;
  late ProviderContainer container;

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
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  tearDown(() async {
    await db.close();
  });

  group('DiveFormNotifier build', () {
    test('null id → empty new-dive state', () async {
      final form = await container.read(diveFormProvider(null).future);
      expect(form.isEditing, isFalse);
      expect(form.startTime, isNull);
      expect(form.location, isEmpty);
    });

    test('new dive defaults: altitude=Sea Level, gasType=Air (D4)', () async {
      final form = await container.read(diveFormProvider(null).future);
      expect(form.altitude, 'Sea Level (0m)');
      expect(form.gasType, 'Air');
    });

    test('existing id → preloads log + gear (edit-gear bug fix)', () async {
      final gId = await db.insertGearItem(GearItem(name: 'Mask'));
      final diveId = await db.insertDiveLog(
        DiveLog(
          startTime: DateTime(2026, 1, 1, 10),
          location: 'Reef',
          maxDepthM: 18.0,
        ),
      );
      await db.setGearEntriesForDive(
        diveId,
        gearItemIds: [gId],
        adHocGearTexts: ['Rentals BCD'],
      );

      final form = await container.read(diveFormProvider(diveId).future);
      expect(form.isEditing, isTrue);
      expect(form.existingId, diveId);
      expect(form.location, 'Reef');
      expect(form.maxDepthM, 18.0);
      expect(form.selectedGearIds, contains(gId));
      expect(form.adHocGear, contains('Rentals BCD'));
    });

    test('missing log id → empty state (not crash)', () async {
      final form = await container.read(diveFormProvider(999999).future);
      expect(form.isEditing, isFalse);
      expect(form.location, isEmpty);
    });
  });

  group('DiveFormNotifier validation', () {
    test('missing startTime + location → errors', () async {
      await container.read(diveFormProvider(null).future);
      final notifier = container.read(diveFormProvider(null).notifier);
      final ok = await notifier.save();
      expect(ok, isFalse);
      final state = container.read(diveFormProvider(null)).requireValue;
      expect(state.validationErrors['startTime'], isNotNull);
      expect(state.validationErrors['location'], isNotNull);
    });

    test('invalid numeric ranges flagged', () async {
      await container.read(diveFormProvider(null).future);
      final notifier = container.read(diveFormProvider(null).notifier);
      notifier.setStartTime(DateTime(2026, 1, 1));
      notifier.setLocation('Reef');
      notifier.setMaxDepth(500); // > 300
      notifier.setDuration(-5); // <= 0
      final ok = await notifier.save();
      expect(ok, isFalse);
      final state = container.read(diveFormProvider(null)).requireValue;
      expect(state.validationErrors['maxDepthM'], isNotNull);
      expect(state.validationErrors['durationMin'], isNotNull);
    });
  });

  // F6: numeric setters must clear a previously-recorded validation error for
  // their field once the user corrects the value (observed live during QA:
  // the "Must be > 0 and ≤ 600" error stayed on screen after the duration was
  // fixed to 45). Mirrors the existing startTime/location clear-on-edit test
  // pattern.
  group('DiveFormNotifier numeric setters clear validation errors (F6)', () {
    late DiveFormNotifier notifier;

    setUp(() async {
      // Hold a listener across setUp + each test so the autoDispose provider
      // isn't torn down between awaits (lesson `scfm7xih`).
      final sub = container.listen(diveFormProvider(null), (_, _) {});
      addTearDown(sub.close);
      await container.read(diveFormProvider(null).future);
      notifier = container.read(diveFormProvider(null).notifier);
      notifier.setStartTime(DateTime(2026, 1, 1));
      notifier.setLocation('Reef');
      // Seed a failed save so the validationErrors map is populated for
      // every numeric field at once.
      notifier.setMaxDepth(500); // > 300
      notifier.setAvgDepth(500); // > 300
      notifier.setDuration(-5); // <= 0
      notifier.setStartPressure(500); // > 400
      notifier.setEndPressure(9999); // >= start
      notifier.setWaterTemp(-50); // < -5
      notifier.setWeight(999); // > 50
      notifier.setVisibility(999); // > 100
      notifier.setTankVolumeValue(-1); // <= 0
      notifier.setGasType('Other');
      notifier.setGasOther(''); // required when gas = Other
      final ok = await notifier.save();
      expect(ok, isFalse);
      final errs = container
          .read(diveFormProvider(null))
          .requireValue
          .validationErrors;
      expect(errs['maxDepthM'], isNotNull);
      expect(errs['avgDepthM'], isNotNull);
      expect(errs['durationMin'], isNotNull);
      expect(errs['startPressureBar'], isNotNull);
      expect(errs['endPressureBar'], isNotNull);
      expect(errs['waterTempC'], isNotNull);
      expect(errs['weightKg'], isNotNull);
      expect(errs['visibilityM'], isNotNull);
      expect(errs['tankVolumeValue'], isNotNull);
      expect(errs['gasOther'], isNotNull);
    });

    test('setMaxDepth clears maxDepthM', () {
      notifier.setMaxDepth(30);
      expect(
        container
            .read(diveFormProvider(null))
            .requireValue
            .validationErrors
            .containsKey('maxDepthM'),
        isFalse,
      );
    });

    test('setAvgDepth clears avgDepthM', () {
      notifier.setAvgDepth(20);
      expect(
        container
            .read(diveFormProvider(null))
            .requireValue
            .validationErrors
            .containsKey('avgDepthM'),
        isFalse,
      );
    });

    test('setDuration clears durationMin', () {
      notifier.setDuration(45);
      expect(
        container
            .read(diveFormProvider(null))
            .requireValue
            .validationErrors
            .containsKey('durationMin'),
        isFalse,
      );
    });

    test('setStartPressure clears startPressureBar', () {
      notifier.setStartPressure(200);
      expect(
        container
            .read(diveFormProvider(null))
            .requireValue
            .validationErrors
            .containsKey('startPressureBar'),
        isFalse,
      );
    });

    test('setEndPressure clears endPressureBar', () {
      notifier.setEndPressure(80);
      expect(
        container
            .read(diveFormProvider(null))
            .requireValue
            .validationErrors
            .containsKey('endPressureBar'),
        isFalse,
      );
    });

    test('setWaterTemp clears waterTempC', () {
      notifier.setWaterTemp(20);
      expect(
        container
            .read(diveFormProvider(null))
            .requireValue
            .validationErrors
            .containsKey('waterTempC'),
        isFalse,
      );
    });

    test('setWeight clears weightKg', () {
      notifier.setWeight(5);
      expect(
        container
            .read(diveFormProvider(null))
            .requireValue
            .validationErrors
            .containsKey('weightKg'),
        isFalse,
      );
    });

    test('setVisibility clears visibilityM', () {
      notifier.setVisibility(15);
      expect(
        container
            .read(diveFormProvider(null))
            .requireValue
            .validationErrors
            .containsKey('visibilityM'),
        isFalse,
      );
    });

    test('setTankVolumeValue clears tankVolumeValue', () {
      notifier.setTankVolumeValue(12);
      expect(
        container
            .read(diveFormProvider(null))
            .requireValue
            .validationErrors
            .containsKey('tankVolumeValue'),
        isFalse,
      );
    });

    test('setGasOther clears gasOther', () {
      notifier.setGasOther('Trimix 21/35');
      expect(
        container
            .read(diveFormProvider(null))
            .requireValue
            .validationErrors
            .containsKey('gasOther'),
        isFalse,
      );
    });

    test('correcting every numeric field yields a saveable form', () async {
      notifier.setMaxDepth(30);
      notifier.setAvgDepth(18);
      notifier.setDuration(45);
      notifier.setStartPressure(200);
      notifier.setEndPressure(80);
      notifier.setWaterTemp(22);
      notifier.setWeight(5);
      notifier.setVisibility(15);
      notifier.setTankVolumeValue(12);
      notifier.setGasOther('Trimix 21/35');
      final errs = container
          .read(diveFormProvider(null))
          .requireValue
          .validationErrors;
      expect(errs, isEmpty);
      final ok = await notifier.save();
      expect(ok, isTrue);
    });
  });

  group('DiveFormNotifier save', () {
    test('new dive inserts + gear', () async {
      final gId = await db.insertGearItem(GearItem(name: 'Fins'));
      // Hold a listener like the form screen does — the provider is
      // autoDispose and would otherwise be torn down between reads.
      final sub = container.listen(diveFormProvider(null), (_, _) {});
      addTearDown(sub.close);
      await container.read(diveFormProvider(null).future);
      final notifier = container.read(diveFormProvider(null).notifier);
      notifier.setStartTime(DateTime(2026, 1, 1, 9));
      notifier.setLocation('New Spot');
      notifier.setMaxDepth(20.0);
      notifier.setDuration(40.0);
      notifier.toggleGear(gId);
      notifier.addAdHocGear('Spare Mask');

      final ok = await notifier.save();
      expect(ok, isTrue);

      final all = (await db.getDiveLogs()).logs;
      expect(all.length, 1);
      expect(all.first.location, 'New Spot');
      final gearRefs = await db.getGearEntriesForDive(all.first.id!);
      expect(gearRefs.length, 2);
      expect(gearRefs.whereType<GearRefAdHoc>().length, 1);
    });

    test('edit dive updates + preserves gear', () async {
      final gId = await db.insertGearItem(GearItem(name: 'BCD'));
      final diveId = await db.insertDiveLog(
        DiveLog(
          startTime: DateTime(2026, 1, 1, 9),
          location: 'Old',
          maxDepthM: 15.0,
        ),
      );
      await db.setGearEntriesForDive(diveId, gearItemIds: [gId]);

      final sub = container.listen(diveFormProvider(diveId), (_, _) {});
      addTearDown(sub.close);
      final notifier = container.read(diveFormProvider(diveId).notifier);
      await container.read(diveFormProvider(diveId).future);
      notifier.setLocation('Updated');
      final ok = await notifier.save();
      expect(ok, isTrue);

      final log = await db.getDiveLog(diveId);
      expect(log!.location, 'Updated');
      // Gear must still be present (the old form wiped it; the notifier
      // preserves preloaded selection).
      final gearRefs = await db.getGearEntriesForDive(diveId);
      expect(gearRefs.length, 1);
      expect(gearRefs.first, isA<GearRefItem>());
    });
  });
}
