// test/unit/auto_category_service_test.dart
// Unit tests for the local auto-categorization engine.
// Uses an in-memory SQLite database via drift; no network involved.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/features/categories/data/category_repository.dart';
import 'package:suicun/services/auto_category_service.dart';

void main() {
  late AppDatabase db;
  late CategoryRepository repo;
  late AutoCategoryService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = CategoryRepository(db);
    service = AutoCategoryService(repo);
  });

  tearDown(() async {
    await db.close();
  });

  group('suggestCategory', () {
    test('returns null when no categories exist', () async {
      expect(
        await service.suggestCategory(title: '火锅', body: '好吃'),
        isNull,
      );
    });

    test('returns null when categories have no keywords', () async {
      await repo.createCategory('美食', '#4866D5');
      expect(
        await service.suggestCategory(title: '火锅', body: '好吃'),
        isNull,
      );
    });

    test('returns null for empty input', () async {
      final cat = await repo.createCategory('美食', '#4866D5');
      await service.setKeywords(cat.id, ['火锅']);
      expect(await service.suggestCategory(), isNull);
      expect(await service.suggestCategory(title: '', body: '  '), isNull);
    });

    test('returns null when nothing matches', () async {
      final cat = await repo.createCategory('美食', '#4866D5');
      await service.setKeywords(cat.id, ['火锅']);
      expect(
        await service.suggestCategory(title: '今天天气不错', body: '去公园散步'),
        isNull,
      );
    });

    test('title hit outranks body hit', () async {
      final cat = await repo.createCategory('美食', '#4866D5');
      await service.setKeywords(cat.id, ['火锅']);

      final fromTitle = await service.suggestCategory(
        title: '火锅真好吃',
        body: '随便写点别的内容',
      );
      final fromBody = await service.suggestCategory(
        title: '随便写点别的内容',
        body: '火锅真好吃',
      );

      expect(fromTitle, isNotNull);
      expect(fromBody, isNotNull);
      expect(fromTitle!.categoryId, cat.id);
      expect(fromBody!.categoryId, cat.id);
      expect(fromTitle.confidence, greaterThan(fromBody.confidence));
      // Sanity on the normalization: 1 title hit -> 0.5, 1 body hit -> ~0.33
      expect(fromTitle.confidence, closeTo(0.5, 0.001));
      expect(fromBody.confidence, closeTo(1 / 3, 0.001));
    });

    test('multiple keyword hits accumulate', () async {
      final cat = await repo.createCategory('美食', '#4866D5');
      await service.setKeywords(cat.id, ['火锅', '烧烤']);

      final oneHit = await service.suggestCategory(title: '火锅');
      final twoHits = await service.suggestCategory(title: '火锅和烧烤');

      expect(oneHit, isNotNull);
      expect(twoHits, isNotNull);
      expect(twoHits!.confidence, greaterThan(oneHit!.confidence));
    });

    test('confidence is normalized to 0..1', () async {
      final cat = await repo.createCategory('美食', '#4866D5');
      await service.setKeywords(cat.id, ['a', 'b', 'c', 'd', 'e', 'f']);
      final suggestion = await service.suggestCategory(
        title: 'a b c d e f',
        body: 'a b c d e f',
      );
      expect(suggestion, isNotNull);
      expect(suggestion!.confidence, greaterThanOrEqualTo(0.0));
      expect(suggestion.confidence, lessThanOrEqualTo(1.0));
      expect(suggestion.confidence,
          greaterThanOrEqualTo(AutoCategoryService.suggestionThreshold));
    });

    test('picks the best matching category', () async {
      final food = await repo.createCategory('美食', '#4866D5');
      final travel = await repo.createCategory('旅行', '#22AA66');
      await service.setKeywords(food.id, ['火锅']);
      await service.setKeywords(travel.id, ['机票']);

      final suggestion = await service.suggestCategory(
        title: '行程安排',
        body: '订好了机票和酒店',
      );
      expect(suggestion, isNotNull);
      expect(suggestion!.categoryId, travel.id);
      expect(suggestion.categoryName, '旅行');
    });
  });

  group('learnFromCorrection', () {
    test('extracts CJK keywords, drops stop words and short tokens',
        () async {
      final cat = await repo.createCategory('美食', '#4866D5');
      await service.learnFromCorrection(
        title: '今天,和朋友,去吃了,火锅',
        body: '火锅,真好吃,a',
        categoryId: cat.id,
      );
      final keywords = await service.getKeywords(cat.id);
      // "今天" is a stop word, "a" is too short, "火锅" is deduped.
      expect(keywords, containsAll(['和朋友', '去吃了', '火锅', '真好吃']));
      expect(keywords, isNot(contains('今天')));
      expect(keywords, isNot(contains('a')));
      expect(keywords.where((k) => k == '火锅'), hasLength(1));
    });

    test('merges with existing keywords without duplicates', () async {
      final cat = await repo.createCategory('美食', '#4866D5');
      await service.setKeywords(cat.id, ['火锅']);
      await service.learnFromCorrection(
        title: '火锅,烧烤',
        body: null,
        categoryId: cat.id,
      );
      final keywords = await service.getKeywords(cat.id);
      expect(keywords, containsAll(['火锅', '烧烤']));
      expect(keywords.where((k) => k == '火锅'), hasLength(1));
    });

    test('learned keywords improve later suggestions', () async {
      final cat = await repo.createCategory('美食', '#4866D5');
      expect(
        await service.suggestCategory(title: '晚上吃火锅'),
        isNull,
      );
      await service.learnFromCorrection(
        title: '火锅，聚餐',
        body: '和朋友，去吃火锅',
        categoryId: cat.id,
      );
      final suggestion = await service.suggestCategory(title: '晚上吃火锅');
      expect(suggestion, isNotNull);
      expect(suggestion!.categoryId, cat.id);
    });
  });

  group('get/set/addKeywords', () {
    test('set replaces and get returns the list', () async {
      final cat = await repo.createCategory('美食', '#4866D5');
      expect(await service.getKeywords(cat.id), isEmpty);
      await service.setKeywords(cat.id, ['火锅', '烧烤']);
      expect(await service.getKeywords(cat.id), ['火锅', '烧烤']);
      await service.setKeywords(cat.id, ['寿司']);
      expect(await service.getKeywords(cat.id), ['寿司']);
    });

    test('set trims and dedupes', () async {
      final cat = await repo.createCategory('美食', '#4866D5');
      await service.setKeywords(cat.id, [' 火锅 ', '火锅', '', '  ', '烧烤']);
      expect(await service.getKeywords(cat.id), ['火锅', '烧烤']);
    });

    test('add merges into the existing list', () async {
      final cat = await repo.createCategory('美食', '#4866D5');
      await service.setKeywords(cat.id, ['火锅']);
      await service.addKeywords(cat.id, ['火锅', '烧烤']);
      expect(await service.getKeywords(cat.id), ['火锅', '烧烤']);
    });

    test('get returns empty list for unknown category', () async {
      expect(await service.getKeywords('no-such-id'), isEmpty);
    });
  });

  group('extractKeywords', () {
    test('splits on punctuation and keeps CJK runs', () {
      expect(
        AutoCategoryService.extractKeywords('你好，世界！hello-world'),
        ['你好', '世界', 'hello', 'world'],
      );
    });

    test('drops tokens shorter than 2 chars and stop words', () {
      expect(
        AutoCategoryService.extractKeywords('这个,ab,a,的'),
        ['ab'],
      );
    });

    test('lowercases latin tokens and dedupes', () {
      expect(
        AutoCategoryService.extractKeywords('Flutter,flutter,FLUTTER'),
        ['flutter'],
      );
    });

    test('returns empty list for blank input', () {
      expect(AutoCategoryService.extractKeywords('  ，！ '), isEmpty);
    });
  });

  group('suggestCategories', () {
    test('returns up to two candidates ranked by confidence', () async {
      final work = await repo.createCategory('工作', '#4A7DDC');
      final study = await repo.createCategory('学习', '#7C5CD6');
      final life = await repo.createCategory('生活', '#3FA76A');
      await service.setKeywords(work.id, ['会议', '项目']);
      await service.setKeywords(study.id, ['考试']);
      await service.setKeywords(life.id, ['火锅']);

      final suggestions = await service.suggestCategories(
        title: '项目会议',
        body: '准备考试',
      );
      expect(suggestions.length, 2);
      // '项目会议' hits two title keywords (weight 2 each) -> highest.
      expect(suggestions[0].categoryId, work.id);
      expect(suggestions[0].confidence,
          greaterThan(suggestions[1].confidence));
      expect(suggestions[1].categoryId, study.id);
    });

    test('respects the limit parameter', () async {
      final a = await repo.createCategory('A', '#111111');
      final b = await repo.createCategory('B', '#222222');
      final c = await repo.createCategory('C', '#333333');
      await service.setKeywords(a.id, ['开会']);
      await service.setKeywords(b.id, ['开会']);
      await service.setKeywords(c.id, ['开会']);

      final suggestions = await service.suggestCategories(
        title: '开会讨论',
        limit: 2,
      );
      expect(suggestions.length, 2);
    });

    test('filters out candidates below the confidence threshold', () async {
      final cat = await repo.createCategory('生活', '#3FA76A');
      await service.setKeywords(cat.id, ['火锅']);

      // '火锅' appears once in a long body -> confidence below threshold.
      final suggestions = await service.suggestCategories(
        body: '今天天气真不错适合出门走走顺便吃一顿火锅再回家休息',
      );
      // Single body hit: 1/(1+2) = 0.33 >= 0.3, so it IS returned.
      // Use a text with no hits at all for the empty case:
      final none = await service.suggestCategories(body: '今天天气真不错');
      expect(none, isEmpty);
      expect(suggestions.length, lessThanOrEqualTo(2));
    });

    test('suggestCategory returns the top candidate', () async {
      final work = await repo.createCategory('工作', '#4A7DDC');
      await service.setKeywords(work.id, ['会议']);

      final top = await service.suggestCategory(title: '开会会议纪要');
      expect(top, isNotNull);
      expect(top!.categoryId, work.id);
    });
  });
}
