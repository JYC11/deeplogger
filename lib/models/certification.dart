/// A scuba certification card (PRD §5.7).
class Certification {
  Certification({
    this.id,
    required this.org,
    required this.level,
    this.certId,
    this.issueDate,
    this.photoPath,
  });

  final int? id;
  final String org;
  final String level;
  final String? certId;
  final DateTime? issueDate;
  final String? photoPath;

  static const Object _unset = Object();

  Certification copyWith({
    int? id,
    String? org,
    String? level,
    Object? certId = _unset,
    Object? issueDate = _unset,
    Object? photoPath = _unset,
  }) {
    return Certification(
      id: id ?? this.id,
      org: org ?? this.org,
      level: level ?? this.level,
      certId: certId == _unset ? this.certId : certId as String?,
      issueDate: issueDate == _unset ? this.issueDate : issueDate as DateTime?,
      photoPath: photoPath == _unset ? this.photoPath : photoPath as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'org': org,
      'level': level,
      'cert_id': certId,
      'issue_date': issueDate?.millisecondsSinceEpoch,
      'photo_path': photoPath,
    };
  }

  factory Certification.fromMap(Map<String, Object?> map) {
    return Certification(
      id: map['id'] as int?,
      org: map['org'] as String,
      level: map['level'] as String,
      certId: map['cert_id'] as String?,
      issueDate: map['issue_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['issue_date'] as int)
          : null,
      photoPath: map['photo_path'] as String?,
    );
  }
}
