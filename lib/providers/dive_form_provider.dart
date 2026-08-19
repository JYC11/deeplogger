import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_helper.dart';
import '../models/dive_log.dart';
import '../models/gear_ref.dart';
import '../services/unit_converter.dart';
import '../services/unit_preferences.dart';
import 'dive_providers.dart';

/// Per-field unit selection (D-UNITS). Storage is metric-canonical; the
/// selected unit is a display preference only. Defaults to metric.
typedef UnitPreferences = Map<String, String>;

/// Default unit per field (metric).
const Map<String, String> kDefaultUnitPreferences = {
  'max_depth_m': 'm',
  'avg_depth_m': 'm',
  'start_pressure_bar': 'bar',
  'end_pressure_bar': 'bar',
  'water_temp_c': '°C',
  'weight_kg': 'kg',
  'visibility_m': 'm',
  'tank_volume_value': 'L',
};

/// Validation errors keyed by field name (D3). Empty map = no errors.
typedef ValidationErrors = Map<String, String>;

/// Mutable form state for the dive add/edit form.
class DiveFormState {
  const DiveFormState({
    this.existingId,
    this.startTime,
    this.location = '',
    this.altitude = '',
    this.maxDepthM,
    this.avgDepthM,
    this.durationMin,
    this.gasType,
    this.gasOther = '',
    this.tankSize = '',
    this.tankVolumeValue,
    this.tankVolumeUnit = 'L',
    this.startPressureBar,
    this.endPressureBar,
    this.waterTempC,
    this.salinity,
    this.visibilityM,
    this.weightKg,
    this.notes = '',
    this.selectedGearIds = const {},
    this.adHocGear = const [],
    this.unitPreferences = kDefaultUnitPreferences,
    this.validationErrors = const {},
    this.isSaving = false,
    this.saveError,
  });

  final int? existingId;
  final DateTime? startTime;
  final String location;
  final String altitude;
  final double? maxDepthM;
  final double? avgDepthM;
  final double? durationMin;
  final String? gasType;
  final String gasOther;
  final String tankSize;
  final double? tankVolumeValue;
  final String tankVolumeUnit;
  final double? startPressureBar;
  final double? endPressureBar;
  final double? waterTempC;
  final String? salinity;
  final double? visibilityM;
  final double? weightKg;
  final String notes;
  final Set<int> selectedGearIds;
  final List<String> adHocGear;
  final UnitPreferences unitPreferences;
  final ValidationErrors validationErrors;
  final bool isSaving;
  final String? saveError;

  bool get isEditing => existingId != null;

  DiveFormState copyWith({
    int? existingId,
    DateTime? startTime,
    String? location,
    String? altitude,
    double? maxDepthM,
    double? avgDepthM,
    double? durationMin,
    String? gasType,
    String? gasOther,
    String? tankSize,
    double? tankVolumeValue,
    String? tankVolumeUnit,
    double? startPressureBar,
    double? endPressureBar,
    double? waterTempC,
    String? salinity,
    double? visibilityM,
    double? weightKg,
    String? notes,
    Set<int>? selectedGearIds,
    List<String>? adHocGear,
    UnitPreferences? unitPreferences,
    ValidationErrors? validationErrors,
    bool? isSaving,
    String? saveError,
  }) {
    return DiveFormState(
      existingId: existingId ?? this.existingId,
      startTime: startTime ?? this.startTime,
      location: location ?? this.location,
      altitude: altitude ?? this.altitude,
      maxDepthM: maxDepthM ?? this.maxDepthM,
      avgDepthM: avgDepthM ?? this.avgDepthM,
      durationMin: durationMin ?? this.durationMin,
      gasType: gasType ?? this.gasType,
      gasOther: gasOther ?? this.gasOther,
      tankSize: tankSize ?? this.tankSize,
      tankVolumeValue: tankVolumeValue ?? this.tankVolumeValue,
      tankVolumeUnit: tankVolumeUnit ?? this.tankVolumeUnit,
      startPressureBar: startPressureBar ?? this.startPressureBar,
      endPressureBar: endPressureBar ?? this.endPressureBar,
      waterTempC: waterTempC ?? this.waterTempC,
      salinity: salinity ?? this.salinity,
      visibilityM: visibilityM ?? this.visibilityM,
      weightKg: weightKg ?? this.weightKg,
      notes: notes ?? this.notes,
      selectedGearIds: selectedGearIds ?? this.selectedGearIds,
      adHocGear: adHocGear ?? this.adHocGear,
      unitPreferences: unitPreferences ?? this.unitPreferences,
      validationErrors: validationErrors ?? this.validationErrors,
      isSaving: isSaving ?? this.isSaving,
      saveError: saveError ?? this.saveError,
    );
  }
}

