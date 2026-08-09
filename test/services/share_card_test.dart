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
    testWidgets('renders with 0 photos and 0 sightings without overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ShareCard(
                log: baseLog,
                photos: [],
                sightings: [],
                sac: baseSac,
              ),
            ),
          ),
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
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ShareCard(
                log: baseLog,
                photos: [],
                sightings: sightings,
                sac: baseSac,
              ),
            ),
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
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ShareCard(log: log, photos: [], sightings: [], sac: sac),
            ),
          ),
        ),
      );

      expect(find.textContaining('bar/min'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders with null SAC', (tester) async {
      final log = baseLog.copyWith(startPressureBar: null);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ShareCard(log: log, photos: [], sightings: [], sac: null),
            ),
          ),
        ),
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
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ShareCard(
                log: baseLog,
                photos: [],
                sightings: sightings,
                sac: baseSac,
              ),
            ),
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
}
