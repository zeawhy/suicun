// lib/features/records/data/record_repository.dart
// Data layer for records — wraps AppDatabase with domain mapping.

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/core/database/tables.dart';
import 'package:suicun/core/errors/app_errors.dart';
import 'package:suicun/features/categories/domain/category_model.dart';
import 'package:suicun/features/records/domain/record_model.dart';
import 'package:suicun/features/tags/domain/tag_model.dart';

const _uuid = Uuid();

/// Repository for all record CRUD and search operations.
class RecordRepository {
  RecordRepository(this._db);

  final AppDatabase _db;

  // ── Mapping ───────────────────────────────────────────────────────────────

  static RecordModel _toModel(Record r) => RecordModel(
        id: r.id,
        title: r.title,
        body: r.body,
        categoryId: r.categoryId,
        isFavorite: r.isFavorite,
        createdAt: r.createdAt.toUtc(),
        updatedAt: r.updatedAt.toUtc(),
        deletedAt: r.deletedAt?.toUtc(),
      );

  static CategoryModel _toCategoryModel(Category c) => CategoryModel(
        id: c.id,
        name: c.name,
        color: c.color,
        deletedAt: c.deletedAt?.toUtc(),
      );

  static TagModel _toTagModel(Tag t) => TagModel(
        id: t.id,
        name: t.name,
        deletedAt: t.deletedAt?.toUtc(),
      );

  static RecordDetail _toDetail(RecordWithDetails d) => RecordDetail(
        record: _toModel(d.record),
        category: d.category != null ? _toCategoryModel(d.category!) : null,
        tags: d.tags.map(_toTagModel).toList(),
      );

  // ── Public API ────────────────────────────────────────────────────────────

  /// Creates a new record (and its tag associations) in a single transaction.
  Future<RecordDetail> createRecord({
    required String title,
    required String body,
    String? categoryId,
    bool isFavorite = false,
    List<String> tagIds = const [],
  }) async {
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();

    try {
      await _db.transaction(() async {
        await _db.into(_db.records).insert(
              RecordsCompanion.insert(
                id: id,
                title: Value(title),
                body: Value(body),
                categoryId: Value(categoryId),
                isFavorite: Value(isFavorite),
                createdAt: now,
                updatedAt: now,
              ),
            );

        for (final tagId in tagIds) {
          await _db.into(_db.recordTags).insert(
                RecordTagsCompanion.insert(recordId: id, tagId: tagId),
              );
        }
      });

      final detail = await getRecord(id);
      if (detail == null) {
        throw const DatabaseError('Record not found after insert');
      }
      return detail;
    } on AppError {
      rethrow;
    } catch (e) {
      throw DatabaseError('Failed to create record', e);
    }
  }

  /// Updates mutable fields and replaces tag associations in a transaction.
  Future<RecordDetail> updateRecord(
    String id, {
    String? title,
    String? body,
    String? categoryId,
    bool? isFavorite,
    List<String>? tagIds,
    bool clearCategoryId = false,
  }) async {
    final now = DateTime.now().toUtc();

    try {
      await _db.transaction(() async {
        await (_db.update(_db.records)..where((r) => r.id.equals(id))).write(
          RecordsCompanion(
            title: title != null ? Value(title) : const Value.absent(),
            body: body != null ? Value(body) : const Value.absent(),
            categoryId: clearCategoryId
                ? const Value(null)
                : (categoryId != null
                    ? Value(categoryId)
                    : const Value.absent()),
            isFavorite:
                isFavorite != null ? Value(isFavorite) : const Value.absent(),
            updatedAt: Value(now),
          ),
        );

        if (tagIds != null) {
          // Replace all existing tag associations
          await (_db.delete(_db.recordTags)
                ..where((rt) => rt.recordId.equals(id)))
              .go();
          for (final tagId in tagIds) {
            await _db.into(_db.recordTags).insert(
                  RecordTagsCompanion.insert(recordId: id, tagId: tagId),
                );
          }
        }
      });

      final detail = await getRecord(id);
      if (detail == null) {
        throw DatabaseError('Record $id not found after update');
      }
      return detail;
    } on AppError {
      rethrow;
    } catch (e) {
      throw DatabaseError('Failed to update record $id', e);
    }
  }

  /// Soft-deletes a record by setting [deletedAt] to UTC now.
  Future<void> softDeleteRecord(String id) async {
    try {
      await (_db.update(_db.records)..where((r) => r.id.equals(id))).write(
        RecordsCompanion(deletedAt: Value(DateTime.now().toUtc())),
      );
    } catch (e) {
      throw DatabaseError('Failed to soft-delete record $id', e);
    }
  }

  /// Restores a soft-deleted record by clearing [deletedAt].
  Future<void> restoreRecord(String id) async {
    try {
      await (_db.update(_db.records)..where((r) => r.id.equals(id))).write(
        const RecordsCompanion(deletedAt: Value(null)),
      );
    } catch (e) {
      throw DatabaseError('Failed to restore record $id', e);
    }
  }

  /// Permanently deletes a record and its tag associations.
  Future<void> permanentDeleteRecord(String id) async {
    try {
      await _db.transaction(() async {
        await (_db.delete(_db.recordTags)
              ..where((rt) => rt.recordId.equals(id)))
            .go();
        await (_db.delete(_db.records)..where((r) => r.id.equals(id))).go();
      });
    } catch (e) {
      throw DatabaseError('Failed to permanently delete record $id', e);
    }
  }

  /// Returns a single record with its details, or null if not found.
  Future<RecordDetail?> getRecord(String id) async {
    try {
      final row = await (_db.select(_db.records)
            ..where((r) => r.id.equals(id)))
          .getSingleOrNull();
      if (row == null) return null;

      final details = await _db.attachDetails([row]);
      return details.isEmpty ? null : _toDetail(details.first);
    } catch (e) {
      throw DatabaseError('Failed to load record $id', e);
    }
  }

  /// Searches records with optional text query, category, and favorites filter.
  Future<List<RecordDetail>> searchRecords({
    String query = '',
    String? categoryId,
    bool? favoritesOnly,
    bool includeDeleted = false,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final rows = await _db.searchRecords(
        query: query,
        categoryId: categoryId,
        favoritesOnly: favoritesOnly,
        includeDeleted: includeDeleted,
        limit: limit,
        offset: offset,
      );
      return rows.map(_toDetail).toList();
    } catch (e) {
      throw DatabaseError('Failed to search records', e);
    }
  }
}
