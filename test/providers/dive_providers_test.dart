import 'dart:io';

import 'package:deeplogger/database/database_helper.dart';
import 'package:deeplogger/database/migration_runner.dart';
import 'package:deeplogger/providers/dive_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
