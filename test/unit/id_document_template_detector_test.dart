// test/unit/id_document_template_detector_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:suicun/features/records/presentation/template_views/template_detector.dart';

void main() {
  group('IdDocumentTemplateDetector', () {
    test('normal case (Chinese): correctly parses all fields with fullwidth and halfwidth colons', () {
      const body = '''
证件类型：身份证
姓名: 张三
证件号码：110101199003072345
有效期至: 2035-12-31
证件照片正面：id_photos/rec_1_front_123.jpg
证件照片反面: id_photos/rec_1_back_123.jpg
备注：个人主力证件
''';

      expect(isIdDocumentTemplate(body), isTrue);
      final data = parseIdDocumentTemplate(body);
      expect(data, isNotNull);
      expect(data!.docType, '身份证');
      expect(data.name, '张三');
      expect(data.docNumber, '110101199003072345');
      expect(data.validUntil, '2035-12-31');
      expect(data.photoFront, 'id_photos/rec_1_front_123.jpg');
      expect(data.photoBack, 'id_photos/rec_1_back_123.jpg');
      expect(data.notes, '个人主力证件');
    });

    test('normal case (English): correctly parses all fields', () {
      const body = '''
Document type: Passport
Name: John Doe
Document number: E12345678
Valid until: 2030-01-01
ID photo front: id_photos/rec_2_front_456.jpg
ID photo back: id_photos/rec_2_back_456.jpg
Notes: Primary passport
''';

      expect(isIdDocumentTemplate(body), isTrue);
      final data = parseIdDocumentTemplate(body);
      expect(data, isNotNull);
      expect(data!.docType, 'Passport');
      expect(data.name, 'John Doe');
      expect(data.docNumber, 'E12345678');
      expect(data.validUntil, '2030-01-01');
      expect(data.photoFront, 'id_photos/rec_2_front_456.jpg');
      expect(data.photoBack, 'id_photos/rec_2_back_456.jpg');
      expect(data.notes, 'Primary passport');
    });

    test('normal case: succeeds with only docType anchor', () {
      const body = '证件类型：驾驶证\n姓名：李四';
      expect(isIdDocumentTemplate(body), isTrue);
      final data = parseIdDocumentTemplate(body);
      expect(data, isNotNull);
      expect(data!.docType, '驾驶证');
      expect(data.name, '李四');
      expect(data.docNumber, isNull);
    });

    test('normal case: succeeds with only docNumber anchor', () {
      const body = '证件号码: 440301199501010001\n姓名: 王五';
      expect(isIdDocumentTemplate(body), isTrue);
      final data = parseIdDocumentTemplate(body);
      expect(data, isNotNull);
      expect(data!.docNumber, '440301199501010001');
      expect(data.name, '王五');
      expect(data.docType, isNull);
    });

    test('missing anchor: returns null when neither docType nor docNumber is present', () {
      const body = '''
姓名：张三
有效期至：2030-12-31
备注：没有证件类型或号码
''';

      expect(isIdDocumentTemplate(body), isFalse);
      expect(parseIdDocumentTemplate(body), isNull);
    });

    test('missing anchor: empty or whitespace body returns null', () {
      expect(isIdDocumentTemplate(''), isFalse);
      expect(parseIdDocumentTemplate(''), isNull);
      expect(isIdDocumentTemplate('   \n  \n  '), isFalse);
      expect(parseIdDocumentTemplate('   \n  \n  '), isNull);
    });

    test('invalid label: returns null when line contains unrecognized label', () {
      const body = '''
证件类型：身份证
姓名：张三
证件号码：110101199003072345
家庭住址：北京市朝阳区
''';

      expect(isIdDocumentTemplate(body), isFalse);
      expect(parseIdDocumentTemplate(body), isNull);
    });

    test('invalid format: returns null when line has no colon separator', () {
      const body = '''
证件类型：身份证
这只是一行普通的说明文字
证件号码：110101199003072345
''';

      expect(isIdDocumentTemplate(body), isFalse);
      expect(parseIdDocumentTemplate(body), isNull);
    });
  });
}
