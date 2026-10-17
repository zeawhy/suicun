import 'package:flutter_test/flutter_test.dart';
import 'package:suicun/features/records/presentation/id_doc_types.dart';

void main() {
  group('IdDocType storage keys', () {
    test('all 11 types have unique storage keys', () {
      final keys = IdDocType.values.map((t) => t.storageKey).toList();
      expect(keys.length, 11);
      expect(keys.toSet().length, 11);
    });

    test('fromStorageKey round-trips', () {
      for (final type in IdDocType.values) {
        expect(
          IdDocTypeStorage.fromStorageKey(type.storageKey),
          type,
        );
      }
    });

    test('unknown key maps to other', () {
      expect(IdDocTypeStorage.fromStorageKey('nonexistent'), IdDocType.other);
      expect(IdDocTypeStorage.fromStorageKey(null), IdDocType.other);
      expect(IdDocTypeStorage.fromStorageKey(''), IdDocType.other);
    });

    test('specific keys match spec', () {
      expect(IdDocType.passport.storageKey, 'passport');
      expect(IdDocType.driverLicense.storageKey, 'driver_license');
      expect(IdDocType.nationalId.storageKey, 'national_id');
      expect(IdDocType.residencePermit.storageKey, 'residence_permit');
      expect(IdDocType.socialSecurity.storageKey, 'social_security');
      expect(IdDocType.healthInsurance.storageKey, 'health_insurance');
      expect(IdDocType.studentId.storageKey, 'student_id');
      expect(IdDocType.cnResidentId.storageKey, 'cn_resident_id');
      expect(IdDocType.hkMoPermit.storageKey, 'hk_mo_permit');
      expect(IdDocType.twPermit.storageKey, 'tw_permit');
      expect(IdDocType.other.storageKey, 'other');
    });
  });

  group('docTypeShowsIssuingCountry', () {
    test('only passport/driver_license/national_id/residence_permit', () {
      expect(docTypeShowsIssuingCountry(IdDocType.passport), true);
      expect(docTypeShowsIssuingCountry(IdDocType.driverLicense), true);
      expect(docTypeShowsIssuingCountry(IdDocType.nationalId), true);
      expect(docTypeShowsIssuingCountry(IdDocType.residencePermit), true);
      expect(docTypeShowsIssuingCountry(IdDocType.cnResidentId), false);
      expect(docTypeShowsIssuingCountry(IdDocType.other), false);
    });
  });

  group('kChinaDocGroup', () {
    test('contains exactly cn/hk_mo/tw', () {
      expect(kChinaDocGroup.length, 3);
      expect(kChinaDocGroup, contains(IdDocType.cnResidentId));
      expect(kChinaDocGroup, contains(IdDocType.hkMoPermit));
      expect(kChinaDocGroup, contains(IdDocType.twPermit));
    });
  });
}
