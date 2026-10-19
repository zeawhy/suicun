// lib/features/records/presentation/template_views/template_detector.dart
// Template detector to identify structured note templates from body text.

import 'package:suicun/features/records/presentation/checklist_line.dart';

/// Data extracted from a password template body.
class PasswordTemplateData {
  const PasswordTemplateData({
    this.website,
    this.username,
    this.password,
    this.notes,
    this.extraLines = const [],
  });

  final String? website;
  final String? username;
  final String? password;
  final String? notes;

  /// Custom `label: value` lines with labels outside the known template set,
  /// preserved verbatim so the template UI never drops user-added fields
  /// when re-saving (Round 9: tolerant parsing).
  final List<String> extraLines;
}

final _colonRegExp = RegExp(r'[:：]');

/// Shared line engine for `label: value` templates (password / idea / contact).
///
/// Round 9: tolerant recognition. Real-world template bodies often deviate
/// slightly from the canonical generated text (user-added custom fields,
/// multi-line notes/addresses, address-only contacts). The strict "every line
/// must carry a known label" rule made such records fall back to the raw-text
/// view on open, and worse, made [record_repository]'s template-loss guard
/// reject legitimate edits with a save error.
///
/// Rules:
/// 1. [body] must not be empty.
/// 2. The first non-empty line must be a `label: value` line (colon `:`/`：`).
///    A body starting with freeform text never matches.
/// 3. A `label: value` line whose label is in [labelToKey] assigns the field;
///    any other labeled line is tolerated and collected into [extraLines]
///    (preserved verbatim by the template views on re-save).
/// 4. A non-empty line without a colon continues the previous field's value
///    only when that field is in [continuableKeys] (free-text fields such as
///    notes/address). Otherwise the body does not match. This keeps genuine
///    corruption (e.g. a mangled `密码 secret123` label after 用户名) rejected.
/// 5. At least one field in [anchorKeys] must be present (label seen, value
///    may be empty).
///
/// Returns the field-key -> value map, or `null` when the body does not match.
Map<String, String?>? _parseLabelValueTemplate({
  required String body,
  required Map<String, String> labelToKey,
  required Set<String> anchorKeys,
  required Set<String> continuableKeys,
  required List<String> extraLines,
}) {
  if (body.trim().isEmpty) return null;

  final lines = body.replaceAll('\r\n', '\n').split('\n');
  final fields = <String, String?>{};
  var hasNonEmptyLine = false;
  // Key of the most recent *known* labeled line; used for continuations.
  String? lastKey;

  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty) {
      continue;
    }
    hasNonEmptyLine = true;

    final match = _colonRegExp.firstMatch(line);
    if (match == null) {
      // Colon-less line: continuation only after a continuable field.
      if (lastKey == null || !continuableKeys.contains(lastKey)) {
        return null;
      }
      final prev = fields[lastKey] ?? '';
      fields[lastKey] = prev.isEmpty ? line : '$prev\n$line';
      continue;
    }

    final rawLabel = line.substring(0, match.start).trim();
    final value = line.substring(match.end).trim();

    final lookupKey = rawLabel.toLowerCase();
    final key = labelToKey[rawLabel] ?? labelToKey[lookupKey];
    if (key == null) {
      // Unknown labeled line: tolerated custom field, preserved verbatim.
      // A colon-less line after this is NOT treated as a continuation.
      extraLines.add(line);
      lastKey = null;
      continue;
    }

    fields[key] = value;
    lastKey = key;
  }

  if (!hasNonEmptyLine) return null;
  if (!anchorKeys.any(fields.containsKey)) return null;
  return fields;
}

/// Detects if [body] matches the password template structure.
///
/// Rule (Round 9: tolerant):
/// 1. Body must not be empty; the first non-empty line must be `label: value`.
/// 2. Known labels assign fields; unknown `label: value` lines are tolerated
///    as user-added custom fields (preserved on re-save).
/// 3. A colon-less line continues the previous field's value only after the
///    备注/Notes field; otherwise the body does not match.
/// 4. At least one line must carry the `密码` / `Password` label.
bool isPasswordTemplate(String body) {
  return parsePasswordTemplate(body) != null;
}

/// Parses [body] into [PasswordTemplateData] if it matches the password template pattern.
/// Returns `null` if [body] does not match the password template rules.
PasswordTemplateData? parsePasswordTemplate(String body) {
  final extraLines = <String>[];
  final fields = _parseLabelValueTemplate(
    body: body,
    labelToKey: const {
      // Chinese labels
      '网站/应用': 'website',
      '用户名': 'username',
      '密码': 'password',
      '备注': 'notes',
      // English labels
      'website/app': 'website',
      'website': 'website',
      'app': 'website',
      'username': 'username',
      'password': 'password',
      'notes': 'notes',
    },
    anchorKeys: const {'password'},
    continuableKeys: const {'notes'},
    extraLines: extraLines,
  );
  if (fields == null) return null;

  return PasswordTemplateData(
    website: fields['website'],
    username: fields['username'],
    password: fields['password'],
    notes: fields['notes'],
    extraLines: extraLines,
  );
}

