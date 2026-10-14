// test/unit/secret_line_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:suicun/features/records/presentation/secret_line.dart';

void main() {
  group('parseSecretLines', () {
    test('recognizes 密码：xxx and Password: xxx', () {
      final zhLines = parseSecretLines('密码：my_secret_123');
      expect(zhLines.length, 1);
      expect(zhLines.first.isSecret, isTrue);
      expect(zhLines.first.label, '密码：');
      expect(zhLines.first.value, 'my_secret_123');
      expect(zhLines.first.rawLine, '密码：my_secret_123');

      final enLines = parseSecretLines('Password: my_en_secret');
      expect(enLines.length, 1);
      expect(enLines.first.isSecret, isTrue);
      expect(enLines.first.label, 'Password:');
      expect(enLines.first.value, 'my_en_secret');
      expect(enLines.first.rawLine, 'Password: my_en_secret');
    });

    test('recognizes empty secret values', () {
      final zhEmpty = parseSecretLines('密码：');
      expect(zhEmpty.length, 1);
      expect(zhEmpty.first.isSecret, isTrue);
      expect(zhEmpty.first.label, '密码：');
      expect(zhEmpty.first.value, '');

      final enEmptyWithSpaces = parseSecretLines('Password:   ');
      expect(enEmptyWithSpaces.length, 1);
      expect(enEmptyWithSpaces.first.isSecret, isTrue);
      expect(enEmptyWithSpaces.first.label, 'Password:');
      expect(enEmptyWithSpaces.first.value, '');
    });

    test('does not recognize non-secret lines', () {
      final lines = parseSecretLines('用户名：alice\n网站：https://example.com');
      expect(lines.length, 2);
      expect(lines[0].isSecret, isFalse);
      expect(lines[0].label, isNull);
      expect(lines[0].value, isNull);
      expect(lines[1].isSecret, isFalse);
      expect(lines[1].label, isNull);
      expect(lines[1].value, isNull);
    });

    test('does not recognize lines with "密码" or "Password" not at line start', () {
      final notAtStart1 = parseSecretLines('我的密码：123456');
      expect(notAtStart1.length, 1);
      expect(notAtStart1.first.isSecret, isFalse);
      expect(notAtStart1.first.label, isNull);
      expect(notAtStart1.first.value, isNull);

      final notAtStart2 = parseSecretLines('Remember Password: secret');
      expect(notAtStart2.length, 1);
      expect(notAtStart2.first.isSecret, isFalse);

      final withLeadingSpace = parseSecretLines(' 密码：123456');
      expect(withLeadingSpace.length, 1);
      expect(withLeadingSpace.first.isSecret, isFalse);
    });

    test('correctly parses mixed multiline text', () {
      const text = '''
网站/应用：Suicun App
用户名：hatch
密码：super_secret_42
备注：保密信息
Password: secondary_pass''';

      final lines = parseSecretLines(text);
      expect(lines.length, 5);

      expect(lines[0].isSecret, isFalse);
      expect(lines[0].rawLine, '网站/应用：Suicun App');

      expect(lines[1].isSecret, isFalse);
      expect(lines[1].rawLine, '用户名：hatch');

      expect(lines[2].isSecret, isTrue);
      expect(lines[2].label, '密码：');
      expect(lines[2].value, 'super_secret_42');

      expect(lines[3].isSecret, isFalse);
      expect(lines[3].rawLine, '备注：保密信息');

      expect(lines[4].isSecret, isTrue);
      expect(lines[4].label, 'Password:');
      expect(lines[4].value, 'secondary_pass');
    });

    test('returns empty list for empty input', () {
      expect(parseSecretLines(''), isEmpty);
    });
  });
}
