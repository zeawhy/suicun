// lib/services/auto_category_service.dart
// Local auto-categorization engine for 随存.
//
// Pure offline (privacy requirement): keyword/rule scoring only — no network
// calls, no ML models. Recommendation logic is fully separated from the UI
// and is unit-testable.
//
// Keyword storage: JSON string array in the categories.keywords column
// (Drift schema v2, nullable TEXT). Empty/absent means "no keywords yet".
//
// Scoring model:
//   score = titleWeight * (distinct title hits)
//         + bodyWeight  * (distinct body hits)
//   confidence = score / (score + confidenceDamping)   // normalized to 0..1
// Suggestions with confidence below [suggestionThreshold] return null.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:suicun/core/database/providers.dart';
import 'package:suicun/features/categories/data/category_repository.dart';

/// A category suggestion produced by [AutoCategoryService.suggestCategory].
class CategorySuggestion {
  final String categoryId;
  final String categoryName;
  final double confidence; // 0.0–1.0

  const CategorySuggestion({
    required this.categoryId,
    required this.categoryName,
    required this.confidence,
  });

  @override
  String toString() =>
      'CategorySuggestion($categoryName, confidence: ${confidence.toStringAsFixed(2)})';
}

class AutoCategoryService {
  AutoCategoryService(this._categoryRepository);

  final CategoryRepository _categoryRepository;

  /// Minimum confidence for a suggestion to be returned.
  static const double suggestionThreshold = 0.3;

  /// Weight of one keyword hit in the title (higher than body).
  static const double titleWeight = 2.0;

  /// Weight of one keyword hit in the body.
  static const double bodyWeight = 1.0;

  /// Damping constant of the confidence normalization.
  /// With 2.0: 1 body hit -> 0.33, 1 title hit -> 0.5, 1 title + 1 body -> 0.6.
  static const double confidenceDamping = 2.0;

  /// Upper bound of stored keywords per category (bounds DB growth).
  static const int maxKeywordsPerCategory = 200;

  /// Suggests the best-matching category for the given text.
  ///
  /// Returns null when there is no text, no categories exist, no category
  /// has keywords, or no category reaches [suggestionThreshold].
  /// Matching is a case-insensitive substring search of each category's
  /// keyword list against the title (weighted higher) and the body.
  Future<CategorySuggestion?> suggestCategory({
    String? title,
    String? body,
  }) async {
    final titleText = (title ?? '').trim();
    final bodyText = (body ?? '').trim();
    if (titleText.isEmpty && bodyText.isEmpty) return null;

    final categories = await _categoryRepository.getAllCategories();
    if (categories.isEmpty) return null;
    final keywordMap = await _categoryRepository.getAllKeywords();

    final titleLower = titleText.toLowerCase();
    final bodyLower = bodyText.toLowerCase();

    String? bestId;
    String? bestName;
    double bestConfidence = 0;

    for (final category in categories) {
      final keywords = keywordMap[category.id];
      if (keywords == null || keywords.isEmpty) continue;

      var titleHits = 0;
      var bodyHits = 0;
      for (final keyword in keywords) {
        final kw = keyword.toLowerCase();
        if (kw.isEmpty) continue;
        if (titleLower.contains(kw)) titleHits++;
        if (bodyLower.contains(kw)) bodyHits++;
      }

      final score = titleWeight * titleHits + bodyWeight * bodyHits;
      if (score <= 0) continue;
      final confidence = score / (score + confidenceDamping);

      if (confidence > bestConfidence) {
        bestConfidence = confidence;
        bestId = category.id;
        bestName = category.name;
      }
    }

    if (bestId == null || bestConfidence < suggestionThreshold) return null;
    return CategorySuggestion(
      categoryId: bestId,
      categoryName: bestName!,
      confidence: bestConfidence,
    );
  }

  /// Learns from a user correction: extracts keywords from [title]/[body]
  /// and merges them into the target category's keyword list (deduped).
  Future<void> learnFromCorrection({
    required String? title,
    required String? body,
    required String categoryId,
  }) async {
    final extracted = extractKeywords('${title ?? ''} ${body ?? ''}');
    if (extracted.isEmpty) return;
    await addKeywords(categoryId, extracted);
  }

  /// Keywords currently configured for a category (empty list if none).
  Future<List<String>> getKeywords(String categoryId) =>
      _categoryRepository.getKeywords(categoryId);

  /// Replaces the keyword list of a category (trimmed, deduped, capped).
  Future<void> setKeywords(String categoryId, List<String> keywords) async {
    await _categoryRepository.setKeywords(
      categoryId,
      _normalizeKeywords(keywords),
    );
  }

