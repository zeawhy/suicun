// lib/features/records/presentation/secret_line.dart
// Parser for secret lines (password masking in view mode).

import 'package:flutter/foundation.dart';

/// Represents a single line parsed for secret/password masking.
@immutable
class SecretLine {
  const SecretLine({
    required this.isSecret,
    required this.rawLine,
    this.label,
    this.value,
  });

  /// Whether this line matches the secret/password line pattern.
  final bool isSecret;

  /// The original unmodified line text.
  final String rawLine;

  /// The label matched at the start of the line (e.g. "密码：" or "Password:").
  final String? label;

  /// The actual secret/password trimmed from after the colon (can be empty).
  final String? value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SecretLine &&
          runtimeType == other.runtimeType &&
          isSecret == other.isSecret &&
          rawLine == other.rawLine &&
          label == other.label &&
          value == other.value;

  @override
  int get hashCode => Object.hash(isSecret, rawLine, label, value);

  @override
  String toString() =>
      'SecretLine(isSecret: $isSecret, rawLine: "$rawLine", label: "$label", value: "$value")';
}

final _secretLineRegExp =
    RegExp(r'^(密码|Password)\s*[:：]', caseSensitive: false);

/// Parses [text] line by line to detect secret lines matching `^(密码|Password)\s*[:：]`.
List<SecretLine> parseSecretLines(String text) {
  if (text.isEmpty) {
    return const [];
  }

  final lines = text.replaceAll('\r\n', '\n').split('\n');
  final result = <SecretLine>[];

  for (final line in lines) {
    final match = _secretLineRegExp.firstMatch(line);
    if (match != null) {
      final label = match.group(0)!;
      final value = line.substring(match.end).trim();
      result.add(
        SecretLine(
          isSecret: true,
          rawLine: line,
          label: label,
          value: value,
        ),
      );
    } else {
      result.add(
        SecretLine(
          isSecret: false,
          rawLine: line,
        ),
      );
    }
  }

  return result;
}
