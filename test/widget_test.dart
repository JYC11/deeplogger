import 'package:deeplogger/main.dart';
import 'package:deeplogger/models/dive_log.dart';
import 'package:deeplogger/providers/dive_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app shows empty state when no dives', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [diveListProvider.overrideWith((ref) async => [])],
        child: const DeepLoggerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DeepLogger'), findsOneWidget);
    expect(find.text('No dives yet'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('list shows dives sorted by date desc', (tester) async {
    // DB returns sorted by start_time DESC; test data mirrors that.
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
        overrides: [diveListProvider.overrideWith((ref) async => logs)],
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
          diveListProvider.overrideWith(
            (ref) async => [
              DiveLog(
                id: 1,
                startTime: DateTime(2026, 2, 1),
                location: 'Draft Dive',
                isDraft: true,
              ),
            ],
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
        overrides: [diveListProvider.overrideWith((ref) async => [])],
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
