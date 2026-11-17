// lib/features/categories/data/category_repository.dart

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/core/errors/app_errors.dart';
import 'package:suicun/features/categories/domain/category_model.dart';
import 'package:suicun/features/sync/sync_enqueuer.dart';

const _uuid = Uuid();

class CategoryRepository {
  CategoryRepository(this._db, {SyncEnqueuer? syncEnqueuer})
      : _syncEnqueuer = syncEnqueuer;

  final AppDatabase _db;
  final SyncEnqueuer? _syncEnqueuer;

  static CategoryModel _toModel(Category c) => CategoryModel(
        id: c.id,
        name: c.name,
        color: c.color,
        deletedAt: c.deletedAt?.toUtc(),
      );

  /// All non-deleted categories ordered by name.
  Future<List<CategoryModel>> getAllCategories() async {
    try {
      final rows = await (_db.select(_db.categories)
            ..where((c) => c.deletedAt.isNull())
            ..orderBy([(c) => OrderingTerm(expression: c.name)]))
          .get();
      return rows.map(_toModel).toList();
    } catch (e) {
      throw DatabaseError('Failed to load categories', e);
    }
  }

  /// Creates a new category. Throws [ValidationError] if name already exists.
  Future<CategoryModel> createCategory(String name, String color) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw const ValidationError('Category name is empty');
    if (await nameExists(trimmed)) {
      throw const ValidationError('Category name already exists');
    }
    try {
      final id = _uuid.v4();
      await _db.transaction(() async {
        await _db.into(_db.categories).insert(
              CategoriesCompanion.insert(
                id: id,
                name: trimmed,
                color: Value(color),
              ),
            );
        await _syncEnqueuer?.enqueueCategorySnapshot(
            id: id, name: trimmed, color: color);
      });
      return _toModel(await (_db.select(_db.categories)
            ..where((c) => c.id.equals(id)))
          .getSingle());
    } catch (e) {
      throw DatabaseError('Failed to create category', e);
    }
  }

  /// Updates a category's name and/or color.
  Future<CategoryModel> updateCategory(
    String id, {
    String? name,
    String? color,
  }) async {
    if (name != null) {
      final trimmed = name.trim();
      if (trimmed.isEmpty) throw const ValidationError('Category name is empty');
      if (await nameExists(trimmed, excludeId: id)) {
        throw const ValidationError('Category name already exists');
      }
    }
    try {
      await _db.transaction(() async {
        await (_db.update(_db.categories)..where((c) => c.id.equals(id)))
            .write(
          CategoriesCompanion(
            name: name != null ? Value(name.trim()) : const Value.absent(),
            color: color != null ? Value(color) : const Value.absent(),
          ),
        );
        final row = await (_db.select(_db.categories)
              ..where((c) => c.id.equals(id)))
            .getSingleOrNull();
        if (row != null) {
          await _syncEnqueuer?.enqueueCategorySnapshot(
              id: id, name: row.name, color: row.color);
        }
      });
      return _toModel(await (_db.select(_db.categories)
            ..where((c) => c.id.equals(id)))
          .getSingle());
    } catch (e) {
      throw DatabaseError('Failed to update category $id', e);
    }
  }

  /// Soft-deletes a category and sets all its records' categoryId to null.
  Future<void> deleteCategory(String id) async {
    try {
      await _db.transaction(() async {
        // Tombstone first (the last head is still known). Records touched by
        // the nullification below get NO record revisions: remote peers apply
        // the same nullification when applying the category tombstone.
        await _syncEnqueuer?.enqueueCategoryTombstone(id);
        // Nullify all records that belong to this category
        await (_db.update(_db.records)
              ..where((r) => r.categoryId.equals(id)))
            .write(const RecordsCompanion(categoryId: Value(null)));
        // Soft-delete the category
        await (_db.update(_db.categories)..where((c) => c.id.equals(id)))
            .write(
          CategoriesCompanion(deletedAt: Value(DateTime.now().toUtc())),
        );
      });
    } catch (e) {
      throw DatabaseError('Failed to delete category $id', e);
    }
  }

  /// Normalizes a category name for case-insensitive, whitespace-trimmed
  /// matching.
  static String normalizeName(String name) => name.trim().toLowerCase();

  /// Deterministic UUID v5 for a default category name so every device and
  /// fresh install derives the same ID for each built-in category.
  static String defaultCategoryId(String name) => _uuid.v5(
        Namespace.url.value,
        'suicun:default-category:${normalizeName(name)}',
      );

  /// Returns true if a non-deleted category with [name] exists (case-insensitive).
  Future<bool> nameExists(String name, {String? excludeId}) async {
    final lower = normalizeName(name);
    final cats = await getAllCategories();
    return cats.any((c) =>
        normalizeName(c.name) == lower &&
        (excludeId == null || c.id != excludeId));
  }

  // ── Auto-category keywords (stored as JSON string array in categories.keywords) ──

  /// Default categories seeded on first use, each with starter keywords so
  /// the auto-category engine works out of the box instead of silently
  /// doing nothing until the user configures keywords by hand.
  static const List<({String name, String color, List<String> keywords})>
      defaultCategories = [
    (
      name: '工作',
      color: '#4A7DDC',
      keywords: [
        '会议', '开会', '项目', '需求', '方案', '汇报', '总结', '邮件', '客户',
        '同事', '任务', '计划', '报告', '加班', '面试', '周报', 'deadline',
      ],
    ),
    (
      name: '学习',
      color: '#7C5CD6',
      keywords: [
        '学习', '课程', '笔记', '考试', '论文', '阅读', '读书', '单词',
        '英语', '教程', '知识', '复习', '作业', '讲座',
      ],
    ),
    (
      name: '生活',
      color: '#3FA76A',
      keywords: [
        '生活', '购物', '菜谱', '做饭', '旅行', '酒店', '机票', '健康',
        '运动', '跑步', '健身', '电影', '朋友', '聚会',
        '密码', '账号', '用户名', '登录',
        '地址', '住址',
      ],
    ),
    (
      name: '灵感',
      color: '#E8A33D',
      keywords: ['灵感', '想法', '创意', '点子', '思考', '随笔', '感悟'],
    ),
    (
      name: '待办',
      color: '#D9534F',
      keywords: [
        '待办', '任务', '提醒', '记得', '缴费', '预约', '截止', '购买', '办理',
      ],
    ),
  ];

  /// Idempotent first-run seeding for the auto-category engine.
  ///
  /// - Fresh install (no categories): creates [defaultCategories] with
  ///   deterministic IDs derived from their names and starter keywords.
  /// - Upgrade (user already has categories): backfills keywords for
  ///   default-named categories that have none yet.
  ///
  /// Never touches user-created categories or existing keyword lists.
  Future<void> ensureDefaultCategories() async {
    try {
      final existing = await getAllCategories();
      final existingByName = <String, List<CategoryModel>>{};
      for (final c in existing) {
        existingByName
            .putIfAbsent(normalizeName(c.name), () => [])
            .add(c);
      }
      for (final def in defaultCategories) {
        final defKey = normalizeName(def.name);
        final matches = existingByName[defKey];
        if (matches == null || matches.isEmpty) {
          final defId = defaultCategoryId(def.name);
          // Skip insert if the deterministic row already exists (e.g. soft-deleted
          // by the user), avoiding a primary-key conflict or resurrection.
          final existingById = await (_db.select(_db.categories)
                ..where((c) => c.id.equals(defId)))
              .getSingleOrNull();
          if (existingById == null) {
            await _db.into(_db.categories).insert(
                  CategoriesCompanion.insert(
                    id: defId,
                    name: def.name,
                    color: Value(def.color),
                    keywords: Value(encodeKeywords(def.keywords)),
                  ),
                );
          }
        } else {
          for (final match in matches) {
            if ((await getKeywords(match.id)).isEmpty) {
              await setKeywords(match.id, def.keywords);
            }
          }
        }
      }
    } catch (e) {
      throw DatabaseError('Failed to seed default categories', e);
    }
  }

  /// Merges duplicate non-deleted categories that share the same normalized
  /// name (trim + lowercase) into a single surviving row.
  ///
  /// - Picks a deterministic survivor per duplicate group (preferring the
  ///   deterministic default ID if present, then the category referenced by
  ///   the most records, then non-empty keywords, then exact trimmed name, then
  ///   lexicographically smallest id).
  /// - Unions non-empty keywords across the group onto the survivor.
  /// - Reassigns all records (live and trashed) pointing to merged duplicates
  ///   so they point to the survivor instead.
  /// - Soft-deletes redundant rows locally WITHOUT enqueuing sync tombstones,
  ///   preventing remote peers from nullifying record categories when syncing.
  ///
  /// Idempotent: returns the number of duplicate category rows merged (0 when
  /// already clean).
  Future<int> deduplicateCategories() async {
    try {
      return await _db.transaction(() async {
        final activeRows = await (_db.select(_db.categories)
              ..where((c) => c.deletedAt.isNull()))
            .get();
        if (activeRows.length <= 1) return 0;

        final groups = <String, List<Category>>{};
        for (final row in activeRows) {
          groups.putIfAbsent(normalizeName(row.name), () => []).add(row);
        }

        final duplicateGroups =
            groups.values.where((g) => g.length > 1).toList();
        if (duplicateGroups.isEmpty) return 0;

        // Count all record references (including trashed records so restoring
        // from trash never leaves a record pointing at a deleted category).
        final allRecords = await _db.select(_db.records).get();
        final recordCounts = <String, int>{};
        for (final r in allRecords) {
          final cid = r.categoryId;
          if (cid != null) {
            recordCounts[cid] = (recordCounts[cid] ?? 0) + 1;
          }
        }

        final now = DateTime.now().toUtc();
        var mergedCount = 0;

        for (final group in duplicateGroups) {
          final groupKey = normalizeName(group.first.name);
          final expectedDefaultId = defaultCategoryId(group.first.name);
          final isDefaultGroup = defaultCategories
              .any((d) => normalizeName(d.name) == groupKey);

          group.sort((a, b) {
            if (isDefaultGroup) {
              final aIsDef = a.id == expectedDefaultId ? 1 : 0;
              final bIsDef = b.id == expectedDefaultId ? 1 : 0;
              if (aIsDef != bIsDef) return bIsDef.compareTo(aIsDef);
            }
            final aCount = recordCounts[a.id] ?? 0;
            final bCount = recordCounts[b.id] ?? 0;
            if (aCount != bCount) return bCount.compareTo(aCount);

            final aHasKw = decodeKeywords(a.keywords).isNotEmpty ? 1 : 0;
            final bHasKw = decodeKeywords(b.keywords).isNotEmpty ? 1 : 0;
            if (aHasKw != bHasKw) return bHasKw.compareTo(aHasKw);

            final aTrimmed = a.name == a.name.trim() ? 1 : 0;
            final bTrimmed = b.name == b.name.trim() ? 1 : 0;
            if (aTrimmed != bTrimmed) return bTrimmed.compareTo(aTrimmed);

            return a.id.compareTo(b.id);
          });

          final survivor = group.first;
          final redundant = group.sublist(1);
          final redundantIds = redundant.map((c) => c.id).toList();

          final mergedKeywords = <String>[];
          for (final c in group) {
            mergedKeywords.addAll(decodeKeywords(c.keywords));
          }
          if (mergedKeywords.isNotEmpty) {
            await (_db.update(_db.categories)
                  ..where((c) => c.id.equals(survivor.id)))
                .write(CategoriesCompanion(
              keywords: Value(encodeKeywords(mergedKeywords)),
            ));
          }

          await (_db.update(_db.records)
                ..where((r) => r.categoryId.isIn(redundantIds)))
              .write(RecordsCompanion(categoryId: Value(survivor.id)));

          await (_db.update(_db.categories)
                ..where((c) => c.id.isIn(redundantIds)))
              .write(CategoriesCompanion(deletedAt: Value(now)));

          mergedCount += redundant.length;
        }

        return mergedCount;
      });
    } catch (e) {
      throw DatabaseError('Failed to deduplicate categories', e);
    }
  }

  /// Decodes a stored keywords JSON string into a keyword list.
  /// Returns an empty list for null, empty, or malformed values.
  static List<String> decodeKeywords(String? stored) {
    if (stored == null || stored.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(stored);
      if (decoded is List) {
        return decoded
            .whereType<String>()
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
    } catch (_) {
      // Malformed JSON — treat as no keywords rather than failing.
    }
    return const [];
  }

  /// Encodes a keyword list as a JSON string array for storage.
  static String encodeKeywords(Iterable<String> keywords) {
    final unique = <String>{};
    for (final kw in keywords) {
      final trimmed = kw.trim();
      if (trimmed.isNotEmpty) unique.add(trimmed);
    }
    return jsonEncode(unique.toList());
  }

  /// Keywords of a single category (empty list if none configured).
  Future<List<String>> getKeywords(String id) async {
    try {
      final row = await (_db.select(_db.categories)
            ..where((c) => c.id.equals(id)))
          .getSingleOrNull();
      return decodeKeywords(row?.keywords);
    } catch (e) {
      throw DatabaseError('Failed to load keywords for category $id', e);
    }
  }

  /// Keywords for all non-deleted categories, keyed by category id.
  Future<Map<String, List<String>>> getAllKeywords() async {
    try {
      final rows = await (_db.select(_db.categories)
            ..where((c) => c.deletedAt.isNull()))
          .get();
      return {
        for (final row in rows) row.id: decodeKeywords(row.keywords),
      };
    } catch (e) {
      throw DatabaseError('Failed to load category keywords', e);
    }
  }

  /// Replaces the keyword list of a category.
  Future<void> setKeywords(String id, List<String> keywords) async {
    try {
      await (_db.update(_db.categories)..where((c) => c.id.equals(id)))
          .write(CategoriesCompanion(
        keywords: Value(encodeKeywords(keywords)),
      ));
    } catch (e) {
      throw DatabaseError('Failed to save keywords for category $id', e);
    }
  }
}
