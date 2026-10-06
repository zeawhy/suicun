// lib/core/database/tables.dart
// Drift table definitions for 随存 Stage A
// Schema version 3 — migration mechanism must be maintained
// v3 replaced the empty sync stub tables with the real Stage C sync schema
// v2 added: Categories.keywords (nullable TEXT, JSON string array)

import 'package:drift/drift.dart';

/// Records table: the core entity
class Records extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get body => text().withDefault(const Constant(''))();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  // local_seq: monotonically increasing, for sync seam (stage C)
  IntColumn get localSeq => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Categories table: one-level categories with optional color
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  // Color stored as hex string e.g. "#4866D5"
  TextColumn get color => text().withDefault(const Constant('#4866D5'))();
  // Auto-category keywords stored as a JSON string array, e.g. '["美食","餐厅"]'.
  // Nullable: null (or empty array) means "no keywords configured yet".
  TextColumn get keywords => text().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tags table
class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Record-tag many-to-many relationship
class RecordTags extends Table {
  TextColumn get recordId => text().references(Records, #id)();
  TextColumn get tagId => text().references(Tags, #id)();

  @override
  Set<Column> get primaryKey => {recordId, tagId};
}

// ── Sync tables (Stage C, schema v3) ─────────────────────────────────────────

/// Immutable revisions: every local edit and every downloaded remote revision.
class Revisions extends Table {
  TextColumn get revisionId => text()();
  // 'record' | 'category' | 'tag'
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get parentsJson => text().withDefault(const Constant('[]'))();
  // Full encrypted revision JSON (exact bytes uploaded to / downloaded from
  // the server, UTF-8 decoded).
  TextColumn get payloadJson => text()();
  // The revision's own creation time (from its payload).
  DateTimeColumn get createdAt => dateTime()();
  // Time this device stored it.
  DateTimeColumn get receivedAt => dateTime()();
  BoolColumn get isLocal => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {revisionId};
}

/// Outbox for the upload queue.
class Outbox extends Table {
  TextColumn get operationId => text()();
  TextColumn get revisionId => text()();
  TextColumn get status =>
      text().withDefault(const Constant('pending'))(); // pending|uploading|done|failed
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextRetryAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  // SyncErrorCode name only.
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {operationId};
}

/// Remote receipts: revisions confirmed present on the server.
class RemoteReceipts extends Table {
  TextColumn get revisionId => text()();
  TextColumn get remotePath => text()();
  TextColumn get etag => text().nullable()();
  DateTimeColumn get observedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {revisionId};
}

/// Sync state (one row per joined vault).
class SyncState extends Table {
  TextColumn get vaultId => text()();
  TextColumn get deviceId => text()();
  IntColumn get protocolVersion => integer().withDefault(const Constant(1))();
  DateTimeColumn get lastSuccessAt => dateTime().nullable()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  // SyncErrorCode name only.
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {vaultId};
}

/// Conflicts: entities with more than one head revision.
class Conflicts extends Table {
  TextColumn get id => text()();
  TextColumn get entityId => text()();
  TextColumn get entityType => text()();
  TextColumn get headRevisionIdsJson =>
      text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get resolutionRevisionId => text().nullable()();
  DateTimeColumn get resolvedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Remote objects permanently skipped (undecryptable / oversize / malformed),
/// so they are not downloaded again on every pass.
class SyncSkipped extends Table {
  TextColumn get revisionId => text()();
  TextColumn get reason => text()();
  DateTimeColumn get skippedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {revisionId};
}
