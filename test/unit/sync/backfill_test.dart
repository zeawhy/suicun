// test/unit/sync/backfill_test.dart
// Regression: records/categories/tags that exist BEFORE createVault must be
// uploaded (backfilled) and recoverable by a fresh device joining the vault.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suicun/core/crypto/key_value_store.dart';
import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/features/categories/data/category_repository.dart';
import 'package:suicun/features/records/data/record_repository.dart';
import 'package:suicun/features/sync/session_holder.dart';
import 'package:suicun/features/sync/sync_engine.dart';
import 'package:suicun/features/sync/sync_enqueuer.dart';
import 'package:suicun/features/sync/vault_crypto.dart';
import 'package:suicun/features/tags/data/tag_repository.dart';
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

class _Device {
  _Device(Map<String, StoredObject> storage) {
    db = AppDatabase(NativeDatabase.memory());
    final provider = FakeSyncProvider(
      supportsConditionalCreate: false,
      supportsConditionalUpdate: false,
      initialStorage: storage,
    );
    enqueuer = SyncEnqueuer(
      db: db,
      sessionProvider: () async => SyncSessionHolder.current,
    );
    records = RecordRepository(db, syncEnqueuer: enqueuer);
    categories = CategoryRepository(db, syncEnqueuer: enqueuer);
    tags = TagRepository(db, syncEnqueuer: enqueuer);
    engine = SyncEngine(
      db: db,
      configStore: _MemConfigStore(),
      secureStore: MemoryKeyValueStore(),
      syncEnqueuer: enqueuer,
      providerFactory: (_) => provider,
      retryPolicy: const RetryPolicy(baseDelay: Duration.zero),
      debounceDelay: const Duration(milliseconds: 50),
    );
    enqueuer.onEnqueued = engine.notifyLocalChange;
  }

  late final AppDatabase db;
  late final SyncEnqueuer enqueuer;
  late final RecordRepository records;
  late final CategoryRepository categories;
  late final TagRepository tags;
  late final SyncEngine engine;

  Future<void> dispose() async {
    engine.dispose();
    await db.close();
  }
}

void main() {
  const config = WebdavConfig(
    serverUrl: 'https://dav.example.com',
    username: 'alice',
    password: 'secret-dav-password',
    directory: '/suicun/',
  );

  MultiKeySession? savedSession;

  setUp(() {
    savedSession = SyncSessionHolder.current;
    SyncSessionHolder.current = null;
  });

  tearDown(() {
    SyncSessionHolder.current = savedSession;
  });

  int objectCount(Map<String, StoredObject> s) =>
      s.keys.where((k) => k.startsWith('v2/objects/')).length;

  test('pre-existing local data is uploaded on createVault and recoverable',
      () async {
    final storage = <String, StoredObject>{};
    final a = _Device(storage);

    // Local data created BEFORE any vault exists (no session => no hooks).
    final cat = await a.categories.createCategory('Notes', '#112233');
    final tag = await a.tags.findOrCreateTag('Important');
    final r1 = await a.records.createRecord(
      title: 'First',
      body: 'Body one',
      categoryId: cat.id,
      tagIds: [tag.id],
      isFavorite: true,
    );
    final r2 = await a.records.createRecord(title: 'Second', body: 'Body two');
    expect(objectCount(storage), 0);

    await a.engine.createVault(config, 'vault-pass');
    await a.engine.syncNow();

    // 2 records + 1 category + 1 tag.
    expect(objectCount(storage), 4);
    final overview = await a.engine.getOverview();
    expect(overview.pendingCount, 0);
    expect(overview.totalRecords, 2);
    expect(overview.syncedRecords, 2);

    // Fresh device joins and recovers everything.
    SyncSessionHolder.current = null;
    final b = _Device(storage);
    await b.engine.joinVault(config, password: 'vault-pass');
    await b.engine.syncNow();

    final recs = await b.records.searchRecords();
    expect(recs, hasLength(2));
    final first = recs.firstWhere((r) => r.id == r1.id);
    expect(first.title, 'First');
    expect(first.body, 'Body one');
    expect(first.isFavorite, isTrue);
    expect(first.categoryId, cat.id);
    expect(first.tags.map((t) => t.id), [tag.id]);
    final second = recs.firstWhere((r) => r.id == r2.id);
    expect(second.title, 'Second');
    expect(second.body, 'Body two');

    final cats = await b.categories.getAllCategories();
    expect(cats, hasLength(1));
    expect(cats.single.name, 'Notes');
    expect(cats.single.color, '#112233');
    final tags = await b.tags.getAllTags();
    expect(tags, hasLength(1));
    expect(tags.single.name, 'Important');

    await a.dispose();
    await b.dispose();
  });

  test('backfill is idempotent and skips trashed records', () async {
    final storage = <String, StoredObject>{};
    final a = _Device(storage);
    await a.records.createRecord(title: 'Keep', body: 'k');
    final gone = await a.records.createRecord(title: 'Trashed', body: 't');
    await a.records.softDeleteRecord(gone.id);

    await a.engine.createVault(config, 'vault-pass');
    await a.engine.syncNow();
    expect(objectCount(storage), 1);

    expect(await a.engine.backfillLocalEntities(), 0);
    expect(await a.engine.backfillLocalEntities(), 0);
    await a.engine.syncNow();
    expect(objectCount(storage), 1);

    await a.dispose();
  });
}
