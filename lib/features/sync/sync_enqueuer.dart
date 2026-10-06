// lib/features/sync/sync_enqueuer.dart
// Stage C: turns local entity writes into encrypted revisions + outbox rows.
//
// All enqueue* methods MUST be called inside the caller's drift transaction,
// so the entity write, the revision and the outbox entry commit atomically.
// They are no-ops when no vault session exists (sync not joined).

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/features/sync/entity_snapshot.dart';
import 'package:suicun/features/sync/sync_store.dart';
import 'package:suicun/features/sync/vault_crypto.dart';

const _uuid = Uuid();

typedef VaultSessionProvider = Future<MultiKeySession?> Function();

class SyncEnqueuer {
  SyncEnqueuer({
    required AppDatabase db,
    required this.sessionProvider,
    VaultCrypto? crypto,
  })  : _store = SyncStore(db),
        _crypto = crypto ?? VaultCrypto();

  final SyncStore _store;
  final VaultCrypto _crypto;
  VaultSessionProvider sessionProvider;

  /// Set by the engine: debounced sync trigger.
  void Function()? onEnqueued;

  Future<void> enqueueRecordSnapshot({
    required String recordId,
    required String title,
    required String body,
    String? categoryId,
    required List<String> tagIds,
    required bool isFavorite,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) =>
      _enqueueTyped(
        EntitySnapshots.recordType,
        recordId,
        false,
        () => EntitySnapshots.recordSnapshot(
          title: title,
          body: body,
          categoryId: categoryId,
          tagIds: tagIds,
          isFavorite: isFavorite,
          createdAt: createdAt,
          updatedAt: updatedAt,
        ),
      );

  Future<void> enqueueRecordTombstone(String recordId) => _enqueueTyped(
      EntitySnapshots.recordType, recordId, true, EntitySnapshots.tombstone);

  Future<void> enqueueCategorySnapshot({
    required String id,
    required String name,
    required String color,
  }) =>
      _enqueueTyped(
        EntitySnapshots.categoryType,
        id,
        false,
        () => EntitySnapshots.categorySnapshot(name: name, color: color),
      );

  Future<void> enqueueCategoryTombstone(String id) => _enqueueTyped(
      EntitySnapshots.categoryType, id, true, EntitySnapshots.tombstone);

  Future<void> enqueueTagSnapshot({required String id, required String name}) =>
      _enqueueTyped(EntitySnapshots.tagType, id, false,
          () => EntitySnapshots.tagSnapshot(name: name));

  Future<void> enqueueTagTombstone(String id) => _enqueueTyped(
      EntitySnapshots.tagType, id, true, EntitySnapshots.tombstone);

  Future<void> _enqueueTyped(
    String type,
    String entityId,
    bool deleted,
    Map<String, Object?> Function() snapshot,
  ) async {
    if (await sessionProvider() == null) return;
    final heads = await _store.computeHeads(type, entityId);
    await enqueueParsed(
      entityType: type,
      entityId: entityId,
      parents: heads.map((h) => h.revisionId).toList(),
      deleted: deleted,
      snapshot: snapshot(),
    );
  }

  /// Generic enqueue; also used by conflict resolution. Caller owns the
  /// transaction. Returns the new revision id ('' when there is no session).
  Future<String> enqueueParsed({
    required String entityType,
    required String entityId,
    required List<String> parents,
    required bool deleted,
    required Map<String, Object?> snapshot,
  }) async {
    final session = await sessionProvider();
    if (session == null || !session.keys.containsKey(session.activeKeyId)) return '';
    final kvault = session.keys[session.activeKeyId]!;
    final now = DateTime.now().toUtc();
    final revisionId = _uuid.v4();
    final payload = EntitySnapshots.payload(
      revisionId: revisionId,
      entityType: entityType,
      entityId: entityId,
      parents: parents,
      createdAt: now,
      deleted: deleted,
      snapshot: snapshot,
    );
    final bytes = await _crypto.encryptRevisionV2(
      kvault: kvault,
      keyId: session.activeKeyId,
      revisionId: revisionId,
      entityType: entityType,
      entityId: entityId,
      payload: payload,
    );
    await _store.insertRevision(RevisionsCompanion.insert(
      revisionId: revisionId,
      entityType: entityType,
      entityId: entityId,
      parentsJson: Value(jsonEncode(parents)),
      payloadJson: utf8.decode(bytes),
      createdAt: now,
      receivedAt: now,
      isLocal: const Value(true),
    ));
    await _store.enqueueOutbox(OutboxCompanion.insert(
      operationId: _uuid.v4(),
      revisionId: revisionId,
      status: const Value('pending'),
      createdAt: now,
    ));
    onEnqueued?.call();
    return revisionId;
  }
}
