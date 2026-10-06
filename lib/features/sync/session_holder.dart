// lib/features/sync/session_holder.dart
// Stage C: process-wide, in-memory holder of the unlocked vault session.

import 'package:suicun/features/sync/vault_crypto.dart';

/// Holds the currently active [MultiKeySession] (keys + activeKeyId) so that
/// repositories can encrypt revisions without depending on the engine.
///
/// In-memory ONLY: never persisted from here and never logged. The sync
/// engine sets it when a vault is joined/restored and clears it when sync is
/// disabled. When null, sync is not joined and local edits create no revisions.
class SyncSessionHolder {
  SyncSessionHolder._();

  static MultiKeySession? current;
}
