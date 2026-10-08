// lib/features/records/presentation/markdown_line.dart
// Lightweight markdown-ish parsing for note body rendering and the
// formatting toolbar: headings, bullet lists and inline bold.
// Storage stays plain text; all parsing and edit helpers are pure.

import 'package:flutter/foundation.dart';
import 'package:suicun/features/records/presentation/checklist_line.dart';

/// Represents a single line parsed for heading / bullet rendering.
@immutable
class MarkdownLine {
  const MarkdownLine({
    required this.isHeading,
    required this.isBullet,
    required this.rawLine,
    this.headingLevel = 0,
    this.content,
  });

  /// Whether this line is a heading (`# `, `## ` or `### ` prefix).
  final bool isHeading;

  /// Whether this line is a bullet list item (`- ` prefix).
  final bool isBullet;

  /// The original unmodified line text.
  final String rawLine;

  /// Heading level (1-3) when [isHeading] is true, else 0.
  final int headingLevel;

  /// The content after removing the marker.
  /// Null when the line is neither a heading nor a bullet.
  final String? content;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarkdownLine &&
          runtimeType == other.runtimeType &&
          isHeading == other.isHeading &&
          isBullet == other.isBullet &&
          rawLine == other.rawLine &&
          headingLevel == other.headingLevel &&
          content == other.content;

  @override
  int get hashCode =>
      Object.hash(isHeading, isBullet, rawLine, headingLevel, content);

  @override
  String toString() =>
      'MarkdownLine(isHeading: $isHeading, isBullet: $isBullet, '
      'rawLine: "$rawLine", headingLevel: $headingLevel, content: "$content")';
}

final _headingRegExp = RegExp(r'^(#{1,3})[ \t\u3000]+');
final _bulletRegExp = RegExp(r'^-[ \t\u3000]+');

/// Parses a single line for heading (`# `) / bullet (`- `) markers.
///
/// A `#` without trailing whitespace is not a heading; a `-` directly
/// followed by a non-space (e.g. `-5`) is not a bullet.
MarkdownLine parseMarkdownLine(String line) {
  final headingMatch = _headingRegExp.firstMatch(line);
  if (headingMatch != null) {
    return MarkdownLine(
      isHeading: true,
      isBullet: false,
      rawLine: line,
      headingLevel: headingMatch.group(1)!.length,
      content: line.substring(headingMatch.end),
    );
  }
  final bulletMatch = _bulletRegExp.firstMatch(line);
  if (bulletMatch != null) {
    return MarkdownLine(
      isHeading: false,
      isBullet: true,
      rawLine: line,
      content: line.substring(bulletMatch.end),
    );
  }
  return MarkdownLine(
    isHeading: false,
    isBullet: false,
    rawLine: line,
  );
}

/// A slice of inline text, either plain or bold (`**...**`).
@immutable
class InlineSegment {
  const InlineSegment({required this.text, required this.bold});

  final String text;
  final bool bold;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InlineSegment &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          bold == other.bold;

  @override
  int get hashCode => Object.hash(text, bold);

  @override
  String toString() => 'InlineSegment(text: "$text", bold: $bold)';
}

final _boldRegExp = RegExp(r'\*\*(.+?)\*\*');

/// Splits [text] into plain/bold segments on `**...**` pairs.
///
/// Unclosed markers are kept as plain text.
List<InlineSegment> parseBoldSegments(String text) {
  if (text.isEmpty) {
    return const [];
  }
  final segments = <InlineSegment>[];
  var cursor = 0;
  for (final match in _boldRegExp.allMatches(text)) {
    if (match.start > cursor) {
      segments.add(
        InlineSegment(
          text: text.substring(cursor, match.start),
          bold: false,
        ),
      );
    }
    segments.add(InlineSegment(text: match.group(1)!, bold: true));
    cursor = match.end;
  }
  if (cursor < text.length) {
    segments.add(
      InlineSegment(text: text.substring(cursor), bold: false),
    );
  }
  return segments;
}

/// Result of a toolbar edit: the new full text and the cursor offset to
/// restore afterwards.
@immutable
class FormatEditResult {
  const FormatEditResult({required this.text, required this.cursorOffset});

