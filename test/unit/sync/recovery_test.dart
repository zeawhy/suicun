// test/unit/sync/recovery_test.dart
// Stage C: Unit tests for SyncEngine recovery on a fresh device.

import 'dart:ui' show Locale;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suicun/core/crypto/key_value_store.dart';
import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/features/categories/data/category_repository.dart';
import 'package:suicun/features/records/data/record_repository.dart';
import 'package:suicun/features/sync/session_holder.dart';
import 'package:suicun/features/sync/sync_engine.dart';
import 'package:suicun/features/sync/sync_enqueuer.dart';
import 'package:suicun/features/sync/sync_store.dart';
import 'package:suicun/features/sync/vault_crypto.dart';
import 'package:suicun/features/tags/data/tag_repository.dart';
import 'package:suicun/services/webdav_service.dart';

import 'fake_sync_provider.dart';

class _InMemoryWebdavConfigStore implements WebdavConfigStore {
  WebdavConfig? _config;

  @override
  Future<WebdavConfig?> loadConfig() async => _config;

  @override
  Future<void> saveConfig(WebdavConfig config) async {
    _config = config;
  }

  @override
  Future<void> clearConfig() async {
    _config = null;
  }
}

class _TestHarness {
  _TestHarness({
    required this.storage,
  }) {
    db = AppDatabase(NativeDatabase.memory());
    store = SyncStore(db);
    secureStore = MemoryKeyValueStore();
    configStore = _InMemoryWebdavConfigStore();

    fakeProvider = FakeSyncProvider(
      supportsConditionalCreate: true,
      supportsConditionalUpdate: true,
      initialStorage: storage,
    );

    enqueuer = SyncEnqueuer(
      db: db,
      sessionProvider: () async => SyncSessionHolder.current,
    );

    recordRepo = RecordRepository(db, syncEnqueuer: enqueuer);
    categoryRepo = CategoryRepository(db, syncEnqueuer: enqueuer);
    tagRepo = TagRepository(db, syncEnqueuer: enqueuer);

    engine = SyncEngine(
      db: db,
      configStore: configStore,
      secureStore: secureStore,
      syncEnqueuer: enqueuer,
      providerFactory: (cfg) => fakeProvider,
      retryPolicy: const RetryPolicy(baseDelay: Duration.zero),
      debounceDelay: const Duration(milliseconds: 50),
      getLocale: () => const Locale('zh'),
    );

    enqueuer.onEnqueued = engine.notifyLocalChange;
  }

  final Map<String, StoredObject> storage;
  late final AppDatabase db;
  late final SyncStore store;
  late final MemoryKeyValueStore secureStore;
  late final _InMemoryWebdavConfigStore configStore;
  late final FakeSyncProvider fakeProvider;
  late final SyncEnqueuer enqueuer;
  late final RecordRepository recordRepo;
  late final CategoryRepository categoryRepo;
  late final TagRepository tagRepo;
  late final SyncEngine engine;

  Future<void> dispose() async {
    engine.dispose();
    await db.close();
  }
}

void main() {
  const testConfig = WebdavConfig(
    serverUrl: 'https://webdav.example/',
    username: 'u',
    password: 'p',
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

  test('recoverFromRemote phases, idempotence, and interruption handling', () async {
    final storage = <String, StoredObject>{};

    // A: createVault, 2 records (one with category+tags+favorite), syncNow.
    final hA = _TestHarness(storage: storage);
    await hA.engine.createVault(testConfig, 'pw');

    final cat = await hA.categoryRepo.createCategory('工作', '#336699');
    final tag1 = await hA.tagRepo.findOrCreateTag('待办');
    final tag2 = await hA.tagRepo.findOrCreateTag('重要');

    await hA.recordRepo.createRecord(
      title: 'Record 1 with meta',
      body: 'Body 1',
      categoryId: cat.id,
      tagIds: [tag1.id, tag2.id],
      isFavorite: true,
    );

    await hA.recordRepo.createRecord(
      title: 'Record 2 plain',
      body: 'Body 2',
    );

    await hA.engine.syncNow();
    await hA.dispose();

    // Fresh DB B: recoverFromRemote
    SyncSessionHolder.current = null;
    final hB = _TestHarness(storage: storage);
    final eventsB = await hB.engine.recoverFromRemote(testConfig, password: 'pw').toList();

    // Verify phases appear in order connecting, listing, downloading, rebuilding, done
    final observedPhases = <String>[];
    for (final e in eventsB) {
      if (observedPhases.isEmpty || observedPhases.last != e.phase) {
        observedPhases.add(e.phase);
      }
    }
    expect(
      observedPhases,
      equals(['connecting', 'listing', 'downloading', 'rebuilding', 'done']),
    );

    final lastEventB = eventsB.last;
    expect(lastEventB.done, isTrue);
    expect(lastEventB.recordsRestored, 2);

    // B has all data
    final recordsB = await hB.recordRepo.searchRecords();
    expect(recordsB, hasLength(2));
    final rWithMeta = recordsB.firstWhere((r) => r.title == 'Record 1 with meta');
    expect(rWithMeta.body, 'Body 1');
    expect(rWithMeta.isFavorite, isTrue);
    expect(rWithMeta.category?.name, '工作');
    expect(rWithMeta.tags.map((t) => t.name), containsAll(['待办', '重要']));

    final rPlain = recordsB.firstWhere((r) => r.title == 'Record 2 plain');
    expect(rPlain.body, 'Body 2');

    // Second recovery on B -> record count still 2.
    final eventsB2 = await hB.engine.recoverFromRemote(testConfig, password: 'pw').toList();
    expect(eventsB2.last.done, isTrue);
    final recordsBAfterSecond = await hB.recordRepo.searchRecords();
    expect(recordsBAfterSecond, hasLength(2));

    await hB.dispose();

    // Interruption: fresh DB C; failOnGet drops some objects
    SyncSessionHolder.current = null;
    final hC = _TestHarness(storage: storage);
    final encKeys = storage.keys.where((k) => k.endsWith('.enc')).toList();
    expect(encKeys, isNotEmpty);
    hC.fakeProvider.failOnGet.add(encKeys.first);

    final eventsC1 = await hC.engine.recoverFromRemote(testConfig, password: 'pw').toList();
    final lastEventC1 = eventsC1.last;
    expect(lastEventC1.phase, 'error');
    expect(lastEventC1.done, isTrue);
    expect(lastEventC1.error, isNotNull);

    // Clear faults; recover again -> completes, correct data, no dupes.
    hC.fakeProvider.failOnGet.clear();
    final eventsC2 = await hC.engine.recoverFromRemote(testConfig, password: 'pw').toList();
    expect(eventsC2.last.done, isTrue);
    expect(eventsC2.last.phase, 'done');

    final recordsC = await hC.recordRepo.searchRecords();
    expect(recordsC, hasLength(2));
    expect(recordsC.map((r) => r.title), containsAll(['Record 1 with meta', 'Record 2 plain']));

    await hC.dispose();
  });
}
