/// Unit conversion for dive form fields (D-UNITS).
///
/// Storage is metric-canonical: the DB always stores meters, bar, °C, kg,
/// etc. The selected display unit is a per-field preference (persisted via
/// SharedPreferences). [toMetric] converts an entered value to the storage
/// unit; [fromMetric] converts a stored metric value to the display unit.
///
/// Tank volume is the exception (D-TANK): it stores value + unit as entered,
/// so it is NOT routed through this converter.
class UnitConverter {
  const UnitConverter();

  /// Converts [value] (in [unit]) to the metric storage unit for [field].
  /// Returns the metric value, or null if [value] is null.
  double? toMetric(DiveField field, double? value, String unit) {
    if (value == null) return null;
    switch (field) {
      case DiveField.maxDepth:
      case DiveField.avgDepth:
      case DiveField.visibility:
        return unit == 'ft' ? value / 3.28084 : value;
      case DiveField.startPressure:
      case DiveField.endPressure:
        return unit == 'psi' ? value / 14.5038 : value;
      case DiveField.waterTemp:
        return unit == '°F' ? (value - 32) * 5 / 9 : value;
      case DiveField.weight:
        return unit == 'lbs' ? value / 2.20462 : value;
    }
  }

  /// Converts a metric [metricValue] to [unit] for display. Returns null if
  /// [metricValue] is null. Rounds to field-appropriate precision to minimize
  /// float-rounding artifacts on edit round-trips.
  double? fromMetric(DiveField field, double? metricValue, String unit) {
    if (metricValue == null) return null;
    double v;
    switch (field) {
      case DiveField.maxDepth:
      case DiveField.avgDepth:
      case DiveField.visibility:
        v = unit == 'ft' ? metricValue * 3.28084 : metricValue;
      case DiveField.startPressure:
      case DiveField.endPressure:
        v = unit == 'psi' ? metricValue * 14.5038 : metricValue;
      case DiveField.waterTemp:
        v = unit == '°F' ? metricValue * 9 / 5 + 32 : metricValue;
      case DiveField.weight:
        v = unit == 'lbs' ? metricValue * 2.20462 : metricValue;
    }
    return _round(field, v);
  }

  /// Display precision per field (minimizes float-rounding artifacts).
  double _round(DiveField field, double v) {
    switch (field) {
      case DiveField.maxDepth:
      case DiveField.avgDepth:
      case DiveField.visibility:
      case DiveField.waterTemp:
      case DiveField.weight:
        return double.parse(v.toStringAsFixed(1));
      case DiveField.startPressure:
      case DiveField.endPressure:
        return double.parse(v.toStringAsFixed(0));
    }
  }

  /// The unit options offered for [field].
  static List<String> unitOptions(DiveField field) {
    switch (field) {
      case DiveField.maxDepth:
      case DiveField.avgDepth:
      case DiveField.visibility:
        return ['m', 'ft'];
      case DiveField.startPressure:
      case DiveField.endPressure:
        return ['bar', 'psi'];
      case DiveField.waterTemp:
        return ['°C', '°F'];
      case DiveField.weight:
        return ['kg', 'lbs'];
    }
  }

  /// The default (metric) unit for [field].
  static String defaultUnit(DiveField field) {
    switch (field) {
      case DiveField.maxDepth:
      case DiveField.avgDepth:
      case DiveField.visibility:
        return 'm';
      case DiveField.startPressure:
      case DiveField.endPressure:
        return 'bar';
      case DiveField.waterTemp:
        return '°C';
      case DiveField.weight:
        return 'kg';
    }
  }
}

/// The unit-bearing fields on the dive form (excludes tank volume — stored
/// as-entered per D-TANK).
enum DiveField {
  maxDepth,
  avgDepth,
  startPressure,
  endPressure,
  waterTemp,
  weight,
  visibility,
}
