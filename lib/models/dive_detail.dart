import 'dive_log.dart';
import 'dive_photo.dart';
import 'gear_ref.dart';
import 'sighting.dart';

/// A dive log plus its related photos, sightings, and gear entries, loaded in
/// a single round trip (collapses multiple sequential provider watches).
class DiveDetail {
  const DiveDetail({
    required this.log,
    required this.photos,
    required this.sightings,
    required this.gear,
  });

  final DiveLog log;
  final List<DivePhoto> photos;
  final List<Sighting> sightings;
  final List<GearRef> gear;
}
