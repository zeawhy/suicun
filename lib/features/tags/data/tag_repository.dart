// lib/features/tags/data/tag_repository.dart

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/core/database/tables.dart';
import 'package:suicun/core/errors/app_errors.dart';
import 'package:suicun/features/tags/domain/tag_model.dart';

const _uuid = Uuid();

class TagRepository {
  TagRepository(this._db);

  final AppDatabase _db;

  static TagModel _toModel(Tag t) => TagModel(
        id: t.id,
        name: t.name,
        deletedAt: t.deletedAt?.toUtc(),
      );

  /// All non-deleted tags ordered by name.
  Future<List<TagModel>> getAllTags() async {
    try {
      final rows = await (_db.select(_db.tags)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm(expression: t.name)]))
          .get();
      return rows.map(_toModel).toList();
    } catch (e) {
      throw DatabaseError('Failed to load tags', e);
    }
  }

  /// Tags associated with a specific record (non-deleted only).
  Future<List<TagModel>> getTagsForRecord(String recordId) async {
    try {
      final joins = await (_db.select(_db.recordTags)
            ..where((rt) => rt.recordId.equals(recordId)))
          .get();
      if (joins.isEmpty) return [];
      final tagIds = joins.map((j) => j.tagId).toList();
      final rows = await (_db.select(_db.tags)
            ..where((t) => t.id.isIn(tagIds) & t.deletedAt.isNull()))
          .get();
      return rows.map(_toModel).toList();
    } catch (e) {
      throw DatabaseError('Failed to load tags for record $recordId', e);
    }
  }

  /// Finds an existing non-deleted tag by name (case-insensitive) or creates one.
  /// Also restores a previously soft-deleted tag with the same name.
  Future<TagModel> findOrCreateTag(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw const ValidationError('Tag name is empty');

    try {
      // Check all tags (including soft-deleted) for same name
      final existing = await (_db.select(_db.tags)).get();
      final match = existing.where(
        (t) => t.name.toLowerCase() == trimmed.toLowerCase(),
      );

      if (match.isNotEmpty) {
        final tag = match.first;
        if (tag.deletedAt != null) {
          // Restore the soft-deleted tag
          await (_db.update(_db.tags)..where((t) => t.id.equals(tag.id)))
              .write(const TagsCompanion(deletedAt: Value(null)));
        }
        return _toModel(await (_db.select(_db.tags)
              ..where((t) => t.id.equals(tag.id)))
            .getSingle());
      }

      // Create new tag
      final id = _uuid.v4();
      await _db.into(_db.tags).insert(TagsCompanion.insert(
            id: id,
            name: trimmed,
          ));
      return _toModel(await (_db.select(_db.tags)
            ..where((t) => t.id.equals(id)))
          .getSingle());
    } catch (e) {
      throw DatabaseError('Failed to find or create tag "$trimmed"', e);
    }
  }

  /// Renames a tag. Throws [ValidationError] if the new name already exists.
  Future<TagModel> renameTag(String id, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) throw const ValidationError('Tag name is empty');

    final all = await getAllTags();
    final dup = all.any(
      (t) => t.name.toLowerCase() == trimmed.toLowerCase() && t.id != id,
    );
    if (dup) throw const ValidationError('Tag name already exists');

    try {
      await (_db.update(_db.tags)..where((t) => t.id.equals(id)))
          .write(TagsCompanion(name: Value(trimmed)));
      return _toModel(await (_db.select(_db.tags)
            ..where((t) => t.id.equals(id)))
          .getSingle());
    } catch (e) {
      throw DatabaseError('Failed to rename tag $id', e);
    }
  }

  /// Soft-deletes a tag and removes all its record associations.
  Future<void> deleteTag(String id) async {
    try {
      await _db.transaction(() async {
        await (_db.delete(_db.recordTags)
              ..where((rt) => rt.tagId.equals(id)))
            .go();
        await (_db.update(_db.tags)..where((t) => t.id.equals(id))).write(
          TagsCompanion(deletedAt: Value(DateTime.now().toUtc())),
        );
      });
    } catch (e) {
      throw DatabaseError('Failed to delete tag $id', e);
    }
  }
}
