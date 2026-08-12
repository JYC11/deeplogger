import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_helper.dart';
import '../models/gear_item.dart';
import 'dive_providers.dart';

/// Mutable form state for the gear add/edit dialog.
class GearFormState {
  const GearFormState({
    this.existingId,
    this.name = '',
    this.typeNotes = '',
    this.category,
    this.validationErrors = const {},
    this.isSaving = false,
    this.saveError,
  });

  final int? existingId;
  final String name;
  final String typeNotes;
  final String? category;
  final Map<String, String> validationErrors;
  final bool isSaving;
  final String? saveError;

  bool get isEditing => existingId != null;

  static const Object _unset = Object();

  GearFormState copyWith({
    int? existingId,
    String? name,
    String? typeNotes,
    Object? category = _unset,
    Map<String, String>? validationErrors,
    bool? isSaving,
    String? saveError,
  }) {
    return GearFormState(
      existingId: existingId ?? this.existingId,
      name: name ?? this.name,
      typeNotes: typeNotes ?? this.typeNotes,
      category: category == _unset ? this.category : category as String?,
      validationErrors: validationErrors ?? this.validationErrors,
      isSaving: isSaving ?? this.isSaving,
      saveError: saveError ?? this.saveError,
    );
  }
}

/// Family notifier: constructor receives the existing gear item id, or `null`.
class GearFormNotifier extends AsyncNotifier<GearFormState> {
  GearFormNotifier(this.id);

  final int? id;

  DatabaseHelper get _db => ref.read(databaseProvider);

  @override
  Future<GearFormState> build() async {
    if (id == null) return const GearFormState();
    final items = (await _db.getGearItems(limit: 100000)).items;
    final item = items.firstWhere(
      (g) => g.id == id,
      orElse: () => GearItem(id: id, name: ''),
    );
    return GearFormState(
      existingId: id,
      name: item.name,
      typeNotes: item.typeNotes ?? '',
      category: item.category,
    );
  }

  void setName(String v) => _update(s: state.value!.copyWith(name: v));
  void setTypeNotes(String v) =>
      _update(s: state.value!.copyWith(typeNotes: v));
  void setCategory(String? v) => _update(s: state.value!.copyWith(category: v));

  Future<bool> save() async {
    final s = state.value!;
    final errors = <String, String>{};
    if (s.name.trim().isEmpty) errors['name'] = 'Name is required';
    if (errors.isNotEmpty) {
      _update(s: s.copyWith(validationErrors: errors));
      return false;
    }
    _update(
      s: s.copyWith(
        isSaving: true,
        saveError: null,
        validationErrors: const {},
      ),
    );
    try {
      final item = GearItem(
        id: s.existingId,
        name: s.name.trim(),
        typeNotes: s.typeNotes.isEmpty ? null : s.typeNotes,
        category: s.category,
      );
      if (item.id != null) {
        // Update via raw map (no dedicated update method exists yet).
        final db = _db;
        final map = item.toMap();
        map.remove('id');
        map['updated_at'] = null;
        await (await db.database).update(
          'gear_items',
          map,
          where: 'id = ?',
          whereArgs: [item.id],
        );
      } else {
        await _db.insertGearItem(item);
      }
      _update(s: state.value!.copyWith(isSaving: false));
      return true;
    } catch (e) {
      _update(
        s: state.value!.copyWith(isSaving: false, saveError: e.toString()),
      );
      return false;
    }
  }

  void _update({required GearFormState s}) {
    state = AsyncData(s);
  }
}

final gearFormProvider =
    AsyncNotifierProvider.family<GearFormNotifier, GearFormState, int?>(
      GearFormNotifier.new,
    );
