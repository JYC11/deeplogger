import 'package:divelogger/database/database_helper.dart';
import 'package:divelogger/providers/dive_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final db = DatabaseHelper.instance;
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
