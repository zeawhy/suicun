// test/unit/cn_id_validator_test.dart
// Unit tests for GB 11643 ID validation (Round 4 §4).

import 'package:flutter_test/flutter_test.dart';
import 'package:suicun/shared/utils/cn_id_validator.dart';

void main() {
  group('isValidCnIdNumber', () {
    test('正确号码返回 true', () {
      // 110101199003072340: verified valid (checksum 0)
      expect(isValidCnIdNumber('110101199003072340'), isTrue);
    });

    test('末位小写 x 也有效（不分大小写）', () {
      expect(isValidCnIdNumber('11010519491231002x'), isTrue);
    });

    test('末位 X 大写有效', () {
      // 11010519491231002X is a classic valid example
      expect(isValidCnIdNumber('11010519491231002X'), isTrue);
      expect(isValidCnIdNumber('11010519491231002x'), isTrue);
    });

    test('错一位返回 false', () {
      // Change one digit of valid number 110101199003072340
      expect(isValidCnIdNumber('110101199003072341'), isFalse);
    });

    test('长度不对返回 false', () {
      expect(isValidCnIdNumber('11010119900307234'), isFalse); // 17位
      expect(isValidCnIdNumber('1101011990030723456'), isFalse); // 19位
      expect(isValidCnIdNumber(''), isFalse);
    });

    test('非数字字符返回 false', () {
      expect(isValidCnIdNumber('11010119900307234A'), isFalse);
      expect(isValidCnIdNumber('ABCDEFGHIJKLMNOPQR'), isFalse);
    });
  });

  group('validateCnIdNumber', () {
    test('正确号码返回 null', () {
      expect(validateCnIdNumber('110101199003072340'), isNull);
    });

    test('空返回错误原因', () {
      expect(validateCnIdNumber(''), '证件号码不能为空');
    });

    test('长度错误返回原因', () {
      expect(validateCnIdNumber('123'), '身份证号码必须为18位');
    });

    test('校验位错误返回原因', () {
      expect(validateCnIdNumber('110101199003072341'), '校验位错误');
    });
  });
}
