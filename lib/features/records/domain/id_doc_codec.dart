// lib/features/records/domain/id_doc_codec.dart
// Round 5 §1.2: ID document body codec.
//
// Storage format (in Records.body, no schema change):
//   line 1: "suivault:id_doc:v2"  (marker)
//   line 2: single-line JSON of IdDocData.toJson()
//
// - [isIdDocBody] returns true for both new and legacy ("label: value") bodies.
// - [decodeIdDocBody] tries the new format first, then the legacy format.
// - [encodeIdDocBody] only ever emits the new format (no localized text).

import 'dart:convert';

import 'package:suicun/features/records/domain/id_doc_data.dart';
import 'package:suicun/features/records/presentation/template_views/template_detector.dart';

/// Marker line identifying the new structured ID document body format.
const kIdDocBodyMarker = 'suivault:id_doc:v2';

/// Matches one or more Markdown list/checkbox prefixes at the very start of
/// a body: `- `, `* `, `- [ ] `, `- [x] `/`- [X] `, possibly repeated, with
/// optional surrounding spaces/tabs. (Round 7 §3.3: the "insert todo"
/// button used to prepend `- [ ] ` to ID document bodies.)
final RegExp _kLeadingListPrefixPattern =
    RegExp(r'^(?:[ \t]*(?:-\s\[[ xX]\]|[-*])[ \t]*)+');

/// Strips leading Markdown list/checkbox prefixes from [body].
///
/// Returns the stripped body, or `null` when no prefix was present.
String? stripIdDocBodyPrefix(String body) {
  final match = _kLeadingListPrefixPattern.firstMatch(body);
  if (match == null) return null;
  return body.substring(match.end);
}

/// Returns true if [body] is an ID document body (new or legacy format).
bool isIdDocBody(String body) {
  final trimmed = body.trimLeft();
  if (trimmed.startsWith(kIdDocBodyMarker)) return true;
  // Round 7 §3.3: tolerate Markdown list/checkbox prefixes before the marker.
  final stripped = stripIdDocBodyPrefix(body);
  if (stripped != null && stripped.trimLeft().startsWith(kIdDocBodyMarker)) {
    return true;
  }
  return parseIdDocumentTemplate(body) != null;
}

/// Returns true if [body] is in the new (marker + JSON) format.
bool isNewIdDocBody(String body) {
  return body.trimLeft().startsWith(kIdDocBodyMarker);
}

/// Decodes an ID document body into [IdDocData].
///
/// Tries the new format first; falls back to the legacy "label: value"
/// format via [parseIdDocumentTemplate]. Returns null if the body is not
/// an ID document body.
///
/// [origTypeLabel] is the localized prefix used when an unmappable legacy
/// type name is preserved at the start of [IdDocData.note]
/// (e.g. "原类型" / "Original type").
IdDocData? decodeIdDocBody(String body, {String origTypeLabel = '原类型'}) {
  // New format: marker line + single-line JSON.
  final trimmedLeft = body.trimLeft();
  if (trimmedLeft.startsWith(kIdDocBodyMarker)) {
    return _decodeNewFormat(body);
  }

  // Round 7 §3.3: lenient — strip Markdown list/checkbox prefixes, then
  // look for the marker again (e.g. bodies damaged by the "insert todo"
  // button: "- [ ] suivault:id_doc:v2\n{...}").
  final stripped = stripIdDocBodyPrefix(body);
  if (stripped != null && stripped.trimLeft().startsWith(kIdDocBodyMarker)) {
    return _decodeNewFormat(stripped);
  }

  // Legacy format.
  final template = parseIdDocumentTemplate(body);
  if (template == null) return null;
  return _convertLegacyTemplate(template, origTypeLabel: origTypeLabel);
}

/// Decodes a marker-led new-format body. Returns null when the marker is
/// present but the JSON payload is unusable (never mis-parses as legacy).
IdDocData? _decodeNewFormat(String body) {
  final lines = body.split('\n');
  if (lines.length >= 2) {
    // JSON may itself contain newlines in theory; join the remainder.
    final jsonText = lines.sublist(1).join('\n').trim();
    if (jsonText.isNotEmpty) {
      try {
        final map = jsonDecode(jsonText) as Map<String, dynamic>;
        return IdDocData.fromJson(map);
      } catch (_) {
        // Corrupted new-format body — fall through to null below.
      }
    }
  }
  // Marker present but JSON unusable: do not silently drop; treat as
  // non-decodable rather than mis-parsing as legacy.
  return null;
}

