// lib/features/sync/entity_snapshot.dart
// Stage C: revision payload format (full-entity snapshots / tombstones) and
// the applier that materializes a revision into the local tables.
//
// Payload (the plaintext that is encrypted into an object):
//   { revision_id, entity_type, entity_id, parents: [..], created_at,
//     deleted, snapshot: {..} }
// Snapshots are FULL entity states (never diffs), so any head revision is
// self-sufficient. Plaintext only ever exists in memory and in the encrypted
// local database; it is never logged.

import 'package:drift/drift.dart';

import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/features/categories/data/category_repository.dart';

/// Builds and parses revision payloads.
abstract final class EntitySnapshots {
  static const recordType = 'record';
  static const categoryType = 'category';
  static const tagType = 'tag';

  static const _types = {recordType, categoryType, tagType};

  static Map<String, Object?> recordSnapshot({
    required String title,
    required String body,
    String? categoryId,
    required List<String> tagIds,
    required bool isFavorite,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) =>
      {
        'title': title,
        'body': body,
        'category_id': categoryId,
        'tag_ids': List<String>.of(tagIds)..sort(),
        'is_favorite': isFavorite,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  static Map<String, Object?> categorySnapshot({
    required String name,
    required String color,
  }) =>
      {'name': name, 'color': color};

  static Map<String, Object?> tagSnapshot({required String name}) =>
      {'name': name};

  static Map<String, Object?> tombstone() => <String, Object?>{};

  static Map<String, Object?> payload({
    required String revisionId,
    required String entityType,
    required String entityId,
    required List<String> parents,
    required DateTime createdAt,
    required bool deleted,
    required Map<String, Object?> snapshot,
  }) =>
      {
        'revision_id': revisionId,
        'entity_type': entityType,
        'entity_id': entityId,
        'parents': List<String>.of(parents),
        'created_at': createdAt.toUtc().toIso8601String(),
        'deleted': deleted,
        'snapshot': snapshot,
      };

  /// Validates types and shapes; throws [SnapshotFormatError].
  static ParsedRevision parse(Map<String, Object?> payload) {
    String str(Map<String, Object?> m, String k) {
      final v = m[k];
      if (v is! String || v.isEmpty) throw SnapshotFormatError(k);
      return v;
    }

    final entityType = str(payload, 'entity_type');
    if (!_types.contains(entityType)) throw const SnapshotFormatError('type');
    final parentsRaw = payload['parents'];
    if (parentsRaw is! List || parentsRaw.any((p) => p is! String)) {
      throw const SnapshotFormatError('parents');
    }
    final deleted = payload['deleted'];
    if (deleted is! bool) throw const SnapshotFormatError('deleted');
    final snap = payload['snapshot'];
    if (snap is! Map) throw const SnapshotFormatError('snapshot');
    final snapshot = Map<String, Object?>.from(snap);
    final createdAt = _date(payload['created_at'], 'created_at');

    if (!deleted) {
      switch (entityType) {
        case recordType:
          _requireString(snapshot, 'title');
          _requireString(snapshot, 'body');
          final cat = snapshot['category_id'];
          if (cat != null && cat is! String) {
            throw const SnapshotFormatError('category_id');
          }
          final tags = snapshot['tag_ids'];
          if (tags is! List || tags.any((t) => t is! String)) {
            throw const SnapshotFormatError('tag_ids');
          }
          if (snapshot['is_favorite'] is! bool) {
            throw const SnapshotFormatError('is_favorite');
          }
          _date(snapshot['created_at'], 'snapshot.created_at');
          _date(snapshot['updated_at'], 'snapshot.updated_at');
        case categoryType:
          _requireString(snapshot, 'name');
          _requireString(snapshot, 'color');
        case tagType:
          _requireString(snapshot, 'name');
      }
    }

    return ParsedRevision(
      revisionId: str(payload, 'revision_id'),
      entityType: entityType,
      entityId: str(payload, 'entity_id'),
      parents: parentsRaw.cast<String>().toList(),
      createdAt: createdAt,
      deleted: deleted,
      snapshot: snapshot,
    );
  }

  static void _requireString(Map<String, Object?> m, String k) {
    if (m[k] is! String) throw SnapshotFormatError('snapshot.$k');
  }

  static DateTime _date(Object? v, String field) {
    if (v is! String) throw SnapshotFormatError(field);
    final d = DateTime.tryParse(v);
    if (d == null) throw SnapshotFormatError(field);
    return d.toUtc();
  }
}

class ParsedRevision {
  const ParsedRevision({
    required this.revisionId,
    required this.entityType,
    required this.entityId,
    required this.parents,
    required this.createdAt,
    required this.deleted,
    required this.snapshot,
  });

  final String revisionId;
  final String entityType;
  final String entityId;
  final List<String> parents;
  final DateTime createdAt;
  final bool deleted;
  final Map<String, Object?> snapshot;
}

/// A payload failed structural validation. Carries only the field name.
class SnapshotFormatError implements Exception {
  const SnapshotFormatError(this.field);

  final String field;

  @override
  String toString() => 'SnapshotFormatError($field)';
}

/// Materializes revisions into the local entity tables.
class SnapshotApplier {
  SnapshotApplier(this._db);

  final AppDatabase _db;

  /// Applies a parsed revision to local tables. The caller owns the
  /// transaction. Never enqueues anything (remote state must not echo back).
  Future<void> apply(ParsedRevision rev) {
    switch (rev.entityType) {
      case EntitySnapshots.recordType:
        return _applyRecord(rev);
      case EntitySnapshots.categoryType:
        return _applyCategory(rev);
      case EntitySnapshots.tagType:
        return _applyTag(rev);
    }
    return Future.value();
  }

  static DateTime _dt(Object? v) => DateTime.parse(v! as String).toUtc();

  Future<void> _applyRecord(ParsedRevision rev) async {
    final id = rev.entityId;
    if (rev.deleted) {
      // Soft-delete only: the row stays so the record remains in the trash.
      await (_db.update(_db.records)..where((r) => r.id.equals(id)))
          .write(RecordsCompanion(deletedAt: Value(rev.createdAt)));
      return;
    }
    final s = rev.snapshot;

    // Drop references to entities that do not exist locally (FK safety).
    String? categoryId = s['category_id'] as String?;
    if (categoryId != null) {
      final cat = await (_db.select(_db.categories)
            ..where((c) => c.id.equals(categoryId!)))
          .getSingleOrNull();
      if (cat == null) categoryId = null;
    }
    final wantedTags = (s['tag_ids']! as List).cast<String>();
    final knownTagRows = wantedTags.isEmpty
        ? <Tag>[]
        : await (_db.select(_db.tags)..where((t) => t.id.isIn(wantedTags)))
            .get();
    final tagIds = knownTagRows.map((t) => t.id).toSet();

    // Upsert (not REPLACE): REPLACE would delete the parent row and violate
    // the record_tags foreign key.
    final companion = RecordsCompanion(
      id: Value(id),
      title: Value(s['title']! as String),
      body: Value(s['body']! as String),
      categoryId: Value(categoryId),
      isFavorite: Value(s['is_favorite']! as bool),
      createdAt: Value(_dt(s['created_at'])),
      updatedAt: Value(_dt(s['updated_at'])),
      deletedAt: const Value(null),
    );
    await _db.into(_db.records).insert(
          companion,
          onConflict: DoUpdate((_) => companion, target: [_db.records.id]),
        );
    await (_db.delete(_db.recordTags)..where((rt) => rt.recordId.equals(id)))
        .go();
    for (final tagId in tagIds) {
      await _db
          .into(_db.recordTags)
          .insert(RecordTagsCompanion.insert(recordId: id, tagId: tagId));
    }
  }

  static List<String>? _findDefaultKeywords(String name) {
    final lower = name.trim().toLowerCase();
    for (final def in CategoryRepository.defaultCategories) {
      if (def.name.trim().toLowerCase() == lower) {
        return def.keywords;
      }
    }
    return null;
  }

  Future<void> _applyCategory(ParsedRevision rev) async {
    final id = rev.entityId;
    if (rev.deleted) {
      await (_db.update(_db.records)..where((r) => r.categoryId.equals(id)))
          .write(const RecordsCompanion(categoryId: Value(null)));
      await (_db.update(_db.categories)..where((c) => c.id.equals(id)))
          .write(CategoriesCompanion(deletedAt: Value(rev.createdAt)));
      return;
    }
    final s = rev.snapshot;
    final name = s['name']! as String;
    final color = s['color']! as String;
    final seedKeywords = _findDefaultKeywords(name);
    final existing = await (_db.select(_db.categories)
          ..where((c) => c.id.equals(id)))
        .getSingleOrNull();
    if (existing == null) {
      await _db.into(_db.categories).insert(CategoriesCompanion.insert(
            id: id,
            name: name,
            color: Value(color),
            keywords: seedKeywords != null
                ? Value(CategoryRepository.encodeKeywords(seedKeywords))
                : const Value.absent(),
          ));
    } else {
      // Update in place: keeps local-only columns (keywords), but backfills
      // starter keywords if the category currently has no keywords.
      final existingKeywords =
          CategoryRepository.decodeKeywords(existing.keywords);
      final shouldBackfill = existingKeywords.isEmpty && seedKeywords != null;
      await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
        CategoriesCompanion(
          name: Value(name),
          color: Value(color),
          keywords: shouldBackfill
              ? Value(CategoryRepository.encodeKeywords(seedKeywords))
              : const Value.absent(),
          deletedAt: const Value(null),
        ),
      );
    }
  }

  Future<void> _applyTag(ParsedRevision rev) async {
    final id = rev.entityId;
    if (rev.deleted) {
      await (_db.delete(_db.recordTags)..where((rt) => rt.tagId.equals(id)))
          .go();
      await (_db.update(_db.tags)..where((t) => t.id.equals(id)))
          .write(TagsCompanion(deletedAt: Value(rev.createdAt)));
      return;
    }
    final name = rev.snapshot['name']! as String;
    final existing = await (_db.select(_db.tags)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existing == null) {
      await _db
          .into(_db.tags)
          .insert(TagsCompanion.insert(id: id, name: name));
    } else {
      await (_db.update(_db.tags)..where((t) => t.id.equals(id))).write(
        TagsCompanion(name: Value(name), deletedAt: const Value(null)),
      );
    }
  }
}
