/// A scuba certification card (PRD §5.7).
class Certification {
  Certification({
    this.id,
    required this.org,
    required this.level,
    this.issueDate,
    this.photoPath,
  });

  final int? id;
  final String org;
  final String level;
  final DateTime? issueDate;
  final String? photoPath;

  Certification copyWith({
    int? id,
    String? org,
    String? level,
    DateTime? issueDate,
    String? photoPath,
  }) {
    return Certification(
      id: id ?? this.id,
      org: org ?? this.org,
      level: level ?? this.level,
      issueDate: issueDate ?? this.issueDate,
      photoPath: photoPath ?? this.photoPath,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'org': org,
      'level': level,
      'issue_date': issueDate?.millisecondsSinceEpoch,
      'photo_path': photoPath,
    };
  }

  factory Certification.fromMap(Map<String, Object?> map) {
    return Certification(
      id: map['id'] as int?,
      org: map['org'] as String,
      level: map['level'] as String,
      issueDate: map['issue_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['issue_date'] as int)
          : null,
      photoPath: map['photo_path'] as String?,
    );
  }
}
