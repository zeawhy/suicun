// Regression tests for the fix3 "infinite spinner" incident.
//
// Scenario A (phone repro): 5 default categories + 2 records backfilled at
// startup, then syncNow must COMPLETE (never hang): remote objects correct,
// receipts written, overview shows 2/2 synced and 0 pending.
//
// Scenario B (persistent failure): uploads keep failing with a server error.
// syncNow must still complete (bounded retries, no infinite loop), surface a
// visible error, and KEEP the outbox entries for the next attempt.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suicun/core/crypto/key_value_store.dart';
import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/features/records/data/record_repository.dart';
import 'package:suicun/features/sync/session_holder.dart';
import 'package:suicun/features/sync/sync_engine.dart';
import 'package:suicun/features/sync/sync_enqueuer.dart';
import 'package:suicun/features/sync/sync_store.dart';
import 'package:suicun/services/webdav_service.dart';

import 'fake_sync_provider.dart';

class _MemConfigStore implements WebdavConfigStore {
  WebdavConfig? _config;

  @override
  Future<WebdavConfig?> loadConfig() async => _config;

  @override
  Future<void> saveConfig(WebdavConfig config) async => _config = config;

  @override
  Future<void> clearConfig() async => _config = null;
}

const _cfg = WebdavConfig(
  serverUrl: 'https://dav.example.com',
  username: 'alice',
  password: 'secret-dav-password',
  directory: '/suicun/',
);

/// Builds an engine pair (db + engine) with a vault created by an "earlier
/// build": 5 default categories exist but were never synced.
Future<({
  AppDatabase db,
  MemoryKeyValueStore secure,
  _MemConfigStore config,
  Map<String, StoredObject> storage,
  SyncEnqueuer Function() newEnqueuer,
})> _buildPhoneDb() async {
  final db = AppDatabase(NativeDatabase.memory());
  final config = _MemConfigStore();
  final secure = MemoryKeyValueStore();
  final storage = <String, StoredObject>{};
  SyncSessionHolder.current = null;

  SyncEnqueuer newEnqueuer() => SyncEnqueuer(
        db: db,
        sessionProvider: () async => SyncSessionHolder.current,
      );

  // Phase 1: vault created by an earlier build; 5 default categories exist.
  var enqueuer = newEnqueuer();
  final engine1 = SyncEngine(
    db: db,
    configStore: config,
    secureStore: secure,
    syncEnqueuer: enqueuer,
    providerFactory: (_) => FakeSyncProvider(
      supportsConditionalCreate: false,
      supportsConditionalUpdate: false,
      initialStorage: storage,
    ),
    retryPolicy: const RetryPolicy(baseDelay: Duration.zero),
    debounceDelay: const Duration(milliseconds: 50),
  );
  enqueuer.onEnqueued = engine1.notifyLocalChange;
  await engine1.createVault(_cfg, 'vault-pass');
  for (var i = 0; i < 5; i++) {
    await (db.into(db.categories).insert(
          CategoriesCompanion.insert(id: 'cat-$i', name: 'C$i'),
        ));
  }
  // Simulate "pre-fix3 state": the startup-backfill flag is not set yet.
  final state = await db.select(db.syncState).getSingle();
  await secure.delete('suicun.sync.backfilled.${state.vaultId}');
  engine1.dispose();
  SyncSessionHolder.current = null;

  return (
    db: db,
    secure: secure,
    config: config,
    storage: storage,
    newEnqueuer: newEnqueuer,
  );
}

SyncEngine _freshEngine({
  required AppDatabase db,
  required _MemConfigStore config,
  required MemoryKeyValueStore secure,
  required SyncEnqueuer enqueuer,
  required Map<String, StoredObject> storage,
  required FakeSyncProvider Function() providerFactory,
}) {
  final engine = SyncEngine(
    db: db,
    configStore: config,
    secureStore: secure,
    syncEnqueuer: enqueuer,
    providerFactory: (_) => providerFactory(),
    retryPolicy: const RetryPolicy(baseDelay: Duration.zero),
    debounceDelay: const Duration(milliseconds: 50),
  );
  enqueuer.onEnqueued = engine.notifyLocalChange;
  return engine;
}

