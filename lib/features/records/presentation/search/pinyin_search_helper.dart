// lib/features/records/presentation/search/pinyin_search_helper.dart

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
