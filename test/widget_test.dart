import 'package:deeplogger/database/sort_fields.dart';
import 'package:deeplogger/main.dart';
import 'package:deeplogger/models/dive_log.dart';
import 'package:deeplogger/providers/list_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('app shows empty state when no dives', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diveListNotifierProvider.overrideWith(() => _StubListNotifier([])),
        ],
        child: const DeepLoggerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DeepLogger'), findsOneWidget);
    expect(find.text('No dives yet'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('list shows dives sorted by date desc', (tester) async {
    final logs = [
      DiveLog(
        id: 2,
        startTime: DateTime(2026, 3, 10),
        location: 'March Wreck',
        maxDepthM: 30.0,
        durationMin: 55,
      ),
      DiveLog(
        id: 1,
        startTime: DateTime(2026, 1, 15),
        location: 'January Reef',
        maxDepthM: 18.0,
        durationMin: 45,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diveListNotifierProvider.overrideWith(() => _StubListNotifier(logs)),
        ],
        child: const DeepLoggerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('March Wreck'), findsOneWidget);
    expect(find.text('January Reef'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('March Wreck')).dy,
      lessThan(tester.getTopLeft(find.text('January Reef')).dy),
    );
  });

  testWidgets('draft dives show draft icon', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diveListNotifierProvider.overrideWith(
            () => _StubListNotifier([
              DiveLog(
                id: 1,
                startTime: DateTime(2026, 2, 1),
                location: 'Draft Dive',
                isDraft: true,
              ),
            ]),
          ),
        ],
        child: const DeepLoggerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Draft Dive'), findsOneWidget);
    expect(find.byIcon(Icons.edit_note), findsOneWidget);
  });

  testWidgets('tapping add navigates to form', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diveListNotifierProvider.overrideWith(() => _StubListNotifier([])),
        ],
        child: const DeepLoggerApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('New Dive'), findsOneWidget);
    expect(find.text('Basic'), findsOneWidget);
  });
}

/// Stub notifier returning a fixed list as the initial state (no pagination,
/// no DB) — for widget tests.
class _StubListNotifier extends DiveListNotifier {
  _StubListNotifier(this._logs);

  final List<DiveLog> _logs;

  @override
  Future<DiveListState> build() async {
    return DiveListState(logs: _logs, hasMore: false);
  }

  @override
  Future<void> loadMore() async {}

  @override
  Future<void> setSearch(String? query) async {}

  @override
  Future<void> setSort(DiveLogSortField field, bool desc) async {}

  @override
  Future<void> refresh() async {}
}
