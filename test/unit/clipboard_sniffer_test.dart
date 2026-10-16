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
      expect(data.bannerLabel, '检测到证件号');
      expect(data.actionLabel, '存为证件');
      expect(data.templateId, 'id_document');
      expect(data.initialBody, contains('110101199003072345'));
      expect(data.previewText, '1101****2345');
    });

    test('sniffs 18-digit ID ending with X', () {
      final data = sniffClipboardText('33010219951112482X');
      expect(data, isNotNull);
      expect(data!.type, SniffedType.idDocument);
      expect(data.previewText, '3301****482X');
    });

    test('sniffs address with phone number', () {
      final data = sniffClipboardText('张三 13800138000 上海市徐汇区宜山路700号');
      expect(data, isNotNull);
      expect(data!.type, SniffedType.address);
      expect(data.bannerLabel, '检测到地址');
      expect(data.actionLabel, '存为地址');
      expect(data.templateId, 'address');
      expect(data.initialBody, contains('13800138000'));
      expect(data.initialBody, contains('上海市徐汇区宜山路700号'));
    });

    test('sniffs address without phone number', () {
      final data = sniffClipboardText('北京市海淀区中关村南大街5号楼');
      expect(data, isNotNull);
      expect(data!.type, SniffedType.address);
      expect(data.bannerLabel, '检测到地址');
      expect(data.actionLabel, '存为地址');
      expect(data.initialBody, contains('北京市海淀区中关村南大街5号楼'));
    });

    test('sniffs http/https URLs', () {
      final data = sniffClipboardText('请访问 https://github.com/login 完成登录');
      expect(data, isNotNull);
      expect(data!.type, SniffedType.link);
      expect(data.bannerLabel, '检测到链接');
      expect(data.actionLabel, '存为网站账号');
      expect(data.previewText, 'github.com');
      expect(data.templateId, 'password');
      expect(data.initialBody, contains('https://github.com/login'));
    });

    test('returns null for generic unstructured text', () {
      expect(sniffClipboardText('明天下午两点开会讨论需求'), isNull);
      expect(sniffClipboardText('Hello this is a regular chat message'), isNull);
    });
  });
}
