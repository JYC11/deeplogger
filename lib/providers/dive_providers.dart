import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_helper.dart';
import '../models/dive_log.dart';
import '../models/dive_photo.dart';
import '../models/gear_item.dart';
import '../models/gear_ref.dart';
import '../models/sighting.dart';
import '../services/sac_calculator.dart';

/// Provides the singleton [DatabaseHelper].
final databaseProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper.instance;
});

/// A single dive log by ID.
final diveDetailProvider = FutureProvider.autoDispose.family<DiveLog?, int>((
  ref,
  id,
) async {
  return ref.watch(databaseProvider).getDiveLog(id);
});

/// All gear items (master list).
final gearListProvider = FutureProvider<List<GearItem>>((ref) async {
  return ref.watch(databaseProvider).getAllGearItems();
});

/// Gear entries for a dive as [GearRef] values — preserves ad-hoc free-text
/// rows (D-GEAR) that an INNER JOIN would drop.
final diveGearEntriesProvider = FutureProvider.autoDispose
    .family<List<GearRef>, int>((ref, diveId) async {
      return ref.watch(databaseProvider).getGearEntriesForDive(diveId);
    });

/// Photos attached to a specific dive.
final divePhotosProvider = FutureProvider.autoDispose
    .family<List<DivePhoto>, int>((ref, diveId) async {
      return ref.watch(databaseProvider).getDivePhotosForLog(diveId);
    });

/// Sightings for a specific dive.
final sightingsProvider = FutureProvider.autoDispose
    .family<List<Sighting>, int>((ref, diveId) async {
      return ref.watch(databaseProvider).getSightingsForLog(diveId);
    });

/// Computed SAC for a dive log (never stored).
final sacProvider = Provider.family<SacResult?, DiveLog>((ref, log) {
  if (log.startPressureBar == null ||
      log.endPressureBar == null ||
      log.durationMin == null ||
      log.avgDepthM == null) {
    return null;
  }
  return computeSac(
    startBar: log.startPressureBar!,
    endBar: log.endPressureBar!,
    durationMin: log.durationMin!,
    avgDepthM: log.avgDepthM!,
    tankSize: log.tankSize ?? '',
    tankVolumeValue: log.tankVolumeValue,
    tankVolumeUnit: log.tankVolumeUnit,
  );
});
