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

  DiveLog copyWith({
    int? id,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    String? altitude,
    double? maxDepthM,
    double? avgDepthM,
    double? durationMin,
    String? gasType,
    String? gasOther,
    String? tankSize,
    double? startPressureBar,
    double? endPressureBar,
    double? waterTempC,
    String? salinity,
    double? visibilityM,
    double? weightKg,
    String? notes,
    bool? isDraft,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DiveLog(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      altitude: altitude ?? this.altitude,
      maxDepthM: maxDepthM ?? this.maxDepthM,
      avgDepthM: avgDepthM ?? this.avgDepthM,
      durationMin: durationMin ?? this.durationMin,
      gasType: gasType ?? this.gasType,
      gasOther: gasOther ?? this.gasOther,
      tankSize: tankSize ?? this.tankSize,
      startPressureBar: startPressureBar ?? this.startPressureBar,
      endPressureBar: endPressureBar ?? this.endPressureBar,
      waterTempC: waterTempC ?? this.waterTempC,
      salinity: salinity ?? this.salinity,
      visibilityM: visibilityM ?? this.visibilityM,
      weightKg: weightKg ?? this.weightKg,
      notes: notes ?? this.notes,
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
