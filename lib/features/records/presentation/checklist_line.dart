// lib/features/records/presentation/checklist_line.dart
// Parser and helpers for interactive checklist lines in notes.

import 'package:flutter/foundation.dart';

/// Represents a single line parsed for checklist / todo box rendering.
@immutable
class ChecklistLine {
  const ChecklistLine({
    required this.isChecklist,
    required this.rawLine,
    this.checked = false,
    this.content,
  });

  /// Whether this line matches the checklist pattern (starts with ☐ or ☑).
  final bool isChecklist;

  /// The original unmodified line text.
  final String rawLine;

  /// Whether this checklist item is checked (☑).
  final bool checked;

  /// The content after removing the checklist marker and separator spaces.
  /// Null if [isChecklist] is false.
  final String? content;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChecklistLine &&
          runtimeType == other.runtimeType &&
          isChecklist == other.isChecklist &&
          rawLine == other.rawLine &&
          checked == other.checked &&
          content == other.content;

  @override
  int get hashCode => Object.hash(isChecklist, rawLine, checked, content);

  @override
  String toString() =>
      'ChecklistLine(isChecklist: $isChecklist, rawLine: "$rawLine", checked: $checked, content: "$content")';
}

final _checklistRegExp = RegExp(r'^([☐☑])[ \t\u3000]*');

/// Parses a single line to determine if it is a checklist line.
ChecklistLine parseChecklistLine(String line) {
  final match = _checklistRegExp.firstMatch(line);
  if (match != null) {
    final marker = match.group(1)!;
    return ChecklistLine(
      isChecklist: true,
      rawLine: line,
      checked: marker == '☑',
      content: line.substring(match.end),
    );
  }
  return ChecklistLine(
    isChecklist: false,
    rawLine: line,
    checked: false,
    content: null,
  );
}

/// Parses [text] line by line to detect checklist lines starting with `☐` or `☑`.
List<ChecklistLine> parseChecklistLines(String text) {
  if (text.isEmpty) {
    return const [];
  }

  final lines = text.replaceAll('\r\n', '\n').split('\n');
  return lines.map(parseChecklistLine).toList();
}

/// Toggles the checklist state (☐ ↔ ☑) of a [ChecklistLine].
///
/// Returns the new line text with other characters preserved.
/// Returns [line.rawLine] unchanged if it is not a checklist line.
String toggleChecklistLine(ChecklistLine line) {
  if (!line.isChecklist) {
    return line.rawLine;
  }
  if (line.rawLine.startsWith('☐')) {
    return '☑${line.rawLine.substring(1)}';
  } else if (line.rawLine.startsWith('☑')) {
    return '☐${line.rawLine.substring(1)}';
  }
  return line.rawLine;
}

/// Toggles the checklist line at [index] (0-based) and returns the full updated text.
///
/// If [index] is out of bounds or the line is not a checklist item, returns [text] unmodified.
String toggleChecklistLineAt(String text, int index) {
  if (text.isEmpty || index < 0) {
    return text;
  }

  final isCrlf = text.contains('\r\n');
  final lineEnding = isCrlf ? '\r\n' : '\n';
  final rawLines = text.replaceAll('\r\n', '\n').split('\n');

  if (index >= rawLines.length) {
    return text;
  }

  final line = parseChecklistLine(rawLines[index]);
  if (!line.isChecklist) {
    return text;
  }

  rawLines[index] = toggleChecklistLine(line);
  return rawLines.join(lineEnding);
}
