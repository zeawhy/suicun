// lib/core/database/app_database.dart
// Drift database definition for 随存

import 'package:drift/drift.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  Records,
  Categories,
  Tags,
  RecordTags,
  // Stage C sync seam stubs
  Revisions,
  Outbox,
  RemoteReceipts,
  SyncState,
  Conflicts,
])
class AppDatabase extends _$AppDatabase {
  /// The executor must be provided by the caller.
  ///
  /// In production, main() opens the SQLCipher-encrypted database via
  /// [DatabaseEncryptionService.openEncryptedDatabase] and passes the
  /// connection here. There is intentionally no plaintext fallback:
  /// a missing executor is a compile-time error, and a failure to open
  /// the encrypted database is a fatal startup error (see main.dart).
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          // Enable WAL mode and foreign keys via pragmas
          await customStatement('PRAGMA foreign_keys = ON');
          await customStatement('PRAGMA journal_mode = WAL');
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // Future migrations will be added here.
          // NEVER delete data or drop tables without user consent.
          // Migrations must be additive and backward-compatible.
          // If a migration fails, the database is preserved as-is.
          if (from < 2) {
            // v2: auto-category keywords on Categories
            await m.addColumn(categories, categories.keywords);
          }
        },
        beforeOpen: (OpeningDetails details) async {
          // Ensure foreign keys are on for every connection
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  // ── Convenience methods for records ───────────────────────────────────────

  /// List all non-deleted records with optional filters and search.
  ///
  /// Search uses parameterized LIKE queries — user input is NEVER interpolated.
  /// % and _ in user input are escaped as literals.
  /// Multi-word search: all tokens must match (AND), each token can match any field.
  Future<List<RecordWithDetails>> searchRecords({
    String query = '',
    String? categoryId,
    bool? favoritesOnly,
    bool includeDeleted = false,
    int limit = 50,
    int offset = 0,
  }) async {
    final tokens = _tokenize(query);

    if (tokens.isEmpty && categoryId == null && favoritesOnly == null) {
      // No filter — simple listing
      return _listRecordsSimple(
        includeDeleted: includeDeleted,
        limit: limit,
        offset: offset,
      );
    }

    return _searchWithTokens(
      tokens: tokens,
      categoryId: categoryId,
      favoritesOnly: favoritesOnly,
      includeDeleted: includeDeleted,
      limit: limit,
      offset: offset,
    );
  }

  /// Tokenize query string by whitespace.
  List<String> _tokenize(String query) {
    return query.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  }

  /// Escape LIKE special characters: %, _, \
  String _escapeLike(String token) {
    return token.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
  }

  Future<List<RecordWithDetails>> _listRecordsSimple({
    required bool includeDeleted,
    required int limit,
    required int offset,
  }) async {
    final query = select(records)
      ..orderBy([
        (r) => OrderingTerm(expression: r.isFavorite, mode: OrderingMode.desc),
        (r) => OrderingTerm(expression: r.updatedAt, mode: OrderingMode.desc),
      ])
      ..limit(limit, offset: offset);

    if (!includeDeleted) {
      query.where((r) => r.deletedAt.isNull());
    } else {
      query.where((r) => r.deletedAt.isNotNull());
    }

    final rows = await query.get();
    return _attachDetails(rows);
  }

  Future<List<RecordWithDetails>> _searchWithTokens({
    required List<String> tokens,
    required String? categoryId,
    required bool? favoritesOnly,
    required bool includeDeleted,
    required int limit,
    required int offset,
  }) async {
    // We use a raw SQL query for the complex multi-token search with ranking.
    // All user input is bound as parameters — never interpolated.
    //
    // Ranking:
    //   score 4 = title exact match
    //   score 3 = title contains
    //   score 2 = tag or category contains
    //   score 1 = body contains

    final params = <Object?>[];
    final conditions = <String>[];

    // Deleted filter
    if (!includeDeleted) {
      conditions.add('r.deleted_at IS NULL');
    } else {
      conditions.add('r.deleted_at IS NOT NULL');
    }

    // Category filter
    if (categoryId != null) {
      conditions.add('r.category_id = ?');
      params.add(categoryId);
    }

    // Favorites filter
    if (favoritesOnly == true) {
      conditions.add('r.is_favorite = 1');
    }

    // Build per-token conditions (AND across tokens, OR across fields per token).
    //
    // IMPORTANT: parameter binding is positional, following the textual order
    // of placeholders in the final SQL. The score expression sits in the
    // SELECT clause (before WHERE), so score params must precede condition
    // params in the bound list. They are collected separately for this reason.
    final scoreParams = <Object?>[];
    final condParams = <Object?>[];
    final tokenScoreExprs = <String>[];
    for (final token in tokens) {
      final escaped = _escapeLike(token.toLowerCase());
      final likePattern = '%$escaped%';
      final exactPattern = token.toLowerCase();

      // Each token: must match at least one field
      conditions.add('''(
        LOWER(r.title) LIKE ? ESCAPE '\\'
        OR LOWER(r.body) LIKE ? ESCAPE '\\'
        OR EXISTS (
          SELECT 1 FROM tags t
          JOIN record_tags rt ON rt.tag_id = t.id
          WHERE rt.record_id = r.id AND t.deleted_at IS NULL
            AND LOWER(t.name) LIKE ? ESCAPE '\\'
        )
        OR (r.category_id IS NOT NULL AND EXISTS (
          SELECT 1 FROM categories c
          WHERE c.id = r.category_id AND c.deleted_at IS NULL
            AND LOWER(c.name) LIKE ? ESCAPE '\\'
        ))
      )''');
      condParams.addAll([likePattern, likePattern, likePattern, likePattern]);

      // Ranking contribution of this token
      tokenScoreExprs.add('''(
        CASE WHEN LOWER(r.title) = ? THEN 4
             WHEN LOWER(r.title) LIKE ? ESCAPE '\\' THEN 3
             WHEN EXISTS (
               SELECT 1 FROM tags t
               JOIN record_tags rt ON rt.tag_id = t.id
               WHERE rt.record_id = r.id AND t.deleted_at IS NULL
                 AND LOWER(t.name) LIKE ? ESCAPE '\\'
             ) OR (r.category_id IS NOT NULL AND EXISTS (
               SELECT 1 FROM categories c
               WHERE c.id = r.category_id AND c.deleted_at IS NULL
                 AND LOWER(c.name) LIKE ? ESCAPE '\\'
             )) THEN 2
             WHEN LOWER(r.body) LIKE ? ESCAPE '\\' THEN 1
             ELSE 0 END
      )''');
      scoreParams
          .addAll([exactPattern, likePattern, likePattern, likePattern, likePattern]);
    }

    final whereClause =
        conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';

    final scoreExpr = tokenScoreExprs.isNotEmpty
        ? tokenScoreExprs.join(' + ')
        : '0';

    final sql = '''
      SELECT r.id,
             ($scoreExpr) AS match_score
      FROM records r
      $whereClause
      ORDER BY match_score DESC,
               r.is_favorite DESC,
               r.updated_at DESC
      LIMIT ? OFFSET ?
    ''';
    // Textual placeholder order: [categoryId?] then score params (SELECT),
    // then condition params (WHERE), then LIMIT/OFFSET.
    final allParams = <Object?>[...params, ...scoreParams, ...condParams];
    allParams.add(limit);
    allParams.add(offset);

    final result = await customSelect(sql, variables: [
      for (final p in allParams)
        if (p is String)
          Variable.withString(p)
        else if (p is int)
          Variable.withInt(p)
        else
          Variable.withString(p.toString()),
    ]).get();

    final ids = result.map((r) => r.read<String>('id')).toList();
    if (ids.isEmpty) return [];

    // Fetch full records in order
    final recordMap = <String, Record>{};
    for (final row in await (select(records)
          ..where((r) => r.id.isIn(ids)))
        .get()) {
      recordMap[row.id] = row;
    }

    final ordered = ids.map((id) => recordMap[id]).whereType<Record>().toList();
    return _attachDetails(ordered);
  }

  /// Public entry point so repositories can reuse the join logic.
  Future<List<RecordWithDetails>> attachDetails(List<Record> rows) =>
      _attachDetails(rows);

  /// Attach tags and category details to records.
  Future<List<RecordWithDetails>> _attachDetails(List<Record> rows) async {
    if (rows.isEmpty) return [];

    final ids = rows.map((r) => r.id).toList();

    // Load tags for all records
    final tagJoins = await (select(recordTags)
          ..where((rt) => rt.recordId.isIn(ids)))
        .get();
    final tagIds = tagJoins.map((j) => j.tagId).toSet().toList();
    final tagMap = <String, Tag>{};
    if (tagIds.isNotEmpty) {
      for (final tag in await (select(tags)
            ..where((t) => t.id.isIn(tagIds)))
          .get()) {
        tagMap[tag.id] = tag;
      }
    }

    final recordTagMap = <String, List<Tag>>{};
    for (final join in tagJoins) {
      final tag = tagMap[join.tagId];
      if (tag != null) {
        recordTagMap.putIfAbsent(join.recordId, () => []).add(tag);
      }
    }

    // Load categories
    final catIds = rows.map((r) => r.categoryId).whereType<String>().toSet().toList();
    final catMap = <String, Category>{};
    if (catIds.isNotEmpty) {
      for (final cat in await (select(categories)
            ..where((c) => c.id.isIn(catIds)))
          .get()) {
        catMap[cat.id] = cat;
      }
    }

    return rows.map((r) => RecordWithDetails(
          record: r,
          category: r.categoryId != null ? catMap[r.categoryId!] : null,
          tags: recordTagMap[r.id] ?? [],
        )).toList();
  }
}

/// Domain object combining record with its associated category and tags.
class RecordWithDetails {
  final Record record;
  final Category? category;
  final List<Tag> tags;

  const RecordWithDetails({
    required this.record,
    required this.category,
    required this.tags,
  });
}

/// NOTE: the old plaintext `_openConnection()` was removed in stage B.
/// The database is always opened encrypted via
/// DatabaseEncryptionService.openEncryptedDatabase() in main().
