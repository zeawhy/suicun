// test/unit/sync/sync_v2_test.dart
// Stage C: Integration and scenario unit tests for Sync Protocol v2 (Plan Section 11).

import 'dart:convert';
import 'dart:typed_data';

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
import 'package:suicun/features/sync/sync_errors.dart';
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

class _V2Harness {
  _V2Harness({
    required this.storage,
    this.supportsConditionalCreate = false,
    this.supportsConditionalUpdate = false,
    AppDatabase? existingDb,
    SyncStore? existingStore,
    MemoryKeyValueStore? existingSecureStore,
    _InMemoryWebdavConfigStore? existingConfigStore,
  }) {
    db = existingDb ?? AppDatabase(NativeDatabase.memory());
    store = existingStore ?? SyncStore(db);
    secureStore = existingSecureStore ?? MemoryKeyValueStore();
    configStore = existingConfigStore ?? _InMemoryWebdavConfigStore();

    fakeProvider = FakeSyncProvider(
      supportsConditionalCreate: supportsConditionalCreate,
      supportsConditionalUpdate: supportsConditionalUpdate,
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
    );

    enqueuer.onEnqueued = engine.notifyLocalChange;
  }

  final Map<String, StoredObject> storage;
  final bool supportsConditionalCreate;
  final bool supportsConditionalUpdate;

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

  Future<void> switchActiveSession() async {
    final keys2Json = await secureStore.read('suicun.sync.keys2');
    if (keys2Json == null) return;
    final list = (jsonDecode(keys2Json) as List).cast<Map<String, dynamic>>();
    final keys = <String, Uint8List>{};
    for (final entry in list) {
      final keyId = entry['key_id'] as String;
      final kBase64 = await secureStore.read('suicun.sync.kvault2.$keyId');
      if (kBase64 != null) {
        keys[keyId] = Uint8List.fromList(base64Decode(kBase64));
      }
    }
    SyncSessionHolder.current = MultiKeySession(keys: keys);
  }

  Future<void> dispose() async {
    engine.dispose();
    await db.close();
  }
}

