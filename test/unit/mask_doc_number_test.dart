// test/unit/mask_doc_number_test.dart
// Unit tests for maskDocNumber / formatDocNumber (spec §2.6).

import 'package:flutter_test/flutter_test.dart';
import 'package:suicun/shared/utils/mask_doc_number.dart';

void main() {
  group('maskDocNumber', () {
    test('18 位：前 4 + 3 组 **** + 后 4', () {
      expect(
        maskDocNumber('110101199003072345'),
        '1101 **** **** **** 2345',
      );
    });

    test('15 位：前 4 + 2 组 **** + 后 4', () {
      expect(
        maskDocNumber('123456789012345'),
        '1234 **** **** 2345',
      );
    });

    test('12 位：前 4 + 1 组 **** + 后 4', () {
      expect(
        maskDocNumber('123456789012'),
        '1234 **** 9012',
      );
    });

    test('9 位（护照）：前 2 + 星号补足 + 后 2，不分组', () {
      expect(maskDocNumber('E12345678'), 'E1*****78');
    });

    test('7 位：前 2 + 星号补足 + 后 2', () {
      expect(maskDocNumber('AB12345'), 'AB***45');
    });

    test('6 位：全部显示 ******', () {
      expect(maskDocNumber('123456'), '******');
    });

    test('空字符串：按 ≤6 规则显示 ******', () {
      expect(maskDocNumber(''), '******');
    });
  });

  group('formatDocNumber', () {
    test('18 位：每 4 位加一个空格', () {
      expect(
        formatDocNumber('110101199003072345'),
        '1101 0119 9003 0723 45',
      );
    });

    test('12 位：每 4 位加一个空格', () {
      expect(formatDocNumber('123456789012'), '1234 5678 9012');
    });

    test('不足 12 位：原样返回', () {
      expect(formatDocNumber('E12345678'), 'E12345678');
      expect(formatDocNumber(''), '');
    });
  });
}
