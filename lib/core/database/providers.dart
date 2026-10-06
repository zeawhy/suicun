// lib/core/database/providers.dart
// Riverpod providers for the database and repositories.

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/features/categories/data/category_repository.dart';
import 'package:suicun/features/records/data/record_repository.dart';
import 'package:suicun/features/sync/session_holder.dart';
import 'package:suicun/features/sync/sync_enqueuer.dart';
import 'package:suicun/features/tags/data/tag_repository.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  // Stage B: the real database is opened encrypted in main() and injected
  // via appDatabaseProvider.overrideWithValue. Failing closed here so a
  // missing override can never silently open a plaintext database.
  throw StateError(
    'appDatabaseProvider must be overridden (main() with the encrypted '
    'database, tests with an in-memory database).',
  );
}

@Riverpod(keepAlive: true)
SyncEnqueuer syncEnqueuer(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return SyncEnqueuer(
    db: db,
    sessionProvider: () async => SyncSessionHolder.current,
  );
}

@Riverpod(keepAlive: true)
RecordRepository recordRepository(Ref ref) => RecordRepository(
      ref.watch(appDatabaseProvider),
      syncEnqueuer: ref.watch(syncEnqueuerProvider),
    );

@Riverpod(keepAlive: true)
CategoryRepository categoryRepository(Ref ref) => CategoryRepository(
      ref.watch(appDatabaseProvider),
      syncEnqueuer: ref.watch(syncEnqueuerProvider),
    );

@Riverpod(keepAlive: true)
TagRepository tagRepository(Ref ref) => TagRepository(
      ref.watch(appDatabaseProvider),
      syncEnqueuer: ref.watch(syncEnqueuerProvider),
    );
