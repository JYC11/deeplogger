import 'package:deeplogger/models/certification.dart';
import 'package:deeplogger/models/dive_log.dart';
import 'package:deeplogger/models/dive_photo.dart';
import 'package:deeplogger/models/gear_item.dart';
import 'package:deeplogger/models/sighting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiveLog', () {
    test('toMap/fromMap round-trips new tank volume fields', () {
      final log = DiveLog(
        startTime: DateTime(2026, 1, 1),
        tankVolumeValue: 12.0,
        tankVolumeUnit: 'L',
      );
      final restored = DiveLog.fromMap(log.toMap());
      expect(restored.tankVolumeValue, 12.0);
      expect(restored.tankVolumeUnit, 'L');
    });

    test('tank volume fields default to null', () {
      final log = DiveLog(startTime: DateTime(2026, 1, 1));
      expect(log.tankVolumeValue, isNull);
      expect(log.tankVolumeUnit, isNull);
    });

    test('copyWith can clear a nullable field to null (sentinel)', () {
      final log = DiveLog(
        startTime: DateTime(2026, 1, 1),
        location: 'Reef',
        maxDepthM: 18.0,
      );
      final cleared = log.copyWith(location: null, maxDepthM: null);
      expect(cleared.location, isNull);
      expect(cleared.maxDepthM, isNull);
    });

    test('copyWith omits keep existing value (sentinel)', () {
      final log = DiveLog(
        startTime: DateTime(2026, 1, 1),
        location: 'Reef',
        maxDepthM: 18.0,
      );
      final updated = log.copyWith(maxDepthM: 25.0);
      expect(updated.location, 'Reef');
      expect(updated.maxDepthM, 25.0);
    });

    test('copyWith clears tank volume unit', () {
      final log = DiveLog(
        startTime: DateTime(2026, 1, 1),
        tankVolumeValue: 12.0,
        tankVolumeUnit: 'L',
      );
      final cleared = log.copyWith(tankVolumeUnit: null, tankVolumeValue: null);
      expect(cleared.tankVolumeUnit, isNull);
      expect(cleared.tankVolumeValue, isNull);
    });

    test('toMap writes is_draft as 0/1', () {
      expect(
        DiveLog(
          startTime: DateTime(2026, 1, 1),
          isDraft: false,
        ).toMap()['is_draft'],
        0,
      );
      expect(
        DiveLog(
          startTime: DateTime(2026, 1, 1),
          isDraft: true,
        ).toMap()['is_draft'],
        1,
      );
    });
  });

  group('GearItem', () {
    test('category round-trips', () {
      final item = GearItem(name: 'BCD', category: 'BCD');
      final restored = GearItem.fromMap(item.toMap());
      expect(restored.category, 'BCD');
    });

    test('copyWith clears typeNotes and category to null', () {
      final item = GearItem(
        name: 'Reg',
        typeNotes: 'notes',
        category: 'Regulator',
      );
      final cleared = item.copyWith(typeNotes: null, category: null);
      expect(cleared.typeNotes, isNull);
      expect(cleared.category, isNull);
    });

    test('kDefaultGearCategories includes Regulator subcategories', () {
      expect(
        kDefaultGearCategories,
        containsAll([
          'BCD',
          'Regulator',
          'Regulator – First Stage',
          'Regulator – Second Stage',
          'Other',
        ]),
      );
      expect(kDefaultGearCategories.length, 9);
    });
  });

  group('Certification', () {
    test('certId round-trips', () {
      final cert = Certification(org: 'PADI', level: 'OW', certId: '12345');
      final restored = Certification.fromMap(cert.toMap());
      expect(restored.certId, '12345');
    });

    test('copyWith clears certId, issueDate, photoPath to null', () {
      final cert = Certification(
        org: 'PADI',
        level: 'OW',
        certId: '12345',
        issueDate: DateTime(2025, 1, 1),
        photoPath: '/img.png',
      );
      final cleared = cert.copyWith(
        certId: null,
        issueDate: null,
        photoPath: null,
      );
      expect(cleared.certId, isNull);
      expect(cleared.issueDate, isNull);
      expect(cleared.photoPath, isNull);
    });

    test('copyWith keeps required fields when optional cleared', () {
      final cert = Certification(org: 'PADI', level: 'OW', certId: 'X');
      final cleared = cert.copyWith(certId: null);
      expect(cleared.org, 'PADI');
      expect(cleared.level, 'OW');
    });
  });

  group('DivePhoto', () {
    test('copyWith clears diveLogId and takenAt to null', () {
      final photo = DivePhoto(
        diveLogId: 1,
        localPath: '/p.jpg',
        takenAt: DateTime(2026, 1, 1),
      );
      final cleared = photo.copyWith(diveLogId: null, takenAt: null);
      expect(cleared.diveLogId, isNull);
      expect(cleared.takenAt, isNull);
      expect(cleared.localPath, '/p.jpg');
    });
  });

  group('Sighting', () {
    test('copyWith clears divePhotoId to null', () {
      final s = Sighting(diveLogId: 1, divePhotoId: 5, commonName: 'Nemo');
      final cleared = s.copyWith(divePhotoId: null);
      expect(cleared.divePhotoId, isNull);
      expect(cleared.diveLogId, 1);
      expect(cleared.commonName, 'Nemo');
    });
  });
}
