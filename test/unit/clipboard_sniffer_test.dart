// test/unit/clipboard_sniffer_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:suicun/features/records/presentation/clipboard_sniffer.dart';

void main() {
  group('sniffClipboardText', () {
    test('returns null for empty or short text', () {
      expect(sniffClipboardText(''), isNull);
      expect(sniffClipboardText('abc'), isNull);
      expect(sniffClipboardText('   '), isNull);
    });

    test('sniffs 18-digit Chinese Resident ID number', () {
      final data = sniffClipboardText('本人身份证号是 110101199003072345 请查收');
      expect(data, isNotNull);
      expect(data!.type, SniffedType.idDocument);
      expect(data.templateId, 'id_document');
      expect(data.initialBody, contains('110101199003072345'));
      expect(data.initialBody, contains('证件类型：'));
      expect(data.previewText, '1101****2345');
    });

    test('sniffs 18-digit ID ending with X', () {
      final data = sniffClipboardText('33010219951112482X');
      expect(data, isNotNull);
      expect(data!.type, SniffedType.idDocument);
      expect(data.previewText, '3301****482X');
    });

    test('sniffs 18-digit ID with English body labels', () {
      final data = sniffClipboardText('本人身份证号是 110101199003072345 请查收',
          isEnglish: true);
      expect(data, isNotNull);
      expect(data!.type, SniffedType.idDocument);
      expect(data.initialBody, contains('Document type:'));
      expect(data.initialBody, contains('Document number: 110101199003072345'));
      expect(data.initialBody, contains('Name: '));
    });

    test('sniffs address with phone number', () {
      final data = sniffClipboardText('张三 13800138000 上海市徐汇区宜山路700号');
      expect(data, isNotNull);
      expect(data!.type, SniffedType.address);
      expect(data.templateId, 'address');
      expect(data.initialBody, contains('13800138000'));
      expect(data.initialBody, contains('上海市徐汇区宜山路700号'));
      expect(data.initialBody, contains('姓名：'));
    });

    test('sniffs address with English body labels', () {
      final data = sniffClipboardText('张三 13800138000 上海市徐汇区宜山路700号',
          isEnglish: true);
      expect(data, isNotNull);
      expect(data!.type, SniffedType.address);
      expect(data.initialBody, contains('Name: '));
      expect(data.initialBody, contains('Phone: 13800138000'));
      expect(data.initialBody, contains('Address: '));
    });

    test('sniffs address without phone number', () {
      final data = sniffClipboardText('北京市海淀区中关村南大街5号楼');
      expect(data, isNotNull);
      expect(data!.type, SniffedType.address);
      expect(data.initialBody, contains('北京市海淀区中关村南大街5号楼'));
    });

    test('sniffs http/https URLs', () {
      final data = sniffClipboardText('请访问 https://github.com/login 完成登录');
      expect(data, isNotNull);
      expect(data!.type, SniffedType.link);
      expect(data.previewText, 'github.com');
      expect(data.templateId, 'password');
      expect(data.initialBody, contains('https://github.com/login'));
      expect(data.initialBody, contains('网站/应用：'));
    });

    test('sniffs URL with English body labels', () {
      final data = sniffClipboardText('请访问 https://github.com/login 完成登录',
          isEnglish: true);
      expect(data, isNotNull);
      expect(data!.type, SniffedType.link);
      expect(data.initialBody, contains('Website/App: https://github.com/login'));
      expect(data.initialBody, contains('Username: '));
      expect(data.initialBody, contains('Password: '));
    });

    test('returns null for generic unstructured text', () {
      expect(sniffClipboardText('明天下午两点开会讨论需求'), isNull);
      expect(sniffClipboardText('Hello this is a regular chat message'), isNull);
    });
  });
}
