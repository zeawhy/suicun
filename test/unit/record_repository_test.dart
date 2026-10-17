// test/unit/record_repository_test.dart
// Unit tests for record CRUD, trash, categories/tags association,
// Chinese substring search, ranking, and LIKE-injection safety.
// Uses an in-memory SQLite database via drift.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/core/errors/app_errors.dart';
import 'package:suicun/features/categories/data/category_repository.dart';
import 'package:suicun/features/records/data/record_repository.dart';
import 'package:suicun/features/records/domain/id_doc_codec.dart';
import 'package:suicun/features/records/domain/id_doc_data.dart';
import 'package:suicun/features/tags/data/tag_repository.dart';

void main() {
  late AppDatabase db;
  late RecordRepository recordRepo;
  late CategoryRepository categoryRepo;
  late TagRepository tagRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    recordRepo = RecordRepository(db);
    categoryRepo = CategoryRepository(db);
    tagRepo = TagRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('CRUD', () {
    test('create and retrieve a record', () async {
      final created = await recordRepo.createRecord(
        title: 'Test Title',
        body: 'Test Body',
      );
      expect(created.title, 'Test Title');
      expect(created.body, 'Test Body');
      expect(created.isFavorite, isFalse);
      expect(created.id, isNotEmpty);

      final fetched = await recordRepo.getRecord(created.id);
      expect(fetched, isNotNull);
      expect(fetched!.id, created.id);
      expect(fetched.title, 'Test Title');
      expect(fetched.body, 'Test Body');
    });

    test('getRecord returns null for unknown id', () async {
      expect(await recordRepo.getRecord('no-such-id'), isNull);
    });

    test('update modifies fields and bumps updatedAt', () async {
      final created = await recordRepo.createRecord(
        title: 'Old',
        body: 'Old body',
      );
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      final updated = await recordRepo.updateRecord(
        created.id,
        title: 'New',
        body: 'New body',
        isFavorite: true,
      );
      expect(updated.title, 'New');
      expect(updated.body, 'New body');
      expect(updated.isFavorite, isTrue);
      expect(
        updated.updatedAt.isAfter(created.updatedAt) ||
            updated.updatedAt.isAtSameMomentAs(created.updatedAt),
        isTrue,
      );
    });

    test('permanent delete removes the record entirely', () async {
      final created =
          await recordRepo.createRecord(title: 'Gone', body: 'soon');
      await recordRepo.permanentDeleteRecord(created.id);
      expect(await recordRepo.getRecord(created.id), isNull);
      final all = await recordRepo.searchRecords();
      expect(all.where((r) => r.id == created.id), isEmpty);
    });
  });

  group('categories and tags association', () {
    test('create with category and tags in one transaction', () async {
      final cat =
          await categoryRepo.createCategory('工作', '#FF0000');
      final t1 = await tagRepo.findOrCreateTag('重要');
      final t2 = await tagRepo.findOrCreateTag('待办');

      final created = await recordRepo.createRecord(
        title: '任务',
        body: '内容',
        categoryId: cat.id,
        tagIds: [t1.id, t2.id],
      );

      expect(created.categoryId, cat.id);
      expect(created.category?.name, '工作');
      expect(created.tags.map((t) => t.name), containsAll(['重要', '待办']));
    });

    test('update replaces tag associations', () async {
      final t1 = await tagRepo.findOrCreateTag('a');
      final t2 = await tagRepo.findOrCreateTag('b');
      final created = await recordRepo.createRecord(
        title: 'T',
        body: 'B',
        tagIds: [t1.id],
      );
      expect(created.tags.map((t) => t.id), [t1.id]);

      final updated =
          await recordRepo.updateRecord(created.id, tagIds: [t2.id]);
      expect(updated.tags.map((t) => t.id), [t2.id]);
    });

    test('clearCategoryId removes the category link', () async {
      final cat = await categoryRepo.createCategory('生活', '#00FF00');
      final created = await recordRepo.createRecord(
        title: 'T',
        body: 'B',
        categoryId: cat.id,
      );
      expect(created.categoryId, cat.id);

      final updated =
          await recordRepo.updateRecord(created.id, clearCategoryId: true);
      expect(updated.categoryId, isNull);
      expect(updated.category, isNull);
    });

    test('deleting a category nullifies record category links', () async {
      final cat = await categoryRepo.createCategory('临时', '#0000FF');
      final created = await recordRepo.createRecord(
        title: 'T',
        body: 'B',
        categoryId: cat.id,
      );
      await categoryRepo.deleteCategory(cat.id);

      final fetched = await recordRepo.getRecord(created.id);
      expect(fetched!.categoryId, isNull);
    });

    test('deleting a tag removes its record associations', () async {
      final tag = await tagRepo.findOrCreateTag('gone-tag');
      final created = await recordRepo.createRecord(
        title: 'T',
        body: 'B',
        tagIds: [tag.id],
      );
      expect(created.tags, hasLength(1));

      await tagRepo.deleteTag(tag.id);
      final fetched = await recordRepo.getRecord(created.id);
      expect(fetched!.tags, isEmpty);
    });
  });

  group('trash', () {
    test('soft-deleted records leave the list but stay in trash', () async {
      final created =
          await recordRepo.createRecord(title: 'Trash me', body: 'x');
      await recordRepo.softDeleteRecord(created.id);

      final list = await recordRepo.searchRecords();
      expect(list.where((r) => r.id == created.id), isEmpty);

      final trash = await recordRepo.searchRecords(includeDeleted: true);
      expect(trash.map((r) => r.id), contains(created.id));
    });

    test('restore brings the record back to the list', () async {
      final created =
          await recordRepo.createRecord(title: 'Restore me', body: 'x');
      await recordRepo.softDeleteRecord(created.id);
      await recordRepo.restoreRecord(created.id);

      final list = await recordRepo.searchRecords();
      expect(list.map((r) => r.id), contains(created.id));
      final trash = await recordRepo.searchRecords(includeDeleted: true);
      expect(trash.map((r) => r.id), isNot(contains(created.id)));
    });

    test('permanent delete from trash removes it everywhere', () async {
      final created =
          await recordRepo.createRecord(title: 'Nuke me', body: 'x');
      await recordRepo.softDeleteRecord(created.id);
      await recordRepo.permanentDeleteRecord(created.id);

      expect(await recordRepo.getRecord(created.id), isNull);
      final trash = await recordRepo.searchRecords(includeDeleted: true);
      expect(trash.map((r) => r.id), isNot(contains(created.id)));
    });
  });

  group('search', () {
    test('empty query lists all ordered by favorite then updatedAt',
        () async {
      final first =
          await recordRepo.createRecord(title: 'First', body: 'a');
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      final second =
          await recordRepo.createRecord(title: 'Second', body: 'b');
      await recordRepo.updateRecord(second.id, isFavorite: true);

      final results = await recordRepo.searchRecords();
      expect(results.map((r) => r.id),
          containsAll([first.id, second.id]));
      // Favorite first regardless of recency
      expect(results.first.id, second.id);
    });

    test('Chinese single-character query matches', () async {
      await recordRepo.createRecord(title: '服务器常用配置', body: 'Nginx');
      await recordRepo.createRecord(title: ' unrelated ', body: 'nothing');

      final results = await recordRepo.searchRecords(query: '服');
      expect(results, hasLength(1));
      expect(results.first.title, '服务器常用配置');
    });

    test('Chinese two-character query matches', () async {
      await recordRepo.createRecord(title: '服务器常用配置', body: 'Nginx');
      await recordRepo.createRecord(title: '客户端设置', body: 'nothing');

      final results = await recordRepo.searchRecords(query: '服务');
      expect(results, hasLength(1));
      expect(results.first.title, '服务器常用配置');
    });

    test('Chinese mid-body substring query matches', () async {
      await recordRepo.createRecord(
        title: '笔记',
        body: '这是正文中间的一段测试内容，看看能不能查到',
      );

      final results = await recordRepo.searchRecords(query: '中间的一段');
      expect(results, hasLength(1));
    });

    test('multi-token query requires ALL tokens (AND)', () async {
      await recordRepo.createRecord(title: '服务器常用配置', body: 'Docker');
      await recordRepo.createRecord(title: '服务器清单', body: 'nothing here');

      final results = await recordRepo.searchRecords(query: '服务 配置');
      expect(results, hasLength(1));
      expect(results.first.title, '服务器常用配置');
    });

    test('query matches tag names', () async {
      final tag = await tagRepo.findOrCreateTag('灵感');
      await recordRepo.createRecord(title: 'No match here', body: 'zzz', tagIds: [tag.id]);

      final results = await recordRepo.searchRecords(query: '灵感');
      expect(results, hasLength(1));
    });

    test('query matches category names', () async {
      final cat = await categoryRepo.createCategory('旅行计划', '#123456');
      await recordRepo.createRecord(
          title: 'No match here', body: 'zzz', categoryId: cat.id);

      final results = await recordRepo.searchRecords(query: '旅行');
      expect(results, hasLength(1));
    });

    test('favoritesOnly filter', () async {
      await recordRepo.createRecord(title: 'plain', body: 'x');
      final fav = await recordRepo.createRecord(title: 'starred', body: 'y');
      await recordRepo.updateRecord(fav.id, isFavorite: true);

      final results =
          await recordRepo.searchRecords(favoritesOnly: true);
      expect(results.map((r) => r.id), [fav.id]);
    });

    test('categoryId filter', () async {
      final cat = await categoryRepo.createCategory('A', '#111111');
      final inCat = await recordRepo.createRecord(
          title: 'in', body: 'x', categoryId: cat.id);
      await recordRepo.createRecord(title: 'out', body: 'y');

      final results =
          await recordRepo.searchRecords(categoryId: cat.id);
      expect(results.map((r) => r.id), [inCat.id]);
    });

    test('ranking: title exact > title contains > body contains', () async {
      final bodyHit =
          await recordRepo.createRecord(title: 'zzz', body: 'has keyword here');
      final titleContains = await recordRepo.createRecord(
          title: 'a keyword inside', body: 'zzz');
      final titleExact =
          await recordRepo.createRecord(title: 'keyword', body: 'zzz');

      final results = await recordRepo.searchRecords(query: 'keyword');
      expect(results.map((r) => r.id).toList(),
          [titleExact.id, titleContains.id, bodyHit.id]);
    });

    test('ranking: tag/category hit outranks body hit', () async {
      final tag = await tagRepo.findOrCreateTag('keyword');
      final tagHit = await recordRepo.createRecord(
          title: 'zzz', body: 'nothing', tagIds: [tag.id]);
      final bodyHit =
          await recordRepo.createRecord(title: 'yyy', body: 'keyword here');

      final results = await recordRepo.searchRecords(query: 'keyword');
      expect(results.first.id, tagHit.id);
      expect(results.map((r) => r.id), contains(bodyHit.id));
    });

    test('pagination with limit and offset', () async {
      for (var i = 0; i < 5; i++) {
        await recordRepo.createRecord(title: 'R$i', body: 'b$i');
      }
      final page1 = await recordRepo.searchRecords(limit: 2, offset: 0);
      final page2 = await recordRepo.searchRecords(limit: 2, offset: 2);
      expect(page1, hasLength(2));
      expect(page2, hasLength(2));
      final ids1 = page1.map((r) => r.id).toSet();
      final ids2 = page2.map((r) => r.id).toSet();
      expect(ids1.intersection(ids2), isEmpty);
    });
  });

  group('injection safety', () {
    test('LIKE wildcards % and _ are treated as literals', () async {
      await recordRepo.createRecord(title: 'plain abc', body: 'def');

      // '%' must NOT act as a wildcard matching everything
      expect(await recordRepo.searchRecords(query: '%'), isEmpty);
      // '_' must NOT act as a single-char wildcard
      expect(await recordRepo.searchRecords(query: '_'), isEmpty);
      // '100%' only matches a literal percent sign
      await recordRepo.createRecord(title: '100% complete', body: 'x');
      final pct = await recordRepo.searchRecords(query: '100%');
      expect(pct, hasLength(1));
      expect(pct.first.title, '100% complete');
    });

    test('backslash is escaped', () async {
      await recordRepo.createRecord(title: r'path\to\file', body: 'x');
      final results = await recordRepo.searchRecords(query: r'\to');
      expect(results, hasLength(1));
    });

    test('single quote does not break the query', () async {
      await recordRepo.createRecord(title: "it's fine", body: 'x');
      final results = await recordRepo.searchRecords(query: "it's");
      expect(results, hasLength(1));

      // Classic injection attempt: must not throw, must not dump the table
      final evil =
          await recordRepo.searchRecords(query: "' OR '1'='1");
      expect(evil, isEmpty);
    });

    test('emoji query matches literally', () async {
      await recordRepo.createRecord(title: 'Party time 👍🎉', body: 'x');
      await recordRepo.createRecord(title: 'No emoji', body: 'y');

      final results = await recordRepo.searchRecords(query: '👍');
      expect(results, hasLength(1));
      expect(results.first.title, 'Party time 👍🎉');
    });

    test('URL with query params is matched literally', () async {
      const url = 'https://example.com/path?a=1&b=2';
      await recordRepo.createRecord(title: 'link', body: 'see $url here');

      final results = await recordRepo.searchRecords(query: url);
      expect(results, hasLength(1));
    });

    test('SQL comment / stacked query attempt is harmless', () async {
      await recordRepo.createRecord(title: 'victim', body: 'x');
      final results = await recordRepo.searchRecords(
        query: "x'; DROP TABLE records; --",
      );
      expect(results, isEmpty);
      // Table still intact
      final all = await recordRepo.searchRecords();
      expect(all, hasLength(1));
    });
  });

  group('round 7 §3.2: id document body protection', () {
    test('refuses to overwrite a valid id doc body with garbage', () async {
      final created = await recordRepo.createRecord(
        title: '身份证',
        body: encodeIdDocBody(
          const IdDocData(type: 'cn_resident_id', name: '张三'),
        ),
      );
      expect(
        () => recordRepo.updateRecord(created.id, body: 'plain text now'),
        throwsA(isA<DatabaseError>()),
      );
      // Database untouched.
      final fetched = await recordRepo.getRecord(created.id);
      expect(isIdDocBody(fetched!.body), isTrue);
      expect(decodeIdDocBody(fetched.body)?.name, '张三');
    });

    test('refuses mangled json, allows valid id doc updates', () async {
      final created = await recordRepo.createRecord(
        title: '身份证',
        body: encodeIdDocBody(
          const IdDocData(type: 'cn_resident_id', name: '张三'),
        ),
      );
      // Mangled JSON after the marker -> refused.
      expect(
        () => recordRepo.updateRecord(
          created.id,
          body: '$kIdDocBodyMarker\n{broken',
        ),
        throwsA(isA<DatabaseError>()),
      );
      // A valid new id doc body -> allowed.
      final updated = await recordRepo.updateRecord(
        created.id,
        body: encodeIdDocBody(
          const IdDocData(type: 'passport', name: 'Li'),
        ),
      );
      expect(decodeIdDocBody(updated.body)?.type, 'passport');
    });

    test('non-id records are unaffected by the guard', () async {
      final created = await recordRepo.createRecord(
        title: 'note',
        body: 'hello',
      );
      final updated = await recordRepo.updateRecord(
        created.id,
        body: 'world',
      );
      expect(updated.body, 'world');
    });

    test('body-less updates (favorite/category) are unaffected', () async {
      final created = await recordRepo.createRecord(
        title: '身份证',
        body: encodeIdDocBody(
          const IdDocData(type: 'cn_resident_id', name: '张三'),
        ),
      );
      final updated = await recordRepo.updateRecord(
        created.id,
        isFavorite: true,
      );
      expect(updated.isFavorite, isTrue);
      expect(isIdDocBody(updated.body), isTrue);
    });
  });
}
