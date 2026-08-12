/// A marine life sighting within a dive (PRD §5.4).
///
/// [divePhotoId] must reference a [DivePhoto] already attached to the same
/// dive — sightings cannot use fresh gallery photos.
class Sighting {
  Sighting({
    this.id,
    this.diveLogId,
    this.divePhotoId,
    required this.commonName,
  });

  final int? id;
  final int? diveLogId;
  final int? divePhotoId;
  final String commonName;

  static const Object _unset = Object();

  Sighting copyWith({
    int? id,
    Object? diveLogId = _unset,
    Object? divePhotoId = _unset,
    String? commonName,
  }) {
    return Sighting(
      id: id ?? this.id,
      diveLogId: diveLogId == _unset ? this.diveLogId : diveLogId as int?,
      divePhotoId: divePhotoId == _unset
          ? this.divePhotoId
          : divePhotoId as int?,
      commonName: commonName ?? this.commonName,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'dive_log_id': diveLogId,
      'dive_photo_id': divePhotoId,
      'common_name': commonName,
    };
  }

  factory Sighting.fromMap(Map<String, Object?> map) {
    return Sighting(
      id: map['id'] as int?,
      diveLogId: map['dive_log_id'] as int?,
      divePhotoId: map['dive_photo_id'] as int?,
      commonName: map['common_name'] as String,
    );
  }
}
