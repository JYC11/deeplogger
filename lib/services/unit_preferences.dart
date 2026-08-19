import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'unit_converter.dart';

/// Persists per-field display-unit preferences (D-UNITS) via SharedPreferences.
///
/// Storage is metric-canonical; these preferences only affect display. Tank
/// volume is excluded (stored as-entered per D-TANK).
class UnitPreferencesService {
  UnitPreferencesService._internal();
  static final UnitPreferencesService instance =
      UnitPreferencesService._internal();

  /// Prefix for all unit-preference SharedPreferences keys. Public so the
  /// backup service can snapshot/restore them (F7).
  static const String prefix = 'unit_pref_';

  /// Test seam: inject a [SharedPreferences] instance so host tests don't need
  /// the platform channel.
  @visibleForTesting
  SharedPreferences? overrideInstance;

  Future<SharedPreferences> _prefs() async =>
      overrideInstance ?? await SharedPreferences.getInstance();

  /// Loads all unit preferences, defaulting to the metric unit for each field.
  Future<Map<String, String>> load() async {
    final prefs = await _prefs();
    final result = <String, String>{};
    for (final field in DiveField.values) {
      final key = _prefKey(field);
      final stored = prefs.getString(key);
      result[_fieldKey(field)] = stored ?? UnitConverter.defaultUnit(field);
    }
    return result;
  }

  /// Saves the unit preference for [field].
  Future<void> set(DiveField field, String unit) async {
    final prefs = await _prefs();
    await prefs.setString(_prefKey(field), unit);
  }

  String _prefKey(DiveField field) => '$prefix${field.name}';

  String _fieldKey(DiveField field) {
    switch (field) {
      case DiveField.maxDepth:
        return 'max_depth_m';
      case DiveField.avgDepth:
        return 'avg_depth_m';
      case DiveField.startPressure:
        return 'start_pressure_bar';
      case DiveField.endPressure:
        return 'end_pressure_bar';
      case DiveField.waterTemp:
        return 'water_temp_c';
      case DiveField.weight:
        return 'weight_kg';
      case DiveField.visibility:
        return 'visibility_m';
    }
  }
}
