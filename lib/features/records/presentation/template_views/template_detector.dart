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
  });

  final String? website;
  final String? username;
  final String? password;
  final String? notes;
}

/// Normalized password template field types.
enum PasswordFieldType {
  website,
  username,
  password,
  notes,
}

/// Map of allowed label names (trimmed, lowercased for Latin) to their field types.
const Map<String, PasswordFieldType> _kPasswordLabels = {
  // Chinese labels
  '网站/应用': PasswordFieldType.website,
  '用户名': PasswordFieldType.username,
  '密码': PasswordFieldType.password,
  '备注': PasswordFieldType.notes,

  // English labels
  'website/app': PasswordFieldType.website,
  'website': PasswordFieldType.website,
  'app': PasswordFieldType.website,
  'username': PasswordFieldType.username,
  'password': PasswordFieldType.password,
  'notes': PasswordFieldType.notes,
};

final _colonRegExp = RegExp(r'[:：]');

/// Detects if [body] matches the password template structure.
///
/// Rule:
/// 1. Body must not be empty.
/// 2. Every non-empty line must match `label: value` (where colon can be `:` or `：`).
/// 3. Every label must belong to the password template label set:
///    {网站/应用, 用户名, 密码, 备注, Website/App, Website, App, Username, Password, Notes}.
/// 4. At least one line must have a label for `密码` / `Password`.
bool isPasswordTemplate(String body) {
  return parsePasswordTemplate(body) != null;
}

/// Parses [body] into [PasswordTemplateData] if it matches the password template pattern.
/// Returns `null` if [body] does not match the password template rules.
PasswordTemplateData? parsePasswordTemplate(String body) {
  if (body.trim().isEmpty) return null;

  final lines = body.replaceAll('\r\n', '\n').split('\n');
  var hasNonEmptyLine = false;
  var hasPassword = false;

  String? website;
  String? username;
  String? password;
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
    final fieldType = _kPasswordLabels[rawLabel] ?? _kPasswordLabels[lookupKey];
    if (fieldType == null) {
      return null;
    }

    switch (fieldType) {
      case PasswordFieldType.website:
        website = value;
      case PasswordFieldType.username:
        username = value;
      case PasswordFieldType.password:
        password = value;
        hasPassword = true;
      case PasswordFieldType.notes:
        notes = value;
    }
  }

  if (!hasNonEmptyLine || !hasPassword) {
    return null;
  }

  return PasswordTemplateData(
    website: website,
    username: username,
    password: password,
    notes: notes,
  );
}

/// Data extracted from an idea template body.
class IdeaTemplateData {
  const IdeaTemplateData({
    this.idea,
    this.source,
    this.nextAction,
  });

  final String? idea;
  final String? source;
  final String? nextAction;
}

/// Normalized idea template field types.
enum IdeaFieldType {
  idea,
  source,
  nextAction,
}

/// Map of allowed label names (trimmed, lowercased for Latin) to their field types.
const Map<String, IdeaFieldType> _kIdeaLabels = {
  // Chinese labels
  '灵感': IdeaFieldType.idea,
  '来源': IdeaFieldType.source,
  '下一步行动': IdeaFieldType.nextAction,

  // English labels
  'idea': IdeaFieldType.idea,
  'source': IdeaFieldType.source,
  'next action': IdeaFieldType.nextAction,
};

/// Detects if [body] matches the idea template structure.
///
/// Rule:
/// 1. Body must not be empty.
/// 2. Every non-empty line must match `label: value` (where colon can be `:` or `：`).
/// 3. Every label must belong to the idea template label set:
///    {灵感, 来源, 下一步行动, Idea, Source, Next action}.
/// 4. At least one line must have a label for `灵感` / `Idea`.
bool isIdeaTemplate(String body) {
  return parseIdeaTemplate(body) != null;
}

/// Parses [body] into [IdeaTemplateData] if it matches the idea template pattern.
/// Returns `null` if [body] does not match the idea template rules.
IdeaTemplateData? parseIdeaTemplate(String body) {
  if (body.trim().isEmpty) return null;

  final lines = body.replaceAll('\r\n', '\n').split('\n');
  var hasNonEmptyLine = false;
  var hasIdea = false;

  String? idea;
  String? source;
  String? nextAction;

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
    final fieldType = _kIdeaLabels[rawLabel] ?? _kIdeaLabels[lookupKey];
    if (fieldType == null) {
      return null;
    }

    switch (fieldType) {
      case IdeaFieldType.idea:
        idea = value;
        hasIdea = true;
      case IdeaFieldType.source:
        source = value;
      case IdeaFieldType.nextAction:
        nextAction = value;
    }
  }

  if (!hasNonEmptyLine || !hasIdea) {
    return null;
  }

  return IdeaTemplateData(
    idea: idea,
    source: source,
    nextAction: nextAction,
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
  });

  final String? name;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
}

/// Normalized contact template field types.
enum ContactFieldType {
  name,
  phone,
  email,
  address,
  notes,
}

/// Map of allowed label names (trimmed, lowercased for Latin) to their field types.
const Map<String, ContactFieldType> _kContactLabels = {
  // Chinese labels
  '姓名': ContactFieldType.name,
  '电话': ContactFieldType.phone,
  '邮箱': ContactFieldType.email,
  '地址': ContactFieldType.address,
  '备注': ContactFieldType.notes,

  // English labels
  'name': ContactFieldType.name,
  'phone': ContactFieldType.phone,
  'email': ContactFieldType.email,
  'address': ContactFieldType.address,
  'notes': ContactFieldType.notes,
};

/// Detects if [body] matches the contact template structure.
///
/// Rule:
/// 1. Body must not be empty.
/// 2. Every non-empty line must match `label: value` (where colon can be `:` or `：`).
/// 3. Every label must belong to the contact template label set:
///    {姓名, 电话, 邮箱, 地址, 备注, Name, Phone, Email, Address, Notes}.
/// 4. At least one line must have an anchor label:
///    姓名 / Name / 电话 / Phone / 邮箱 / Email.
bool isContactTemplate(String body) {
  return parseContactTemplate(body) != null;
}

/// Parses [body] into [ContactTemplateData] if it matches the contact template pattern.
/// Returns `null` if [body] does not match the contact template rules.
ContactTemplateData? parseContactTemplate(String body) {
  if (body.trim().isEmpty) return null;

  final lines = body.replaceAll('\r\n', '\n').split('\n');
  var hasNonEmptyLine = false;
  var hasAnchor = false;

  String? name;
  String? phone;
  String? email;
  String? address;
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
    final fieldType = _kContactLabels[rawLabel] ?? _kContactLabels[lookupKey];
    if (fieldType == null) {
      return null;
    }

    switch (fieldType) {
      case ContactFieldType.name:
        name = value;
        hasAnchor = true;
      case ContactFieldType.phone:
        phone = value;
        hasAnchor = true;
      case ContactFieldType.email:
        email = value;
        hasAnchor = true;
      case ContactFieldType.address:
        address = value;
      case ContactFieldType.notes:
        notes = value;
    }
  }

  if (!hasNonEmptyLine || !hasAnchor) {
    return null;
  }

  return ContactTemplateData(
    name: name,
    phone: phone,
    email: email,
    address: address,
    notes: notes,
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

