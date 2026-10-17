// lib/features/records/data/id_doc_migration.dart
// Migration from legacy "label: value" body text to structured [IdDocData].
// (Round 4 §1). Pure functions, no UI, no side effects — covered by unit tests.

import 'dart:convert';

import 'package:suicun/features/records/domain/id_doc_data.dart';

/// Canonical document type keys (must match the shared interface).
const List<String> kIdDocTypeKeys = [
  'passport',
  'driver_license',
  'national_id',
  'residence_permit',
  'social_security',
  'health_insurance',
  'student_id',
  'cn_resident_id',
  'hk_mo_permit',
  'tw_permit',
  'other',
];

/// Maps legacy type names (Chinese/English) to canonical keys.
/// Unmatched names fall back to 'other'.
const Map<String, String> _kTypeNameMap = {
  // Chinese
  '身份证': 'cn_resident_id',
  '居民身份证': 'cn_resident_id',
  '护照': 'passport',
  '驾驶证': 'driver_license',
  '驾照': 'driver_license',
  '机动车驾驶证': 'driver_license',
  '港澳通行证': 'hk_mo_permit',
  '港澳居民来往内地通行证': 'hk_mo_permit',
  '台湾通行证': 'tw_permit',
  '台湾居民来往大陆通行证': 'tw_permit',
  '社保卡': 'social_security',
  '社会保障卡': 'social_security',
  '医保卡': 'health_insurance',
  '医疗保险卡': 'health_insurance',
  '学生证': 'student_id',
  '学生卡': 'student_id',
  '居住证': 'residence_permit',
  '暂住证': 'residence_permit',
  '其他': 'other',
  // English (lowercased)
  'id card': 'cn_resident_id',
  'national id': 'national_id',
  'national id card': 'national_id',
  'passport': 'passport',
  'driver license': 'driver_license',
  'driving license': 'driver_license',
  'hk/mo permit': 'hk_mo_permit',
  'hong kong/macao permit': 'hk_mo_permit',
  'tw permit': 'tw_permit',
  'taiwan permit': 'tw_permit',
  'social security': 'social_security',
  'social security card': 'social_security',
  'health insurance': 'health_insurance',
  'health insurance card': 'health_insurance',
  'student id': 'student_id',
  'student card': 'student_id',
  'residence permit': 'residence_permit',
  'other': 'other',
};

/// Legacy field labels (without colon) in both languages.
/// Maps normalized label -> field key.
const Map<String, String> _kLabelMap = {
  // Chinese
  '证件类型': 'type',
  '姓名': 'name',
  '证件号码': 'number',
  '有效期至': 'expiry',
  '证件照片正面': 'photoFront',
  '证件照片反面': 'photoBack',
  '备注': 'note',
  // English (lowercased for matching)
  'document type': 'type',
  'name': 'name',
  'document number': 'number',
  'valid until': 'expiry',
  'id photo front': 'photoFront',
  'id photo back': 'photoBack',
  'notes': 'note',
  'note': 'note',
};

