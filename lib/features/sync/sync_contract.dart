// lib/features/sync/sync_contract.dart
// Stage C: UI-facing contract for the sync engine.
//
// This file is the STABLE interface between the functional sync stack
// (implemented by Claude: crypto, WebDAV provider, revision store, engine)
// and the sync UI (implemented by Gemini: settings page, conflict page,
// recovery flow).
//
// Rules:
// - Do NOT rename or change the signature of anything declared here without
//   updating BOTH the functional implementation and the UI.
// - The functional side MAY add new declarations (extend, don't break).
// - All providers declared here must be implemented by the functional side.
// - UI code must only depend on these declarations, never on internals.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suicun/services/webdav_service.dart';

/// High-level sync overview shown on the settings page.
class SyncOverview {
  const SyncOverview({
    required this.enabled,
    required this.syncing,
    this.lastSuccessAt,
    this.pendingCount = 0,
    this.conflictCount = 0,
    this.lockedKeyCount = 0,
    this.keyCount = 0,
    this.totalRecords = 0,
    this.syncedRecords = 0,
    this.vaultId,
    this.lastError,
  });

  /// Whether the user has enabled sync (config + vault joined).
  final bool enabled;

  /// Whether a sync pass is currently running.
  final bool syncing;

  /// Last time a full sync pass completed successfully (local time, UTC stored).
  final DateTime? lastSuccessAt;

  /// Number of outbox entries not yet confirmed on the server.
  final int pendingCount;

  /// Number of unresolved conflicts.
  final int conflictCount;

  /// Number of keys known on server but not unlocked locally.
  final int lockedKeyCount;

  /// Total number of keys known on server.
  final int keyCount;

  /// Number of live (non-deleted) local records.
  final int totalRecords;

  /// Live local records whose head revision(s) are all confirmed on the server.
  final int syncedRecords;

  /// The vault id of the joined sync library, if any.
  final String? vaultId;

  /// Last sync error as a user-facing message (already localized), if any.
  final String? lastError;
}

/// One unresolved conflict for the conflict resolution page.
class ConflictInfo {
  const ConflictInfo({
    required this.id,
    required this.entityId,
    required this.entityType, // 'record' | 'category' | 'tag'
    required this.localTitle,
    required this.localBody,
    required this.remoteTitle,
    required this.remoteBody,
    required this.localUpdatedAt,
    required this.remoteUpdatedAt,
  });

  final String id;
  final String entityId;
  final String entityType;
  final String localTitle;
  final String localBody;
  final String remoteTitle;
  final String remoteBody;
  final DateTime localUpdatedAt;
  final DateTime remoteUpdatedAt;
}

/// How the user resolves a conflict (spec §11.2).
enum ConflictChoice {
  /// Keep the local version; the discarded version is preserved in history.
  keepLocal,

  /// Keep the other version; the discarded version is preserved in history.
  keepRemote,

  /// Keep both: the other version becomes a new entity with a new id.
  keepBoth,

  /// User-edited merge; [mergedTitle]/[mergedBody] are required.
  manualMerge,
}

/// Progress of a "recover from WebDAV" run on a new device (spec §11.6).
class RecoveryProgress {
  const RecoveryProgress({
    required this.phase,
    required this.totalObjects,
    required this.doneObjects,
    required this.failedObjects,
    required this.recordsRestored,
    this.done = false,
    this.error,
  });

  /// Machine phase: 'connecting' | 'listing' | 'downloading' | 'rebuilding' | 'done' | 'error'.
  final String phase;
  final int totalObjects;
  final int doneObjects;
  final int failedObjects;
  final int recordsRestored;
  final bool done;
  final String? error;
}

/// Result of checking whether the configured directory already holds a vault.
enum RemoteVaultCheck {
  /// No vault found — the user can create a new vault here.
  noVault,

  /// A valid v2 vault was found — the user must enter the vault password
  /// or recovery key to join.
  hasVault,

  /// A v1 header.json was found — offer migration to v2.
  hasV1Vault,
}

class MigrationReport {
  const MigrationReport({
    required this.keyId,
    required this.copiedObjects,
    required this.skippedObjects,
  });

  final String keyId;
  final int copiedObjects;
  final int skippedObjects;
}

/// Actions the UI can trigger. Implemented by the functional side.
abstract interface class SyncActions {
  /// Runs one sync pass now (no-op while already syncing or when disabled).
  Future<void> syncNow();

  /// Enables sync with an already-joined vault (resumes background passes).
  Future<void> setEnabled(bool enabled);

  /// Disables sync: stops network tasks, keeps local data (spec §4.6).
  /// When [removeCredentials] is true, also deletes stored WebDAV credentials.
  Future<void> disableSync({bool removeCredentials = false});

  /// Checks the configured directory for an existing vault header.
  Future<RemoteVaultCheck> checkRemoteVault(WebdavConfig config);

  /// Creates a new vault at the configured directory with [password].
  /// Throws a user-facing (localized) message on failure.
  Future<void> createVault(WebdavConfig config, String password);

  /// Joins an existing vault using [password] or [recoveryKey].
  /// Throws a user-facing (localized) message on failure.
  Future<void> joinVault(
    WebdavConfig config, {
    String? password,
    String? recoveryKey,
  });

  /// Migrates a v1 vault at [config] to v2 using [password].
  Future<MigrationReport> migrateV1ToV2(WebdavConfig config, String password);

  /// Unlocks locked keys using the provided credential, returning the count
  /// of newly unlocked keys.
  Future<int> unlockKeys({String? password, String? recoveryKey});

  /// True when the last [createVault] call found an existing vault and joined it instead.
  bool get lastCreateJoinedExisting;

  /// Starts recovery on a new device. Emits progress; completes when done.
  /// The local database is rebuilt with this device's own device key.
  Stream<RecoveryProgress> recoverFromRemote(
    WebdavConfig config, {
    String? password,
    String? recoveryKey,
  });

  /// Resolves a conflict. For [ConflictChoice.manualMerge], [mergedTitle]
  /// and [mergedBody] are required.
  Future<void> resolveConflict(
    String conflictId,
    ConflictChoice choice, {
    String? mergedTitle,
    String? mergedBody,
  });

  /// Returns the recovery key produced by the most recent [createVault] and
  /// forgets it (one-shot). Returns null if there is none. The UI must show
  /// it to the user exactly once; it is never persisted.
  String? consumePendingRecoveryKey();
}

// ── Providers (implemented by the functional side) ───────────────────────────

/// Live sync overview for the settings page.
final syncOverviewProvider = StreamProvider<SyncOverview>((ref) {
  throw UnimplementedError(
      'syncOverviewProvider must be overridden by the sync engine');
});

/// Unresolved conflicts for the conflict page.
final conflictsProvider = StreamProvider<List<ConflictInfo>>((ref) {
  throw UnimplementedError(
      'conflictsProvider must be overridden by the sync engine');
});

/// Entry point for UI-triggered sync operations.
final syncActionsProvider = Provider<SyncActions>((ref) {
  throw UnimplementedError(
      'syncActionsProvider must be overridden by the sync engine');
});
