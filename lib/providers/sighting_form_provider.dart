import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_helper.dart';
import '../models/sighting.dart';
import 'dive_providers.dart';

/// Mutable form state for the sighting add/edit dialog.
class SightingFormState {
  const SightingFormState({
    this.existingId,
    required this.diveLogId,
    this.commonName = '',
    this.divePhotoId,
    this.validationErrors = const {},
    this.isSaving = false,
    this.saveError,
  });

  final int? existingId;
  final int diveLogId;
  final String commonName;
  final int? divePhotoId;
  final Map<String, String> validationErrors;
  final bool isSaving;
  final String? saveError;

  bool get isEditing => existingId != null;

  SightingFormState copyWith({
    int? existingId,
    int? diveLogId,
    String? commonName,
    int? divePhotoId,
    Map<String, String>? validationErrors,
    bool? isSaving,
    String? saveError,
  }) {
    return SightingFormState(
      existingId: existingId ?? this.existingId,
      diveLogId: diveLogId ?? this.diveLogId,
      commonName: commonName ?? this.commonName,
      divePhotoId: divePhotoId ?? this.divePhotoId,
      validationErrors: validationErrors ?? this.validationErrors,
      isSaving: isSaving ?? this.isSaving,
      saveError: saveError ?? this.saveError,
    );
  }
}

/// Family notifier keyed by a tuple of (existing sighting id?, dive log id).
/// Since Riverpod families take a single arg, we bundle them in a small record
/// type [SightingFormKey].
class SightingFormKey {
  const SightingFormKey({this.existingId, required this.diveLogId});
  final int? existingId;
  final int diveLogId;

  @override
  bool operator ==(Object other) =>
      other is SightingFormKey &&
      other.existingId == existingId &&
      other.diveLogId == diveLogId;

  @override
  int get hashCode => Object.hash(existingId, diveLogId);
}

class SightingFormNotifier extends AsyncNotifier<SightingFormState> {
  SightingFormNotifier(this.key);

  final SightingFormKey key;

  DatabaseHelper get _db => ref.read(databaseProvider);

  @override
  Future<SightingFormState> build() async {
    if (key.existingId == null) {
      return SightingFormState(diveLogId: key.diveLogId);
    }
    final sightings = await _db.getSightingsForLog(key.diveLogId);
    final s = sightings.firstWhere(
      (x) => x.id == key.existingId,
      orElse: () => Sighting(diveLogId: key.diveLogId, commonName: ''),
    );
    return SightingFormState(
      existingId: s.id,
      diveLogId: key.diveLogId,
      commonName: s.commonName,
      divePhotoId: s.divePhotoId,
    );
  }

  void setCommonName(String v) =>
      _update(s: state.value!.copyWith(commonName: v));
  void setPhotoId(int? v) => _update(s: state.value!.copyWith(divePhotoId: v));

  Future<bool> save() async {
    final s = state.value!;
    final errors = <String, String>{};
    if (s.commonName.trim().isEmpty) {
      errors['commonName'] = 'Common name is required';
    }
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
      final sighting = Sighting(
        id: s.existingId,
        diveLogId: s.diveLogId,
        divePhotoId: s.divePhotoId,
        commonName: s.commonName.trim(),
      );
      if (sighting.id != null) {
        final db = _db;
        final map = sighting.toMap();
        map.remove('id');
        await (await db.database).update(
          'sightings',
          map,
          where: 'id = ?',
          whereArgs: [sighting.id],
        );
      } else {
        await _db.insertSighting(sighting);
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

  void _update({required SightingFormState s}) {
    state = AsyncData(s);
  }
}

// AutoDispose: reopening the dialog always starts from a fresh build.
final sightingFormProvider =
    AsyncNotifierProvider.family<
      SightingFormNotifier,
      SightingFormState,
      SightingFormKey
    >(SightingFormNotifier.new, isAutoDispose: true);
