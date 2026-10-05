// lib/core/database/providers.dart
// Riverpod providers for the database and repositories.

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/features/categories/data/category_repository.dart';
import 'package:suicun/features/records/data/record_repository.dart';
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
RecordRepository recordRepository(Ref ref) =>
    RecordRepository(ref.watch(appDatabaseProvider));

@Riverpod(keepAlive: true)
CategoryRepository categoryRepository(Ref ref) =>
    CategoryRepository(ref.watch(appDatabaseProvider));

@Riverpod(keepAlive: true)
TagRepository tagRepository(Ref ref) =>
    TagRepository(ref.watch(appDatabaseProvider));
