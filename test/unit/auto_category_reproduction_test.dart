// test/unit/auto_category_reproduction_test.dart
// Reproduction, root cause analysis and regression tests for auto-category suggestion engine.

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/features/categories/data/category_repository.dart';
import 'package:suicun/features/sync/entity_snapshot.dart';
import 'package:suicun/services/auto_category_service.dart';

void main() {
  late AppDatabase db;
  late CategoryRepository repo;
  late AutoCategoryService service;
  late SnapshotApplier applier;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = CategoryRepository(db);
    service = AutoCategoryService(repo);
    applier = SnapshotApplier(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Auto Category Root Cause & Regression Tests', () {
    test('input with seed keywords produces non-empty suggestions when seeded',
        () async {
      await repo.ensureDefaultCategories();
      final suggestions = await service.suggestCategories(
        title: '项目方案讨论',
        body: '下周会议汇报',
      );
      expect(suggestions, isNotEmpty);
      expect(suggestions.first.categoryName, '工作');
    });

    test('input with no keywords produces empty suggestions', () async {
      await repo.ensureDefaultCategories();
      final suggestions = await service.suggestCategories(
        title: '今天天气不错',
        body: '出去走走晒太阳',
      );
      expect(suggestions, isEmpty);
    });

    test(
        '(a) sync recovery path: category download automatically seeds keywords and enables recommendation',
        () async {
      // Simulates WebDAV sync downloading a category with only name and color.
      final rev = ParsedRevision(
        revisionId: 'rev-cat-work-1',
        entityType: EntitySnapshots.categoryType,
        entityId: 'remote-cat-work-id',
        parents: const [],
        createdAt: DateTime.now().toUtc(),
        deleted: false,
        snapshot: {'name': '工作', 'color': '#4A7DDC'},
      );
      await applier.apply(rev);

      // Verify category was inserted with seed keywords directly.
      final keywords = await repo.getKeywords('remote-cat-work-id');
      expect(keywords, isNotEmpty,
          reason: 'Sync applier should insert default categories with seed keywords');
      expect(keywords, contains('会议'));
      expect(keywords, contains('开会'));

      // Verify suggestions immediately work for recovered users.
      final suggestions = await service.suggestCategories(
        title: '项目方案讨论',
        body: '下周汇报',
      );
      expect(suggestions, isNotEmpty);
      expect(suggestions.first.categoryId, 'remote-cat-work-id');
      expect(suggestions.first.categoryName, '工作');
    });

    test(
        '(a.2) sync update backfills keywords for pre-existing empty-keyword default category',
        () async {
      // Pre-existing row without keywords (e.g. from an older version or previous sync).
      await db.into(db.categories).insert(CategoriesCompanion.insert(
            id: 'old-empty-cat',
            name: '学习',
            color: const Value('#7C5CD6'),
          ));
      expect(await repo.getKeywords('old-empty-cat'), isEmpty);

      // Re-apply sync revision for this category.
      final rev = ParsedRevision(
        revisionId: 'rev-cat-study-2',
        entityType: EntitySnapshots.categoryType,
        entityId: 'old-empty-cat',
        parents: const [],
        createdAt: DateTime.now().toUtc(),
        deleted: false,
        snapshot: {'name': '学习', 'color': '#7C5CD6'},
      );
      await applier.apply(rev);

      // Keywords must be backfilled.
      final keywords = await repo.getKeywords('old-empty-cat');
      expect(keywords, isNotEmpty);
      expect(keywords, contains('笔记'));

      final suggestions = await service.suggestCategories(
        title: '英语复习笔记',
        body: '背诵单词',
      );
      expect(suggestions, isNotEmpty);
      expect(suggestions.first.categoryId, 'old-empty-cat');
    });

    test('(b) ensureDefaultCategories handles duplicates, whitespace, and case',
        () async {
      // Multiple categories with same default name, some with whitespace/case differences.
      final cat1 = await repo.createCategory(' 工作 ', '#4A7DDC');
      await db.into(db.categories).insert(CategoriesCompanion.insert(
            id: 'second-work-id',
            name: '工作',
            color: const Value('#4A7DDC'),
          ));

      expect(await repo.getKeywords(cat1.id), isEmpty);
      expect(await repo.getKeywords('second-work-id'), isEmpty);

      await repo.ensureDefaultCategories();

      expect(await repo.getKeywords(cat1.id), isNotEmpty);
      expect(await repo.getKeywords('second-work-id'), isNotEmpty);
    });

    test('(c) typical Chinese inputs reach confidence threshold', () async {
      await repo.ensureDefaultCategories();

      // Case 1: Work - "明天要开会讨论项目需求"
      final suggestions1 = await service.suggestCategories(
        title: '',
        body: '明天要开会讨论项目需求',
      );
      expect(suggestions1, isNotEmpty);
      expect(suggestions1.first.categoryName, '工作');
      // hits: '开会', '项目', '需求' -> 3 body hits -> score 3.0, confidence 3/5 = 0.6 >= 0.3
      expect(suggestions1.first.confidence, greaterThanOrEqualTo(0.5));

      // Case 2: Life/Travel - "下周去旅行订机票酒店"
      final suggestions2 = await service.suggestCategories(
        title: '',
        body: '下周去旅行订机票酒店',
      );
      expect(suggestions2, isNotEmpty);
      expect(suggestions2.first.categoryName, '生活');
      expect(suggestions2.first.confidence, greaterThanOrEqualTo(0.5));

      // Case 3: Todo - "记得明天缴费"
      final suggestions3 = await service.suggestCategories(
        title: '',
        body: '记得明天缴费',
      );
      expect(suggestions3, isNotEmpty);
      expect(suggestions3.first.categoryName, '待办');
      expect(suggestions3.first.confidence,
          greaterThanOrEqualTo(AutoCategoryService.suggestionThreshold));
    });

    test('(c.2) threshold boundary tests (precision check)', () async {
      await repo.ensureDefaultCategories();

      // 0 hits -> confidence = 0.0 < 0.3 -> not returned
      expect(
        await service.suggestCategories(title: '纯文本无关键词测试', body: '没有任何匹配'),
        isEmpty,
      );

      // Exactly 1 body hit -> score = 1.0 -> confidence = 1 / (1 + 2) = 0.3333 >= 0.3
      final oneBodyHit = await service.suggestCategories(
        title: '没有任何匹配',
        body: '今天去健身', // '健身' is in '生活'
      );
      expect(oneBodyHit, isNotEmpty);
      expect(oneBodyHit.first.categoryName, '生活');
      expect(oneBodyHit.first.confidence, closeTo(1 / 3, 0.001));
      expect(oneBodyHit.first.confidence,
          greaterThanOrEqualTo(AutoCategoryService.suggestionThreshold));

      // Exactly 1 title hit -> score = 2.0 -> confidence = 2 / (2 + 2) = 0.5 >= 0.3
      final oneTitleHit = await service.suggestCategories(
        title: '健身日记',
        body: '没有任何匹配',
      );
      expect(oneTitleHit, isNotEmpty);
      expect(oneTitleHit.first.categoryName, '生活');
      expect(oneTitleHit.first.confidence, closeTo(0.5, 0.001));
      expect(oneTitleHit.first.confidence,
          greaterThan(oneBodyHit.first.confidence));
    });

    test(
        '(d) password template notes are categorized as "生活" with high confidence',
        () async {
      await repo.ensureDefaultCategories();

      // Password template note format 1: Title and fields
      final suggestions1 = await service.suggestCategories(
        title: '路由器登录信息',
        body: '账号：admin\n密码：123456\n登录地址：192.168.1.1',
      );
      expect(suggestions1, isNotEmpty);
      expect(suggestions1.first.categoryName, '生活');
      // Contains '登录' (title 2.0 + body 1.0), '账号' (body 1.0), '密码' (body 1.0)
      expect(suggestions1.first.confidence, greaterThanOrEqualTo(0.6));

      // Password template note format 2: Credentials note
      final suggestions2 = await service.suggestCategories(
        title: 'Wi-Fi 密码',
        body: '用户名：HomeWiFi\n密码：Password123',
      );
      expect(suggestions2, isNotEmpty);
      expect(suggestions2.first.categoryName, '生活');

      // Password template note format 3: Body only
      final suggestions3 = await service.suggestCategories(
        title: '',
        body: '账号：user@example.com，密码：secret',
      );
      expect(suggestions3, isNotEmpty);
      expect(suggestions3.first.categoryName, '生活');
    });
  });
}
