// lib/shared/utils/mask_doc_number.dart
// Pure helpers for masking and formatting document numbers on the ID card
// view (spec §2.6). No UI, no side effects — covered by unit tests.

/// Masks a document number for display.
///
/// Rules:
/// - Length >= 12 (e.g. national ID): first 4 chars + one `****` group per
///   4 chars of the middle part (rounded up) + last 4 chars, space-separated.
///   Example: `110101199003072345` -> `1101 **** **** **** 2345`.
/// - Length 7-11 (e.g. passport): first 2 chars + `*` padding + last 2 chars,
///   no grouping. Example: `E12345678` -> `E1*****78`.
/// - Length <= 6: always `******`.
String maskDocNumber(String raw) {
  final len = raw.length;
  if (len >= 12) {
    final groups = ((len - 8) / 4).ceil();
    final middle = List.filled(groups, '****').join(' ');
    return '${raw.substring(0, 4)} $middle ${raw.substring(len - 4)}';
  }
  if (len >= 7) {
    return '${raw.substring(0, 2)}${'*' * (len - 4)}${raw.substring(len - 2)}';
  }
  return '******';
}

/// Formats a document number for full display: inserts a space every 4
/// characters when the number is at least 12 chars long; shorter numbers are
/// returned unchanged.
///
/// Copying always uses the raw value without spaces (handled by the caller).
String formatDocNumber(String raw) {
  if (raw.length < 12) return raw;
  final buf = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    if (i > 0 && i % 4 == 0) buf.write(' ');
    buf.write(raw[i]);
  }
  return buf.toString();
}