/// Family notifier: constructor receives the existing dive log id, or `null`
/// for a new dive. [build] loads the existing log + gear (fixes the edit-gear
/// data-loss bug where the old form never preloaded gear).
class DiveFormNotifier extends AsyncNotifier<DiveFormState> {
  DiveFormNotifier(this.id);

  final int? id;

  DatabaseHelper get _db => ref.read(databaseProvider);

  @override
  Future<DiveFormState> build() async {
    // Load per-field unit display preferences (D-UNITS).
    final unitPrefs = await UnitPreferencesService.instance.load();
    if (id == null) {
      // D4: defaults for new dives — altitude + gas type.
      return DiveFormState(
        altitude: 'Sea Level (0m)',
        gasType: 'Air',
        unitPreferences: unitPrefs,
      );
    }
    final detail = await _db.getDiveDetail(id!);
    if (detail == null) {
      return DiveFormState(unitPreferences: unitPrefs);
    }
    final log = detail.log;
    final selectedGearIds = <int>{};
    final adHocGear = <String>[];
    for (final g in detail.gear) {
      switch (g) {
        case GearRefItem(:final item):
          if (item.id != null) selectedGearIds.add(item.id!);
        case GearRefAdHoc(:final text):
          adHocGear.add(text);
      }
    }
    return DiveFormState(
      existingId: id,
      startTime: log.startTime,
      location: log.location ?? '',
      altitude: log.altitude ?? '',
      maxDepthM: log.maxDepthM,
      avgDepthM: log.avgDepthM,
      durationMin: log.durationMin,
      gasType: log.gasType,
      gasOther: log.gasOther ?? '',
      tankSize: log.tankSize ?? '',
      tankVolumeValue: log.tankVolumeValue,
      tankVolumeUnit: log.tankVolumeUnit ?? 'L',
      startPressureBar: log.startPressureBar,
      endPressureBar: log.endPressureBar,
      waterTempC: log.waterTempC,
      salinity: log.salinity,
      visibilityM: log.visibilityM,
      weightKg: log.weightKg,
      notes: log.notes ?? '',
      selectedGearIds: selectedGearIds,
      adHocGear: adHocGear,
      unitPreferences: unitPrefs,
    );
  }

  // --- Typed field setters ---

  void _clearError(String key) {
    if (state.value!.validationErrors.containsKey(key)) {
      final errors = Map<String, String>.from(state.value!.validationErrors)
        ..remove(key);
      _update(s: state.value!.copyWith(validationErrors: errors));
    }
  }

  void setStartTime(DateTime? v) {
    _update(s: state.value!.copyWith(startTime: v));
    _clearError('startTime');
  }

  void setLocation(String v) {
    _update(s: state.value!.copyWith(location: v));
    _clearError('location');
  }

