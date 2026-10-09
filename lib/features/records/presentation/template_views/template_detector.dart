// lib/features/records/presentation/template_views/template_detector.dart
// Template detector to identify structured note templates from body text.

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
