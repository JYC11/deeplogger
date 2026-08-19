import 'dart:io';

import 'package:deeplogger/database/database_helper.dart';
import 'package:deeplogger/database/migration_runner.dart';
import 'package:deeplogger/models/gear_item.dart';
import 'package:deeplogger/providers/certification_form_provider.dart';
import 'package:deeplogger/providers/dive_form_provider.dart';
import 'package:deeplogger/providers/dive_providers.dart';
import 'package:deeplogger/providers/gear_form_provider.dart';
import 'package:deeplogger/providers/sighting_form_provider.dart';
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

/// Regression tests for the 2026-08-19 QA feedback:
/// 1. Newly created gear must show up in the dive form's gear selector.
/// 2. Form state must be cleared when a form is closed and reopened.
///
/// Both are fixed by making the providers autoDispose so dropping the last
/// listener (form closed) resets state; reopening rebuilds fresh.
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

  /// Lets any scheduled autoDispose run.
  Future<void> pumpDisposal() => Future<void>.delayed(Duration.zero);

  group('B1: gearListProvider reflects newly created gear', () {
    test('re-queries after the last listener drops', () async {
      var sub = container.listen(gearListProvider, (_, _) {});
      expect(await container.read(gearListProvider.future), isEmpty);
      sub.close();
      await pumpDisposal();

      // User creates gear on the gear screen (form provider not listening).
      await db.insertGearItem(GearItem(name: 'Mask'));

      sub = container.listen(gearListProvider, (_, _) {});
      final items = await container.read(gearListProvider.future);
      expect(items.map((g) => g.name), contains('Mask'));
      sub.close();
    });
  });

  group('B2: forms reset when reopened', () {
    test('diveFormProvider(null) resets after listener drop', () async {
      var sub = container.listen(diveFormProvider(null), (_, _) {});
      await container.read(diveFormProvider(null).future);
      final notifier = container.read(diveFormProvider(null).notifier);
      notifier.setStartTime(DateTime(2026, 1, 1, 9));
      notifier.setLocation('Reef');
      sub.close();
      await pumpDisposal();

      sub = container.listen(diveFormProvider(null), (_, _) {});
      final fresh = await container.read(diveFormProvider(null).future);
      expect(fresh.location, isEmpty);
      expect(fresh.startTime, isNull);
      // Defaults must be re-applied.
      expect(fresh.altitude, 'Sea Level (0m)');
      expect(fresh.gasType, 'Air');
      sub.close();
    });

    test('gearFormProvider(null) resets after listener drop', () async {
      var sub = container.listen(gearFormProvider(null), (_, _) {});
      await container.read(gearFormProvider(null).future);
      container.read(gearFormProvider(null).notifier).setName('Mask');
      sub.close();
      await pumpDisposal();

      sub = container.listen(gearFormProvider(null), (_, _) {});
      final fresh = await container.read(gearFormProvider(null).future);
      expect(fresh.name, isEmpty);
      sub.close();
    });

    test(
      'certificationFormProvider(null) resets after listener drop',
      () async {
        var sub = container.listen(certificationFormProvider(null), (_, _) {});
        await container.read(certificationFormProvider(null).future);
        final notifier = container.read(
          certificationFormProvider(null).notifier,
        );
        notifier.setOrg('PADI');
        notifier.setLevel('Open Water');
        sub.close();
        await pumpDisposal();

        sub = container.listen(certificationFormProvider(null), (_, _) {});
        final fresh = await container.read(
          certificationFormProvider(null).future,
        );
        expect(fresh.org, isEmpty);
        expect(fresh.level, isEmpty);
        sub.close();
      },
    );

    test('sightingFormProvider(new) resets after listener drop', () async {
      const key = SightingFormKey(diveLogId: 1);
      var sub = container.listen(sightingFormProvider(key), (_, _) {});
      await container.read(sightingFormProvider(key).future);
      container
          .read(sightingFormProvider(key).notifier)
          .setCommonName('Clownfish');
      sub.close();
      await pumpDisposal();

      sub = container.listen(sightingFormProvider(key), (_, _) {});
      final fresh = await container.read(sightingFormProvider(key).future);
      expect(fresh.commonName, isEmpty);
      sub.close();
    });
  });
}
