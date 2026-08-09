import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_helper.dart';
import '../models/certification.dart';
import '../models/dive_log.dart';
import '../models/dive_photo.dart';
import '../models/gear_item.dart';
import '../models/sighting.dart';
import '../services/sac_calculator.dart';

/// Provides the singleton [DatabaseHelper].
final databaseProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper.instance;
});

/// All dive logs (drafts + saved), sorted by start_time DESC.
final diveListProvider = FutureProvider<List<DiveLog>>((ref) async {
  return ref.watch(databaseProvider).getAllDiveLogs();
});

/// A single dive log by ID.
final diveDetailProvider = FutureProvider.family<DiveLog?, int>((
  ref,
  id,
) async {
  return ref.watch(databaseProvider).getDiveLog(id);
});

/// All gear items (master list).
final gearListProvider = FutureProvider<List<GearItem>>((ref) async {
  return ref.watch(databaseProvider).getAllGearItems();
});

/// Gear selected for a specific dive.
final diveGearProvider = FutureProvider.family<List<GearItem>, int>((
  ref,
  diveId,
) async {
  return ref.watch(databaseProvider).getGearForDive(diveId);
});

/// Photos attached to a specific dive.
final divePhotosProvider = FutureProvider.family<List<DivePhoto>, int>((
  ref,
  diveId,
) async {
  return ref.watch(databaseProvider).getDivePhotosForLog(diveId);
});

/// Sightings for a specific dive.
final sightingsProvider = FutureProvider.family<List<Sighting>, int>((
  ref,
  diveId,
) async {
  return ref.watch(databaseProvider).getSightingsForLog(diveId);
});

/// All certifications, sorted by org.
final certificationListProvider = FutureProvider<List<Certification>>((
  ref,
) async {
  return ref.watch(databaseProvider).getAllCertifications();
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
  );
});