/// Round 7 §3.3: repairs a Markdown-prefixed ID document body.
///
/// Returns the canonical standard-format body when [body] carries list/
/// checkbox prefixes but still decodes; otherwise returns null (no prefix,
/// or undecodable even after stripping).
String? repairPrefixedIdDocBody(String body) {
  if (stripIdDocBodyPrefix(body) == null) return null;
  final data = decodeIdDocBody(body);
  if (data == null) return null;
  final canonical = encodeIdDocBody(data);
  if (canonical == body) return null;
  return canonical;
}

/// Encodes [data] into the new body format. The output contains no
/// localized text — only the marker line and JSON.
String encodeIdDocBody(IdDocData data) {
  return '$kIdDocBodyMarker\n${jsonEncode(data.toJson())}';
}

/// Returns a human-readable plain-text rendering of [data] for export,
/// search summaries, and auto-categorization input.
///
/// Contains no JSON marker and no `id_photos/` paths.
String idDocToReadableText({
  required IdDocData data,
  required String typeName,
  required String nameLabel,
  required String numberLabel,
  required String expiryLabel,
  required String noteLabel,
  required String noExpiryText,
  required String Function(DateTime) formatDate,
}) {
  final sb = StringBuffer();
  sb.writeln(typeName);
  final name = data.name?.trim() ?? '';
  if (name.isNotEmpty) sb.writeln('$nameLabel: $name');
  final number = data.number?.trim() ?? '';
  if (number.isNotEmpty) sb.writeln('$numberLabel: $number');
  if (data.noExpiry) {
    sb.writeln('$expiryLabel: $noExpiryText');
  } else if (data.expiryDate != null) {
    sb.writeln('$expiryLabel: ${formatDate(data.expiryDate!)}');
  }
  final note = data.note?.trim() ?? '';
  if (note.isNotEmpty) sb.writeln('$noteLabel: $note');
  return sb.toString().trim();
}

/// Maps a legacy type display name to a canonical storage key.
///
/// Merges every name that could have been written into a legacy body:
/// - `app_zh.arb` / `app_en.arb` `idType*` values (Round 4),
/// - `id_doc_type.dart` legacy label tables (Round 2/3),
/// - older free-form names.
///
/// Comparison ignores case and surrounding whitespace.
/// `身份证` / `ID card` map to `cn_resident_id` (NOT `national_id`).
/// Returns 'other' when nothing matches.
String mapLegacyTypeNameToKey(String? rawType) {
  if (rawType == null) return 'other';
  final t = rawType.trim();
  if (t.isEmpty) return 'other';
  final lower = t.toLowerCase();

  // Spec priority: 身份证 / ID card -> cn_resident_id.
  if (t == '身份证' || lower == 'id card') return 'cn_resident_id';

  return _kLegacyTypeNameMap[t] ?? _kLegacyTypeNameMap[lower] ?? 'other';
}

/// Legacy type display name -> canonical storage key.
///
/// Chinese names are matched exactly (after trim); English names are
/// matched lowercased. This table merges:
/// 1. Round 4 arb `idType*` zh/en values,
/// 2. Round 2/3 `kDocTypeChineseLabels` / `kDocTypeEnglishLabels`,
/// 3. Older free-form variants seen in the wild.
const Map<String, String> _kLegacyTypeNameMap = {
  // ── Chinese (exact) ──
  // Round 4 arb
  '中国居民身份证': 'cn_resident_id',
  '护照': 'passport',
  '驾驶证': 'driver_license',
  '居留卡': 'residence_permit',
  '社保卡': 'social_security',
  '医保卡': 'health_insurance',
  '学生证': 'student_id',
  '港澳通行证': 'hk_mo_permit',
  '台湾通行证': 'tw_permit',
  '其他证件': 'other',
  '其他': 'other',
  // Round 2/3 legacy labels
  '居民身份证': 'cn_resident_id',
  '行驶证': 'other', // no equivalent in the 11-type system
  '房产证': 'other', // no equivalent in the 11-type system
  '驾照': 'driver_license',
  '机动车驾驶证': 'driver_license',
  '港澳居民来往内地通行证': 'hk_mo_permit',
  '台湾居民来往大陆通行证': 'tw_permit',
  '社会保障卡': 'social_security',
  '医疗保险卡': 'health_insurance',
  '学生卡': 'student_id',
  '居住证': 'residence_permit',
  '暂住证': 'residence_permit',

  // ── English (lowercased) ──
  // Round 4 arb
  'china resident id': 'cn_resident_id',
  'passport': 'passport',
  "driver's license": 'driver_license',
  'driver license': 'driver_license',
  'id card': 'cn_resident_id', // spec: NOT national_id
  'residence permit': 'residence_permit',
  'social security card': 'social_security',
  'health insurance card': 'health_insurance',
  'student id': 'student_id',
  'hk-macau travel permit': 'hk_mo_permit',
  'taiwan travel permit': 'tw_permit',
  'other': 'other',
  // Round 2/3 legacy labels
  'national id': 'national_id',
  'national id card': 'national_id',
  'driving license': 'driver_license',
  'vehicle license': 'other', // no equivalent
  'exit-entry permit (hk/macau)': 'hk_mo_permit',
  'property certificate': 'other', // no equivalent
  'social security': 'social_security',
  'health insurance': 'health_insurance',
  'student card': 'student_id',
};