/// Data extracted from an idea template body.
class IdeaTemplateData {
  const IdeaTemplateData({
    this.idea,
    this.source,
    this.nextAction,
    this.extraLines = const [],
  });

  final String? idea;
  final String? source;
  final String? nextAction;

  /// Custom `label: value` lines with labels outside the known template set,
  /// preserved verbatim so the template UI never drops user-added fields
  /// when re-saving (Round 9: tolerant parsing).
  final List<String> extraLines;
}

/// Detects if [body] matches the idea template structure.
///
/// Rule (Round 9: tolerant):
/// 1. Body must not be empty; the first non-empty line must be `label: value`.
/// 2. Known labels assign fields; unknown `label: value` lines are tolerated
///    as user-added custom fields (preserved on re-save).
/// 3. A colon-less line never continues a field here: it rejects the body
///    (keeps mangled labels like `来源 test source` rejected).
/// 4. At least one line must carry the `灵感` / `Idea` label.
bool isIdeaTemplate(String body) {
  return parseIdeaTemplate(body) != null;
}

/// Parses [body] into [IdeaTemplateData] if it matches the idea template pattern.
/// Returns `null` if [body] does not match the idea template rules.
IdeaTemplateData? parseIdeaTemplate(String body) {
  final extraLines = <String>[];
  final fields = _parseLabelValueTemplate(
    body: body,
    labelToKey: const {
      // Chinese labels
      '灵感': 'idea',
      '来源': 'source',
      '下一步行动': 'nextAction',
      // English labels
      'idea': 'idea',
      'source': 'source',
      'next action': 'nextAction',
    },
    anchorKeys: const {'idea'},
    // No continuable fields: a colon-less line after any idea field
    // (e.g. a mangled `来源 test source`) must keep failing.
    continuableKeys: const {},
    extraLines: extraLines,
  );
  if (fields == null) return null;

  return IdeaTemplateData(
    idea: fields['idea'],
    source: fields['source'],
    nextAction: fields['nextAction'],
    extraLines: extraLines,
  );
}

/// A single item in a todo template.
class TodoTemplateItem {
  const TodoTemplateItem({
    required this.checked,
    required this.content,
    required this.lineIndex,
  });

  final bool checked;
  final String content;
  final int lineIndex;
}

/// Data extracted from a todo template body.
class TodoTemplateData {
  const TodoTemplateData({
    required this.items,
  });

  final List<TodoTemplateItem> items;
}

/// Detects if [body] matches the todo template structure.
///
/// Rule:
/// 1. Body must not be empty.
/// 2. Every non-empty line must satisfy `parseChecklistLine().isChecklist` when trimmed
///    (i.e. starts with `☐` or `☑`).
/// 3. There must be at least one checklist item.
bool isTodoTemplate(String body) {
  return parseTodoTemplate(body) != null;
}

/// Parses [body] into [TodoTemplateData] if it matches the todo template pattern.
/// Returns `null` if [body] does not match the todo template rules.
TodoTemplateData? parseTodoTemplate(String body) {
  if (body.trim().isEmpty) return null;

  final lines = body.replaceAll('\r\n', '\n').split('\n');
  var hasNonEmptyLine = false;
  final items = <TodoTemplateItem>[];

  for (var i = 0; i < lines.length; i++) {
    final rawLine = lines[i];
    final line = rawLine.trim();
    if (line.isEmpty) {
      continue;
    }
    hasNonEmptyLine = true;

    final parsed = parseChecklistLine(line);
    if (!parsed.isChecklist) {
      return null;
    }

    items.add(TodoTemplateItem(
      checked: parsed.checked,
      content: parsed.content ?? '',
      lineIndex: i,
    ));
  }

  if (!hasNonEmptyLine || items.isEmpty) {
    return null;
  }

  return TodoTemplateData(items: items);
}

/// Data extracted from a contact template body.
class ContactTemplateData {
  const ContactTemplateData({
    this.name,
    this.phone,
    this.email,
    this.address,
    this.notes,
    this.extraLines = const [],
  });

  final String? name;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;

  /// Custom `label: value` lines with labels outside the known template set,
  /// preserved verbatim so the template UI never drops user-added fields
  /// when re-saving (Round 9: tolerant parsing).
  final List<String> extraLines;
}

/// Detects if [body] matches the contact template structure.
///
/// Rule (Round 9: tolerant):
/// 1. Body must not be empty; the first non-empty line must be `label: value`.
/// 2. Known labels assign fields; unknown `label: value` lines are tolerated
///    as user-added custom fields (preserved on re-save).
/// 3. A colon-less line continues the previous field's value only after the
///    地址/Address or 备注/Notes field; otherwise the body does not match.
/// 4. At least one line must carry an anchor label:
///    姓名 / Name / 电话 / Phone / 邮箱 / Email / 地址 / Address.
///    (Round 9: 地址 is an anchor so address-only contacts show the template.)
bool isContactTemplate(String body) {
  return parseContactTemplate(body) != null;
}

