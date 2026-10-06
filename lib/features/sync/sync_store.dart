// lib/features/sync/sync_store.dart
// Stage C: database access for the sync tables (revisions, outbox, receipts,
// state, conflicts, skipped objects).
//
// Transaction notes: methods that are part of a multi-step invariant are
// marked "CALLER TRANSACTION" — the caller must wrap them (together with the
// related writes) in a single `db.transaction`. All other methods are safe
// to call standalone.

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:suicun/core/database/app_database.dart';

const _uuid = Uuid();

class SyncStore {
  SyncStore(this._db);

  final AppDatabase _db;

  // ── Revisions ─────────────────────────────────────────────────────────────

  /// Inserts a revision. Revisions are immutable, so an existing row with the
  /// same id is left untouched (makes recovery/resume idempotent).
  ///
  /// CALLER TRANSACTION: together with the entity write / outbox insert.
  Future<void> insertRevision(RevisionsCompanion companion) =>
      _db.into(_db.revisions).insert(companion, mode: InsertMode.insertOrIgnore);

  Future<Revision?> getRevision(String id) => (_db.select(_db.revisions)
        ..where((r) => r.revisionId.equals(id)))
      .getSingleOrNull();

  Future<bool> hasRevision(String id) async => await getRevision(id) != null;

  Future<Set<String>> allRevisionIds() async {
    final q = _db.selectOnly(_db.revisions)
      ..addColumns([_db.revisions.revisionId]);
    final rows = await q.get();
    return rows.map((r) => r.read(_db.revisions.revisionId)!).toSet();
  }

  /// All revisions of an entity ordered by their own creation time.
  Future<List<Revision>> revisionsForEntity(String type, String id) =>
      (_db.select(_db.revisions)
            ..where((r) => r.entityType.equals(type) & r.entityId.equals(id))
            ..orderBy([
              (r) => OrderingTerm(expression: r.createdAt),
              (r) => OrderingTerm(expression: r.revisionId),
            ]))
          .get();

  static List<String> parentsOf(Revision r) {
    try {
      final d = jsonDecode(r.parentsJson);
      if (d is List) return d.whereType<String>().toList();
    } catch (_) {}
    return const [];
  }

  /// Head revisions of an entity: those that are not the parent of any other
  /// revision of the same entity.
  Future<List<Revision>> computeHeads(String type, String id) async {
    final revs = await revisionsForEntity(type, id);
    final referenced = <String>{};
    for (final r in revs) {
      referenced.addAll(parentsOf(r));
    }
    return revs.where((r) => !referenced.contains(r.revisionId)).toList();
  }

  /// All ancestors (transitive parents) of [revisionId] within the entity.
  /// Parents are same-entity by construction. Memoized in-memory walk.
  Future<Set<String>> ancestorsOf(
      String type, String id, String revisionId) async {
    final revs = await revisionsForEntity(type, id);
    final parents = {for (final r in revs) r.revisionId: parentsOf(r)};
    final memo = <String, Set<String>>{};
    Set<String> walk(String rid, Set<String> visiting) {
      final cached = memo[rid];
      if (cached != null) return cached;
      final out = <String>{};
      if (!visiting.add(rid)) return out; // cycle guard
      for (final p in parents[rid] ?? const <String>[]) {
        out.add(p);
        out.addAll(walk(p, visiting));
      }
      visiting.remove(rid);
      memo[rid] = out;
      return out;
    }

    return walk(revisionId, <String>{});
  }

  // ── Outbox ────────────────────────────────────────────────────────────────

  /// CALLER TRANSACTION: together with the revision insert.
  Future<void> enqueueOutbox(OutboxCompanion companion) =>
      _db.into(_db.outbox).insert(companion);

  /// Entries that are due: status pending|failed and retry time reached.
  Future<List<OutboxData>> pendingOutbox({int limit = 100}) {
    final now = DateTime.now().toUtc();
    return (_db.select(_db.outbox)
          ..where((o) =>
              o.status.isIn(const ['pending', 'failed', 'uploading']) &
              (o.nextRetryAt.isNull() | o.nextRetryAt.isSmallerOrEqualValue(now)))
          ..orderBy([(o) => OrderingTerm(expression: o.createdAt)])
          ..limit(limit))
        .get();
  }

  /// Number of entries not yet confirmed on the server (regardless of backoff).
  Future<int> pendingOutboxCount() async {
    final count = _db.outbox.operationId.count();
    final q = _db.selectOnly(_db.outbox)..addColumns([count]);
    return (await q.getSingle()).read(count) ?? 0;
  }

  Future<void> markOutboxUploading(String opId) =>
      (_db.update(_db.outbox)..where((o) => o.operationId.equals(opId)))
          .write(const OutboxCompanion(status: Value('uploading')));

  /// Deletes the row (done entries carry no information; the receipt does).
  ///
  /// CALLER TRANSACTION: together with [putReceipt].
  Future<void> markOutboxDone(String opId) =>
      (_db.delete(_db.outbox)..where((o) => o.operationId.equals(opId))).go();

  Future<void> markOutboxFailed(
    String opId,
    String errorCode,
    DateTime nextRetryAt,
    int attemptCount,
  ) =>
      (_db.update(_db.outbox)..where((o) => o.operationId.equals(opId))).write(
        OutboxCompanion(
          status: const Value('failed'),
          lastError: Value(errorCode),
          nextRetryAt: Value(nextRetryAt.toUtc()),
          attemptCount: Value(attemptCount),
        ),
      );

