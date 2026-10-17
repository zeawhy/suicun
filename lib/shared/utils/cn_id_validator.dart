// lib/shared/utils/cn_id_validator.dart
// GB 11643 Chinese Resident Identity Card number validation (Round 4 §4).
// Pure functions, no UI, no side effects — covered by unit tests.

/// Checksum weights for the first 17 digits (GB 11643).
const List<int> _kWeights = [7, 9, 10, 5, 8, 4, 2, 1, 6, 3, 7, 9, 10, 5, 8, 4, 2];

/// Checksum mapping: remainder -> check digit.
const List<String> _kCheckDigits = [
  '1', '0', 'X', '9', '8', '7', '6', '5', '4', '3', '2'
];

/// Validates a Chinese Resident Identity Card number (18 digits).
bool isValidCnIdNumber(String raw) {
  final s = raw.trim().toUpperCase();
  if (s.length != 18) return false;
  for (var i = 0; i < 17; i++) {
    final c = s.codeUnitAt(i);
    if (c < 0x30 || c > 0x39) return false;
  }
  final last = s[17];
  if (!RegExp(r'^[0-9X]$').hasMatch(last)) return false;
  var sum = 0;
  for (var i = 0; i < 17; i++) {
    sum += (s.codeUnitAt(i) - 0x30) * _kWeights[i];
  }
  return last == _kCheckDigits[sum % 11];
}

/// Validates a CN ID number and returns the reason if invalid.
String? validateCnIdNumber(String raw) {
  final s = raw.trim().toUpperCase();
  if (s.isEmpty) return '证件号码不能为空';
  if (s.length != 18) return '身份证号码必须为18位';
  for (var i = 0; i < 17; i++) {
    final c = s.codeUnitAt(i);
    if (c < 0x30 || c > 0x39) return '前17位必须为数字';
  }
  final last = s[17];
  if (!RegExp(r'^[0-9X]$').hasMatch(last)) return '末位必须为数字或X';
  var sum = 0;
  for (var i = 0; i < 17; i++) {
    sum += (s.codeUnitAt(i) - 0x30) * _kWeights[i];
  }
  if (last != _kCheckDigits[sum % 11]) return '校验位错误';
  return null;
}
