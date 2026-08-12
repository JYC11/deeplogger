import 'dart:io';

import 'package:deeplogger/database/database_helper.dart';
import 'package:deeplogger/database/migration_runner.dart';
import 'package:deeplogger/database/sort_fields.dart';
import 'package:deeplogger/models/certification.dart';
import 'package:deeplogger/models/dive_log.dart';
import 'package:deeplogger/models/gear_item.dart';
import 'package:deeplogger/providers/list_providers.dart';
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

  group('DiveListNotifier', () {
    test('initial build loads first page', () async {
      await seed(5);
      final state = await container.read(diveListNotifierProvider.future);
      expect(state.logs.length, 5);
      expect(state.page, 0);
      expect(state.hasMore, isFalse);
    });

    test('loadMore appends next page and updates hasMore', () async {
      await seed(45);
      final notifier = container.read(diveListNotifierProvider.notifier);
      await container.read(diveListNotifierProvider.future);
      expect(
        container.read(diveListNotifierProvider).requireValue.logs.length,
        20,
      );
      expect(
        container.read(diveListNotifierProvider).requireValue.hasMore,
        isTrue,
      );
      await notifier.loadMore();
      expect(
        container.read(diveListNotifierProvider).requireValue.logs.length,
        40,
      );
      expect(container.read(diveListNotifierProvider).requireValue.page, 1);
      await notifier.loadMore();
      expect(
        container.read(diveListNotifierProvider).requireValue.logs.length,
        45,
      );
      expect(
        container.read(diveListNotifierProvider).requireValue.hasMore,
        isFalse,
      );
    });

    test('setSearch resets to page 0 with filter', () async {
      await seed(10);
      final notifier = container.read(diveListNotifierProvider.notifier);
      await container.read(diveListNotifierProvider.future);
      await notifier.setSearch('Dive 3');
      final s = container.read(diveListNotifierProvider).requireValue;
      expect(s.page, 0);
      expect(s.search, 'Dive 3');
      // Matches "Dive 3" prefix: Dive 3, Dive 30-39 (if seeded more) — here 10
      // items so Dive 3 only.
      expect(s.logs.length, 1);
      expect(s.logs.first.location, 'Dive 3');
    });

    test('setSort resets to page 0 with new sort', () async {
      await seed(5);
      final notifier = container.read(diveListNotifierProvider.notifier);
      await container.read(diveListNotifierProvider.future);
      await notifier.setSort(DiveLogSortField.maxDepthM, false);
      final s = container.read(diveListNotifierProvider).requireValue;
      expect(s.sortField, DiveLogSortField.maxDepthM);
      expect(s.sortDesc, isFalse);
      expect(s.page, 0);
      // Ascending by maxDepthM: Dive 0 (1.0), Dive 1 (2.0), ...
      expect(s.logs.first.maxDepthM, 1.0);
    });

    test('refresh reloads keeping search/sort state', () async {
      await seed(5);
      final notifier = container.read(diveListNotifierProvider.notifier);
      await container.read(diveListNotifierProvider.future);
      await notifier.setSort(DiveLogSortField.maxDepthM, false);
      // Add a new dive that should appear after refresh.
      await db.insertDiveLog(
        DiveLog(
          startTime: DateTime(2026, 1, 2),
          location: 'New',
          maxDepthM: 0.5,
        ),
      );
      await notifier.refresh();
      final s = container.read(diveListNotifierProvider).requireValue;
      expect(s.sortField, DiveLogSortField.maxDepthM);
      expect(s.sortDesc, isFalse);
      expect(s.logs.length, 6);
      // New dive has smallest maxDepth -> first in ascending order.
      expect(s.logs.first.location, 'New');
    });

    test('loadMore is a no-op when hasMore is false', () async {
      await seed(3);
      final notifier = container.read(diveListNotifierProvider.notifier);
      await container.read(diveListNotifierProvider.future);
      await notifier.loadMore();
      expect(
        container.read(diveListNotifierProvider).requireValue.logs.length,
        3,
      );
      expect(container.read(diveListNotifierProvider).requireValue.page, 0);
    });
  });

  group('GearListNotifier', () {
    test('initial build + category filter', () async {
      await db.insertGearItem(GearItem(name: 'BCD1', category: 'BCD'));
      await db.insertGearItem(GearItem(name: 'Fin1', category: 'Fins'));
      final notifier = container.read(gearListNotifierProvider.notifier);
      await container.read(gearListNotifierProvider.future);
      expect(
        container.read(gearListNotifierProvider).requireValue.items.length,
        2,
      );
      await notifier.setCategoryFilter('BCD');
      expect(
        container.read(gearListNotifierProvider).requireValue.items.length,
        1,
      );
      expect(
        container.read(gearListNotifierProvider).requireValue.items.first.name,
        'BCD1',
      );
    });
  });

  group('CertificationListNotifier', () {
    test('initial build + search', () async {
      await db.insertCertification(Certification(org: 'PADI', level: 'OW'));
      await db.insertCertification(Certification(org: 'SSI', level: 'AOW'));
      final notifier = container.read(
        certificationListNotifierProvider.notifier,
      );
      await container.read(certificationListNotifierProvider.future);
      expect(
        container
            .read(certificationListNotifierProvider)
            .requireValue
            .certs
            .length,
        2,
      );
      await notifier.setSearch('ssi');
      expect(
        container
            .read(certificationListNotifierProvider)
            .requireValue
            .certs
            .length,
        1,
      );
    });
  });
}
