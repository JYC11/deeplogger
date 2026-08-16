import 'package:deeplogger/models/dive_log.dart';
import 'package:deeplogger/models/dive_photo.dart';
import 'package:deeplogger/models/gear_ref.dart';
import 'package:deeplogger/models/sighting.dart';
import 'package:deeplogger/providers/dive_providers.dart';
import 'package:deeplogger/screens/dive_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

DiveLog _fullSacLog() => DiveLog(
  id: 1,
  startTime: DateTime(2026, 1, 1, 9),
  location: 'Test Reef',
  maxDepthM: 30.0,
  avgDepthM: 18.0,
  durationMin: 45,
  startPressureBar: 200,
  endPressureBar: 80,
  tankVolumeValue: 12.0,
  tankVolumeUnit: 'L',
);

ProviderContainer _container(DiveLog log) {
  return ProviderContainer(
    overrides: [
      diveDetailProvider.overrideWith((ref, id) async => log),
      diveGearEntriesProvider.overrideWith((ref, id) async => <GearRef>[]),
      divePhotosProvider.overrideWith((ref, id) async => <DivePhoto>[]),
      sightingsProvider.overrideWith((ref, id) async => <Sighting>[]),
    ],
  );
}

Future<void> _pumpDetail(WidgetTester tester, DiveLog log) async {
  final container = _container(log);
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: DiveDetailScreen(diveId: 1)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'full SAC shows L/min primary; imperial only in expanded details',
    (tester) async {
      await _pumpDetail(tester, _fullSacLog());

      // Primary block: L/min visible, imperial conversions NOT.
      expect(find.text('L/min'), findsOneWidget);
      expect(find.text('bar/min'), findsNothing);
      expect(find.text('psi/min'), findsNothing);
      expect(find.text('cu ft/min'), findsNothing);

      // Expand the Details tile: imperial conversions appear.
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();
      expect(find.text('bar/min'), findsOneWidget);
      expect(find.text('psi/min'), findsOneWidget);
      expect(find.text('cu ft/min'), findsOneWidget);
    },
  );

  testWidgets(
    'unknown tank volume shows bar/min-only note in expanded details',
    (tester) async {
      await _pumpDetail(
        tester,
        _fullSacLog().copyWith(tankVolumeValue: null, tankVolumeUnit: null),
      );

      // No L/min primary stat; bar/min-only note hidden until expanded.
      expect(find.text('L/min'), findsNothing);
      expect(
        find.text('Tank volume unknown — showing bar/min only'),
        findsNothing,
      );

      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();
      expect(find.text('bar/min'), findsOneWidget);
      expect(
        find.text('Tank volume unknown — showing bar/min only'),
        findsOneWidget,
      );
    },
  );
}
