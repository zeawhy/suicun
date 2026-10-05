// lib/core/database/tables.dart
// Drift table definitions for 随存 Stage A
// Schema version 2 — migration mechanism must be maintained
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

// ── Sync seam tables (schema placeholder for Stage C) ────────────────────────
// These tables are defined now to establish the migration baseline.
// Stage A does NOT use these tables — they are empty stubs only.

/// Immutable version records for sync (Stage C)
class Revisions extends Table {
  TextColumn get revisionId => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get parentsJson => text().withDefault(const Constant('[]'))();
  TextColumn get encryptedPayload => text().withDefault(const Constant(''))();
  TextColumn get state => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {revisionId};
}

/// Outbox for upload queue (Stage C)
class Outbox extends Table {
  TextColumn get operationId => text()();
  TextColumn get revisionId => text()();
  TextColumn get status =>
      text().withDefault(const Constant('pending'))(); // pending|uploading|done|failed
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextRetryAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {operationId};
}

/// Remote receipts (Stage C)
class RemoteReceipts extends Table {
  TextColumn get revisionId => text()();
  TextColumn get remotePath => text()();
  DateTimeColumn get observedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {revisionId};
}

/// Sync state (Stage C)
class SyncState extends Table {
  TextColumn get vaultId => text()();
  TextColumn get deviceId => text()();
  IntColumn get protocolVersion => integer().withDefault(const Constant(1))();
  DateTimeColumn get lastSuccessAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {vaultId};
}

/// Conflicts (Stage C)
class Conflicts extends Table {
  TextColumn get id => text()();
  TextColumn get entityId => text()();
  TextColumn get headRevisionIdsJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get resolutionRevisionId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
