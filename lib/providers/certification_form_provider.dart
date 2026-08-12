import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_helper.dart';
import '../models/certification.dart';
import 'dive_providers.dart';

/// Mutable form state for the certification add/edit dialog.
class CertificationFormState {
  const CertificationFormState({
    this.existingId,
    this.org = '',
    this.level = '',
    this.certId = '',
    this.issueDate,
    this.photoPath,
    this.validationErrors = const {},
    this.isSaving = false,
    this.saveError,
  });

  final int? existingId;
  final String org;
  final String level;
  final String certId;
  final DateTime? issueDate;
  final String? photoPath;
  final Map<String, String> validationErrors;
  final bool isSaving;
  final String? saveError;

  bool get isEditing => existingId != null;

  static const Object _unset = Object();

  CertificationFormState copyWith({
    int? existingId,
    String? org,
    String? level,
    String? certId,
    Object? issueDate = _unset,
    Object? photoPath = _unset,
    Map<String, String>? validationErrors,
    bool? isSaving,
    String? saveError,
  }) {
    return CertificationFormState(
      existingId: existingId ?? this.existingId,
      org: org ?? this.org,
      level: level ?? this.level,
      certId: certId ?? this.certId,
      issueDate: issueDate == _unset ? this.issueDate : issueDate as DateTime?,
      photoPath: photoPath == _unset ? this.photoPath : photoPath as String?,
      validationErrors: validationErrors ?? this.validationErrors,
      isSaving: isSaving ?? this.isSaving,
      saveError: saveError ?? this.saveError,
    );
  }
}

/// Family notifier: constructor receives the existing certification id, or
/// `null` for new.
class CertificationFormNotifier extends AsyncNotifier<CertificationFormState> {
  CertificationFormNotifier(this.id);

  final int? id;

  DatabaseHelper get _db => ref.read(databaseProvider);

  @override
  Future<CertificationFormState> build() async {
    if (id == null) return const CertificationFormState();
    final certs = (await _db.getCertifications(limit: 100000)).certs;
    final cert = certs.firstWhere(
      (c) => c.id == id,
      orElse: () => Certification(org: '', level: '', id: id),
    );
    return CertificationFormState(
      existingId: id,
      org: cert.org,
      level: cert.level,
      certId: cert.certId ?? '',
      issueDate: cert.issueDate,
      photoPath: cert.photoPath,
    );
  }

  void setOrg(String v) => _update(s: state.value!.copyWith(org: v));
  void setLevel(String v) => _update(s: state.value!.copyWith(level: v));
  void setCertId(String v) => _update(s: state.value!.copyWith(certId: v));
  void setIssueDate(DateTime? v) =>
      _update(s: state.value!.copyWith(issueDate: v));
  void setPhotoPath(String? v) =>
      _update(s: state.value!.copyWith(photoPath: v));

  Future<bool> save() async {
    final s = state.value!;
    final errors = <String, String>{};
    if (s.org.trim().isEmpty) errors['org'] = 'Organization is required';
    if (s.level.trim().isEmpty) errors['level'] = 'Level is required';
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
      final cert = Certification(
        id: s.existingId,
        org: s.org.trim(),
        level: s.level.trim(),
        certId: s.certId.isEmpty ? null : s.certId,
        issueDate: s.issueDate,
        photoPath: s.photoPath,
      );
      if (cert.id != null) {
        final db = _db;
        final map = cert.toMap();
        map.remove('id');
        await (await db.database).update(
          'certifications',
          map,
          where: 'id = ?',
          whereArgs: [cert.id],
        );
      } else {
        await _db.insertCertification(cert);
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

  void _update({required CertificationFormState s}) {
    state = AsyncData(s);
  }
}

final certificationFormProvider =
    AsyncNotifierProvider.family<
      CertificationFormNotifier,
      CertificationFormState,
      int?
    >(CertificationFormNotifier.new);
