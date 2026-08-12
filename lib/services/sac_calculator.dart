/// SAC (Surface Air Consumption) rate calculator.
///
/// Implements the industry-standard RMV formula per PRD §5.2:
///   P_rate = (Start - End) / (Duration × ((AvgDepth / 10) + 1))  → bar/min
///   SAC    = P_rate × TankVolumeL                                → L/min
///
/// Tank volume is parsed from the free-text Tank Size field:
///   "12L"      → 12.0 L
///   "80 cu ft" → 80 × 28.3168 / 207 ≈ 10.9 L  (207 bar service pressure)
///
/// Guards: Duration ≤ 0 or End ≥ Start → returns null (no SAC).
/// Unknown tank volume → returns [SacResult] with bar/min only.
class SacResult {
  const SacResult({
    required this.barPerMin,
    this.tankVolumeL,
    this.litersPerMin,
    this.psiPerMin,
    this.cubicFtPerMin,
  });

  /// Surface pressure rate in bar/min (always present when result is non-null).
  final double barPerMin;

  /// Parsed tank volume in liters, or null if unparseable.
  final double? tankVolumeL;

  /// SAC in L/min (barPerMin × tankVolumeL), or null if tank volume unknown.
  final double? litersPerMin;

  /// bar/min converted to psi/min (barPerMin × 14.5038).
  final double? psiPerMin;

  /// L/min converted to cu ft/min (litersPerMin × 0.0353147).
  final double? cubicFtPerMin;

  bool get hasFullSac => litersPerMin != null;
}

/// Parses a free-text tank size string into liters, or null if unparseable.
///
/// Recognized formats (case-insensitive, whitespace-tolerant):
///   "12L", "12 L", "12l"        → 12.0
///   "80 cu ft", "80cuft"        → 80 × 28.3168 / 207
double? parseTankVolumeLiters(String tankSize) {
  final trimmed = tankSize.trim().toLowerCase();
  if (trimmed.isEmpty) return null;

  // Cubic feet: "<n> cu ft" or "<n>cuft"
  if (trimmed.contains('cu')) {
    final match = RegExp(r'([\d.]+)').firstMatch(trimmed);
    if (match == null) return null;
    final cuFt = double.tryParse(match.group(1)!);
    if (cuFt == null || cuFt <= 0) return null;
    return cuFt * 28.3168 / 207;
  }

  // Liters: "<n>L" or "<n> L"
  if (trimmed.contains('l')) {
    final match = RegExp(r'([\d.]+)').firstMatch(trimmed);
    if (match == null) return null;
    final liters = double.tryParse(match.group(1)!);
    if (liters == null || liters <= 0) return null;
    return liters;
  }

  return null;
}

/// Computes the SAC result for a dive.
///
/// Returns null if [durationMin] ≤ 0 or [endBar] ≥ [startBar].
/// Returns bar/min only (no L/min) if the tank volume is unknown.
///
/// Tank volume resolution (D1): when [tankVolumeValue] + [tankVolumeUnit] are
/// provided, the structured value wins. `cu ft` is converted to liters via the
/// 207-bar service pressure assumption (`value × 28.3168 / 207`); `L` is used
/// directly. Otherwise, falls back to parsing the legacy [tankSize] text for
/// old rows.
SacResult? computeSac({
  required double startBar,
  required double endBar,
  required double durationMin,
  required double avgDepthM,
  String tankSize = '',
  double? tankVolumeValue,
  String? tankVolumeUnit,
}) {
  if (durationMin <= 0 || endBar >= startBar) return null;

  final pRate = (startBar - endBar) / (durationMin * ((avgDepthM / 10) + 1));

  final tankVolumeL = _resolveTankVolumeLiters(
    tankSize: tankSize,
    tankVolumeValue: tankVolumeValue,
    tankVolumeUnit: tankVolumeUnit,
  );
  final litersPerMin = tankVolumeL != null ? pRate * tankVolumeL : null;

  return SacResult(
    barPerMin: pRate,
    tankVolumeL: tankVolumeL,
    litersPerMin: litersPerMin,
    psiPerMin: pRate * 14.5038,
    cubicFtPerMin: litersPerMin != null ? litersPerMin * 0.0353147 : null,
  );
}

/// Resolves tank volume in liters. Structured value wins when present;
/// otherwise falls back to parsing [tankSize].
double? _resolveTankVolumeLiters({
  required String tankSize,
  double? tankVolumeValue,
  String? tankVolumeUnit,
}) {
  if (tankVolumeValue != null && tankVolumeValue > 0) {
    if (tankVolumeUnit == 'cu_ft') {
      return tankVolumeValue * 28.3168 / 207;
    }
    // Default to liters for 'L' or any unrecognized unit.
    return tankVolumeValue;
  }
  return parseTankVolumeLiters(tankSize);
}