/// Parses [body] into [ContactTemplateData] if it matches the contact template pattern.
/// Returns `null` if [body] does not match the contact template rules.
ContactTemplateData? parseContactTemplate(String body) {
  final extraLines = <String>[];
  final fields = _parseLabelValueTemplate(
    body: body,
    labelToKey: const {
      // Chinese labels
      '姓名': 'name',
      '电话': 'phone',
      '邮箱': 'email',
      '地址': 'address',
      '备注': 'notes',
      // English labels
      'name': 'name',
      'phone': 'phone',
      'email': 'email',
      'address': 'address',
      'notes': 'notes',
    },
    anchorKeys: const {'name', 'phone', 'email', 'address'},
    continuableKeys: const {'address', 'notes'},
    extraLines: extraLines,
  );
  if (fields == null) return null;

  return ContactTemplateData(
    name: fields['name'],
    phone: fields['phone'],
    email: fields['email'],
    address: fields['address'],
    notes: fields['notes'],
    extraLines: extraLines,
  );
}

/// Data extracted from an id document template body.
class IdDocumentTemplateData {
  const IdDocumentTemplateData({
    this.docType,
    this.name,
    this.docNumber,
    this.validUntil,
    this.photoFront,
    this.photoBack,
    this.notes,
  });

  final String? docType;
  final String? name;
  final String? docNumber;
  final String? validUntil;
  final String? photoFront;
  final String? photoBack;
  final String? notes;
}

/// Normalized id document template field types.
enum IdDocumentFieldType {
  docType,
  name,
  docNumber,
  validUntil,
  photoFront,
  photoBack,
  notes,
}

/// Map of allowed label names (trimmed, lowercased for Latin) to their field types.
const Map<String, IdDocumentFieldType> _kIdDocumentLabels = {
  // Chinese labels
  '证件类型': IdDocumentFieldType.docType,
  '姓名': IdDocumentFieldType.name,
  '证件号码': IdDocumentFieldType.docNumber,
  '有效期至': IdDocumentFieldType.validUntil,
  '证件照片正面': IdDocumentFieldType.photoFront,
  '证件照片反面': IdDocumentFieldType.photoBack,
  '备注': IdDocumentFieldType.notes,

  // English labels
  'document type': IdDocumentFieldType.docType,
  'name': IdDocumentFieldType.name,
  'document number': IdDocumentFieldType.docNumber,
  'valid until': IdDocumentFieldType.validUntil,
  'id photo front': IdDocumentFieldType.photoFront,
  'id photo back': IdDocumentFieldType.photoBack,
  'notes': IdDocumentFieldType.notes,
};

/// Detects if [body] matches the id document template structure.
///
/// Rule:
/// 1. Body must not be empty.
/// 2. Every non-empty line must match `label: value` (where colon can be `:` or `：`).
/// 3. Every label must belong to the id document template label set:
///    {证件类型, 姓名, 证件号码, 有效期至, 证件照片正面, 证件照片反面, 备注,
///     Document type, Name, Document number, Valid until, ID photo front, ID photo back, Notes}.
/// 4. At least one line must have an anchor label:
///    证件类型 / Document type / 证件号码 / Document number.
bool isIdDocumentTemplate(String body) {
  return parseIdDocumentTemplate(body) != null;
}

/// Parses [body] into [IdDocumentTemplateData] if it matches the id document template pattern.
/// Returns `null` if [body] does not match the id document template rules.
IdDocumentTemplateData? parseIdDocumentTemplate(String body) {
  if (body.trim().isEmpty) return null;

  final lines = body.replaceAll('\r\n', '\n').split('\n');
  var hasNonEmptyLine = false;
  var hasAnchor = false;

  String? docType;
  String? name;
  String? docNumber;
  String? validUntil;
  String? photoFront;
  String? photoBack;
  String? notes;

  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty) {
      continue;
    }
    hasNonEmptyLine = true;

    final match = _colonRegExp.firstMatch(line);
    if (match == null) {
      return null;
    }

    final rawLabel = line.substring(0, match.start).trim();
    final value = line.substring(match.end).trim();

    // Check label in allowed set
    final lookupKey = rawLabel.toLowerCase();
    final fieldType =
        _kIdDocumentLabels[rawLabel] ?? _kIdDocumentLabels[lookupKey];
    if (fieldType == null) {
      return null;
    }

    switch (fieldType) {
      case IdDocumentFieldType.docType:
        docType = value;
        hasAnchor = true;
      case IdDocumentFieldType.name:
        name = value;
      case IdDocumentFieldType.docNumber:
        docNumber = value;
        hasAnchor = true;
      case IdDocumentFieldType.validUntil:
        validUntil = value;
      case IdDocumentFieldType.photoFront:
        photoFront = value;
      case IdDocumentFieldType.photoBack:
        photoBack = value;
      case IdDocumentFieldType.notes:
        notes = value;
    }
  }

  if (!hasNonEmptyLine || !hasAnchor) {
    return null;
  }

  return IdDocumentTemplateData(
    docType: docType,
    name: name,
    docNumber: docNumber,
    validUntil: validUntil,
    photoFront: photoFront,
    photoBack: photoBack,
    notes: notes,
  );
}

