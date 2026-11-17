// lib/features/categories/data/category_dedup_migration.dart
// One-time local deduplication migration for duplicate categories caused by
// syncing per-device random default category IDs.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suicun/core/database/providers.dart';

/// SharedPreferences flag marking the category deduplication migration as done.
const kCategoryDedupMigratedV1Key = 'category_dedup_migrated_v1';

/// Runs the one-time local category deduplication migration.
///
/// Safe to call on every startup: returns immediately when the flag is set,
/// and [CategoryRepository.deduplicateCategories] is idempotent.
/// Never throws; failures leave the flag unset so it retries on next launch.
Future<void> runCategoryDedupMigration(
  ProviderContainer container, {
  SharedPreferences? prefs,
}) async {
  try {
    final sp = prefs ?? await SharedPreferences.getInstance();
    if (sp.getBool(kCategoryDedupMigratedV1Key) ?? false) return;

    final repo = container.read(categoryRepositoryProvider);
    await repo.deduplicateCategories();
    await sp.setBool(kCategoryDedupMigratedV1Key, true);
  } catch (_) {
    // Never block startup; flag stays unset so the migration retries next time.
  }
}