  /// Merges [keywords] into the category's existing list (deduped, capped).
  Future<void> addKeywords(
      String categoryId, Iterable<String> keywords) async {
    final existing = await _categoryRepository.getKeywords(categoryId);
    final merged = <String>{...existing, ..._normalizeKeywords(keywords)};
    await _categoryRepository.setKeywords(
      categoryId,
      merged.take(maxKeywordsPerCategory).toList(),
    );
  }

  // ── Keyword extraction (CJK-aware tokenizer) ──────────────────────────────

  /// Extracts candidate keywords from free text.
  ///
  /// Splits on punctuation/whitespace/symbols (Unicode-aware), keeping
  /// consecutive CJK runs intact. Drops tokens shorter than 2 characters and
  /// common Chinese/English stop words. Pure-ASCII tokens are lowercased;
  /// duplicates are removed with order preserved.
  static List<String> extractKeywords(String text) {
    final seen = <String>{};
    final result = <String>[];
    for (final token in _splitTokens(text)) {
      if (token.length < 2) continue;
      final normalized = _isAsciiWord(token) ? token.toLowerCase() : token;
      if (_stopWords.contains(normalized)) continue;
      if (seen.add(normalized)) result.add(normalized);
    }
    return result;
  }

  /// Splits on Unicode punctuation, symbols and separators.
  static List<String> _splitTokens(String text) {
    final splitter = RegExp(r'[\p{P}\p{S}\p{Z}]+', unicode: true);
    return text
        .split(splitter)
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  static final _asciiWord = RegExp(r'^[a-zA-Z0-9]+$');

  static bool _isAsciiWord(String token) => _asciiWord.hasMatch(token);

  static List<String> _normalizeKeywords(Iterable<String> keywords) {
    final seen = <String>{};
    final result = <String>[];
    for (final kw in keywords) {
      final trimmed = kw.trim();
      if (trimmed.isEmpty) continue;
      if (seen.add(trimmed)) result.add(trimmed);
    }
    return result.take(maxKeywordsPerCategory).toList();
  }

  /// Common Chinese + English stop words excluded from learned keywords.
  static const Set<String> _stopWords = {
    // Chinese
    '的', '了', '在', '是', '我', '有', '和', '就', '不', '人', '都', '一', '个',
    '上', '也', '很', '到', '说', '要', '去', '你', '会', '着', '没有', '看',
    '好', '自己', '这', '那', '之', '与', '或', '为', '被', '把', '对', '从',
    '以', '及', '等', '其', '它们', '他们', '我们', '你们', '吗', '呢', '吧',
    '啊', '如果', '因为', '所以', '但是', '然后', '还有', '已经', '正在', '可以',
    '应该', '需要', '觉得', '非常', '比较', '这样', '那样', '这里', '那里', '什么',
    '怎么', '为什么', '哪里', '多少', '一些', '每个', '这种', '那个', '这个',
    '这些', '那些', '另外', '此外', '以及', '或者', '还是', '并且', '而且',
    '不过', '然而', '因此', '于是', '首先', '其次', '最后', '比如', '例如',
    '包括', '通过', '关于', '对于', '由于', '随着', '之间', '之中', '之后',
    '之前', '上面', '下面', '里面', '外面', '今天', '明天', '昨天', '现在',
    '目前', '最近', '时候', '时间', '地方', '东西', '事情', '问题', '方面',
    '情况', '原因', '结果', '方法', '方式', '可能', '必须', '能够', '想要',
    '喜欢', '知道', '认为', '表示', '进行', '使用', '成为', '出现', '发生',
    '发展', '提高', '增加', '减少', '改变', '影响', '关系', '作用', '意义',
    '价值', '重要', '主要', '基本', '一般', '特别', '更加', '十分', '有点',
    '一下', '一起', '一样', '一切', '一直', '一定', '当中', '以内', '以外',
    '以来', '予以', '加以', '之一', '其中', '其余', '其它', '其他',
    // English
    'the', 'a', 'an', 'and', 'or', 'of', 'to', 'in', 'on', 'for', 'with',
    'is', 'are', 'was', 'were', 'be', 'been', 'being', 'at', 'by', 'from',
    'as', 'it', 'its', 'this', 'that', 'these', 'those', 'i', 'you', 'he',
    'she', 'we', 'they', 'them', 'his', 'her', 'their', 'our', 'your', 'my',
    'me', 'him', 'us', 'what', 'which', 'who', 'whom', 'whose', 'when',
    'where', 'why', 'how', 'not', 'no', 'yes', 'but', 'if', 'then', 'else',
    'than', 'so', 'such', 'too', 'very', 'can', 'will', 'just', 'do',
    'does', 'did', 'done', 'have', 'has', 'had', 'having', 'would',
    'could', 'should', 'may', 'might', 'must', 'shall',
  };
}

/// Riverpod provider for [AutoCategoryService].
final autoCategoryServiceProvider = Provider<AutoCategoryService>((ref) {
  return AutoCategoryService(ref.watch(categoryRepositoryProvider));
});
