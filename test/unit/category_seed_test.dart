// test/unit/category_seed_test.dart
// Unit tests for default-category seeding that powers the auto-category
// engine out of the box. Uses an in-memory SQLite database via drift.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/features/categories/data/category_repository.dart';

void main() {
  late AppDatabase db;
  late CategoryRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = CategoryRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('ensureDefaultCategories', () {
    test('seeds defaults with keywords on fresh install', () async {
      await repo.ensureDefaultCategories();

      final cats = await repo.getAllCategories();
      expect(cats.length, CategoryRepository.defaultCategories.length);
      for (final def in CategoryRepository.defaultCategories) {
        final match = cats.where((c) => c.name == def.name);
        expect(match, hasLength(1));
        final keywords = await repo.getKeywords(match.single.id);
        expect(keywords, isNotEmpty);
        expect(
          keywords.toSet(),
          containsAll(def.keywords),
        );
      }
    });

    test('is idempotent — second run creates nothing new', () async {
      await repo.ensureDefaultCategories();
      await repo.ensureDefaultCategories();

      final cats = await repo.getAllCategories();
      expect(cats.length, CategoryRepository.defaultCategories.length);
    });

    test('backfills keywords for default-named categories lacking them',
        () async {
      final existing = await repo.createCategory('工作', '#4A7DDC');
      expect(await repo.getKeywords(existing.id), isEmpty);

      await repo.ensureDefaultCategories();

      final keywords = await repo.getKeywords(existing.id);
      expect(keywords, isNotEmpty);
      // The other defaults are still created.
      final cats = await repo.getAllCategories();
      expect(cats.length, CategoryRepository.defaultCategories.length);
    });

    test('never overwrites existing user keywords', () async {
      final existing = await repo.createCategory('工作', '#4A7DDC');
      await repo.setKeywords(existing.id, ['我的关键词']);

      await repo.ensureDefaultCategories();

      expect(await repo.getKeywords(existing.id), ['我的关键词']);
    });

    test('leaves custom user categories alone', () async {
      await repo.createCategory('我的收藏', '#123456');

      await repo.ensureDefaultCategories();

      final cats = await repo.getAllCategories();
      expect(
        cats.length,
        CategoryRepository.defaultCategories.length + 1,
      );
      final custom =
          cats.firstWhere((c) => c.name == '我的收藏');
      expect(await repo.getKeywords(custom.id), isEmpty);
    });
  });
}
