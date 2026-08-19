import 'package:deeplogger/models/dive_log.dart';
import 'package:deeplogger/models/sighting.dart';
import 'package:deeplogger/services/sac_calculator.dart';
import 'package:deeplogger/services/share_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final baseLog = DiveLog(
    id: 1,
    startTime: DateTime(2026, 3, 15, 10, 0),
    location: 'Great Barrier Reef',
    maxDepthM: 18.5,
    avgDepthM: 12.0,
    durationMin: 45,
    tankSize: '12L',
    startPressureBar: 200,
    endPressureBar: 60,
  );

  final baseSac = computeSac(
    startBar: 200,
    endBar: 60,
    durationMin: 45,
    avgDepthM: 12,
    tankSize: '12L',
  );

  group('ShareCard', () {
    // F5: the card has an intrinsic width of 1080px (Instagram-share canvas).
    // Pumping it bare in a default 800px viewport overflows. Wrap in
    // FittedBox — the same wrapper the production preview dialog uses — so
    // the card scales to the viewport while preserving its 1080 layout.
    Widget pumpCard(ShareCard card) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.topCenter,
            child: card,
          ),
        ),
      ),
    );

    testWidgets('renders with 0 photos and 0 sightings without overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        pumpCard(
          ShareCard(log: baseLog, photos: [], sightings: [], sac: baseSac),
        ),
      );

      expect(find.text('Great Barrier Reef'), findsOneWidget);
      expect(find.text('18.5m'), findsOneWidget);
      expect(find.text('45min'), findsOneWidget);
      expect(find.text('DeepLogger'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders with 5 sightings without overflow', (tester) async {
      final sightings = List.generate(
        5,
        (i) => Sighting(id: i, commonName: 'Species $i'),
      );

      await tester.pumpWidget(
        pumpCard(
          ShareCard(
            log: baseLog,
            photos: [],
            sightings: sightings,
            sac: baseSac,
          ),
        ),
      );

      expect(find.text('Marine Life'), findsOneWidget);
      for (var i = 0; i < 5; i++) {
        expect(find.text('Species $i'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders with SAC when tank volume unknown', (tester) async {
      final log = baseLog.copyWith(tankSize: '');
      final sac = computeSac(
        startBar: 200,
        endBar: 60,
        durationMin: 45,
        avgDepthM: 12,
        tankSize: '',
      );

      await tester.pumpWidget(
        pumpCard(ShareCard(log: log, photos: [], sightings: [], sac: sac)),
      );

      expect(find.textContaining('bar/min'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders with null SAC', (tester) async {
      final log = baseLog.copyWith(startPressureBar: null);

      await tester.pumpWidget(
        pumpCard(ShareCard(log: log, photos: [], sightings: [], sac: null)),
      );

      expect(find.text('Great Barrier Reef'), findsOneWidget);
      expect(find.byIcon(Icons.share), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows at most 5 species even with 10', (tester) async {
      final sightings = List.generate(
        10,
        (i) => Sighting(id: i, commonName: 'Species $i'),
      );

      await tester.pumpWidget(
        pumpCard(
          ShareCard(
            log: baseLog,
            photos: [],
            sightings: sightings,
            sac: baseSac,
          ),
        ),
      );

      for (var i = 0; i < 5; i++) {
        expect(find.text('Species $i'), findsOneWidget);
      }
      for (var i = 5; i < 10; i++) {
        expect(find.text('Species $i'), findsNothing);
      }
    });
  });

  // F5: stat chips used `Expanded` in a Row, which squished each chip to ~95px
  // in the narrow preview dialog and wrapped the value char-by-char. Now
  // chips are fixed-width SizedBoxes sized to the 1080 canvas; the Row
  // itself is unconstrained inside the canvas and the preview dialog uses a
  // FittedBox to scale the 1080-wide card to the viewport.
  group('ShareCard stat chips (F5 fixed-width)', () {
    testWidgets(
      'each stat chip is a fixed-width SizedBox (no Expanded, no wrap)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.topCenter,
                  child: ShareCard(
                    log: baseLog,
                    photos: [],
                    sightings: [],
                    sac: baseSac,
                  ),
                ),
              ),
            ),
          ),
        );

        // Every stat chip must be wrapped in a SizedBox of width 320.
        // (no Expanded remains in the stat-chip Row).
        final sizedBoxes = tester
            .widgetList<SizedBox>(
              find.byWidgetPredicate((w) => w is SizedBox && w.width == 320),
            )
            .toList();
        expect(
          sizedBoxes.length,
          greaterThanOrEqualTo(3),
          reason: 'expected at least 3 fixed-width stat chips',
        );

        // No RenderFlex overflow should fire even when the card is pumped
        // at narrow viewport constraints (the original bug).
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('renders without overflow at narrow viewport (F5)', (
      tester,
    ) async {
      // Simulate the narrow AlertDialog content area that exposed the bug.
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: FittedBox(
                fit: BoxFit.contain,
                child: ShareCard(
                  log: baseLog,
                  photos: [],
                  sightings: [],
                  sac: baseSac,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Great Barrier Reef'), findsOneWidget);
      expect(find.text('18.5m'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