  final String text;
  final int cursorOffset;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FormatEditResult &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          cursorOffset == other.cursorOffset;

  @override
  int get hashCode => Object.hash(text, cursorOffset);

  @override
  String toString() =>
      'FormatEditResult(text: "$text", cursorOffset: $cursorOffset)';
}

/// Returns the (start, end) character offsets of the line containing [offset].
(int, int) _lineBounds(String text, int offset) {
  final safeOffset = offset.clamp(0, text.length);
  final start = safeOffset == 0 ? 0 : text.lastIndexOf('\n', safeOffset - 1) + 1;
  var end = text.indexOf('\n', safeOffset);
  if (end < 0) end = text.length;
  return (start, end);
}

/// Toggles a `☐ ` checklist marker at the start of the line containing
/// [offset]. Removes the marker (☐ or ☑) when the line is already a
/// checklist item.
FormatEditResult toggleCheckboxAt(String text, int offset) {
  final (start, end) = _lineBounds(text, offset);
  final line = text.substring(start, end);
  if (parseChecklistLine(line).isChecklist) {
    final stripped = line.replaceFirst(_checklistLineMarkerRegExp, '');
    final removed = line.length - stripped.length;
    return FormatEditResult(
      text: text.replaceRange(start, end, stripped),
      cursorOffset: (offset - removed).clamp(start, start + stripped.length),
    );
  }
  const marker = '☐ ';
  return FormatEditResult(
    text: text.replaceRange(start, start, marker),
    cursorOffset: (offset + marker.length).clamp(start, end + marker.length),
  );
}

final _checklistLineMarkerRegExp = RegExp(r'^[☐☑][ \t\u3000]*');

/// Toggles a `# ` heading marker at the start of the line containing
/// [offset]. Removes an existing `#`/`##`/`###` marker.
FormatEditResult toggleHeadingAt(String text, int offset) {
  final (start, end) = _lineBounds(text, offset);
  final line = text.substring(start, end);
  if (parseMarkdownLine(line).isHeading) {
    final stripped = line.replaceFirst(_headingRegExp, '');
    final removed = line.length - stripped.length;
    return FormatEditResult(
      text: text.replaceRange(start, end, stripped),
      cursorOffset: (offset - removed).clamp(start, start + stripped.length),
    );
  }
  const marker = '# ';
  return FormatEditResult(
    text: text.replaceRange(start, start, marker),
    cursorOffset: (offset + marker.length).clamp(start, end + marker.length),
  );
}

/// Toggles a `- ` bullet marker at the start of the line containing [offset].
/// Removes the marker when the line is already a bullet item.
FormatEditResult toggleBulletAt(String text, int offset) {
  final (start, end) = _lineBounds(text, offset);
  final line = text.substring(start, end);
  if (parseMarkdownLine(line).isBullet) {
    final stripped = line.replaceFirst(_bulletRegExp, '');
    final removed = line.length - stripped.length;
    return FormatEditResult(
      text: text.replaceRange(start, end, stripped),
      cursorOffset: (offset - removed).clamp(start, start + stripped.length),
    );
  }
  const marker = '- ';
  return FormatEditResult(
    text: text.replaceRange(start, start, marker),
    cursorOffset: (offset + marker.length).clamp(start, end + marker.length),
  );
}

/// Wraps the selection in `**...**`. With a collapsed selection (or an
/// invalid range) inserts `****` and places the cursor between the markers.
FormatEditResult applyBold(String text, int selectionStart, int selectionEnd) {
  var start = selectionStart.clamp(0, text.length);
  var end = selectionEnd.clamp(0, text.length);
  if (start > end) {
    final tmp = start;
    start = end;
    end = tmp;
  }
  if (start == end) {
    const markers = '****';
    return FormatEditResult(
      text: text.replaceRange(start, start, markers),
      cursorOffset: start + 2,
    );
  }
  final selected = text.substring(start, end);
  return FormatEditResult(
    text: text.replaceRange(start, end, '**$selected**'),
    cursorOffset: end + 4,
  );
}