void main() {
  const testConfig = WebdavConfig(
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

  group('Sync Protocol v2 Scenarios (supportsConditionalCreate=false)', () {
    test('1. A inits, B joins, full sync with no plaintext in storage', () async {
      final storage = <String, StoredObject>{};

      final hA = _V2Harness(storage: storage);
      await hA.engine.createVault(testConfig, 'vault-pass');

      final cat = await hA.categoryRepo.createCategory('Notes', '#112233');
      final tag = await hA.tagRepo.findOrCreateTag('Important');
      await hA.recordRepo.createRecord(
        title: 'Secret Title',
        body: 'Secret Plaintext Content',
        categoryId: cat.id,
        tagIds: [tag.id],
        isFavorite: true,
      );

      await hA.engine.syncNow();
      final overviewA = await hA.engine.getOverview();
      expect(overviewA.pendingCount, 0);

      // Verify no plaintext appears in any stored bytes
      for (final obj in storage.values) {
        final text = utf8.decode(obj.bytes, allowMalformed: true);
        expect(text.contains('Secret Title'), isFalse);
        expect(text.contains('Secret Plaintext Content'), isFalse);
        expect(text.contains('vault-pass'), isFalse);
      }

      // B joins with same password
      SyncSessionHolder.current = null;
      final hB = _V2Harness(storage: storage);
      await hB.engine.joinVault(testConfig, password: 'vault-pass');
      await hB.engine.syncNow();

      final recordsB = await hB.recordRepo.searchRecords();
      expect(recordsB, hasLength(1));
      expect(recordsB.first.title, 'Secret Title');
      expect(recordsB.first.body, 'Secret Plaintext Content');
      expect(recordsB.first.isFavorite, isTrue);

      final catsB = await hB.categoryRepo.getAllCategories();
      expect(catsB, hasLength(1));
      expect(catsB.first.name, 'Notes');

      final tagsB = await hB.tagRepo.getAllTags();
      expect(tagsB, hasLength(1));
      expect(tagsB.first.name, 'Important');

      await hA.dispose();
      await hB.dispose();
    });

    test('2. Concurrent init with same password -> 2 keys coexist, active key converges to min', () async {
      final storage = <String, StoredObject>{};

      final hA = _V2Harness(storage: storage);
      final hB = _V2Harness(storage: storage);

      // Hide v2/keys from hB during init so both A and B create their own key objects concurrently
      hB.fakeProvider.hiddenFromList.add('v2/keys/');
      await Future.wait([
        hA.engine.createVault(testConfig, 'same-pass'),
        hB.engine.createVault(testConfig, 'same-pass'),
      ]);
      hB.fakeProvider.hiddenFromList.clear();

      // There should be 2 key files in v2/keys/
      final keyFiles = storage.keys.where((k) => k.startsWith('v2/keys/')).toList();
      expect(keyFiles, hasLength(2));

      // A creates a record and syncs
      await hA.switchActiveSession();
      await hA.recordRepo.createRecord(title: 'RecA', body: 'BodyA');
      await hA.engine.syncNow();

      // B creates a record and syncs
      await hB.switchActiveSession();
      await hB.recordRepo.createRecord(title: 'RecB', body: 'BodyB');
      await hB.engine.syncNow();

      // B syncs to fetch A's record
      await hB.switchActiveSession();
      await hB.engine.syncNow();

      // A syncs again to fetch B's record
      await hA.switchActiveSession();
      await hA.engine.syncNow();

      final recsA = await hA.recordRepo.searchRecords();
      final recsB = await hB.recordRepo.searchRecords();
      expect(recsA, hasLength(2));
      expect(recsB, hasLength(2));

      // Check active key convergence
      final sessionA = (await hA.engine.getOverview()).vaultId;
      final sessionB = (await hB.engine.getOverview()).vaultId;
      expect(sessionA, sessionB);

      await hA.dispose();
      await hB.dispose();
    });

    test('3. Concurrent init with different passwords -> locked keys, unlocked via unlockKeys', () async {
      final storage = <String, StoredObject>{};

      final hA = _V2Harness(storage: storage);
      final hB = _V2Harness(storage: storage);

      await hA.engine.createVault(testConfig, 'pass-A');
      // Hide A's keys from B during B's init so B creates its own vault/key with pass-B
      hB.fakeProvider.hiddenFromList.add('v2/keys/');
      await hB.engine.createVault(testConfig, 'pass-B');
      hB.fakeProvider.hiddenFromList.clear();

      // B creates a record encrypted with B's key and uploads it
      await hB.switchActiveSession();
      await hB.recordRepo.createRecord(title: 'RecordB', body: 'BodyB');
      await hB.engine.syncNow();

      // A syncs: A cannot decrypt B's object because pass-A does not unlock B's key
      await hA.switchActiveSession();
      await hA.engine.syncNow();

      var overviewA = await hA.engine.getOverview();
      expect(overviewA.lockedKeyCount, 1);
      var recsA = await hA.recordRepo.searchRecords();
      expect(recsA, isEmpty); // B's record is locked, not stored

      // A unlocks B's key using B's password
      final unlockedCount = await hA.engine.unlockKeys(password: 'pass-B');
      expect(unlockedCount, 1);

      // Now A can sync and decrypt B's record
      await hA.engine.syncNow();
      overviewA = await hA.engine.getOverview();
      expect(overviewA.lockedKeyCount, 0);

      recsA = await hA.recordRepo.searchRecords();
      expect(recsA, hasLength(1));
      expect(recsA.first.title, 'RecordB');

      await hA.dispose();
      await hB.dispose();
    });

    test('4. Key file arrives late: temporary visible min converges, all objects readable', () async {
      final storage = <String, StoredObject>{};

      final hA = _V2Harness(storage: storage);
      await hA.engine.createVault(testConfig, 'pw');

      final hB = _V2Harness(storage: storage);
      // Hide A's key during B's init so B creates its own key
      hB.fakeProvider.hiddenFromList.add('v2/keys/');
      await hB.engine.createVault(testConfig, 'pw');
      hB.fakeProvider.hiddenFromList.clear();

      final keyFiles = storage.keys.where((k) => k.startsWith('v2/keys/')).toList();
      expect(keyFiles, hasLength(2));
      keyFiles.sort();

      // Hide the smaller key file temporarily from B
      final smallerKeyFile = keyFiles.first;
      hB.fakeProvider.hiddenFromList.add(smallerKeyFile);

      // B writes a record and syncs
      await hB.switchActiveSession();
      await hB.recordRepo.createRecord(title: 'RecB', body: 'BodyB');
      await hB.engine.syncNow();

      // Unhide key file
      hB.fakeProvider.hiddenFromList.clear();

      // A syncs and reads B's object
      await hA.switchActiveSession();
      await hA.engine.syncNow();
      final recsA = await hA.recordRepo.searchRecords();
      expect(recsA, hasLength(1));
      expect(recsA.first.title, 'RecB');

      await hA.dispose();
      await hB.dispose();
    });

    test('5. Two devices offline edit same record -> conflict preserved', () async {
      final storage = <String, StoredObject>{};

      final hA = _V2Harness(storage: storage);
      await hA.engine.createVault(testConfig, 'pw');

      final rec = await hA.recordRepo.createRecord(title: 'Shared Title', body: 'Initial');
      await hA.engine.syncNow();

      final hB = _V2Harness(storage: storage);
      SyncSessionHolder.current = null;
      await hB.engine.joinVault(testConfig, password: 'pw');
      await hB.engine.syncNow();

      // Go offline on both
      hA.fakeProvider.offline = true;
      hB.fakeProvider.offline = true;

      // Device A edits
      await hA.switchActiveSession();
      await hA.recordRepo.updateRecord(rec.id, title: 'Title From A', body: 'Body From A');

      // Device B edits
      await hB.switchActiveSession();
      await hB.recordRepo.updateRecord(rec.id, title: 'Title From B', body: 'Body From B');

      hA.fakeProvider.offline = false;
      hB.fakeProvider.offline = false;

      // Both devices sync
      await hA.switchActiveSession();
      await hA.engine.syncNow();

      await hB.switchActiveSession();
      await hB.engine.syncNow();

      // A syncs to discover conflict
      await hA.switchActiveSession();
      await hA.engine.syncNow();

      final overviewA = await hA.engine.getOverview();
      expect(overviewA.conflictCount, 1);

      final conflicts = await hA.store.openConflicts();
      expect(conflicts, hasLength(1));
      expect(conflicts.first.entityId, rec.id);

      await hA.dispose();
      await hB.dispose();
    });

    test('6. Upload timeout after PUT: retry is idempotent, remote single object', () async {
      final storage = <String, StoredObject>{};

      final hA = _V2Harness(storage: storage);
      await hA.engine.createVault(testConfig, 'pw');
      await hA.recordRepo.createRecord(title: 'Timeout Title', body: 'Body');

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

      final encObjects = storage.keys.where((k) => k.startsWith('v2/objects/')).toList();
      expect(encObjects, hasLength(1));

      // Restart engine on same DB
      final hA2 = _V2Harness(
        storage: storage,
        existingDb: hA.db,
        existingStore: hA.store,
        existingSecureStore: hA.secureStore,
        existingConfigStore: hA.configStore,
      );

      await hA2.switchActiveSession();
      await hA2.engine.syncNow();
      final encObjects2 = storage.keys.where((k) => k.startsWith('v2/objects/')).toList();
      expect(encObjects2, hasLength(1));

      await hA.dispose();
      hA2.engine.dispose();
    });

    test('7. Fresh device full recovery on multi-key vault', () async {
      final storage = <String, StoredObject>{};

      final hA = _V2Harness(storage: storage);
      await hA.engine.createVault(testConfig, 'pass-shared');
      final cat = await hA.categoryRepo.createCategory('Life', '#00ff00');
      final tag = await hA.tagRepo.findOrCreateTag('Personal');
      await hA.recordRepo.createRecord(
        title: 'Rec 1',
        body: 'Body 1',
        categoryId: cat.id,
        tagIds: [tag.id],
        isFavorite: true,
      );
      await hA.engine.syncNow();

      final hB = _V2Harness(storage: storage);
      // Hide A's key during B's init so B creates its second key
      hB.fakeProvider.hiddenFromList.add('v2/keys/');
      await hB.engine.createVault(testConfig, 'pass-shared');
      hB.fakeProvider.hiddenFromList.clear();

      await hB.switchActiveSession();
      await hB.recordRepo.createRecord(title: 'Rec 2', body: 'Body 2');
      await hB.engine.syncNow();

      // Fresh device recovery
      SyncSessionHolder.current = null;
      final hC = _V2Harness(storage: storage);
      final events = <RecoveryProgress>[];
      await for (final p in hC.engine.recoverFromRemote(testConfig, password: 'pass-shared')) {
        events.add(p);
      }

      expect(events.last.done, isTrue);
      expect(events.last.recordsRestored, 2);

      final recsC = await hC.recordRepo.searchRecords();
      expect(recsC, hasLength(2));
      final catsC = await hC.categoryRepo.getAllCategories();
      expect(catsC, hasLength(1));
      expect(catsC.first.name, 'Life');
      final tagsC = await hC.tagRepo.getAllTags();
      expect(tagsC, hasLength(1));
      expect(tagsC.first.name, 'Personal');

      await hA.dispose();
      await hB.dispose();
      await hC.dispose();
    });

    test('8. Wrong password / tampered key / tampered ciphertext security tests', () async {
      final storage = <String, StoredObject>{};

      final hA = _V2Harness(storage: storage);
      await hA.engine.createVault(testConfig, 'right-pass');
      await hA.recordRepo.createRecord(title: 'Original', body: 'Content');
      await hA.engine.syncNow();

      final keyCountBefore = storage.keys.where((k) => k.startsWith('v2/keys/')).length;

      // Wrong password join throws and makes NO remote writes
      SyncSessionHolder.current = null;
      final hB = _V2Harness(storage: storage);
      await expectLater(
        () => hB.engine.joinVault(testConfig, password: 'wrong-pass'),
        throwsA(isA<SyncError>().having((e) => e.code, 'code', SyncErrorCode.wrongPasswordOrKey)),
      );
      expect(storage.keys.where((k) => k.startsWith('v2/keys/')).length, keyCountBefore);

      // Corrupt a key file: corrupt key file skipped, valid key still works
      storage['v2/keys/9999999999999999.00000000.json'] = StoredObject(
        bytes: Uint8List.fromList(utf8.encode('{"format":"broken"}')),
        etag: '"broken"',
      );

      SyncSessionHolder.current = null;
      final hC = _V2Harness(storage: storage);
      await hC.engine.joinVault(testConfig, password: 'right-pass');
      await hC.engine.syncNow();
      final recsC = await hC.recordRepo.searchRecords();
      expect(recsC, hasLength(1)); // readable using valid key

      // Tampered object ciphertext: skipped and never stored into database
      final encFile = storage.keys.firstWhere((k) => k.startsWith('v2/objects/'));
      final oldBytes = storage[encFile]!.bytes;
      final tampered = Uint8List.fromList(oldBytes)..[oldBytes.length - 1] ^= 0xff;
      storage[encFile] = StoredObject(bytes: tampered, etag: '"tampered"');

      SyncSessionHolder.current = null;
      final hD = _V2Harness(storage: storage);
      await hD.engine.joinVault(testConfig, password: 'right-pass');
      await hD.engine.syncNow();
      final recsD = await hD.recordRepo.searchRecords();
      expect(recsD, isEmpty); // never stored

      await hA.dispose();
      await hB.dispose();
      await hC.dispose();
      await hD.dispose();
    });

    test('9. Migration from v1 to v2: legacy backup, idempotence, wrong password leaves remote intact', () async {
      final storage = <String, StoredObject>{};

      // Seed a v1 vault: header.json + 3 legacy objects
      final crypto = VaultCrypto();
      final v1Vault = await crypto.createVault(password: 'v1-pass');
      storage['header.json'] = StoredObject(
        bytes: Uint8List.fromList(utf8.encode(v1Vault.headerJson)),
        etag: '"header-v1"',
      );

      final now = DateTime.now().toUtc();
      for (var i = 1; i <= 3; i++) {
        final payload = EntitySnapshots.payload(
          revisionId: 'rev-v1-$i',
          entityType: EntitySnapshots.recordType,
          entityId: 'rec-v1-$i',
          parents: [],
          createdAt: now,
          deleted: false,
          snapshot: EntitySnapshots.recordSnapshot(
            title: 'Legacy Title $i',
            body: 'Legacy Body $i',
            tagIds: [],
            isFavorite: false,
            createdAt: now,
            updatedAt: now,
          ),
        );
        final enc = await crypto.encryptRevision(
          session: v1Vault.session,
          revisionId: 'rev-v1-$i',
          entityType: EntitySnapshots.recordType,
          entityId: 'rec-v1-$i',
          payload: payload,
        );
        storage['objects/rev-v1-$i.enc'] = StoredObject(bytes: enc, etag: '"etag-$i"');
      }

      final hMigrator = _V2Harness(storage: storage);

      // Wrong password throws wrongPasswordOrKey with ZERO remote changes
      await expectLater(
        () => hMigrator.engine.migrateV1ToV2(testConfig, 'wrong-pass'),
        throwsA(isA<SyncError>().having((e) => e.code, 'code', SyncErrorCode.wrongPasswordOrKey)),
      );
      expect(storage.containsKey('header.json'), isTrue);
      expect(storage.keys.where((k) => k.startsWith('v2/')), isEmpty);

      // Successful migration
      final report = await hMigrator.engine.migrateV1ToV2(testConfig, 'v1-pass');
      expect(report.copiedObjects, 3);
      expect(report.skippedObjects, 0);

      // header.json renamed to header.json.migrated-backup
      expect(storage.containsKey('header.json'), isFalse);
      expect(storage.containsKey('header.json.migrated-backup'), isTrue);

      // All 3 objects copied into v2/objects/ with identical bytes
      for (var i = 1; i <= 3; i++) {
        expect(storage.containsKey('v2/objects/rev-v1-$i.enc'), isTrue);
        expect(
          storage['v2/objects/rev-v1-$i.enc']!.bytes,
          storage['objects/rev-v1-$i.enc']!.bytes,
        );
      }

      // Sync and verify all records read successfully
      await hMigrator.engine.syncNow();
      final recs = await hMigrator.recordRepo.searchRecords();
      expect(recs, hasLength(3));

      await hMigrator.dispose();
    });

    test('10. Regression with supportsConditionalCreate=true core flow', () async {
      final storage = <String, StoredObject>{};

      final hA = _V2Harness(
        storage: storage,
        supportsConditionalCreate: true,
        supportsConditionalUpdate: true,
      );

      await hA.engine.createVault(testConfig, 'pw');
      await hA.recordRepo.createRecord(title: 'Cond Title', body: 'Cond Body');
      await hA.engine.syncNow();

      final hB = _V2Harness(
        storage: storage,
        supportsConditionalCreate: true,
        supportsConditionalUpdate: true,
      );
      SyncSessionHolder.current = null;
      await hB.engine.joinVault(testConfig, password: 'pw');
      await hB.engine.syncNow();

      final recsB = await hB.recordRepo.searchRecords();
      expect(recsB, hasLength(1));
      expect(recsB.first.title, 'Cond Title');

      await hA.dispose();
      await hB.dispose();
    });
  });
}
