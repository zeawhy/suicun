// test/unit/id_doc_codec_test.dart
// Round 5 §1.2: codec round-trip, legacy parsing, type mapping.

import 'package:flutter_test/flutter_test.dart';
import 'package:suicun/features/records/domain/id_doc_codec.dart';
import 'package:suicun/features/records/domain/id_doc_data.dart';

void main() {
  group('new format round-trip', () {
    test('encode/decode preserves all fields', () {
      final data = IdDocData(
        type: 'cn_resident_id',
        name: '张三',
        number: '110101199003072340',
        issuingCountry: 'CN',
        issueDate: DateTime(2020, 1, 15),
        expiryDate: DateTime(2030, 1, 15),
        noExpiry: false,
        photoFront: 'id_photos/abc_front.jpg',
        photoBack: 'id_photos/abc_back.jpg',
        note: '备注',
      );
      final body = encodeIdDocBody(data);
      expect(body.startsWith(kIdDocBodyMarker), isTrue);
      // No localized text in the encoded body.
      expect(body.contains('证件类型'), isFalse);
      expect(body.contains('Document type'), isFalse);

      final decoded = decodeIdDocBody(body);
      expect(decoded, isNotNull);
      expect(decoded, equals(data));
    });

    test('noExpiry round-trip', () {
      const data = IdDocData(type: 'passport', name: 'Li', noExpiry: true);
      final decoded = decodeIdDocBody(encodeIdDocBody(data));
      expect(decoded?.noExpiry, isTrue);
      expect(decoded?.expiryDate, isNull);
    });

    test('isIdDocBody true for new format', () {
      const data = IdDocData(type: 'other');
      expect(isIdDocBody(encodeIdDocBody(data)), isTrue);
      expect(isNewIdDocBody(encodeIdDocBody(data)), isTrue);
    });

    test('non-id body returns false/null', () {
      expect(isIdDocBody('just a note\nhello'), isFalse);
      expect(decodeIdDocBody('just a note'), isNull);
    });
  });

  group('legacy format decode', () {
    test('chinese labels with full-width colon', () {
      const body = '证件类型：身份证\n姓名：张三\n证件号码：110101199003072340\n'
          '有效期至：2030-01-15\n备注：测试';
      expect(isIdDocBody(body), isTrue);
      final data = decodeIdDocBody(body)!;
      expect(data.type, 'cn_resident_id');
      expect(data.name, '张三');
      expect(data.number, '110101199003072340');
      expect(data.expiryDate, DateTime(2030, 1, 15));
      expect(data.noExpiry, isFalse);
      expect(data.note, '测试');
    });

    test('english labels with half-width colon', () {
      const body = 'Document type: Passport\nName: John\n'
          'Document number: E12345678\nValid until: 2028-05-01';
      final data = decodeIdDocBody(body)!;
      expect(data.type, 'passport');
      expect(data.name, 'John');
      expect(data.number, 'E12345678');
      expect(data.expiryDate, DateTime(2028, 5, 1));
    });

    test('身份证 maps to cn_resident_id, not national_id', () {
      expect(mapLegacyTypeNameToKey('身份证'), 'cn_resident_id');
      expect(mapLegacyTypeNameToKey('ID card'), 'cn_resident_id');
      expect(mapLegacyTypeNameToKey('id card'), 'cn_resident_id');
    });

    test('all 11 arb zh names map correctly', () {
      const pairs = {
        '中国居民身份证': 'cn_resident_id',
        '护照': 'passport',
        '驾驶证': 'driver_license',
        '居留卡': 'residence_permit',
        '社保卡': 'social_security',
        '医保卡': 'health_insurance',
        '学生证': 'student_id',
        '港澳通行证': 'hk_mo_permit',
        '台湾通行证': 'tw_permit',
        '其他证件': 'other',
      };
      pairs.forEach((name, key) {
        expect(mapLegacyTypeNameToKey(name), key, reason: name);
      });
    });

    test('all 11 arb en names map correctly', () {
      const pairs = {
        'China Resident ID': 'cn_resident_id',
        'Passport': 'passport',
        "Driver's license": 'driver_license',
        'Residence permit': 'residence_permit',
        'Social security card': 'social_security',
        'Health insurance card': 'health_insurance',
        'Student ID': 'student_id',
        'HK-Macau Travel Permit': 'hk_mo_permit',
        'Taiwan Travel Permit': 'tw_permit',
        'Other': 'other',
      };
      pairs.forEach((name, key) {
        expect(mapLegacyTypeNameToKey(name), key, reason: name);
      });
    });

    test('legacy id_doc_type.dart labels map correctly', () {
      expect(mapLegacyTypeNameToKey('行驶证'), 'other');
      expect(mapLegacyTypeNameToKey('房产证'), 'other');
      expect(mapLegacyTypeNameToKey('Vehicle License'), 'other');
      expect(mapLegacyTypeNameToKey('Exit-Entry Permit (HK/Macau)'),
          'hk_mo_permit');
      expect(mapLegacyTypeNameToKey('Property Certificate'), 'other');
    });

    test('case and whitespace insensitive', () {
      expect(mapLegacyTypeNameToKey('  PASSPORT  '), 'passport');
      expect(mapLegacyTypeNameToKey('护照 '), 'passport');
    });

    test('unknown type -> other with original name in note', () {
      const body = '证件类型：外星人证件\n姓名：ET';
      final data = decodeIdDocBody(body)!;
      expect(data.type, 'other');
      expect(data.note, contains('外星人证件'));
      expect(data.note, startsWith('原类型：'));
    });

    test('genuine other does not get orig-type note', () {
      const body = '证件类型：其他\n姓名：X';
      final data = decodeIdDocBody(body)!;
      expect(data.type, 'other');
      expect(data.note ?? '', isNot(contains('原类型')));
    });

    test('长期 and No expiry -> noExpiry', () {
      final zh = decodeIdDocBody('证件类型：护照\n有效期至：长期')!;
      expect(zh.noExpiry, isTrue);
      expect(zh.expiryDate, isNull);
      final en =
          decodeIdDocBody('Document type: Passport\nValid until: No expiry')!;
      expect(en.noExpiry, isTrue);
    });

    test('unparseable expiry preserved in note', () {
      final data = decodeIdDocBody('证件类型：护照\n有效期至：很久以后')!;
      expect(data.expiryDate, isNull);
      expect(data.noExpiry, isFalse);
      expect(data.note, contains('很久以后'));
    });

    test('photo paths preserved', () {
      const body = '证件类型：身份证\n证件照片正面：id_photos/a.jpg\n'
          '证件照片反面：id_photos/b.jpg';
      final data = decodeIdDocBody(body)!;
      expect(data.photoFront, 'id_photos/a.jpg');
      expect(data.photoBack, 'id_photos/b.jpg');
    });
  });

  group('round 7 §3.3: lenient markdown prefix handling', () {
    IdDocData sampleData() => IdDocData(
          type: 'cn_resident_id',
          name: '张三',
          number: '110101199003072340',
          photoFront: 'id_photos/abc_front.enc',
          note: '备注',
        );

    test('checkbox-prefixed body decodes and repairs to canonical', () {
      final canonical = encodeIdDocBody(sampleData());
      final damaged = '- [ ] $canonical';
      expect(isIdDocBody(damaged), isTrue);
      expect(decodeIdDocBody(damaged), equals(sampleData()));
      expect(repairPrefixedIdDocBody(damaged), canonical);
      // Re-encoding the repaired body is stable.
      expect(encodeIdDocBody(decodeIdDocBody(damaged)!), canonical);
    });

    test('repeated mixed prefixes decode', () {
      final canonical = encodeIdDocBody(sampleData());
      const prefixes = [
        '- [x] - [ ] ',
        '- [ ] - [x] - [ ] ',
        '- ',
        '* ',
        '- - [ ] ',
        '  - [ ] ',
      ];
      for (final p in prefixes) {
        final damaged = '$p$canonical';
        expect(isIdDocBody(damaged), isTrue, reason: p);
        expect(decodeIdDocBody(damaged), equals(sampleData()), reason: p);
        expect(repairPrefixedIdDocBody(damaged), canonical, reason: p);
      }
    });

    test('no prefix -> repair returns null', () {
      final canonical = encodeIdDocBody(sampleData());
      expect(repairPrefixedIdDocBody(canonical), isNull);
      expect(stripIdDocBodyPrefix(canonical), isNull);
    });

    test('prefix but unparseable JSON -> no repair, decode null', () {
      const damaged = '- [ ] suivault:id_doc:v2\n{not json}';
      expect(isIdDocBody(damaged), isTrue);
      expect(decodeIdDocBody(damaged), isNull);
      expect(repairPrefixedIdDocBody(damaged), isNull);
    });

    test('plain note starting with dash is not an id doc', () {
      expect(isIdDocBody('- buy milk\n- call mom'), isFalse);
      expect(decodeIdDocBody('- buy milk'), isNull);
      expect(repairPrefixedIdDocBody('- buy milk'), isNull);
    });
  });
}