/// Parses a legacy "label: value" body into [IdDocData].
///
/// Returns `null` if the body does not look like an ID document template
/// (no recognized anchor fields). On parse failure for individual fields,
/// the raw text is preserved in [IdDocData.note] with type 'other'.
///
/// Rules:
/// - Each non-empty line must be `label: value` or `label：value`
///   (half-width `:` or full-width `：`).
/// - Labels are matched case-insensitively for English, exactly for Chinese.
/// - At least one anchor field (type/number) must be present.
IdDocData? parseLegacyIdDocBody(String body) {
  if (body.trim().isEmpty) return null;

  final fields = <String, String>{};
  final unmatchedLines = <String>[];

  for (final rawLine in body.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;

    // Split on first colon (half-width or full-width, whichever comes first)
    var colonIdx = line.indexOf(':');
    final fullWidthIdx = line.indexOf('：');
    if (colonIdx == -1 || (fullWidthIdx != -1 && fullWidthIdx < colonIdx)) {
      colonIdx = fullWidthIdx;
    }
    if (colonIdx == -1) {
      unmatchedLines.add(line);
      continue;
    }

    final label = line.substring(0, colonIdx).trim();
    final value = line.substring(colonIdx + 1).trim();

    // Normalize label: Chinese as-is, English lowercased
    final normalizedLabel = _isAscii(label) ? label.toLowerCase() : label;
    final fieldKey = _kLabelMap[normalizedLabel];

    if (fieldKey == null) {
      unmatchedLines.add(line);
      continue;
    }

    // Last occurrence wins for duplicate labels
    fields[fieldKey] = value;
  }

  // Anchor check: must have at least type or number
  if (!fields.containsKey('type') && !fields.containsKey('number')) {
    return null;
  }

  // Map type name to canonical key
  final rawType = fields['type']?.trim() ?? '';
  final typeKey = _mapTypeName(rawType);

  // Parse expiry date (may be empty or "长期"/"permanent")
  DateTime? expiryDate;
  var noExpiry = false;
  final expiryRaw = fields['expiry']?.trim() ?? '';
  if (expiryRaw.isNotEmpty) {
    if (_isNoExpiryText(expiryRaw)) {
      noExpiry = true;
    } else {
      expiryDate = DateTime.tryParse(_normalizeDate(expiryRaw));
    }
  }

  // Build note: original note field + unmatched lines + unmapped type name
  final noteParts = <String>[];
  final originalNote = fields['note']?.trim() ?? '';
  if (originalNote.isNotEmpty) noteParts.add(originalNote);
  if (typeKey == 'other' && rawType.isNotEmpty) {
    noteParts.add('原证件类型: $rawType');
  }
  if (unmatchedLines.isNotEmpty) {
    noteParts.add('未识别内容:\n${unmatchedLines.join('\n')}');
  }

  return IdDocData(
    type: typeKey,
    name: _nullIfEmpty(fields['name']),
    number: _nullIfEmpty(fields['number']),
    expiryDate: expiryDate,
    noExpiry: noExpiry,
    photoFront: _nullIfEmpty(fields['photoFront']),
    photoBack: _nullIfEmpty(fields['photoBack']),
    note: noteParts.isEmpty ? null : noteParts.join('\n'),
  );
}

/// Maps a legacy type name to a canonical key.
/// Returns 'other' if no match found.
String _mapTypeName(String rawType) {
  if (rawType.isEmpty) return 'other';
  final normalized =
      _isAscii(rawType) ? rawType.toLowerCase().trim() : rawType.trim();
  return _kTypeNameMap[normalized] ?? 'other';
}

/// Checks if text indicates "no expiry" (长期, 永久, permanent, etc.)
bool _isNoExpiryText(String text) {
  final lower = text.toLowerCase();
  return lower.contains('长期') ||
      lower.contains('永久') ||
      lower.contains('permanent') ||
      lower.contains('indefinite') ||
      lower == '无' ||
      lower == 'n/a' ||
      lower == 'na';
}

/// Normalizes common date formats to ISO 8601 for DateTime.tryParse.
/// Handles: 2030-01-01, 2030/01/01, 2030.01.01, 20300101
String _normalizeDate(String raw) {
  var s = raw.trim();
  // 20300101 -> 2030-01-01
  if (RegExp(r'^\d{8}$').hasMatch(s)) {
    s = '${s.substring(0, 4)}-${s.substring(4, 6)}-${s.substring(6, 8)}';
  } else {
    s = s.replaceAll('/', '-').replaceAll('.', '-');
  }
  return s;
}

String? _nullIfEmpty(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  return s.trim();
}

bool _isAscii(String s) {
  return s.codeUnits.every((c) => c < 128);
}

/// Result of attempting a lazy migration.
class IdDocMigrationResult {
  const IdDocMigrationResult({
    required this.data,
    required this.migrated,
  });

  /// The structured data (null if body is not an ID doc template).
  final IdDocData? data;

  /// True if a migration was performed (data was parsed from legacy body).
  final bool migrated;
}

/// Attempts lazy migration: if [existingJson] is null/empty and [body] looks
/// like a legacy ID document template, parses it into [IdDocData].
///
/// Returns [IdDocMigrationResult] with the parsed data and whether migration
/// occurred. The caller is responsible for writing the result back to storage.
IdDocMigrationResult tryMigrateIdDocData({
  required String? existingJson,
  required String body,
}) {
  // Already has structured data — no migration needed
  if (existingJson != null && existingJson.trim().isNotEmpty) {
    try {
      final map = jsonDecode(existingJson) as Map<String, dynamic>;
      final data = IdDocData.fromJson(map);
      return IdDocMigrationResult(data: data, migrated: false);
    } catch (_) {
      // Corrupted JSON — fall through to try parsing body
    }
  }

  final parsed = parseLegacyIdDocBody(body);
  if (parsed == null) {
    return const IdDocMigrationResult(data: null, migrated: false);
  }

  return IdDocMigrationResult(data: parsed, migrated: true);
}
