// lib/features/records/data/id_doc_body_migration.dart
// Round 5 §1.2: one-time migration of legacy ID document bodies to the
// new structured format (marker + JSON).
//
// Runs once in the background after the database is opened. Uses the
// [RecordRepository] so sync outbox revisions are produced. Failures are
// skipped (retried on next startup); the flag is only set when every
// candidate record was processed without error.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suicun/core/database/providers.dart';
import 'package:suicun/features/records/domain/id_doc_codec.dart';

/// SharedPreferences flag marking the migration as complete.
const kIdDocMigratedV2Key = 'id_doc_migrated_v2';

/// Runs the one-time ID document body migration in the background.
///
/// Safe to call on every startup: returns immediately when the flag is set.
/// Never throws; per-record failures are skipped and retried next time.
Future<void> runIdDocBodyMigration(ProviderContainer container) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(kIdDocMigratedV2Key) ?? false) return;

    final repo = container.read(recordRepositoryProvider);
    // Fetch all non-deleted records (ID docs are few; large limit is fine).
    final records = await repo.searchRecords(
      query: '',
      includeDeleted: false,
      limit: 10000,
    );

    var allOk = true;
    for (final detail in records) {
      final body = detail.record.body;
      if (!isIdDocBody(body) || isNewIdDocBody(body)) continue;

      try {
        // Decode with a neutral prefix (no BuildContext in background).
        final data = decodeIdDocBody(body);
        if (data == null) continue; // not decodable; leave as-is
        final newBody = encodeIdDocBody(data);
        if (newBody == body) continue;
        await repo.updateRecord(detail.record.id, body: newBody);
      } catch (_) {
        allOk = false; // retry this record next startup
      }
    }

    if (allOk) {
      await prefs.setBool(kIdDocMigratedV2Key, true);
    }
  } catch (_) {
    // Never block startup.
  }
}
