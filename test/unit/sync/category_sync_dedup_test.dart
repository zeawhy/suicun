// test/unit/sync/category_sync_dedup_test.dart
// Regression tests for:
// 1. Remote category revisions with matching normalized names merging instead
//    of creating duplicates, while preserving incoming records' categories.
// 2. One-time idempotent local category deduplication migration.
// 3. Sync-safe tombstone handling so deleting/merging a duplicate never drops
//    records to uncategorized when a same-name survivor exists.

import 'dart:typed_data';
import 'dart:ui' show Locale;

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suicun/core/crypto/key_value_store.dart';
import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/core/database/providers.dart';
import 'package:suicun/features/categories/data/category_dedup_migration.dart';
import 'package:suicun/features/categories/data/category_repository.dart';
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

class _DeviceHarness {
  _DeviceHarness(Map<String, StoredObject> sharedStorage) {
    db = AppDatabase(NativeDatabase.memory());
    store = SyncStore(db);
    enqueuer = SyncEnqueuer(
      db: db,
      sessionProvider: () async => SyncSessionHolder.current,
    );
    categoryRepo = CategoryRepository(db, syncEnqueuer: enqueuer);
    recordRepo = RecordRepository(db, syncEnqueuer: enqueuer);
    engine = SyncEngine(
      db: db,
      configStore: _MemConfigStore(),
      secureStore: MemoryKeyValueStore(),
      syncEnqueuer: enqueuer,
      providerFactory: (_) => FakeSyncProvider(
        supportsConditionalCreate: false,
        supportsConditionalUpdate: false,
        initialStorage: sharedStorage,
      ),
      retryPolicy: const RetryPolicy(baseDelay: Duration.zero),
      debounceDelay: const Duration(milliseconds: 50),
      getLocale: () => const Locale('zh'),
    );
  }

  late final AppDatabase db;
  late final SyncStore store;
  late final SyncEnqueuer enqueuer;
  late final CategoryRepository categoryRepo;
  late final RecordRepository recordRepo;
  late final SyncEngine engine;

  Future<void> dispose() async {
    engine.dispose();
    await db.close();
  }
}

