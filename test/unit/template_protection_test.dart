// test/unit/template_protection_test.dart
// Round 8: Regression tests for template loss protection.
// Ensures that valid template bodies cannot be accidentally corrupted.

import 'package:flutter_test/flutter_test.dart';
import 'package:suicun/features/records/presentation/template_views/template_detector.dart';

void main() {
  group('Template parsers - valid bodies', () {
    test('password template parses', () {
      const body = '网站/应用：https://github.com\n用户名：testuser\n密码：secret123\n备注：personal';
      expect(parsePasswordTemplate(body), isNotNull);
    });

    test('password template with empty values parses', () {
      const body = '网站/应用：\n用户名：\n密码：\n备注：';
      expect(parsePasswordTemplate(body), isNotNull);
    });

    test('idea template parses', () {
      const body = '灵感：test idea\n来源：test source\n下一步行动：test action';
      expect(parseIdeaTemplate(body), isNotNull);
    });

    test('todo template parses', () {
      const body = '☐ 事项一\n☐ 事项二\n☑ 事项三';
      expect(parseTodoTemplate(body), isNotNull);
    });

    test('contact template parses', () {
      const body = '姓名：张三\n电话：13800138000\n邮箱：test@example.com\n地址：北京市\n备注：朋友';
      expect(parseContactTemplate(body), isNotNull);
    });
  });

  group('Template parsers - corrupted bodies fail', () {
    test('password template with broken label fails', () {
      // Simulates accidental corruption: label modified
      const body = '网站/应用：https://github.com\n用户名：testuser\n密码 secret123\n备注：personal';
      expect(parsePasswordTemplate(body), isNull);
    });

    test('password template with extra invalid line fails', () {
      // Simulates user adding a freeform line
      const body = '网站/应用：https://github.com\n用户名：testuser\n密码：secret123\n备注：personal\nThis is a note';
      expect(parsePasswordTemplate(body), isNull);
    });

    test('idea template with broken label fails', () {
      const body = '灵感：test idea\n来源 test source\n下一步行动：test action';
      expect(parseIdeaTemplate(body), isNull);
    });

    test('todo template with non-checklist line fails', () {
      const body = '☐ 事项一\nJust some text\n☐ 事项三';
      expect(parseTodoTemplate(body), isNull);
    });

    test('contact template with broken label fails', () {
      const body = '姓名：张三\n电话 13800138000\n邮箱：test@example.com';
      expect(parseContactTemplate(body), isNull);
    });
  });

  group('Template parsers - English variants', () {
    test('password template English parses', () {
      const body = 'Website/App: https://github.com\nUsername: testuser\nPassword: secret123\nNotes: personal';
      expect(parsePasswordTemplate(body), isNotNull);
    });

    test('idea template English parses', () {
      const body = 'Idea: test idea\nSource: test source\nNext action: test action';
      expect(parseIdeaTemplate(body), isNotNull);
    });

    test('contact template English parses', () {
      const body = 'Name: John\nPhone: 1234567890\nEmail: test@example.com';
      expect(parseContactTemplate(body), isNotNull);
    });
  });
}
