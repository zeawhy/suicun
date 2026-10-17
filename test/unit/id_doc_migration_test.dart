// test/unit/id_doc_migration_test.dart
// Unit tests for legacy ID document body migration (Round 4 §1).

import 'package:flutter_test/flutter_test.dart';
import 'package:suicun/features/records/data/id_doc_migration.dart';
import 'package:suicun/features/records/domain/id_doc_data.dart';

void main() {
  group('parseLegacyIdDocBody - Chinese prefixes', () {
    test('parses full Chinese format with half-width colons', () {
      const body = '证件类型: 身份证\n'
          '姓名: 张三\n'
          '证件号码: 110101199003072345\n'
          '有效期至: 2030-01-01\n'
          '证件照片正面: photos/front.jpg\n'
          '证件照片反面: photos/back.jpg\n'
          '备注: 测试备注';
      final data = parseLegacyIdDocBody(body);
      expect(data, isNotNull);
      expect(data!.type, 'cn_resident_id');
      expect(data.name, '张三');
      expect(data.number, '110101199003072345');
      expect(data.expiryDate, DateTime(2030, 1, 1));
      expect(data.photoFront, 'photos/front.jpg');
      expect(data.photoBack, 'photos/back.jpg');
      expect(data.note, '测试备注');
    });

    test('parses Chinese format with full-width colons', () {
      const body = '证件类型：身份证\n'
          '姓名：李四\n'
          '证件号码：110101199003072346\n'
          '有效期至：2030-01-01\n'
          '备注：';
      final data = parseLegacyIdDocBody(body);
      expect(data, isNotNull);
      expect(data!.type, 'cn_resident_id');
      expect(data.name, '李四');
      expect(data.number, '110101199003072346');
    });

    test('maps 身份证 to cn_resident_id', () {
      const body = '证件类型: 身份证\n证件号码: 123456';
      final data = parseLegacyIdDocBody(body);
      expect(data!.type, 'cn_resident_id');
    });

    test('maps 护照 to passport', () {
      const body = '证件类型: 护照\n证件号码: E12345678';
      final data = parseLegacyIdDocBody(body);
      expect(data!.type, 'passport');
    });

    test('unmapped type goes to other with original name in note', () {
      const body = '证件类型: 军官证\n证件号码: 123456\n备注: 原备注';
      final data = parseLegacyIdDocBody(body);
      expect(data!.type, 'other');
      expect(data.note, contains('原证件类型: 军官证'));
      expect(data.note, contains('原备注'));
    });
  });

  group('parseLegacyIdDocBody - English prefixes', () {
    test('parses full English format', () {
      const body = 'Document type: Passport\n'
          'Name: John Doe\n'
          'Document number: E12345678\n'
          'Valid until: 2030-01-01\n'
          'ID photo front: photos/front.jpg\n'
          'ID photo back: photos/back.jpg\n'
          'Notes: Test note';
      final data = parseLegacyIdDocBody(body);
      expect(data, isNotNull);
      expect(data!.type, 'passport');
      expect(data.name, 'John Doe');
      expect(data.number, 'E12345678');
      expect(data.expiryDate, DateTime(2030, 1, 1));
      expect(data.note, 'Test note');
    });

    test('English labels are case-insensitive', () {
      const body = 'DOCUMENT TYPE: Passport\nDOCUMENT NUMBER: E12345678';
      final data = parseLegacyIdDocBody(body);
      expect(data, isNotNull);
      expect(data!.type, 'passport');
    });

    test('maps ID card to cn_resident_id', () {
      const body = 'Document type: ID card\nDocument number: 123456';
      final data = parseLegacyIdDocBody(body);
      expect(data!.type, 'cn_resident_id');
    });
  });

  group('parseLegacyIdDocBody - edge cases', () {
    test('handles missing fields gracefully', () {
      const body = '证件类型: 身份证\n证件号码: 123456';
      final data = parseLegacyIdDocBody(body);
      expect(data, isNotNull);
      expect(data!.name, isNull);
      expect(data.expiryDate, isNull);
      expect(data.note, isNull);
    });

    test('handles extra blank lines', () {
      const body = '\n\n证件类型: 身份证\n\n证件号码: 123456\n\n\n';
      final data = parseLegacyIdDocBody(body);
      expect(data, isNotNull);
      expect(data!.type, 'cn_resident_id');
    });

    test('handles 长期 as noExpiry', () {
      const body = '证件类型: 身份证\n证件号码: 123456\n有效期至: 长期';
      final data = parseLegacyIdDocBody(body);
      expect(data!.noExpiry, isTrue);
      expect(data.expiryDate, isNull);
    });

    test('unrecognized content goes to note', () {
      const body = '证件类型: 身份证\n证件号码: 123456\n未知字段: 未知值\n备注: 原备注';
      final data = parseLegacyIdDocBody(body);
      expect(data, isNotNull);
      expect(data!.note, contains('原备注'));
      expect(data.note, contains('未识别内容'));
      expect(data.note, contains('未知字段: 未知值'));
    });

    test('returns null for non-ID body', () {
      const body = '这是一篇普通的笔记\n没有证件相关的字段';
      final data = parseLegacyIdDocBody(body);
      expect(data, isNull);
    });

    test('returns null for empty body', () {
      expect(parseLegacyIdDocBody(''), isNull);
      expect(parseLegacyIdDocBody('   \n  '), isNull);
    });

    test('parses various date formats', () {
      const body1 = '证件类型: 身份证\n证件号码: 123\n有效期至: 2030/01/01';
      expect(parseLegacyIdDocBody(body1)!.expiryDate, DateTime(2030, 1, 1));

      const body2 = '证件类型: 身份证\n证件号码: 123\n有效期至: 20300101';
      expect(parseLegacyIdDocBody(body2)!.expiryDate, DateTime(2030, 1, 1));
    });
  });

  group('tryMigrateIdDocData', () {
    test('migrates when no existing JSON and body is legacy format', () {
      const body = '证件类型: 身份证\n证件号码: 123456';
      final result = tryMigrateIdDocData(existingJson: null, body: body);
      expect(result.migrated, isTrue);
      expect(result.data, isNotNull);
      expect(result.data!.type, 'cn_resident_id');
    });

    test('does not migrate when existing JSON is present', () {
      const existing = '{"type":"passport","number":"E123","schemaVersion":2}';
      const body = '证件类型: 身份证\n证件号码: 123456';
      final result = tryMigrateIdDocData(existingJson: existing, body: body);
      expect(result.migrated, isFalse);
      expect(result.data!.type, 'passport');
    });

    test('returns null data when body is not ID format', () {
      const body = '普通笔记内容';
      final result = tryMigrateIdDocData(existingJson: null, body: body);
      expect(result.migrated, isFalse);
      expect(result.data, isNull);
    });
  });

  group('IdDocData', () {
    test('toJson/fromJson roundtrip', () {
      const data = IdDocData(
        type: 'cn_resident_id',
        name: '张三',
        number: '110101199003072345',
        expiryDate: null,
        noExpiry: true,
        photoFront: 'a.jpg',
        note: '备注',
      );
      final json = data.toJson();
      final restored = IdDocData.fromJson(json);
      expect(restored, equals(data));
    });

    test('copyWith works', () {
      const data = IdDocData(type: 'other');
      final updated = data.copyWith(type: 'passport', name: 'Test');
      expect(updated.type, 'passport');
      expect(updated.name, 'Test');
    });
  });
}