void main() {
  MultiKeySession? savedSession;

  setUp(() {
    savedSession = SyncSessionHolder.current;
    SyncSessionHolder.current = null;
  });

  tearDown(() {
    SyncSessionHolder.current = savedSession;
  });

  group('Category sync deduplication (SnapshotApplier)', () {
    late AppDatabase db;
    late CategoryRepository categoryRepo;
    late RecordRepository recordRepo;
    late SnapshotApplier applier;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      categoryRepo = CategoryRepository(db);
      recordRepo = RecordRepository(db);
      applier = SnapshotApplier(db);
    });

    tearDown(() async {
      await db.close();
    });

    test(
        'reproduces user bug: local seeded defaults + remote same-name '
        'different-ID category keeps 1 row and preserves synced record category',
        () async {
      // 1. Seed default categories locally.
      await categoryRepo.ensureDefaultCategories();
      final localStudy = (await categoryRepo.getAllCategories())
          .singleWhere((c) => c.name == '学习');

      // 2. Apply a remote category revision for '学习' with a different ID.
      const remoteStudyId = 'remote-study-uuid-999';
      final now = DateTime.now().toUtc();
      await applier.apply(ParsedRevision(
        revisionId: 'rev-cat-remote-1',
        entityType: EntitySnapshots.categoryType,
        entityId: remoteStudyId,
        parents: const [],
        createdAt: now,
        deleted: false,
        snapshot: const {'name': '学习', 'color': '#7C5CD6'},
      ));

      // Only 1 active '学习' row should exist.
      final activeCategories = await categoryRepo.getAllCategories();
      final studyRows =
          activeCategories.where((c) => c.name.trim() == '学习').toList();
      expect(studyRows, hasLength(1));
      expect(studyRows.single.id, localStudy.id);
      expect(
        activeCategories.length,
        CategoryRepository.defaultCategories.length,
      );

      // 3. Apply a remote record revision pointing to remoteStudyId.
      await applier.apply(ParsedRevision(
        revisionId: 'rev-rec-remote-1',
        entityType: EntitySnapshots.recordType,
        entityId: 'remote-rec-1',
        parents: const [],
        createdAt: now,
        deleted: false,
        snapshot: {
          'title': 'Synced Study Note',
          'body': 'Important notes',
          'category_id': remoteStudyId,
          'tag_ids': const <String>[],
          'is_favorite': false,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        },
      ));

      // The synced record must NOT become uncategorized and must point to
      // the surviving local '学习' category.
      final rec = await recordRepo.getRecord('remote-rec-1');
      expect(rec, isNotNull);
      expect(rec!.record.categoryId, localStudy.id);
      expect(rec.category?.name, '学习');

      // Filtering by the local '学习' category finds the synced record.
      final filtered =
          await recordRepo.searchRecords(categoryId: localStudy.id);
      expect(filtered.map((r) => r.record.id), contains('remote-rec-1'));
    });

    test(
        'matches same category across whitespace and case differences, '
        'and later updates to alias do not resurrect duplicate', () async {
      final localCustom = await categoryRepo.createCategory('Travel', '#112233');
      final now = DateTime.now().toUtc();

      // Remote has ' travel ' with different ID.
      await applier.apply(ParsedRevision(
        revisionId: 'rev-travel-1',
        entityType: EntitySnapshots.categoryType,
        entityId: 'remote-travel-id',
        parents: const [],
        createdAt: now,
        deleted: false,
        snapshot: const {'name': ' travel ', 'color': '#445566'},
      ));

      var active = await categoryRepo.getAllCategories();
      expect(active.where((c) => c.name.trim().toLowerCase() == 'travel'),
          hasLength(1));

      // Later update to the remote alias must still not resurrect it.
      await applier.apply(ParsedRevision(
        revisionId: 'rev-travel-2',
        entityType: EntitySnapshots.categoryType,
        entityId: 'remote-travel-id',
        parents: const ['rev-travel-1'],
        createdAt: now.add(const Duration(seconds: 5)),
        deleted: false,
        snapshot: const {'name': 'TRAVEL', 'color': '#778899'},
      ));

      active = await categoryRepo.getAllCategories();
      expect(active, hasLength(1));
      expect(active.single.id, localCustom.id);
    });

    test(
        'sync-safe tombstone: deleting merged/duplicate remote category ID '
        'reassigns records to same-name survivor instead of nullifying',
        () async {
      await categoryRepo.ensureDefaultCategories();
      final localStudy = (await categoryRepo.getAllCategories())
          .singleWhere((c) => c.name == '学习');

      // Suppose a duplicate row 'dup-study' existed and a record points to it.
      const dupStudyId = 'dup-study-id';
      await db.into(db.categories).insert(CategoriesCompanion.insert(
            id: dupStudyId,
            name: '学习',
            color: const drift.Value('#7C5CD6'),
          ));
      final rec = await recordRepo.createRecord(
        title: 'Note on duplicate',
        body: 'Keep my category',
        categoryId: dupStudyId,
      );

      // Remote sends a tombstone for dup-study-id.
      await applier.apply(ParsedRevision(
        revisionId: 'rev-del-dup',
        entityType: EntitySnapshots.categoryType,
        entityId: dupStudyId,
        parents: const [],
        createdAt: DateTime.now().toUtc(),
        deleted: true,
        snapshot: const {},
      ));

      // Record must be reassigned to localStudy, NOT set to null.
      final updatedRec = await recordRepo.getRecord(rec.record.id);
      expect(updatedRec!.record.categoryId, localStudy.id);
      expect(updatedRec.category?.name, '学习');

      final active = await categoryRepo.getAllCategories();
      expect(active.where((c) => c.name == '学习'), hasLength(1));
    });

    test(
        'genuine category deletion (no same-name survivor) still nullifies '
        'records categoryId', () async {
      final work = await categoryRepo.createCategory('自定义', '#112233');
      final rec = await recordRepo.createRecord(
        title: 'Custom note',
        body: 'Body',
        categoryId: work.id,
      );

      await applier.apply(ParsedRevision(
        revisionId: 'rev-del-custom',
        entityType: EntitySnapshots.categoryType,
        entityId: work.id,
        parents: const [],
        createdAt: DateTime.now().toUtc(),
        deleted: true,
        snapshot: const {},
      ));

      final updatedRec = await recordRepo.getRecord(rec.record.id);
      expect(updatedRec!.record.categoryId, isNull);
      expect(await categoryRepo.getAllCategories(), isEmpty);
    });
  });

  group('End-to-end two-device SyncEngine category dedup', () {
    const config = WebdavConfig(
      serverUrl: 'https://dav.example.com',
      username: 'u',
      password: 'p',
      directory: '/suicun/',
    );

    test(
        'legacy device with random default IDs + new device with deterministic '
        'default IDs sync without duplicating categories or dropping note categories',
        () async {
      final sharedStorage = <String, StoredObject>{};
      final legacyDevice = _DeviceHarness(sharedStorage);
      final newDevice = _DeviceHarness(sharedStorage);
      try {
        // Legacy device already had random-ID default categories + a note.
        const legacyStudyId = 'legacy-random-study-id';
        await legacyDevice.db.into(legacyDevice.db.categories).insert(
              CategoriesCompanion.insert(
                id: legacyStudyId,
                name: '学习',
                color: const drift.Value('#7C5CD6'),
                keywords: drift.Value(CategoryRepository.encodeKeywords(
                    CategoryRepository.defaultCategories
                        .singleWhere((d) => d.name == '学习')
                        .keywords)),
              ),
            );
        await legacyDevice.recordRepo.createRecord(
          title: 'Legacy note',
          body: 'From old phone',
          categoryId: legacyStudyId,
        );
        await legacyDevice.engine.createVault(config, 'pass123');
        await legacyDevice.engine.syncNow();

        // New device seeds defaults with deterministic IDs and creates a note
        // BEFORE joining/syncing the vault.
        await newDevice.categoryRepo.ensureDefaultCategories();
        final newStudyId = CategoryRepository.defaultCategoryId('学习');
        await newDevice.recordRepo.createRecord(
          title: 'New note',
          body: 'From new phone',
          categoryId: newStudyId,
        );

        await newDevice.engine.joinVault(config, password: 'pass123');
        await newDevice.engine.syncNow();
        await legacyDevice.engine.syncNow();

        // Neither device has duplicate '学习'.
        final newCats = await newDevice.categoryRepo.getAllCategories();
        final legacyCats = await legacyDevice.categoryRepo.getAllCategories();
        expect(newCats.where((c) => c.name == '学习'), hasLength(1));
        expect(legacyCats.where((c) => c.name == '学习'), hasLength(1));

        // Both notes exist on both devices and neither lost its category.
        final newRecs = await newDevice.recordRepo.searchRecords();
        final legacyRecs = await legacyDevice.recordRepo.searchRecords();
        expect(newRecs, hasLength(2));
        expect(legacyRecs, hasLength(2));
        for (final r in newRecs) {
          expect(r.category?.name, '学习');
          expect(r.record.categoryId, newStudyId);
        }
        for (final r in legacyRecs) {
          expect(r.category?.name, '学习');
          expect(r.record.categoryId, legacyStudyId);
        }
      } finally {
        await legacyDevice.dispose();
        await newDevice.dispose();
      }
    });
  });

  group('Local deduplication migration', () {
    late AppDatabase db;
    late SyncStore store;
    late SyncEnqueuer enqueuer;
    late CategoryRepository categoryRepo;
    late RecordRepository recordRepo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      store = SyncStore(db);
      enqueuer = SyncEnqueuer(
        db: db,
        sessionProvider: () async => SyncSessionHolder.current,
      );
      categoryRepo = CategoryRepository(db, syncEnqueuer: enqueuer);
      recordRepo = RecordRepository(db, syncEnqueuer: enqueuer);
    });

    tearDown(() async {
      await db.close();
    });

    test(
        'merges 4 duplicate 学习 categories, preserves all notes & custom '
        'keywords, is idempotent, and enqueues zero sync tombstones', () async {
      final studyDef = CategoryRepository.defaultCategories
          .singleWhere((d) => d.name == '学习');
      final encodedDefaultKw =
          CategoryRepository.encodeKeywords(studyDef.keywords);

      // Insert 4 duplicate '学习' rows (including whitespace variant and
      // custom keyword on one of them).
      for (var i = 1; i <= 4; i++) {
        await db.into(db.categories).insert(CategoriesCompanion.insert(
              id: 'study-$i',
              name: i == 4 ? ' 学习 ' : '学习',
              color: const drift.Value('#7C5CD6'),
              keywords: drift.Value(i == 3
                  ? CategoryRepository.encodeKeywords(
                      [...studyDef.keywords, '考研'])
                  : encodedDefaultKw),
            ));
      }
      // Also insert 2 duplicates of '工作'.
      await db.into(db.categories).insert(CategoriesCompanion.insert(
            id: 'work-1',
            name: '工作',
            color: const drift.Value('#4A7DDC'),
          ));
      await db.into(db.categories).insert(CategoriesCompanion.insert(
            id: 'work-2',
            name: '工作',
            color: const drift.Value('#4A7DDC'),
          ));

      // Attach live records to study-1, study-2 (2 records), and study-4,
      // plus a trashed record to study-3.
      final r1 = await recordRepo.createRecord(
          title: 'Note 1', body: 'b1', categoryId: 'study-1');
      final r2 = await recordRepo.createRecord(
          title: 'Note 2', body: 'b2', categoryId: 'study-2');
      final r3 = await recordRepo.createRecord(
          title: 'Note 3', body: 'b3', categoryId: 'study-2');
      final r4 = await recordRepo.createRecord(
          title: 'Note 4', body: 'b4', categoryId: 'study-4');
      final rTrash = await recordRepo.createRecord(
          title: 'Trashed', body: 'bt', categoryId: 'study-3');
      await recordRepo.softDeleteRecord(rTrash.record.id);

      // Activate a dummy sync session to prove dedup emits NO outbox entries.
      SyncSessionHolder.current = MultiKeySession(
        keys: {'k1': Uint8List(32)},
      );

      final merged = await categoryRepo.deduplicateCategories();
      expect(merged, 4); // 3 redundant '学习' + 1 redundant '工作'

      // Only 1 active '学习' and 1 active '工作' remain.
      final active = await categoryRepo.getAllCategories();
      expect(active, hasLength(2));
      final survivorStudy = active.singleWhere((c) => c.name.trim() == '学习');
      expect(survivorStudy.id, 'study-2'); // had the most records (2)

      // Custom keyword '考研' from study-3 was preserved on survivor.
      final survivorKeywords = await categoryRepo.getKeywords(survivorStudy.id);
      expect(survivorKeywords, contains('考研'));
      expect(survivorKeywords, containsAll(studyDef.keywords));

      // All 4 live notes still exist and all point to survivorStudy.id.
      final liveNotes = await recordRepo.searchRecords();
      expect(liveNotes, hasLength(4));
      for (final id in [r1.record.id, r2.record.id, r3.record.id, r4.record.id]) {
        final detail = await recordRepo.getRecord(id);
        expect(detail, isNotNull);
        expect(detail!.record.categoryId, survivorStudy.id);
        expect(detail.category?.id, survivorStudy.id);
      }

      // Trashed note also points to survivorStudy.id (so restoring it works).
      final trashedRow = await (db.select(db.records)
            ..where((r) => r.id.equals(rTrash.record.id)))
          .getSingle();
      expect(trashedRow.categoryId, survivorStudy.id);

      // Sync-safe: zero outbox entries created by deduplication.
      expect(await store.pendingOutboxCount(), 0);

      // Idempotent: second run merges 0 rows and changes nothing.
      expect(await categoryRepo.deduplicateCategories(), 0);
      expect(await categoryRepo.getAllCategories(), hasLength(2));
    });

    test('runCategoryDedupMigration sets SharedPreferences flag and is one-time',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await db.into(db.categories).insert(CategoriesCompanion.insert(
            id: 'dup-1',
            name: '学习',
          ));
      await db.into(db.categories).insert(CategoriesCompanion.insert(
            id: 'dup-2',
            name: '学习',
          ));

      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      await runCategoryDedupMigration(container, prefs: prefs);
      expect(prefs.getBool(kCategoryDedupMigratedV1Key), isTrue);
      expect(await categoryRepo.getAllCategories(), hasLength(1));

      // Subsequent run respects the flag and returns immediately.
      await db.into(db.categories).insert(CategoriesCompanion.insert(
            id: 'dup-3',
            name: '工作',
          ));
      await db.into(db.categories).insert(CategoriesCompanion.insert(
            id: 'dup-4',
            name: '工作',
          ));
      await runCategoryDedupMigration(container, prefs: prefs);
      // Flag was set so migration skipped on second launch.
      expect(
        (await categoryRepo.getAllCategories())
            .where((c) => c.name == '工作'),
        hasLength(2),
      );
    });
  });
}
