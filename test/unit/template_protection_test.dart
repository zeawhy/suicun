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
      // Simulates accidental corruption: label modified (colon-less line
      // after a non-notes field is still rejected).
      const body = '网站/应用：https://github.com\n用户名：testuser\n密码 secret123\n备注：personal';
      expect(parsePasswordTemplate(body), isNull);
    });

    test('password template with freeform line after username fails', () {
      // A colon-less line after 用户名 is not a notes continuation.
      const body = '网站/应用：https://github.com\n用户名：testuser\nsome random note\n密码：secret123';
      expect(parsePasswordTemplate(body), isNull);
    });

    test('password template with freeform first line fails', () {
      // A body starting with freeform text never matches.
      const body = 'hello world\n密码：secret123';
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

  group('Round 9: tolerant template recognition', () {
    test('password with custom labeled line parses and preserves it', () {
      const body = '网站/应用：https://github.com\n用户名：testuser\n密码：secret123\n密保问题：宠物名\n备注：personal';
      final data = parsePasswordTemplate(body);
      expect(data, isNotNull);
      expect(data!.extraLines, ['密保问题：宠物名']);
      expect(data.password, 'secret123');
    });

    test('password with multi-line notes parses', () {
      const body = '网站/应用：github\n用户名：u\n密码：p\n备注：第一行\n第二行';
      final data = parsePasswordTemplate(body);
      expect(data, isNotNull);
      expect(data!.notes, '第一行\n第二行');
    });

    test('password with multi-line notes round-trips through sync shape', () {
      // Simulates what _syncBody produces: canonical fields + extra lines.
      const body = '网站/应用：github\n用户名：u\n密码：p\n备注：第一行\n第二行\n密保问题：宠物名';
      final data = parsePasswordTemplate(body);
      expect(data, isNotNull);
      expect(data!.notes, '第一行\n第二行');
      expect(data.extraLines, ['密保问题：宠物名']);
    });

    test('contact with only address parses (address is an anchor)', () {
      const body = '地址：北京市朝阳区建国路88号';
      final data = parseContactTemplate(body);
      expect(data, isNotNull);
      expect(data!.address, '北京市朝阳区建国路88号');
    });

    test('contact with only address + notes parses', () {
      const body = '地址：北京市朝阳区\n备注：公司地址';
      expect(parseContactTemplate(body), isNotNull);
    });

    test('contact with multi-line address parses', () {
      const body = '姓名：张三\n地址：北京市\n朝阳区建国路\n备注：';
      final data = parseContactTemplate(body);
      expect(data, isNotNull);
      expect(data!.address, '北京市\n朝阳区建国路');
    });

    test('contact with custom labeled line parses and preserves it', () {
      const body = '姓名：张三\n电话：138\n微信：wxid123\n地址：北京';
      final data = parseContactTemplate(body);
      expect(data, isNotNull);
      expect(data!.extraLines, ['微信：wxid123']);
      expect(data.phone, '138');
    });

    test('contact with notes-only body still fails (notes is not an anchor)', () {
      const body = '备注：朋友';
      expect(parseContactTemplate(body), isNull);
    });

    test('contact with broken label still fails', () {
      const body = '姓名：张三\n电话 13800138000\n邮箱：test@example.com';
      expect(parseContactTemplate(body), isNull);
    });

    test('idea with custom labeled line parses and preserves it', () {
      const body = '灵感：test idea\n来源：test source\n下一步行动：test action\n标签：重要';
      final data = parseIdeaTemplate(body);
      expect(data, isNotNull);
      expect(data!.extraLines, ['标签：重要']);
    });

    test('idea with broken label still fails', () {
      const body = '灵感：test idea\n来源 test source\n下一步行动：test action';
      expect(parseIdeaTemplate(body), isNull);
    });

    test('plain note with unknown labels and no anchor does not match', () {
      const body = '时间：2024-01-01\n地点：会议室';
      expect(parsePasswordTemplate(body), isNull);
      expect(parseContactTemplate(body), isNull);
      expect(parseIdeaTemplate(body), isNull);
    });
  });
}
