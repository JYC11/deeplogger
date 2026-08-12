/// A photo attached to a dive log (PRD §5.3).
///
/// Images are copied into the app's private directory — [localPath] always
/// refers to the copied file, never the original gallery path.
class DivePhoto {
  DivePhoto({this.id, this.diveLogId, required this.localPath, this.takenAt});

  final int? id;
  final int? diveLogId;
  final String localPath;
  final DateTime? takenAt;

  static const Object _unset = Object();

  DivePhoto copyWith({
    int? id,
    Object? diveLogId = _unset,
    String? localPath,
    Object? takenAt = _unset,
  }) {
    return DivePhoto(
      id: id ?? this.id,
      diveLogId: diveLogId == _unset ? this.diveLogId : diveLogId as int?,
      localPath: localPath ?? this.localPath,
      takenAt: takenAt == _unset ? this.takenAt : takenAt as DateTime?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'dive_log_id': diveLogId,
      'local_path': localPath,
      'taken_at': takenAt?.millisecondsSinceEpoch,
    };
  }

  factory DivePhoto.fromMap(Map<String, Object?> map) {
    return DivePhoto(
      id: map['id'] as int?,
      diveLogId: map['dive_log_id'] as int?,
      localPath: map['local_path'] as String,
      takenAt: map['taken_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['taken_at'] as int)
          : null,
    );
  }
}
