import 'package:deeplogger/services/unit_converter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const c = UnitConverter();

  group('UnitConverter toMetric', () {
    test('depth ft -> m', () {
      expect(c.toMetric(DiveField.maxDepth, 59.055, 'ft'), closeTo(18.0, 0.01));
    });
    test('depth m stays m', () {
      expect(c.toMetric(DiveField.maxDepth, 18.0, 'm'), 18.0);
    });
    test('pressure psi -> bar', () {
      expect(
        c.toMetric(DiveField.startPressure, 2900.76, 'psi'),
        closeTo(200, 0.1),
      );
    });
    test('pressure bar stays bar', () {
      expect(c.toMetric(DiveField.startPressure, 200, 'bar'), 200);
    });
    test('temp F -> C', () {
      expect(c.toMetric(DiveField.waterTemp, 68, '°F'), closeTo(20, 0.01));
    });
    test('weight lbs -> kg', () {
      expect(c.toMetric(DiveField.weight, 11.02, 'lbs'), closeTo(5.0, 0.01));
    });
    test('null value -> null', () {
      expect(c.toMetric(DiveField.maxDepth, null, 'ft'), isNull);
    });
  });

  group('UnitConverter fromMetric', () {
    test('depth m -> ft', () {
      expect(c.fromMetric(DiveField.maxDepth, 18.0, 'ft'), closeTo(59.1, 0.1));
    });
    test('temp C -> F', () {
      expect(c.fromMetric(DiveField.waterTemp, 20, '°F'), closeTo(68.0, 0.01));
    });
    test('pressure bar -> psi', () {
      expect(
        c.fromMetric(DiveField.startPressure, 200, 'psi'),
        closeTo(2901, 1),
      );
    });
    test('round-trip depth m->ft->m within rounding', () {
      final ft = c.fromMetric(DiveField.maxDepth, 18.0, 'ft')!;
      final back = c.toMetric(DiveField.maxDepth, ft, 'ft');
      expect(back, closeTo(18.0, 0.05));
    });
    test('null metric -> null', () {
      expect(c.fromMetric(DiveField.maxDepth, null, 'ft'), isNull);
    });
  });

  group('unit options + defaults', () {
    test('depth options m/ft, default m', () {
      expect(UnitConverter.unitOptions(DiveField.maxDepth), ['m', 'ft']);
      expect(UnitConverter.defaultUnit(DiveField.maxDepth), 'm');
    });
    test('pressure options bar/psi, default bar', () {
      expect(UnitConverter.unitOptions(DiveField.startPressure), [
        'bar',
        'psi',
      ]);
      expect(UnitConverter.defaultUnit(DiveField.startPressure), 'bar');
    });
    test('temp options C/F, default C', () {
      expect(UnitConverter.unitOptions(DiveField.waterTemp), ['°C', '°F']);
      expect(UnitConverter.defaultUnit(DiveField.waterTemp), '°C');
    });
  });
}
