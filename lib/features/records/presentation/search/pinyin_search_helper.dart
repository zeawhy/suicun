import 'package:flutter/widgets.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:suicun/features/records/domain/record_model.dart';

/// Checks if [text] matches [query] via direct substring match OR pinyin first-letter match.
///
/// Matching rules:
/// 1. If [query] is empty, returns true.
/// 2. If [text] contains [query] (case-insensitive), returns true.
/// 3. If the pinyin first-letter acronym (e.g. "sfz" for "身份证") contains [query]
///    (case-insensitive), returns true.
bool matchesPinyinOrText({
  required String text,
  required String query,
}) {
  final cleanQuery = query.trim().toLowerCase();
  if (cleanQuery.isEmpty) return true;
  if (text.isEmpty) return false;

  final lowerText = text.toLowerCase();
  if (lowerText.contains(cleanQuery)) {
    return true;
  }

  try {
    final shortPinyin = PinyinHelper.getShortPinyin(text).toLowerCase();
    if (shortPinyin.contains(cleanQuery)) {
      return true;
    }
  } catch (_) {
    // If lpinyin encounters an error, fallback to false
  }

  return false;
}

/// Matches a [RecordDetail] against [query].
///
/// Returns true if either the record title or record body satisfies
/// [matchesPinyinOrText].
bool matchesRecordPinyinOrText(RecordDetail record, String query) {
  final cleanQuery = query.trim();
  if (cleanQuery.isEmpty) return true;

  return matchesPinyinOrText(text: record.title, query: cleanQuery) ||
      matchesPinyinOrText(text: record.body, query: cleanQuery);
}

/// A matched character range `[start, end)` in original string.
class MatchRange {
  final int start;
  final int end;
  const MatchRange(this.start, this.end);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MatchRange &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => start.hashCode ^ end.hashCode;

  @override
  String toString() => 'MatchRange($start, $end)';
}

/// Finds all matched character ranges `[start, end)` in [text] for [query],
/// considering both direct substring matching and pinyin first-letter acronym matching.
List<MatchRange> findMatchRanges({
  required String text,
  required String query,
}) {
  final cleanQuery = query.trim().toLowerCase();
  if (cleanQuery.isEmpty || text.isEmpty) return const [];

  final List<MatchRange> ranges = [];
  final lowerText = text.toLowerCase();

  // 1. Direct substring match
  int start = 0;
  while (start < lowerText.length) {
    final idx = lowerText.indexOf(cleanQuery, start);
    if (idx == -1) break;
    ranges.add(MatchRange(idx, idx + cleanQuery.length));
    start = idx + 1;
  }

  // 2. Pinyin acronym match (e.g. "sfz" matching "身份证")
  try {
    final List<int> charStarts = [];
    final List<int> charEnds = [];
    final StringBuffer pinyinAcronym = StringBuffer();

    int textIndex = 0;
    for (final char in text.characters) {
      final py = PinyinHelper.getShortPinyin(char).toLowerCase();
      if (py.isNotEmpty) {
        pinyinAcronym.write(py[0]);
        charStarts.add(textIndex);
        charEnds.add(textIndex + char.length);
      }
      textIndex += char.length;
    }

    final acronymStr = pinyinAcronym.toString();
    int acrStart = 0;
    while (acrStart < acronymStr.length) {
      final acrIdx = acronymStr.indexOf(cleanQuery, acrStart);
      if (acrIdx == -1) break;
      final matchEndIdx = acrIdx + cleanQuery.length - 1;
      if (matchEndIdx < charEnds.length) {
        final origStart = charStarts[acrIdx];
        final origEnd = charEnds[matchEndIdx];
        ranges.add(MatchRange(origStart, origEnd));
      }
      acrStart = acrIdx + 1;
    }
  } catch (_) {}

  if (ranges.isEmpty) return const [];

  // Sort and merge overlapping / adjacent ranges
  ranges.sort((a, b) => a.start.compareTo(b.start));
  final List<MatchRange> merged = [];
  var current = ranges.first;

  for (int i = 1; i < ranges.length; i++) {
    final next = ranges[i];
    if (next.start <= current.end) {
      current = MatchRange(
        current.start,
        next.end > current.end ? next.end : current.end,
      );
    } else {
      merged.add(current);
      current = next;
    }
  }
  merged.add(current);

  return merged;
}

/// Builds a list of [TextSpan]s where segments matching [query] (via direct substring
/// or pinyin first-letter acronym) are styled with [highlightStyle].
List<TextSpan> buildHighlightedSpans({
  required String text,
  required String query,
  required TextStyle? baseStyle,
  required TextStyle? highlightStyle,
}) {
  if (text.isEmpty) return const [];
  final ranges = findMatchRanges(text: text, query: query);
  if (ranges.isEmpty) {
    return [TextSpan(text: text, style: baseStyle)];
  }

  final List<TextSpan> spans = [];
  int currentIdx = 0;

  for (final range in ranges) {
    if (range.start > currentIdx) {
      spans.add(TextSpan(
        text: text.substring(currentIdx, range.start),
        style: baseStyle,
      ));
    }
    spans.add(TextSpan(
      text: text.substring(range.start, range.end),
      style: highlightStyle,
    ));
    currentIdx = range.end;
  }

  if (currentIdx < text.length) {
    spans.add(TextSpan(
      text: text.substring(currentIdx),
      style: baseStyle,
    ));
  }

  return spans;
}
