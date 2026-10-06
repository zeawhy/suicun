// test/unit/sync/lazy_init_regression_test.dart
// Regression: the sync engine used to be created lazily (only when a sync page
// was opened), so SyncSessionHolder.current stayed null after app start and
// edits saved from the home page silently skipped the outbox ("synced 0 of 2").

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suicun/core/crypto/key_value_store.dart';
import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/features/records/data/record_repository.dart';
import 'package:suicun/features/sync/entity_snapshot.dart';
import 'package:suicun/features/sync/session_holder.dart';
import 'package:suicun/features/sync/sync_engine.dart';
import 'package:suicun/features/sync/sync_enqueuer.dart';
import 'package:suicun/features/sync/sync_store.dart';
import 'package:suicun/features/sync/vault_crypto.dart';
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

/// One "app process" over a persistent db / stores.
class _App {
  _App(this.db, this.config, this.secure, this.storage) {
    enqueuer = SyncEnqueuer(
      db: db,
      sessionProvider: () async => SyncSessionHolder.current,
    );
    records = RecordRepository(db, syncEnqueuer: enqueuer);
    engine = SyncEngine(
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
    enqueuer.onEnqueued = engine.notifyLocalChange;
  }

  final AppDatabase db;
  final _MemConfigStore config;
  final MemoryKeyValueStore secure;
  final Map<String, StoredObject> storage;
  late final SyncEnqueuer enqueuer;
  late final RecordRepository records;
  late final SyncEngine engine;
}

void main() {
  const cfg = WebdavConfig(
    serverUrl: 'https://dav.example.com',
    username: 'alice',
    password: 'secret-dav-password',
    directory: '/suicun/',
  );

  MultiKeySession? savedSession;
  late AppDatabase db;
  late _MemConfigStore config;
  late MemoryKeyValueStore secure;
  late Map<String, StoredObject> storage;
  final apps = <_App>[];

  setUp(() {
    savedSession = SyncSessionHolder.current;
    SyncSessionHolder.current = null;
    db = AppDatabase(NativeDatabase.memory());
    config = _MemConfigStore();
    secure = MemoryKeyValueStore();
    storage = <String, StoredObject>{};
  });

  tearDown(() async {
    for (final a in apps) {
      a.engine.dispose();
    }
    apps.clear();
    await db.close();
    SyncSessionHolder.current = savedSession;
  });

  _App newApp() {
    final a = _App(db, config, secure, storage);
    apps.add(a);
    return a;
  }

  int objectCount() =>
      storage.keys.where((k) => k.startsWith('v2/objects/')).length;

  /// Creates a vault, then "restarts" the app: session cleared, fresh engine.
  Future<void> createVaultThenRestartPrepared() async {
    final first = newApp();
    await first.engine.createVault(cfg, 'vault-pass');
    first.engine.dispose();
    apps.remove(first);
    SyncSessionHolder.current = null;
  }

  test('lazy-init regression A: record saved before engine init is uploaded '
      'after init + syncNow', () async {
    await createVaultThenRestartPrepared();
    final state = await db.select(db.syncState).getSingle();
    final vaultId = state.vaultId;
    // Simulate an install that predates the once-per-vault backfill flag.
    await secure.delete('suicun.sync.backfilled.$vaultId');

    final app = newApp(); // engine created but NOT initialized
    final rec = await app.records.createRecord(title: 'T1', body: 'B1');
    expect(SyncSessionHolder.current, isNull);
    expect((await app.engine.getOverview()).pendingCount, 0,
        reason: 'without a session the save is not enqueued');

    await app.engine.ensureInitialized(); // restore + one-per-vault backfill
    expect(SyncSessionHolder.current, isNotNull);
    expect(await secure.read('suicun.sync.backfilled.$vaultId'), '1');
    await app.engine.syncNow();

    expect(objectCount(), 1);
    final overview = await app.engine.getOverview();
    expect(overview.pendingCount, 0);
    expect(overview.totalRecords, 1);
    expect(overview.syncedRecords, 1);

    final store = SyncStore(app.db);
    final heads = await store.computeHeads(EntitySnapshots.recordType, rec.id);
    expect(heads, hasLength(1));
    expect(
      storage.containsKey('v2/objects/${heads.single.revisionId}.enc'),
      isTrue,
    );

    // Flag is set now: a second backfill must return 0.
    expect(await app.engine.backfillLocalEntities(), 0);
  });

  test('lazy-init regression B: engine initialized at startup syncs 2 of 2',
      () async {
    await createVaultThenRestartPrepared();

    final app = newApp();
    await app.engine.ensureInitialized(); // what main() now does at startup
    expect(SyncSessionHolder.current, isNotNull);

    final r1 = await app.records.createRecord(title: 'One', body: 'a');
    final r2 = await app.records.createRecord(title: 'Two', body: 'b');
    expect((await app.engine.getOverview()).pendingCount, 2);

    await app.engine.syncNow();

    expect(objectCount(), 2);
    final overview = await app.engine.getOverview();
    expect(overview.totalRecords, 2);
    expect(overview.syncedRecords, 2);
    expect(overview.pendingCount, 0);

    final store = SyncStore(app.db);
    final h1 = await store.computeHeads(EntitySnapshots.recordType, r1.id);
    final h2 = await store.computeHeads(EntitySnapshots.recordType, r2.id);
    expect(h1, hasLength(1));
    expect(h2, hasLength(1));
    expect(storage.containsKey('v2/objects/${h1.single.revisionId}.enc'), isTrue);
    expect(storage.containsKey('v2/objects/${h2.single.revisionId}.enc'), isTrue);
  });
}

