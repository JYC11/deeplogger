import 'dart:io';

import 'package:deeplogger/database/database_helper.dart';
import 'package:deeplogger/database/migration_runner.dart';
import 'package:deeplogger/models/dive_log.dart';
import 'package:deeplogger/providers/dive_providers.dart';
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

  setUp(() async {
    final db = DatabaseHelper.instance;
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
    await DatabaseHelper.instance.close();
  });

  test('diveListProvider resolves with empty list', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final future = container.read(diveListProvider.future);
    final logs = await future;

    expect(logs, isEmpty);
  });

  group('sacProvider', () {
    ProviderContainer makeContainer() {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      return c;
    }

    test('metric dive with 12L tank → full SAC', () {
      final c = makeContainer();
      final log = DiveLog(
        startPressureBar: 200,
        endPressureBar: 50,
        durationMin: 40,
        avgDepthM: 15,
        tankSize: '12L',
      );
      final sac = c.read(sacProvider(log));
      expect(sac, isNotNull);
      expect(sac!.barPerMin, closeTo(1.5, 0.001));
      expect(sac.litersPerMin, closeTo(18.0, 0.01));
      expect(sac.hasFullSac, isTrue);
    });

    test('unknown tank → bar/min only (hasFullSac false)', () {
      final c = makeContainer();
      final log = DiveLog(
        startPressureBar: 200,
        endPressureBar: 50,
        durationMin: 40,
        avgDepthM: 15,
      );
      final sac = c.read(sacProvider(log));
      expect(sac, isNotNull);
      expect(sac!.litersPerMin, isNull);
      expect(sac.hasFullSac, isFalse);
    });

    test('structured tank volume (L) wins', () {
      final c = makeContainer();
      final log = DiveLog(
        startPressureBar: 200,
        endPressureBar: 50,
        durationMin: 40,
        avgDepthM: 15,
        tankSize: '12L',
        tankVolumeValue: 10.0,
        tankVolumeUnit: 'L',
      );
      final sac = c.read(sacProvider(log));
      expect(sac!.tankVolumeL, closeTo(10.0, 0.001));
      expect(sac.litersPerMin, closeTo(1.5 * 10.0, 0.01));
    });

    test('structured cu_ft converts', () {
      final c = makeContainer();
      final log = DiveLog(
        startPressureBar: 200,
        endPressureBar: 50,
        durationMin: 40,
        avgDepthM: 15,
        tankVolumeValue: 80.0,
        tankVolumeUnit: 'cu_ft',
      );
      final sac = c.read(sacProvider(log));
      expect(sac!.tankVolumeL, closeTo(80 * 28.3168 / 207, 0.01));
    });

    test('missing pressure/duration/depth → null', () {
      final c = makeContainer();
      expect(
        c.read(sacProvider(DiveLog(durationMin: 40, avgDepthM: 15))),
        isNull,
      );
      expect(
        c.read(
          sacProvider(
            DiveLog(startPressureBar: 200, endPressureBar: 50, avgDepthM: 15),
          ),
        ),
        isNull,
      );
    });

    test('duration <= 0 → null (guard)', () {
      final c = makeContainer();
      final log = DiveLog(
        startPressureBar: 200,
        endPressureBar: 50,
        durationMin: 0,
        avgDepthM: 15,
        tankSize: '12L',
      );
      expect(c.read(sacProvider(log)), isNull);
    });

    test('end >= start → null (guard)', () {
      final c = makeContainer();
      final log = DiveLog(
        startPressureBar: 200,
        endPressureBar: 200,
        durationMin: 40,
        avgDepthM: 15,
        tankSize: '12L',
      );
      expect(c.read(sacProvider(log)), isNull);
    });
  });
}