  void setAltitude(String v) => _update(s: state.value!.copyWith(altitude: v));
  void setMaxDepth(double? v) =>
      _update(s: state.value!.copyWith(maxDepthM: v));
  void setAvgDepth(double? v) =>
      _update(s: state.value!.copyWith(avgDepthM: v));
  void setDuration(double? v) =>
      _update(s: state.value!.copyWith(durationMin: v));
  void setGasType(String? v) => _update(s: state.value!.copyWith(gasType: v));
  void setGasOther(String v) => _update(s: state.value!.copyWith(gasOther: v));
  void setTankSize(String v) => _update(s: state.value!.copyWith(tankSize: v));
  void setTankVolumeValue(double? v) =>
      _update(s: state.value!.copyWith(tankVolumeValue: v));
  void setTankVolumeUnit(String v) =>
      _update(s: state.value!.copyWith(tankVolumeUnit: v));
  void setStartPressure(double? v) =>
      _update(s: state.value!.copyWith(startPressureBar: v));
  void setEndPressure(double? v) =>
      _update(s: state.value!.copyWith(endPressureBar: v));
  void setWaterTemp(double? v) =>
      _update(s: state.value!.copyWith(waterTempC: v));
  void setSalinity(String? v) => _update(s: state.value!.copyWith(salinity: v));
  void setVisibility(double? v) =>
      _update(s: state.value!.copyWith(visibilityM: v));
  void setWeight(double? v) => _update(s: state.value!.copyWith(weightKg: v));
  void setNotes(String v) => _update(s: state.value!.copyWith(notes: v));
  void setUnitPreference(String field, String unit) {
    final prefs = Map<String, String>.from(state.value!.unitPreferences);
    prefs[field] = unit;
    _update(s: state.value!.copyWith(unitPreferences: prefs));
    // Persist the display preference (D-UNITS). Best-effort: don't block the UI.
    final diveField = _diveFieldForColumn(field);
    if (diveField != null) {
      UnitPreferencesService.instance.set(diveField, unit);
    }
  }

  DiveField? _diveFieldForColumn(String column) {
    switch (column) {
      case 'max_depth_m':
        return DiveField.maxDepth;
      case 'avg_depth_m':
        return DiveField.avgDepth;
      case 'start_pressure_bar':
        return DiveField.startPressure;
      case 'end_pressure_bar':
        return DiveField.endPressure;
      case 'water_temp_c':
        return DiveField.waterTemp;
      case 'weight_kg':
        return DiveField.weight;
      case 'visibility_m':
        return DiveField.visibility;
      default:
        return null;
    }
  }

  // --- Gear ---

  void toggleGear(int itemId) {
    final ids = Set<int>.from(state.value!.selectedGearIds);
    if (ids.contains(itemId)) {
      ids.remove(itemId);
    } else {
      ids.add(itemId);
    }
    _update(s: state.value!.copyWith(selectedGearIds: ids));
  }

  void addAdHocGear(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final list = List<String>.from(state.value!.adHocGear)..add(trimmed);
    _update(s: state.value!.copyWith(adHocGear: list));
  }

  void removeAdHocGear(String text) {
    final list = List<String>.from(state.value!.adHocGear)..remove(text);
    _update(s: state.value!.copyWith(adHocGear: list));
  }

  // --- Save ---

  /// Validates the form (D3 rules), returns true if valid. On success,
  /// persists the log + gear and returns true; on failure sets validation
  /// errors (or saveError) and returns false.
  Future<bool> save() async {
    final s = state.value!;
    final errors = _validate(s);
    if (errors.isNotEmpty) {
      _update(s: s.copyWith(validationErrors: errors));
      return false;
    }
    _update(
      s: s.copyWith(
        isSaving: true,
        saveError: null,
        validationErrors: const {},
      ),
    );
    try {
      final log = DiveLog(
        id: s.existingId,
        startTime: s.startTime,
        location: s.location.isEmpty ? null : s.location,
        altitude: s.altitude.isEmpty ? null : s.altitude,
        maxDepthM: s.maxDepthM,
        avgDepthM: s.avgDepthM,
        durationMin: s.durationMin,
        gasType: s.gasType,
        gasOther: s.gasType == 'Other' ? s.gasOther : null,
        tankSize: s.tankSize.isEmpty ? null : s.tankSize,
        tankVolumeValue: s.tankVolumeValue,
        tankVolumeUnit: s.tankVolumeValue == null ? null : s.tankVolumeUnit,
        startPressureBar: s.startPressureBar,
        endPressureBar: s.endPressureBar,
        waterTempC: s.waterTempC,
        salinity: s.salinity,
        visibilityM: s.visibilityM,
        weightKg: s.weightKg,
        notes: s.notes.isEmpty ? null : s.notes,
        isDraft: false,
        updatedAt: DateTime.now(),
      );
      final db = _db;
      int logId;
      if (log.id != null) {
        await db.updateDiveLog(log);
        logId = log.id!;
      } else {
        logId = await db.insertDiveLog(log);
      }
      await db.setGearEntriesForDive(
        logId,
        gearItemIds: s.selectedGearIds.toList(),
        adHocGearTexts: s.adHocGear,
      );
      _update(s: state.value!.copyWith(isSaving: false, existingId: logId));
      return true;
    } catch (e) {
      _update(
        s: state.value!.copyWith(isSaving: false, saveError: e.toString()),
      );
      return false;
    }
  }

