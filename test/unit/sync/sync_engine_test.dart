// test/unit/sync/sync_engine_test.dart
// Stage C: Unit tests for SyncEngine scenarios and SyncStore graph algorithms.

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Locale;

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suicun/core/crypto/key_value_store.dart';
import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/features/categories/data/category_repository.dart';
import 'package:suicun/features/records/data/record_repository.dart';
import 'package:suicun/features/sync/entity_snapshot.dart';
import 'package:suicun/features/sync/session_holder.dart';
import 'package:suicun/features/sync/sync_contract.dart';
import 'package:suicun/features/sync/sync_engine.dart';
import 'package:suicun/features/sync/sync_enqueuer.dart';
import 'package:suicun/features/sync/sync_store.dart';
import 'package:suicun/features/sync/vault_crypto.dart';
import 'package:suicun/features/tags/data/tag_repository.dart';
import 'package:suicun/services/webdav_service.dart';

import 'fake_sync_provider.dart';

class InMemoryWebdavConfigStore implements WebdavConfigStore {
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

class TestHarness {
  TestHarness({
    Map<String, StoredObject>? sharedStorage,
    bool supportsConditionalCreate = true,
    bool supportsConditionalUpdate = true,
  }) {
    db = AppDatabase(NativeDatabase.memory());
    store = SyncStore(db);
    secureStore = MemoryKeyValueStore();
    configStore = InMemoryWebdavConfigStore();

    fakeProvider = FakeSyncProvider(
      supportsConditionalCreate: supportsConditionalCreate,
      supportsConditionalUpdate: supportsConditionalUpdate,
      initialStorage: sharedStorage,
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

  late final AppDatabase db;
  late final SyncStore store;
  late final MemoryKeyValueStore secureStore;
  late final InMemoryWebdavConfigStore configStore;
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

  group('SyncStore graph algorithms', () {
    late AppDatabase db;
    late SyncStore store;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      store = SyncStore(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('computeHeads with 2 branches and ancestorsOf', () async {
      final now = DateTime.now().toUtc();
      // Tree structure for entity 'rec-1':
      // r0 -> r1 -> r2 (branch 1)
      //    -> r3 (branch 2)
      await store.insertRevision(RevisionsCompanion.insert(
        revisionId: 'r0',
        entityType: 'record',
        entityId: 'rec-1',
        parentsJson: const drift.Value('[]'),
        payloadJson: '{}',
        createdAt: now.subtract(const Duration(minutes: 4)),
        receivedAt: now,
      ));
      await store.insertRevision(RevisionsCompanion.insert(
        revisionId: 'r1',
        entityType: 'record',
        entityId: 'rec-1',
        parentsJson: const drift.Value('["r0"]'),
        payloadJson: '{}',
        createdAt: now.subtract(const Duration(minutes: 3)),
        receivedAt: now,
      ));
      await store.insertRevision(RevisionsCompanion.insert(
        revisionId: 'r2',
        entityType: 'record',
        entityId: 'rec-1',
        parentsJson: const drift.Value('["r1"]'),
        payloadJson: '{}',
        createdAt: now.subtract(const Duration(minutes: 2)),
        receivedAt: now,
      ));
      await store.insertRevision(RevisionsCompanion.insert(
        revisionId: 'r3',
        entityType: 'record',
        entityId: 'rec-1',
        parentsJson: const drift.Value('["r0"]'),
        payloadJson: '{}',
        createdAt: now.subtract(const Duration(minutes: 1)),
        receivedAt: now,
      ));

      final heads = await store.computeHeads('record', 'rec-1');
      final headIds = heads.map((h) => h.revisionId).toSet();
      expect(headIds, equals({'r2', 'r3'}));

      final ancestorsR2 = await store.ancestorsOf('record', 'rec-1', 'r2');
      expect(ancestorsR2, equals({'r0', 'r1'}));

      final ancestorsR3 = await store.ancestorsOf('record', 'rec-1', 'r3');
      expect(ancestorsR3, equals({'r0'}));

      final ancestorsR0 = await store.ancestorsOf('record', 'rec-1', 'r0');
      expect(ancestorsR0, isEmpty);
    });
  });

  group('SyncEngine Scenarios', () {
    test('1. create+join+sync, no-plaintext', () async {
      final storage = <String, StoredObject>{};

      final hA = TestHarness(sharedStorage: storage);
      await hA.engine.createVault(testConfig, 'pass123');

      final cat = await hA.categoryRepo.createCategory('Cat-1', '#123456');
      final tag = await hA.tagRepo.findOrCreateTag('Tag-1');
      await hA.recordRepo.createRecord(
        title: 'NoPlainA-Title-xyz',
        body: 'Secret body content here',
        categoryId: cat.id,
        tagIds: [tag.id],
        isFavorite: true,
      );

      await hA.engine.syncNow();
      final overviewA = await hA.engine.getOverview();
      expect(overviewA.pendingCount, 0);

      // Fresh DB device B
      SyncSessionHolder.current = null;
      final hB = TestHarness(sharedStorage: storage);
      await hB.engine.joinVault(testConfig, password: 'pass123');
      await hB.engine.syncNow();

      final recordsB = await hB.recordRepo.searchRecords();
      expect(recordsB, hasLength(1));
      final recB = recordsB.first;
      expect(recB.title, 'NoPlainA-Title-xyz');
      expect(recB.body, 'Secret body content here');
      expect(recB.isFavorite, isTrue);
      expect(recB.category?.name, 'Cat-1');
      expect(recB.tags.map((t) => t.name), contains('Tag-1'));

      // Scan every stored object bytes: decoded text must NOT contain distinctive strings
      for (final entry in storage.entries) {
        final decoded = utf8.decode(entry.value.bytes, allowMalformed: true);
        expect(decoded.contains('NoPlainA-Title-xyz'), isFalse,
            reason: 'Object ${entry.key} contains unencrypted title');
        expect(decoded.contains('Secret body content here'), isFalse,
            reason: 'Object ${entry.key} contains unencrypted body');
        expect(decoded.contains('pass123'), isFalse,
            reason: 'Object ${entry.key} contains unencrypted password');
      }

      await hA.dispose();
      await hB.dispose();
    });

    test('2. concurrent edit conflict with resolveConflict(keepBoth)', () async {
      final storage = <String, StoredObject>{};

      final hA = TestHarness(sharedStorage: storage);
      await hA.engine.createVault(testConfig, 'pw');

      final created = await hA.recordRepo.createRecord(
        title: 'Initial Title',
        body: 'Initial Body',
      );
      await hA.engine.syncNow();

      SyncSessionHolder.current = null;
      final hB = TestHarness(sharedStorage: storage);
      await hB.engine.joinVault(testConfig, password: 'pw');
      await hB.engine.syncNow();

      // Go offline on both
      hA.fakeProvider.offline = true;
      hB.fakeProvider.offline = true;

      // Device A edits
      final keys2JsonA = await hA.secureStore.read('suicun.sync.keys2');
      final listA = (jsonDecode(keys2JsonA!) as List).cast<Map<String, dynamic>>();
      final keyIdA = listA.first['key_id'] as String;
      final kvaultA = await hA.secureStore.read('suicun.sync.kvault2.$keyIdA');
      SyncSessionHolder.current = MultiKeySession(
        keys: {keyIdA: Uint8List.fromList(base64Decode(kvaultA!))},
      );
      await hA.recordRepo.updateRecord(created.id, title: 'A-edit');

      // Device B edits
      final keys2JsonB = await hB.secureStore.read('suicun.sync.keys2');
      final listB = (jsonDecode(keys2JsonB!) as List).cast<Map<String, dynamic>>();
      final keyIdB = listB.first['key_id'] as String;
      final kvaultB = await hB.secureStore.read('suicun.sync.kvault2.$keyIdB');
      SyncSessionHolder.current = MultiKeySession(
        keys: {keyIdB: Uint8List.fromList(base64Decode(kvaultB!))},
      );
      await hB.recordRepo.updateRecord(created.id, title: 'B-edit');

      hA.fakeProvider.offline = false;
      hB.fakeProvider.offline = false;

      await hA.engine.syncNow();
      await hB.engine.syncNow();
      await hA.engine.syncNow();

      // Expect exactly 1 open conflict with 2 heads
      final conflictsA = await hA.store.openConflicts();
      expect(conflictsA, hasLength(1));
      final heads = await hA.store.computeHeads('record', created.id);
      expect(heads, hasLength(2));

      final overviewA = await hA.engine.getOverview();
      expect(overviewA.conflictCount, 1);

      // Resolve conflict with keepBoth
      await hA.engine.resolveConflict(conflictsA.first.id, ConflictChoice.keepBoth);
      await hA.engine.syncNow();
      await hB.engine.syncNow();

      final recordsOnA = await hA.recordRepo.searchRecords();
      final recordsOnB = await hB.recordRepo.searchRecords();
      expect(recordsOnA, hasLength(2));
      expect(recordsOnB, hasLength(2));
      expect(recordsOnA.map((r) => r.title), containsAll(['A-edit', 'B-edit']));
      expect(recordsOnB.map((r) => r.title), containsAll(['A-edit', 'B-edit']));

      await hA.dispose();
      await hB.dispose();
    });

    test('3. delete-vs-edit with resolveConflict(keepRemote)', () async {
      final storage = <String, StoredObject>{};

      final hA = TestHarness(sharedStorage: storage);
      await hA.engine.createVault(testConfig, 'pw');

      final created = await hA.recordRepo.createRecord(
        title: 'Original Title',
        body: 'Original Body',
      );
      await hA.engine.syncNow();

      SyncSessionHolder.current = null;
      final hB = TestHarness(sharedStorage: storage);
      await hB.engine.joinVault(testConfig, password: 'pw');
      await hB.engine.syncNow();

      // Go offline
      hA.fakeProvider.offline = true;
      hB.fakeProvider.offline = true;

      final keys2JsonA = await hA.secureStore.read('suicun.sync.keys2');
      final listA = (jsonDecode(keys2JsonA!) as List).cast<Map<String, dynamic>>();
      final keyIdA = listA.first['key_id'] as String;
      final kvaultA = await hA.secureStore.read('suicun.sync.kvault2.$keyIdA');
      SyncSessionHolder.current = MultiKeySession(
        keys: {keyIdA: Uint8List.fromList(base64Decode(kvaultA!))},
      );
      await hA.recordRepo.softDeleteRecord(created.id); // soft-delete

      final keys2JsonB = await hB.secureStore.read('suicun.sync.keys2');
      final listB = (jsonDecode(keys2JsonB!) as List).cast<Map<String, dynamic>>();
      final keyIdB = listB.first['key_id'] as String;
      final kvaultB = await hB.secureStore.read('suicun.sync.kvault2.$keyIdB');
      SyncSessionHolder.current = MultiKeySession(
        keys: {keyIdB: Uint8List.fromList(base64Decode(kvaultB!))},
      );
      await hB.recordRepo.updateRecord(created.id, body: 'B-body');

      hA.fakeProvider.offline = false;
      hB.fakeProvider.offline = false;

      await hA.engine.syncNow();
      await hB.engine.syncNow();
      await hA.engine.syncNow();

      final conflictsA = await hA.store.openConflicts();
      expect(conflictsA, hasLength(1));

      // Resolve keeping remote (which is B's edit)
      await hA.engine.resolveConflict(conflictsA.first.id, ConflictChoice.keepRemote);
      await hA.engine.syncNow();
      await hB.engine.syncNow();

      final recordA = await hA.recordRepo.getRecord(created.id);
      expect(recordA, isNotNull);
      expect(recordA!.body, 'B-body');
      expect(recordA.deletedAt, isNull);

      final recordB = await hB.recordRepo.getRecord(created.id);
      expect(recordB, isNotNull);
      expect(recordB!.body, 'B-body');
      expect(recordB.deletedAt, isNull);

      await hA.dispose();
      await hB.dispose();
    });

    test('4a. mid-download network failure then resume without dupes', () async {
      final storage = <String, StoredObject>{};

      final hA = TestHarness(sharedStorage: storage);
      await hA.engine.createVault(testConfig, 'pw');

      await hA.recordRepo.createRecord(title: 'Rec 1', body: 'Body 1');
      await hA.recordRepo.createRecord(title: 'Rec 2', body: 'Body 2');
      await hA.recordRepo.createRecord(title: 'Rec 3', body: 'Body 3');
      await hA.engine.syncNow();

      // Join B
      SyncSessionHolder.current = null;
      final hB = TestHarness(sharedStorage: storage);
      await hB.engine.joinVault(testConfig, password: 'pw');

      // Fail one of the object downloads
      final encPaths = storage.keys.where((k) => k.endsWith('.enc')).toList();
      expect(encPaths, hasLength(3));
      hB.fakeProvider.failOnGet.add(encPaths[1]);

      await hB.engine.syncNow();
      var overviewB = await hB.engine.getOverview();
      expect(overviewB.lastError, isNotNull);

      // Now clear fault and sync again
      hB.fakeProvider.failOnGet.clear();
      await hB.engine.syncNow();

      overviewB = await hB.engine.getOverview();
      expect(overviewB.lastError, isNull);

      final revisionsCount = (await hB.store.allRevisionIds()).length;
      expect(revisionsCount, 3);

      await hA.dispose();
      await hB.dispose();
    });

    test('4b. upload timeout-after-put then retry', () async {
      final storage = <String, StoredObject>{};

      final hA = TestHarness(sharedStorage: storage);
      await hA.engine.createVault(testConfig, 'pw');

      await hA.recordRepo.createRecord(title: 'Timeout Title', body: 'Body');

      // Make put simulate timeout after storing
      hA.fakeProvider.timeoutAfterPut = true;
      await hA.engine.syncNow();

      var overview = await hA.engine.getOverview();
      expect(overview.pendingCount, 1);
      expect(overview.lastError, isNotNull);

      // Retry without timeout
      hA.fakeProvider.timeoutAfterPut = false;
      await hA.engine.syncNow();

      overview = await hA.engine.getOverview();
      expect(overview.pendingCount, 0);
      expect(overview.lastError, isNull);

      final encObjects = storage.keys.where((k) => k.endsWith('.enc')).toList();
      expect(encObjects, hasLength(1));

      final revId = encObjects.first.split('/').last.replaceAll('.enc', '');
      expect(await hA.store.hasReceipt(revId), isTrue);

      await hA.dispose();
    });

    test('4c. 429 with Retry-After suppresses auto sync', () async {
      final storage = <String, StoredObject>{};

      final hA = TestHarness(sharedStorage: storage);
      await hA.engine.createVault(testConfig, 'pw');

      await hA.recordRepo.createRecord(title: 'R1', body: 'B1');

      // Force 429 on upload
      final outbox = await hA.store.pendingOutbox();
      expect(outbox, isNotEmpty);
      final path = 'v2/objects/${outbox.first.revisionId}.enc';
      hA.fakeProvider.forcePutStatus[path] = 429;
      hA.fakeProvider.putRetryAfter = const Duration(minutes: 5);

      // Wait for any initial debounce from createRecord to elapse
      await Future<void>.delayed(const Duration(milliseconds: 100));

      await hA.engine.syncNow();
      final overview = await hA.engine.getOverview();
      // Expect lastError localized message corresponding to rateLimited
      expect(overview.lastError, contains('频繁'));

      // Check that notifyLocalChange adds no provider requests
      final initialLogCount = hA.fakeProvider.requestLog.length;
      hA.engine.notifyLocalChange();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(hA.fakeProvider.requestLog.length, initialLogCount);

      await hA.dispose();
    });

    test('4d. 401 on list: lastError unauthorized with 暂停, local data intact', () async {
      final storage = <String, StoredObject>{};

      final hA = TestHarness(sharedStorage: storage);
      await hA.engine.createVault(testConfig, 'pw');

      await hA.recordRepo.createRecord(title: 'KeepIntact', body: 'Important');
      hA.fakeProvider.forceListStatus = 401;

      await hA.engine.syncNow();
      final overview = await hA.engine.getOverview();
      expect(overview.lastError, contains('暂停'));

      final records = await hA.recordRepo.searchRecords();
      expect(records, hasLength(1));
      expect(records.first.title, 'KeepIntact');

      await hA.dispose();
    });

    test('4e. 507 on put: lastError insufficientStorage, record intact', () async {
      final storage = <String, StoredObject>{};

      final hA = TestHarness(sharedStorage: storage);
      await hA.engine.createVault(testConfig, 'pw');

      await hA.recordRepo.createRecord(title: 'NoSpace', body: 'Body');
      final outbox = await hA.store.pendingOutbox();
      expect(outbox, isNotEmpty);
      final path = 'v2/objects/${outbox.first.revisionId}.enc';
      hA.fakeProvider.forcePutStatus[path] = 507;

      await hA.engine.syncNow();
      final overview = await hA.engine.getOverview();
      expect(overview.lastError, contains('空间不足'));

      final records = await hA.recordRepo.searchRecords();
      expect(records, hasLength(1));
      expect(records.first.title, 'NoSpace');

      await hA.dispose();
    });

    test('4f. create race, same password -> both joined, same vaultId', () async {
      final storage = <String, StoredObject>{};

      // Pre-seed a v2 key object built by VaultCrypto().createKeyObject('pw')
      final crypto = VaultCrypto();
      final created = await crypto.createKeyObject(password: 'pw');
      storage['v2/keys/${created.keyId}.${created.variant}.json'] = StoredObject(
        bytes: Uint8List.fromList(utf8.encode(created.keyJson)),
        etag: '"key-etag"',
      );

      final hA = TestHarness(sharedStorage: storage);
      final hB = TestHarness(sharedStorage: storage);

      await Future.wait([
        hA.engine.createVault(testConfig, 'pw'),
        hB.engine.createVault(testConfig, 'pw'),
      ]);

      final overviewA = await hA.engine.getOverview();
      final overviewB = await hB.engine.getOverview();
      expect(overviewA.vaultId, isNotNull);
      expect(overviewA.vaultId, overviewB.vaultId);

      await hA.dispose();
      await hB.dispose();
    });

    test('4g. supportsConditionalCreate=false -> createVault succeeds on a server without conditional writes', () async {
      final hA = TestHarness(supportsConditionalCreate: false);

      await hA.engine.createVault(testConfig, 'pw');
      final overview = await hA.engine.getOverview();
      expect(overview.vaultId, isNotNull);

      await hA.dispose();
    });

    test('4h. no-conditional fallback: upload GET-verify, tamper -> contentConflict', () async {
      final storage = <String, StoredObject>{};

      final hA = TestHarness(
        sharedStorage: storage,
        supportsConditionalCreate: false,
        supportsConditionalUpdate: false,
      );

      await hA.engine.createVault(testConfig, 'pw');
      await hA.recordRepo.createRecord(title: 'Rec', body: 'Body');
      await hA.engine.syncNow();

      final encPaths = storage.keys.where((k) => k.endsWith('.enc')).toList();
      expect(encPaths, hasLength(1));

      // Tamper stored bytes
      final oldBytes = storage[encPaths.first]!.bytes;
      final tampered = Uint8List.fromList(oldBytes)..[oldBytes.length - 1] ^= 0xff;
      storage[encPaths.first] = StoredObject(bytes: tampered, etag: '"tampered"');

      // Requeue outbox
      final revId = encPaths.first.split('/').last.replaceAll('.enc', '');
      await hA.store.enqueueOutbox(OutboxCompanion.insert(
        operationId: 'op-tamper',
        revisionId: revId,
        createdAt: DateTime.now().toUtc(),
      ));

      await hA.engine.syncNow();
      final overview = await hA.engine.getOverview();
      expect(overview.lastError, contains('同名对象'));

      await hA.dispose();
    });

    test('4i. unknown protocol_version=99 object -> lastError unsupportedProtocol, revisions empty', () async {
      final storage = <String, StoredObject>{};
      final hA = TestHarness(sharedStorage: storage);
      await hA.engine.createVault(testConfig, 'pw');

      final overviewA = await hA.engine.getOverview();
      final vaultId = overviewA.vaultId!;

      // Create an unknown protocol version revision object
      final fakeRev = jsonEncode({
        'format': 'suicun-revision',
        'protocol_version': 99,
        'vault_id': vaultId,
        'revision_id': 'rev-v99',
        'entity_type': 'record',
        'entity_id': 'rec-1',
        'nonce_b64': base64Encode(Uint8List(12)),
        'ciphertext_b64': base64Encode(Uint8List(32)),
      });

      storage['v2/objects/rev-v99.enc'] = StoredObject(
        bytes: Uint8List.fromList(utf8.encode(fakeRev)),
        etag: '"v99"',
      );

      // Join B and sync
      SyncSessionHolder.current = null;
      final hB = TestHarness(sharedStorage: storage);
      await hB.engine.joinVault(testConfig, password: 'pw');
      await hB.engine.syncNow();

      final overviewB = await hB.engine.getOverview();
      expect(overviewB.lastError, contains('版本不受支持'));

      final revisions = await hB.store.allRevisionIds();
      expect(revisions, isEmpty);

      await hA.dispose();
      await hB.dispose();
    });

    test('4j. tampered ciphertext -> skipped, sync completes, revisions empty', () async {
      final storage = <String, StoredObject>{};
      final hA = TestHarness(sharedStorage: storage);
      await hA.engine.createVault(testConfig, 'pw');

      await hA.recordRepo.createRecord(title: 'Tamp', body: 'Body');
      await hA.engine.syncNow();

      final encPaths = storage.keys.where((k) => k.endsWith('.enc')).toList();
      expect(encPaths, hasLength(1));

      // Tamper ciphertext
      final bytes = storage[encPaths.first]!.bytes;
      final tampered = Uint8List.fromList(bytes)..[bytes.length - 2] ^= 0xff;
      storage[encPaths.first] = StoredObject(bytes: tampered, etag: '"tampered"');

      // B joins and syncs
      SyncSessionHolder.current = null;
      final hB = TestHarness(sharedStorage: storage);
      await hB.engine.joinVault(testConfig, password: 'pw');
      await hB.engine.syncNow();

      final overviewB = await hB.engine.getOverview();
      expect(overviewB.lastError, isNull);

      final revisionsB = await hB.store.allRevisionIds();
      expect(revisionsB, isEmpty);

      final skippedB = await hB.store.allSkippedIds();
      final revId = encPaths.first.split('/').last.replaceAll('.enc', '');
      expect(skippedB, contains(revId));

      await hA.dispose();
      await hB.dispose();
    });

    test('5. restart: record created before sync, dispose engine, new engine on same db uploads once', () async {
      final storage = <String, StoredObject>{};

      final hA = TestHarness(sharedStorage: storage);
      await hA.engine.createVault(testConfig, 'pw');

      await hA.recordRepo.createRecord(title: 'Created Offline', body: 'Body');

      // Dispose engine
      hA.engine.dispose();
      SyncSessionHolder.current = null;

      // Recreate engine on SAME db & secureStore & configStore
      final newEngine = SyncEngine(
        db: hA.db,
        configStore: hA.configStore,
        secureStore: hA.secureStore,
        syncEnqueuer: hA.enqueuer,
        providerFactory: (cfg) => hA.fakeProvider,
        retryPolicy: const RetryPolicy(baseDelay: Duration.zero),
        debounceDelay: const Duration(milliseconds: 50),
        getLocale: () => const Locale('zh'),
      );
      hA.enqueuer.onEnqueued = newEngine.notifyLocalChange;

      await newEngine.syncNow();
      final overview = await newEngine.getOverview();
      expect(overview.pendingCount, 0);

      final encObjects = storage.keys.where((k) => k.endsWith('.enc')).toList();
      expect(encObjects, hasLength(1));

      newEngine.dispose();
      await hA.db.close();
    });

    test('6. out-of-order: parent+child revisions hand-crafted into fake, child content shown', () async {
      final storage = <String, StoredObject>{};
      final crypto = VaultCrypto();
      final created = await crypto.createKeyObject(password: 'pw');
      storage['v2/keys/${created.keyId}.${created.variant}.json'] = StoredObject(
        bytes: Uint8List.fromList(utf8.encode(created.keyJson)),
        etag: '"k"',
      );

      final entityId = 'rec-out-of-order';
      final now = DateTime.now().toUtc();

      // Parent payload
      final parentPayload = EntitySnapshots.payload(
        revisionId: 'rev-parent',
        entityType: EntitySnapshots.recordType,
        entityId: entityId,
        parents: [],
        createdAt: now.subtract(const Duration(minutes: 5)),
        deleted: false,
        snapshot: EntitySnapshots.recordSnapshot(
          title: 'Parent Title',
          body: 'Parent Body',
          tagIds: [],
          isFavorite: false,
          createdAt: now.subtract(const Duration(minutes: 5)),
          updatedAt: now.subtract(const Duration(minutes: 5)),
        ),
      );

      final parentEnc = await crypto.encryptRevisionV2(
        kvault: created.kvault,
        keyId: created.keyId,
        revisionId: 'rev-parent',
        entityType: EntitySnapshots.recordType,
        entityId: entityId,
        payload: parentPayload,
      );

      // Child payload
      final childPayload = EntitySnapshots.payload(
        revisionId: 'rev-child',
        entityType: EntitySnapshots.recordType,
        entityId: entityId,
        parents: ['rev-parent'],
        createdAt: now,
        deleted: false,
        snapshot: EntitySnapshots.recordSnapshot(
          title: 'Child Title',
          body: 'Child Body',
          tagIds: [],
          isFavorite: false,
          createdAt: now.subtract(const Duration(minutes: 5)),
          updatedAt: now,
        ),
      );

      final childEnc = await crypto.encryptRevisionV2(
        kvault: created.kvault,
        keyId: created.keyId,
        revisionId: 'rev-child',
        entityType: EntitySnapshots.recordType,
        entityId: entityId,
        payload: childPayload,
      );

      storage['v2/objects/rev-parent.enc'] = StoredObject(bytes: parentEnc, etag: '"p"');
      storage['v2/objects/rev-child.enc'] = StoredObject(bytes: childEnc, etag: '"c"');

      final hB = TestHarness(sharedStorage: storage);
      await hB.engine.joinVault(testConfig, password: 'pw');
      await hB.engine.syncNow();

      final rec = await hB.recordRepo.getRecord(entityId);
      expect(rec, isNotNull);
      expect(rec!.title, 'Child Title');
      expect(rec.body, 'Child Body');

      final revisions = await hB.store.allRevisionIds();
      expect(revisions, containsAll(['rev-parent', 'rev-child']));

      await hB.dispose();
    });
  });
}