/// Returns true if [text] means "no expiry" (长期 / No expiry and variants).
bool isNoExpiryText(String text) {
  final t = text.trim().toLowerCase();
  return t == '长期' ||
      t == 'no expiry' ||
      t == '永久' ||
      t == 'permanent' ||
      t == 'indefinite' ||
      t == '无' ||
      t == 'n/a' ||
      t == 'na';
}

/// Parses a legacy expiry text into (expiryDate, noExpiry).
///
/// - "长期" / "No expiry" (and variants) -> (null, true)
/// - "yyyy-MM-dd" (also tolerates /, ., and yyyymmdd) -> (date, false)
/// - Unparseable -> (null, false); caller should preserve the raw text.
({DateTime? expiryDate, bool noExpiry}) parseLegacyExpiry(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return (expiryDate: null, noExpiry: false);
  }
  final t = raw.trim();
  if (isNoExpiryText(t)) {
    return (expiryDate: null, noExpiry: true);
  }
  final normalized = _normalizeDate(t);
  final date = DateTime.tryParse(normalized);
  return (expiryDate: date, noExpiry: false);
}

/// Normalizes common date spellings for [DateTime.tryParse].
/// Handles: 2030-01-01, 2030/01/01, 2030.01.01, 20300101.
String _normalizeDate(String raw) {
  var s = raw.trim();
  if (RegExp(r'^\d{8}$').hasMatch(s)) {
    s = '${s.substring(0, 4)}-${s.substring(4, 6)}-${s.substring(6, 8)}';
  } else {
    s = s.replaceAll('/', '-').replaceAll('.', '-');
  }
  return s;
}

/// Converts a parsed legacy template into [IdDocData].
IdDocData _convertLegacyTemplate(
  IdDocumentTemplateData template, {
  required String origTypeLabel,
}) {
  final rawType = template.docType?.trim() ?? '';
  final typeKey = mapLegacyTypeNameToKey(rawType);

  final expiry = parseLegacyExpiry(template.validUntil);
  final expiryRaw = template.validUntil?.trim() ?? '';
  final expiryUnparsed =
      expiryRaw.isNotEmpty && expiry.expiryDate == null && !expiry.noExpiry;

  // Build note: original note + unmappable type name + unparsable expiry.
  final noteParts = <String>[];
  final originalNote = template.notes?.trim() ?? '';
  if (originalNote.isNotEmpty) noteParts.add(originalNote);
  final isGenuineOther = typeKey == 'other' &&
      (rawType.isEmpty ||
          rawType == '其他' ||
          rawType == '其他证件' ||
          rawType.toLowerCase() == 'other');
  if (!isGenuineOther && rawType.isNotEmpty && typeKey == 'other') {
    noteParts.insert(0, '$origTypeLabel：$rawType');
  }
  if (expiryUnparsed) {
    noteParts.add('原有效期：$expiryRaw');
  }

  String? nullIfEmpty(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    return s.trim();
  }

  return IdDocData(
    type: typeKey,
    name: nullIfEmpty(template.name),
    number: nullIfEmpty(template.docNumber),
    // Legacy bodies have no issuingCountry / issueDate fields.
    issuingCountry: null,
    issueDate: null,
    expiryDate: expiry.expiryDate,
    noExpiry: expiry.noExpiry,
    photoFront: nullIfEmpty(template.photoFront),
    photoBack: nullIfEmpty(template.photoBack),
    note: noteParts.isEmpty ? null : noteParts.join('\n'),
  );
}