  ValidationErrors _validate(DiveFormState s) {
    final errors = <String, String>{};
    if (s.startTime == null) {
      errors['startTime'] = 'Start time is required';
    }
    if (s.location.trim().isEmpty) {
      errors['location'] = 'Location is required';
    }
    if (s.gasType == 'Other' && s.gasOther.trim().isEmpty) {
      errors['gasOther'] = 'Required when gas is Other';
    }
    // Numeric range guards (D3). Empty optional fields are allowed.
    if (s.maxDepthM != null && (s.maxDepthM! <= 0 || s.maxDepthM! > 300)) {
      errors['maxDepthM'] = 'Must be > 0 and ≤ 300';
    }
    if (s.avgDepthM != null) {
      if (s.avgDepthM! <= 0 || s.avgDepthM! > 300) {
        errors['avgDepthM'] = 'Must be > 0 and ≤ 300';
      } else if (s.maxDepthM != null && s.avgDepthM! > s.maxDepthM!) {
        errors['avgDepthM'] = 'Must be ≤ max depth';
      }
    }
    if (s.durationMin != null &&
        (s.durationMin! <= 0 || s.durationMin! > 600)) {
      errors['durationMin'] = 'Must be > 0 and ≤ 600';
    }
    if (s.startPressureBar != null &&
        (s.startPressureBar! <= 0 || s.startPressureBar! > 400)) {
      errors['startPressureBar'] = 'Must be > 0 and ≤ 400';
    }
    if (s.endPressureBar != null) {
      if (s.endPressureBar! < 0) {
        errors['endPressureBar'] = 'Must be ≥ 0';
      } else if (s.startPressureBar != null &&
          s.endPressureBar! >= s.startPressureBar!) {
        errors['endPressureBar'] = 'Must be < start pressure';
      }
    }
    if (s.waterTempC != null && (s.waterTempC! < -5 || s.waterTempC! > 40)) {
      errors['waterTempC'] = 'Must be between -5 and 40';
    }
    if (s.weightKg != null && (s.weightKg! < 0 || s.weightKg! > 50)) {
      errors['weightKg'] = 'Must be ≥ 0 and ≤ 50';
    }
    if (s.visibilityM != null && (s.visibilityM! < 0 || s.visibilityM! > 100)) {
      errors['visibilityM'] = 'Must be ≥ 0 and ≤ 100';
    }
    if (s.tankVolumeValue != null && s.tankVolumeValue! <= 0) {
      errors['tankVolumeValue'] = 'Must be > 0';
    }
    return errors;
  }

  void _update({required DiveFormState s}) {
    state = AsyncData(s);
  }
}

// AutoDispose: closing the form drops the last listener, so reopening a form
// always starts from a fresh build (no stale field values).
final diveFormProvider =
    AsyncNotifierProvider.family<DiveFormNotifier, DiveFormState, int?>(
      DiveFormNotifier.new,
      isAutoDispose: true,
    );
