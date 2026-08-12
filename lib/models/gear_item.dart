/// A piece of gear in the master equipment list (PRD §5.6).
///
/// Gear items are selected per-dive via the `dive_log_gear` join table.
/// [category] is a free-text tag, typically one of [kDefaultGearCategories].
class GearItem {
  GearItem({this.id, required this.name, this.typeNotes, this.category});

  final int? id;
  final String name;
  final String? typeNotes;
  final String? category;

  static const Object _unset = Object();

  GearItem copyWith({
    int? id,
    String? name,
    Object? typeNotes = _unset,
    Object? category = _unset,
  }) {
    return GearItem(
      id: id ?? this.id,
      name: name ?? this.name,
      typeNotes: typeNotes == _unset ? this.typeNotes : typeNotes as String?,
      category: category == _unset ? this.category : category as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'type_notes': typeNotes,
      'category': category,
    };
  }

  factory GearItem.fromMap(Map<String, Object?> map) {
    return GearItem(
      id: map['id'] as int?,
      name: map['name'] as String,
      typeNotes: map['type_notes'] as String?,
      category: map['category'] as String?,
    );
  }
}

/// Default gear category taxonomy (PRD §5.6, feedback.md:23-33).
///
/// Constant-only — NOT seeded into the database. Used to populate the category
/// dropdown in the add/edit gear dialog. Regulator subcategories are flattened
/// to three top-level entries (no parent/child column).
const List<String> kDefaultGearCategories = [
  'BCD',
  'Wetsuit',
  'Fins',
  'Dive Computer',
  'Torch',
  'Regulator',
  'Regulator – First Stage',
  'Regulator – Second Stage',
  'Other',
];
