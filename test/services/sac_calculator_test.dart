import 'package:divelogger/services/sac_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SacCalculator', () {
    group('computeSac', () {
      test('metric dive with 12L tank', () {
        // P_rate = (200-50) / (40 * ((15/10)+1)) = 150 / 100 = 1.5 bar/min
        // SAC  = 1.5 * 12 = 18 L/min
        final r = computeSac(
          startBar: 200,
          endBar: 50,
          durationMin: 40,
          avgDepthM: 15,
          tankSize: '12L',
        );
        expect(r, isNotNull);
        expect(r!.barPerMin, closeTo(1.5, 0.001));
        expect(r.tankVolumeL, closeTo(12.0, 0.001));
        expect(r.litersPerMin, closeTo(18.0, 0.001));
        expect(r.psiPerMin, closeTo(1.5 * 14.5038, 0.01));
        expect(r.cubicFtPerMin, closeTo(18.0 * 0.0353147, 0.001));
      });

      test('imperial tank 80 cu ft converts to liters', () {
        // tankVolumeL = 80 * 28.3168 / 207 = 10.944...
        // same dive: P_rate = 1.5 bar/min
        // SAC = 1.5 * 10.944 = 16.416 L/min
        final r = computeSac(
          startBar: 200,
          endBar: 50,
          durationMin: 40,
          avgDepthM: 15,
          tankSize: '80 cu ft',
        );
        expect(r, isNotNull);
        expect(r!.tankVolumeL, closeTo(80 * 28.3168 / 207, 0.01));
        expect(r.barPerMin, closeTo(1.5, 0.001));
        expect(r.litersPerMin, closeTo(1.5 * (80 * 28.3168 / 207), 0.01));
        expect(r.cubicFtPerMin, closeTo(r.litersPerMin! * 0.0353147, 0.001));
      });

      test('shallow dive with surface-level depth (0m)', () {
        // P_rate = (200-180) / (30 * ((0/10)+1)) = 20 / 30 = 0.6667 bar/min
        final r = computeSac(
          startBar: 200,
          endBar: 180,
          durationMin: 30,
          avgDepthM: 0,
          tankSize: '12L',
        );
        expect(r, isNotNull);
        expect(r!.barPerMin, closeTo(0.6667, 0.001));
        expect(r.litersPerMin, closeTo(0.6667 * 12, 0.01));
      });

      test('unknown tank size -> bar/min only, no L/min', () {
        final r = computeSac(
          startBar: 200,
          endBar: 50,
          durationMin: 40,
          avgDepthM: 15,
          tankSize: '',
        );
        expect(r, isNotNull);
        expect(r!.barPerMin, closeTo(1.5, 0.001));
        expect(r.tankVolumeL, isNull);
        expect(r.litersPerMin, isNull);
        expect(r.cubicFtPerMin, isNull);
        expect(r.psiPerMin, isNotNull);
      });

      test('unparseable tank size -> bar/min only', () {
        // P_rate = (200-100) / (50 * ((20/10)+1)) = 100 / 150 = 0.6667
        final r = computeSac(
          startBar: 200,
          endBar: 100,
          durationMin: 50,
          avgDepthM: 20,
          tankSize: 'unknown',
        );
        expect(r, isNotNull);
        expect(r!.barPerMin, closeTo(0.6667, 0.001));
        expect(r.tankVolumeL, isNull);
        expect(r.litersPerMin, isNull);
      });
    });

    group('guard rails', () {
      test('duration <= 0 returns null', () {
        expect(
          computeSac(
            startBar: 200,
            endBar: 50,
            durationMin: 0,
            avgDepthM: 15,
            tankSize: '12L',
          ),
          isNull,
        );
        expect(
          computeSac(
            startBar: 200,
            endBar: 50,
            durationMin: -5,
            avgDepthM: 15,
            tankSize: '12L',
          ),
          isNull,
        );
      });

      test('end pressure >= start pressure returns null', () {
        expect(
          computeSac(
            startBar: 200,
            endBar: 200,
            durationMin: 40,
            avgDepthM: 15,
            tankSize: '12L',
          ),
          isNull,
        );
        expect(
          computeSac(
            startBar: 200,
            endBar: 250,
            durationMin: 40,
            avgDepthM: 15,
            tankSize: '12L',
          ),
          isNull,
        );
      });
    });

    group('tank size parsing', () {
      test('12L variations parse to 12.0', () {
        for (final s in ['12L', '12 L', '12l', '12 l', ' 12L ']) {
          final r = computeSac(
            startBar: 200,
            endBar: 100,
            durationMin: 40,
            avgDepthM: 10,
            tankSize: s,
          );
          expect(r, isNotNull, reason: 'failed for "$s"');
          expect(
            r!.tankVolumeL,
            closeTo(12.0, 0.001),
            reason: 'failed for "$s"',
          );
        }
      });

      test('cubic feet variations parse correctly', () {
        for (final s in ['80 cu ft', '80cuft', '80 cuft', '80 Cu Ft']) {
          final r = computeSac(
            startBar: 200,
            endBar: 100,
            durationMin: 40,
            avgDepthM: 10,
            tankSize: s,
          );
          expect(r, isNotNull, reason: 'failed for "$s"');
          expect(
            r!.tankVolumeL,
            closeTo(80 * 28.3168 / 207, 0.01),
            reason: 'failed for "$s"',
          );
        }
      });

      test('decimal liter sizes parse', () {
        final r = computeSac(
          startBar: 200,
          endBar: 100,
          durationMin: 40,
          avgDepthM: 10,
          tankSize: '10.5L',
        );
        expect(r, isNotNull);
        expect(r!.tankVolumeL, closeTo(10.5, 0.001));
      });

      test('empty/null/nonsense return null volume', () {
        for (final s in ['', '  ', 'foobar', 'L', 'cu ft']) {
          final r = computeSac(
            startBar: 200,
            endBar: 100,
            durationMin: 40,
            avgDepthM: 10,
            tankSize: s,
          );
          expect(r, isNotNull, reason: 'should still return bar/min for "$s"');
          expect(r!.tankVolumeL, isNull, reason: 'failed for "$s"');
        }
      });
    });
  });
}
