/// A dive log entry (PRD §5.1).
///
/// SAC rate is never stored — it is computed dynamically via [computeSac].
class DiveLog {
  DiveLog({
    this.id,
    this.startTime,
    this.endTime,
    this.location,
    this.altitude,
    this.maxDepthM,
    this.avgDepthM,
    this.durationMin,
    this.gasType,
    this.gasOther,
    this.tankSize,
    this.tankVolumeValue,
    this.tankVolumeUnit,
    this.startPressureBar,
    this.endPressureBar,
    this.waterTempC,
    this.salinity,
    this.visibilityM,
    this.weightKg,
    this.notes,
    this.isDraft = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  final int? id;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? location;
  final String? altitude;
  final double? maxDepthM;
  final double? avgDepthM;
  final double? durationMin;
  final String? gasType;
  final String? gasOther;
  final String? tankSize;
  final double? tankVolumeValue;
  final String? tankVolumeUnit;
  final double? startPressureBar;
  final double? endPressureBar;
  final double? waterTempC;
  final String? salinity;
  final double? visibilityM;
  final double? weightKg;
  final String? notes;
  final bool isDraft;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Sentinel for [copyWith] so callers can explicitly set a nullable field
  /// to `null` (the default `field ?? this.field` pattern makes clearing
  /// impossible). Pass `null` to clear; omit the argument to keep the value.
  static const Object _unset = Object();

  DiveLog copyWith({
    int? id,
    Object? startTime = _unset,
    Object? endTime = _unset,
    Object? location = _unset,
    Object? altitude = _unset,
    Object? maxDepthM = _unset,
    Object? avgDepthM = _unset,
    Object? durationMin = _unset,
    Object? gasType = _unset,
    Object? gasOther = _unset,
    Object? tankSize = _unset,
    Object? tankVolumeValue = _unset,
    Object? tankVolumeUnit = _unset,
    Object? startPressureBar = _unset,
    Object? endPressureBar = _unset,
    Object? waterTempC = _unset,
    Object? salinity = _unset,
    Object? visibilityM = _unset,
    Object? weightKg = _unset,
    Object? notes = _unset,
    bool? isDraft,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DiveLog(
      id: id ?? this.id,
      startTime: startTime == _unset ? this.startTime : startTime as DateTime?,
      endTime: endTime == _unset ? this.endTime : endTime as DateTime?,
      location: location == _unset ? this.location : location as String?,
      altitude: altitude == _unset ? this.altitude : altitude as String?,
      maxDepthM: maxDepthM == _unset
          ? this.maxDepthM
          : (maxDepthM as num?)?.toDouble(),
      avgDepthM: avgDepthM == _unset
          ? this.avgDepthM
          : (avgDepthM as num?)?.toDouble(),
      durationMin: durationMin == _unset
          ? this.durationMin
          : (durationMin as num?)?.toDouble(),
      gasType: gasType == _unset ? this.gasType : gasType as String?,
      gasOther: gasOther == _unset ? this.gasOther : gasOther as String?,
      tankSize: tankSize == _unset ? this.tankSize : tankSize as String?,
      tankVolumeValue: tankVolumeValue == _unset
          ? this.tankVolumeValue
          : (tankVolumeValue as num?)?.toDouble(),
      tankVolumeUnit: tankVolumeUnit == _unset
          ? this.tankVolumeUnit
          : tankVolumeUnit as String?,
      startPressureBar: startPressureBar == _unset
          ? this.startPressureBar
          : (startPressureBar as num?)?.toDouble(),
      endPressureBar: endPressureBar == _unset
          ? this.endPressureBar
          : (endPressureBar as num?)?.toDouble(),
      waterTempC: waterTempC == _unset
          ? this.waterTempC
          : (waterTempC as num?)?.toDouble(),
      salinity: salinity == _unset ? this.salinity : salinity as String?,
      visibilityM: visibilityM == _unset
          ? this.visibilityM
          : (visibilityM as num?)?.toDouble(),
      weightKg: weightKg == _unset
          ? this.weightKg
          : (weightKg as num?)?.toDouble(),
      notes: notes == _unset ? this.notes : notes as String?,
      isDraft: isDraft ?? this.isDraft,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'start_time': startTime?.millisecondsSinceEpoch,
      'end_time': endTime?.millisecondsSinceEpoch,
      'location': location,
      'altitude': altitude,
      'max_depth_m': maxDepthM,
      'avg_depth_m': avgDepthM,
      'duration_min': durationMin,
      'gas_type': gasType,
      'gas_other': gasOther,
      'tank_size': tankSize,
      'tank_volume_value': tankVolumeValue,
      'tank_volume_unit': tankVolumeUnit,
      'start_pressure_bar': startPressureBar,
      'end_pressure_bar': endPressureBar,
      'water_temp_c': waterTempC,
      'salinity': salinity,
      'visibility_m': visibilityM,
      'weight_kg': weightKg,
      'notes': notes,
      'is_draft': isDraft ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory DiveLog.fromMap(Map<String, Object?> map) {
    return DiveLog(
      id: map['id'] as int?,
      startTime: map['start_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['start_time'] as int)
          : null,
      endTime: map['end_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['end_time'] as int)
          : null,
      location: map['location'] as String?,
      altitude: map['altitude'] as String?,
      maxDepthM: (map['max_depth_m'] as num?)?.toDouble(),
      avgDepthM: (map['avg_depth_m'] as num?)?.toDouble(),
      durationMin: (map['duration_min'] as num?)?.toDouble(),
      gasType: map['gas_type'] as String?,
      gasOther: map['gas_other'] as String?,
      tankSize: map['tank_size'] as String?,
      tankVolumeValue: (map['tank_volume_value'] as num?)?.toDouble(),
      tankVolumeUnit: map['tank_volume_unit'] as String?,
      startPressureBar: (map['start_pressure_bar'] as num?)?.toDouble(),
      endPressureBar: (map['end_pressure_bar'] as num?)?.toDouble(),
      waterTempC: (map['water_temp_c'] as num?)?.toDouble(),
      salinity: map['salinity'] as String?,
      visibilityM: (map['visibility_m'] as num?)?.toDouble(),
      weightKg: (map['weight_kg'] as num?)?.toDouble(),
      notes: map['notes'] as String?,
      isDraft: (map['is_draft'] as int?) == 1,
      createdAt: map['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int)
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int)
          : DateTime.now(),
    );
  }
}
