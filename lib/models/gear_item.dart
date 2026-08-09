/// A piece of gear in the master equipment list (PRD §5.6).
///
/// Gear items are selected per-dive via the `dive_log_gear` join table.
class GearItem {
  GearItem({this.id, required this.name, this.typeNotes});

  final int? id;
  final String name;
  final String? typeNotes;

  GearItem copyWith({int? id, String? name, String? typeNotes}) {
    return GearItem(
      id: id ?? this.id,
      name: name ?? this.name,
      typeNotes: typeNotes ?? this.typeNotes,
    );
  }

  Map<String, Object?> toMap() {
    return {'id': id, 'name': name, 'type_notes': typeNotes};
  }

  factory GearItem.fromMap(Map<String, Object?> map) {
    return GearItem(
      id: map['id'] as int?,
      name: map['name'] as String,
      typeNotes: map['type_notes'] as String?,
    );
  }
}