void main() {
  test(
      'A: 7 backfilled entries (5 cats + 2 records) sync to completion, '
      'remote objects + receipts correct, 2/2 synced', () async {
    final phone = await _buildPhoneDb();
    final enqueuer = phone.newEnqueuer();

    // Phase 2: "overlay install" — fresh engine, startup init + backfill.
    final engine = _freshEngine(
      db: phone.db,
      config: phone.config,
      secure: phone.secure,
      enqueuer: enqueuer,
      storage: phone.storage,
      providerFactory: () => FakeSyncProvider(
        supportsConditionalCreate: false,
        supportsConditionalUpdate: false,
        initialStorage: phone.storage,
      ),
    );
    final records = RecordRepository(phone.db, syncEnqueuer: enqueuer);
    await engine.ensureInitialized();
    await records.createRecord(title: 'One', body: 'a');
    await records.createRecord(title: 'Two', body: 'b');

    final before = await engine.getOverview();
    expect(before.pendingCount, 7); // 5 categories + 2 records

    // Must complete — the watchdog is 3 min; 60s here proves no hang.
    await engine.syncNow().timeout(
      const Duration(seconds: 60),
      onTimeout: () => throw StateError('HANG: syncNow did not complete'),
    );

    final after = await engine.getOverview();
    expect(after.pendingCount, 0);
    expect(after.syncedRecords, 2);
    expect(after.totalRecords, 2);
    expect(after.lastError, isNull);

    // Remote objects: exactly the 7 uploaded revisions.
    final objects = phone.storage.keys
        .where((k) => k.startsWith('v2/objects/'))
        .toList();
    expect(objects, hasLength(7));

    // Receipts: every local revision has a remote receipt.
    final store = SyncStore(phone.db);
    final revs = await phone.db.select(phone.db.revisions).get();
    expect(revs, hasLength(7));
    for (final r in revs) {
      expect(await store.hasReceipt(r.revisionId), isTrue,
          reason: 'missing receipt for ${r.revisionId}');
    }

    engine.dispose();
    await phone.db.close();
    SyncSessionHolder.current = null;
  });

  test(
      'B: persistent upload failure -> bounded retries, visible error, '
      'outbox retained, sync still completes', () async {
    final phone = await _buildPhoneDb();
    final enqueuer = phone.newEnqueuer();
    final fake = FakeSyncProvider(
      supportsConditionalCreate: false,
      supportsConditionalUpdate: false,
      initialStorage: phone.storage,
    )..failAllObjectPuts = true;

    final engine = _freshEngine(
      db: phone.db,
      config: phone.config,
      secure: phone.secure,
      enqueuer: enqueuer,
      storage: phone.storage,
      providerFactory: () => fake,
    );
    final records = RecordRepository(phone.db, syncEnqueuer: enqueuer);
    await engine.ensureInitialized();
    await records.createRecord(title: 'One', body: 'a');

    // Must complete even though every upload fails — no infinite loop.
    await engine.syncNow().timeout(
      const Duration(seconds: 60),
      onTimeout: () => throw StateError('HANG: syncNow did not complete'),
    );

    final after = await engine.getOverview();
    // Visible error (not a fake "success").
    expect(after.lastError, isNotNull);
    // Outbox retained for the next attempt.
    expect(after.pendingCount, greaterThan(0));

    // Bounded retries: each entry attempted a small number of times
    // (backoff keeps them out of the due set; attempts stay small).
    final store = SyncStore(phone.db);
    final outbox = await phone.db.select(phone.db.outbox).get();
    expect(outbox, isNotEmpty);
    for (final o in outbox) {
      expect(o.attemptCount, lessThanOrEqualTo(3),
          reason: 'unbounded retries for ${o.operationId}');
      expect(o.status, isNot('done'));
    }
    // Revisions still present and consistent with outbox entries.
    for (final o in outbox) {
      expect(await store.hasRevision(o.revisionId), isTrue);
    }

    engine.dispose();
    await phone.db.close();
    SyncSessionHolder.current = null;
  });
}