  // ── Receipts ──────────────────────────────────────────────────────────────

  Future<void> putReceipt(String revisionId, String remotePath, String? etag) =>
      _db.into(_db.remoteReceipts).insert(
            RemoteReceiptsCompanion.insert(
              revisionId: revisionId,
              remotePath: remotePath,
              etag: Value(etag),
              observedAt: DateTime.now().toUtc(),
            ),
            mode: InsertMode.insertOrReplace,
          );

  Future<bool> hasReceipt(String revisionId) async =>
      await (_db.select(_db.remoteReceipts)
            ..where((r) => r.revisionId.equals(revisionId)))
          .getSingleOrNull() !=
      null;

  // ── State ─────────────────────────────────────────────────────────────────

  /// The (single) sync state row, or null when never joined.
  Future<SyncStateData?> getState() async {
    final rows = await _db.select(_db.syncState).get();
    return rows.isEmpty ? null : rows.first;
  }

  /// Stores the joined vault. Only one vault is kept: rows for other vaults
  /// are removed.
  ///
  /// CALLER TRANSACTION.
  Future<void> saveState({
    required String vaultId,
    required String deviceId,
    required bool enabled,
    int protocolVersion = 1,
  }) async {
    await (_db.delete(_db.syncState)..where((s) => s.vaultId.equals(vaultId).not()))
        .go();
    await _db.into(_db.syncState).insert(
          SyncStateCompanion.insert(
            vaultId: vaultId,
            deviceId: deviceId,
            protocolVersion: Value(protocolVersion),
            enabled: Value(enabled),
          ),
          onConflict: DoUpdate(
            (_) => SyncStateCompanion(
              deviceId: Value(deviceId),
              protocolVersion: Value(protocolVersion),
              enabled: Value(enabled),
            ),
            target: [_db.syncState.vaultId],
          ),
        );
  }

  Future<void> setLastSuccess(DateTime at) =>
      _db.update(_db.syncState).write(
          SyncStateCompanion(lastSuccessAt: Value(at.toUtc())));

  Future<void> setEnabled(bool enabled) => _db
      .update(_db.syncState)
      .write(SyncStateCompanion(enabled: Value(enabled)));

  /// [codeName] is a SyncErrorCode name only (never details), or null.
  Future<void> setLastError(String? codeName) => _db
      .update(_db.syncState)
      .write(SyncStateCompanion(lastError: Value(codeName)));

  // ── Conflicts ─────────────────────────────────────────────────────────────

  /// Updates the open conflict of the entity or creates one.
  ///
  /// CALLER TRANSACTION: together with the revision insert that caused it.
  Future<void> upsertOpenConflict({
    required String entityId,
    required String entityType,
    required List<String> headRevisionIds,
  }) async {
    final heads = jsonEncode(headRevisionIds);
    final open = await openConflictFor(entityId);
    if (open != null) {
      await (_db.update(_db.conflicts)..where((c) => c.id.equals(open.id)))
          .write(ConflictsCompanion(headRevisionIdsJson: Value(heads)));
      return;
    }
    await _db.into(_db.conflicts).insert(ConflictsCompanion.insert(
          id: _uuid.v4(),
          entityId: entityId,
          entityType: entityType,
          headRevisionIdsJson: Value(heads),
          createdAt: DateTime.now().toUtc(),
        ));
  }

  Future<Conflict?> openConflictFor(String entityId) =>
      (_db.select(_db.conflicts)
            ..where((c) =>
                c.entityId.equals(entityId) & c.resolutionRevisionId.isNull()))
          .getSingleOrNull();

  Future<List<Conflict>> openConflicts() => (_db.select(_db.conflicts)
        ..where((c) => c.resolutionRevisionId.isNull())
        ..orderBy([(c) => OrderingTerm(expression: c.createdAt)]))
      .get();

  Future<Conflict?> getConflict(String id) => (_db.select(_db.conflicts)
        ..where((c) => c.id.equals(id)))
      .getSingleOrNull();

  Future<void> markConflictResolved(String id, String resolutionRevisionId) =>
      (_db.update(_db.conflicts)..where((c) => c.id.equals(id))).write(
        ConflictsCompanion(
          resolutionRevisionId: Value(resolutionRevisionId),
          resolvedAt: Value(DateTime.now().toUtc()),
        ),
      );

  Future<int> openConflictCount() async {
    final count = _db.conflicts.id.count();
    final q = _db.selectOnly(_db.conflicts)
      ..addColumns([count])
      ..where(_db.conflicts.resolutionRevisionId.isNull());
    return (await q.getSingle()).read(count) ?? 0;
  }

  // ── Skipped remote objects ────────────────────────────────────────────────

  Future<void> markSkipped(String revisionId, String reason) =>
      _db.into(_db.syncSkipped).insert(
            SyncSkippedCompanion.insert(
              revisionId: revisionId,
              reason: reason,
              skippedAt: DateTime.now().toUtc(),
            ),
            mode: InsertMode.insertOrIgnore,
          );

  Future<bool> isSkipped(String id) async =>
      await (_db.select(_db.syncSkipped)..where((s) => s.revisionId.equals(id)))
          .getSingleOrNull() !=
      null;

  Future<Set<String>> allSkippedIds() async {
    final q = _db.selectOnly(_db.syncSkipped)
      ..addColumns([_db.syncSkipped.revisionId]);
    final rows = await q.get();
    return rows.map((r) => r.read(_db.syncSkipped.revisionId)!).toSet();
  }
}
