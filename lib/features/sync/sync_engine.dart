// lib/features/sync/sync_engine.dart
// Stage C: the sync engine (spec §11.3 seven-step pass, §11.2 conflicts,
// §11.6 recovery).
//
// Design summary
// - Every local edit is stored as an immutable, encrypted revision + an
//   outbox row (see SyncEnqueuer). The engine uploads outbox entries as
//   `objects/<revision_id>.enc` (create-only, never overwritten) and downloads
//   unknown remote revisions, validating every object (envelope, vault id,
//   name, AEAD, payload shape) BEFORE anything is written to the database.
// - Divergent heads (concurrent edits) become conflicts; nothing is ever
//   auto-merged or overwritten.
//
// K_vault persistence decision: K_vault is stored base64 in the platform
// secure storage under `suicun.sync.kvault.<vaultId>` on join / create /
// recover, and deleted on `disableSync(removeCredentials: true)`. It has the
// same protection level as the SQLCipher database key and enables a seamless
// restart (no password prompt). `sync_state` only stores vault_id/device_id —
// never passwords or keys.
//
// Security: nothing secret or user-authored (passwords, keys, titles, bodies,
// Authorization headers) is ever logged; errors carry only codes/status/counts.

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:drift/drift.dart';
import 'package:cryptography/cryptography.dart' as crypto;
import 'package:suicun/core/crypto/key_value_store.dart';
import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/features/sync/entity_snapshot.dart';
import 'package:suicun/features/sync/session_holder.dart';
import 'package:suicun/features/sync/sync_contract.dart';
import 'package:suicun/features/sync/sync_enqueuer.dart';
import 'package:suicun/features/sync/sync_errors.dart';
import 'package:suicun/features/sync/sync_provider.dart';
import 'package:suicun/features/sync/sync_store.dart';
import 'package:suicun/features/sync/vault_crypto.dart';
import 'package:suicun/features/sync/webdav_sync_provider.dart';
import 'package:suicun/services/webdav_service.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

typedef SyncProviderFactory = SyncProvider Function(WebdavConfig config);

/// Persistence of the WebDAV connection config (adapter over WebdavService).
abstract interface class WebdavConfigStore {
  Future<WebdavConfig?> loadConfig();
  Future<void> saveConfig(WebdavConfig config);
  Future<void> clearConfig();
}

/// Exponential backoff with jitter for failed uploads.
class RetryPolicy {
  const RetryPolicy({
    this.baseDelay = const Duration(seconds: 5),
    this.maxDelay = const Duration(minutes: 15),
    this.jitterRatio = 0.25,
    Random? random,
  }) : _random = random;

  final Duration baseDelay;
  final Duration maxDelay;
  final double jitterRatio;
  final Random? _random;

  /// [attempt] >= 1: base * 2^(attempt-1) capped at [maxDelay], +/- jitter.
  Duration delayForAttempt(int attempt) {
    final exp = (attempt < 1 ? 0 : attempt - 1).clamp(0, 30);
    var micros = baseDelay.inMicroseconds * (1 << exp);
    if (micros > maxDelay.inMicroseconds || micros < 0) {
      micros = maxDelay.inMicroseconds;
    }
    if (micros == 0 || jitterRatio <= 0) return Duration(microseconds: micros);
    final r = (_random ?? Random()).nextDouble() * 2 - 1; // [-1, 1)
    final jittered = micros + (micros * jitterRatio * r).round();
    return Duration(microseconds: max(0, jittered));
  }
}

class _Session {
  _Session({
    required this.config,
    required this.provider,
    required this.vault,
    required this.deviceId,
    this.caps,
    this.credential,
    List<String>? lockedKeyIds,
    List<String>? allKeyIds,
  })  : lockedKeyIds = lockedKeyIds ?? <String>[],
        allKeyIds = allKeyIds ?? <String>[];

  final WebdavConfig config;
  final SyncProvider provider;
  final MultiKeySession vault;
  final String deviceId;
  Capabilities? caps;

  /// In-memory join/unlock credential (password or recovery key) used to unlock
  /// newly arrived key files during [refreshKeys]. Never persisted or logged.
  String? credential;

  /// Keys discovered on remote but not unlocked.
  List<String> lockedKeyIds;

  /// All keys discovered on remote.
  List<String> allKeyIds;
}

class _ValidatedRevision {
  _ValidatedRevision({
    required this.path,
    required this.etag,
    required this.bytes,
    required this.envelope,
    required this.parsed,
  });

  final String path;
  final String? etag;
  final Uint8List bytes;
  final RevisionEnvelope envelope;
  final ParsedRevision parsed;
}

class SyncEngine implements SyncActions {
  SyncEngine({
    required AppDatabase db,
    required WebdavConfigStore configStore,
    required KeyValueStore secureStore,
    required this.syncEnqueuer,
    SyncProviderFactory? providerFactory,
    VaultCrypto? crypto,
    RetryPolicy? retryPolicy,
    Duration debounceDelay = const Duration(seconds: 5),
    Future<bool> Function()? isUnlocked,
    Locale Function()? getLocale,
  })  : _db = db,
        _store = SyncStore(db),
        _applier = SnapshotApplier(db),
        _configStore = configStore,
        _secureStore = secureStore,
        _providerFactory =
            providerFactory ?? ((config) => WebdavSyncProvider(config: config)),
        _crypto = crypto ?? VaultCrypto(),
        _retryPolicy = retryPolicy ?? const RetryPolicy(),
        _debounceDelay = debounceDelay,
        _isUnlocked = isUnlocked ?? (() async => true),
        _getLocale = getLocale ?? (() => PlatformDispatcher.instance.locale);

  final AppDatabase _db;
  final SyncStore _store;
  final SnapshotApplier _applier;
  final WebdavConfigStore _configStore;
  final KeyValueStore _secureStore;
  final SyncEnqueuer syncEnqueuer;
  final SyncProviderFactory _providerFactory;
  final VaultCrypto _crypto;
  final RetryPolicy _retryPolicy;
  final Duration _debounceDelay;
  final Future<bool> Function() _isUnlocked;
  final Locale Function() _getLocale;

  final _overviewCtrl = StreamController<SyncOverview>.broadcast();
  final _conflictsCtrl = StreamController<List<ConflictInfo>>.broadcast();

  _Session? _session;
  bool _stateEnabled = false;
  bool _authPaused = false;
  bool _syncing = false;
  Future<void>? _inFlight;
  DateTime? _notBefore;
  SyncError? _lastError;
  Timer? _debounce;
  Future<void>? _initFuture;
  bool _disposed = false;
  String? _pendingRecoveryKey;

  bool _lastCreateJoinedExisting = false;

  @override
  bool get lastCreateJoinedExisting => _lastCreateJoinedExisting;

  static const String _keys2Key = 'suicun.sync.keys2';
  static String _kvault2Key(String keyId) => 'suicun.sync.kvault2.$keyId';

  static Future<String> _vaultIdForDirectory(String directory) async {
    final hash = await crypto.Sha256().hash(utf8.encode(directory));
    final hexStr = hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'v2:${hexStr.substring(0, 16)}';
  }

  bool get _isEnglish =>
      _getLocale().languageCode.toLowerCase().startsWith('en');

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Restores a previously joined vault from the DB + secure storage.
  /// Never throws.
  Future<void> ensureInitialized() => _initFuture ??= _init();

  Future<void> _init() async {
    try {
      final state = await _store.getState();
      if (state != null) {
        _stateEnabled = state.enabled;
        final name = state.lastError;
        if (name != null) {
          for (final c in SyncErrorCode.values) {
            if (c.name == name) _lastError = SyncError(c);
          }
        }
        if (state.enabled) await _restoreSession(state);
      }
    } catch (_) {
      // Initialization must never throw; sync simply stays inactive.
    }
    _emitOverview();
    _emitConflicts();
  }

  /// Rebuilds [_session] from stored config + keys2 secure storage. Returns false
  /// when the credentials are missing.
  Future<bool> _restoreSession([SyncStateData? known]) async {
    final state = known ?? await _store.getState();
    if (state == null) return false;
    final config = await _configStore.loadConfig();
    if (config == null) return false;

    final keys2Json = await _secureStore.read(_keys2Key);
    if (keys2Json == null) return false;

    final List<dynamic> keyEntries;
    try {
      keyEntries = jsonDecode(keys2Json) as List<dynamic>;
    } catch (_) {
      return false;
    }

    final keys = <String, Uint8List>{};
    final legacyKeys = <String, Uint8List>{};

    for (final entry in keyEntries) {
      if (entry is! Map<String, dynamic>) continue;
      final keyId = entry['key_id'] as String?;
      if (keyId == null) continue;
      final legacyVaultId = entry['legacy_vault_id'] as String?;
      final kBase64 = await _secureStore.read(_kvault2Key(keyId));
      if (kBase64 == null) continue;
      final kBytes = Uint8List.fromList(base64Decode(kBase64));
      keys[keyId] = kBytes;
      if (legacyVaultId != null) {
        legacyKeys[legacyVaultId] = kBytes;
      }
    }

    if (keys.isEmpty) return false;

    final multiSession = MultiKeySession(
      keys: keys,
      legacyKeys: legacyKeys,
    );

    _session?.provider.close();
    _session = _Session(
      config: config,
      provider: _providerFactory(config),
      vault: multiSession,
      deviceId: state.deviceId,
    );
    SyncSessionHolder.current = multiSession;
    return true;
  }

  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _session?.provider.close();
    _session = null;
    SyncSessionHolder.current = null;
    _overviewCtrl.close();
    _conflictsCtrl.close();
  }

  // ── Streams ───────────────────────────────────────────────────────────────

  /// Emits the current overview first, then every change.
  Stream<SyncOverview> get overviewStream async* {
    yield await getOverview();
    yield* _overviewCtrl.stream;
  }

  /// Emits the current conflict list first, then every change.
  Stream<List<ConflictInfo>> get conflictsStream async* {
    yield await _buildConflictInfos();
    yield* _conflictsCtrl.stream;
  }

  Future<SyncOverview> getOverview() async {
    final state = await _store.getState();
    final counts = await _recordSyncCounts();
    return SyncOverview(
      enabled: _session != null && _stateEnabled,
      syncing: _syncing,
      lastSuccessAt: state?.lastSuccessAt,
      pendingCount: await _store.pendingOutboxCount(),
      conflictCount: await _store.openConflictCount(),
      lockedKeyCount: _session?.lockedKeyIds.length ?? 0,
      keyCount: _session?.allKeyIds.length ?? _session?.vault.keys.length ?? 0,
      totalRecords: counts.total,
      syncedRecords: counts.synced,
      vaultId: state?.vaultId,
      lastError: _lastError?.message(english: _isEnglish),
    );
  }

  /// Live local records vs. those whose head revisions all have a remote
  /// receipt (receipts are written only after a verified upload/download).
  Future<({int total, int synced})> _recordSyncCounts() async {
    final rows = await (_db.select(_db.records)
          ..where((r) => r.deletedAt.isNull()))
        .get();
    var synced = 0;
    for (final r in rows) {
      final heads =
          await _store.computeHeads(EntitySnapshots.recordType, r.id);
      if (heads.isEmpty) continue;
      var all = true;
      for (final h in heads) {
        if (!await _store.hasReceipt(h.revisionId)) {
          all = false;
          break;
        }
      }
      if (all) synced++;
    }
    return (total: rows.length, synced: synced);
  }

  void _emitOverview() {
    if (_disposed) return;
    unawaited(() async {
      try {
        final o = await getOverview();
        if (!_disposed && !_overviewCtrl.isClosed) _overviewCtrl.add(o);
      } catch (_) {}
    }());
  }

  void _emitConflicts() {
    if (_disposed) return;
    unawaited(() async {
      try {
        final c = await _buildConflictInfos();
        if (!_disposed && !_conflictsCtrl.isClosed) _conflictsCtrl.add(c);
      } catch (_) {}
    }());
  }

  // ── Triggers ──────────────────────────────────────────────────────────────

  bool get _rateLimitedNow =>
      _notBefore != null && DateTime.now().isBefore(_notBefore!);

  bool _canAutoSync() =>
      _session != null && _stateEnabled && !_authPaused && !_rateLimitedNow;

  /// Called after local edits: debounced -> [syncNow].
  void notifyLocalChange() {
    if (_disposed || !_canAutoSync()) return;
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () => unawaited(syncNow()));
  }

  /// Called when the app returns to the foreground (no debounce).
  void onForeground() {
    if (_disposed || !_canAutoSync()) return;
    unawaited(syncNow());
  }

  @override
  String? consumePendingRecoveryKey() {
    final k = _pendingRecoveryKey;
    _pendingRecoveryKey = null;
    return k;
  }

  // ── Sync pass ─────────────────────────────────────────────────────────────

  /// Runs one pass. Single-instance: when a pass is already running this
  /// waits for that pass instead of starting a second one.
  @override
  Future<void> syncNow() async {
    await ensureInitialized();
    if (_syncing) {
      await _inFlight;
      return;
    }
    if (_session == null || !_stateEnabled) return;
    if (!await _isUnlocked()) return;
    _authPaused = false; // manual retry clears the credential pause
    _syncing = true;
    _emitOverview();
    final done = Completer<void>();
    _inFlight = done.future;
    try {
      await _syncPass();
      _lastError = null;
      _notBefore = null;
      await _store.setLastError(null);
    } on SyncError catch (e) {
      _lastError = e;
      await _safe(() => _store.setLastError(e.code.name));
      if (e.code == SyncErrorCode.unauthorized ||
          e.code == SyncErrorCode.forbidden) {
        _authPaused = true;
      }
    } catch (e) {
      _lastError = SyncError(SyncErrorCode.unknown, _safeDetail(e));
      await _safe(() => _store.setLastError('unknown'));
    } finally {
      _syncing = false;
      _inFlight = null;
      done.complete();
      _emitOverview();
      _emitConflicts();
    }
  }

  Future<void> _safe(Future<void> Function() fn) async {
    try {
      await fn();
    } catch (_) {}
  }

  static String _safeDetail(Object e) {
    final line = e.toString().split('\n').first;
    return line.length > 200 ? line.substring(0, 200) : line;
  }

  Future<void> _syncPass() async {
    final session = _session!;

    // Step 1: refresh keys. If session has zero unlocked keys -> throw needsPassword.
    await _refreshKeys(session);
    if (session.vault.keys.isEmpty) {
      throw const SyncError(SyncErrorCode.needsPassword);
    }
    session.caps ??= await _guard(session.provider.probe);

    // Steps 2-3: list + download + validate + apply remote revisions.
    await _downloadNew();
    // Steps 4-6: upload outbox, verify.
    await _uploadOutbox();
    // Step 7: pick up anything that arrived meanwhile.
    await _downloadNew();
    await _store.setLastSuccess(DateTime.now().toUtc());
  }

  /// Lists v2/keys; downloads files whose key_id is unknown; unlocks with in-memory credential.
  Future<void> _refreshKeys(_Session session) async {
    List<RemoteObject> remote;
    try {
      remote = await _guard(() => session.provider.list('v2/keys'));
    } on SyncError catch (e) {
      if (e.code == SyncErrorCode.objectNotFound) return;
      rethrow;
    }

    final keyFiles = remote.where((o) => !o.isDirectory && o.path.endsWith('.json')).toList();
    final allKnownIds = <String>{};
    var keysChanged = false;

    for (final kFile in keyFiles) {
      final base = kFile.path.split('/').last; // <key_id>.<variant>.json
      final dotParts = base.split('.');
      if (dotParts.isEmpty) continue;
      final keyId = dotParts[0];
      allKnownIds.add(keyId);

      if (session.vault.keys.containsKey(keyId)) continue;

      // Unknown key: download and parse
      final DownloadedObject dl;
      try {
        dl = await session.provider.get(kFile.path);
      } on SyncProviderException catch (e) {
        if (e.kind == ProviderErrorKind.notFound) continue;
        throw _mapProviderError(e);
      }

      final VaultKeyObject keyObj;
      try {
        keyObj = VaultKeyObject.parse(utf8.decode(dl.bytes));
      } catch (_) {
        // Skip malformed key files
        continue;
      }

      if (keyObj.protocolVersion > kVaultProtocolVersionV2) {
        throw const SyncError(SyncErrorCode.unsupportedProtocol);
      }

      final cred = session.credential;
      if (cred != null) {
        UnlockedKey? unlocked;
        try {
          unlocked = await _crypto.openKeyObjectWithPassword(dl.bytes is String ? dl.bytes as String : utf8.decode(dl.bytes), cred);
        } catch (_) {}
        if (unlocked == null) {
          try {
            unlocked = await _crypto.openKeyObjectWithRecoveryKey(utf8.decode(dl.bytes), cred);
          } catch (_) {}
        }
        if (unlocked != null) {
          session.vault.keys[unlocked.keyId] = unlocked.kvault;
          if (unlocked.legacyVaultId != null) {
            session.vault.legacyKeys[unlocked.legacyVaultId!] = unlocked.kvault;
          }
          await _secureStore.write(_kvault2Key(unlocked.keyId), base64Encode(unlocked.kvault));
          session.lockedKeyIds.remove(unlocked.keyId);
          keysChanged = true;
          continue;
        }
      }
      if (!session.lockedKeyIds.contains(keyObj.keyId)) {
        session.lockedKeyIds.add(keyObj.keyId);
      }
    }

    session.allKeyIds = allKnownIds.toList();

    if (keysChanged) {
      session.vault.activeKeyId = MultiKeySession.pickActiveKeyId(session.vault.keys.keys);
      await _persistKeysIndex(session.vault);
    }
  }

  Future<void> _persistKeysIndex(MultiKeySession vault) async {
    final list = <Map<String, String>>[];
    for (final e in vault.keys.entries) {
      final item = <String, String>{'key_id': e.key};
      for (final legacy in vault.legacyKeys.entries) {
        if (identical(legacy.value, e.value) || _bytesEqual(legacy.value, e.value)) {
          item['legacy_vault_id'] = legacy.key;
          break;
        }
      }
      list.add(item);
    }
    await _secureStore.write(_keys2Key, jsonEncode(list));
  }

  SyncError _mapProviderError(SyncProviderException e) {
    final status = e.statusCode == null ? '' : 'status ${e.statusCode}';
    switch (e.kind) {
      case ProviderErrorKind.unauthorized:
        return SyncError(SyncErrorCode.unauthorized, status);
      case ProviderErrorKind.forbidden:
        return SyncError(SyncErrorCode.forbidden, status);
      case ProviderErrorKind.notFound:
        return SyncError(SyncErrorCode.objectNotFound, status);
      case ProviderErrorKind.preconditionFailed:
        return SyncError(SyncErrorCode.preconditionFailed, status);
      case ProviderErrorKind.rateLimited:
        _notBefore = DateTime.now()
            .add(e.retryAfter ?? _retryPolicy.delayForAttempt(1));
        return SyncError(SyncErrorCode.rateLimited, status);
      case ProviderErrorKind.insufficientStorage:
        return SyncError(SyncErrorCode.insufficientStorage, status);
      case ProviderErrorKind.serverError:
        return SyncError(SyncErrorCode.serverError, status);
      case ProviderErrorKind.network:
        return const SyncError(SyncErrorCode.networkUnavailable);
      case ProviderErrorKind.timeout:
        return const SyncError(SyncErrorCode.timeout);
      case ProviderErrorKind.protocolError:
        return SyncError(SyncErrorCode.malformedObject, status);
      case ProviderErrorKind.payloadTooLarge:
        return const SyncError(SyncErrorCode.payloadTooLarge);
      case ProviderErrorKind.redirectBlocked:
        return const SyncError(SyncErrorCode.redirectBlocked);
      case ProviderErrorKind.notHttps:
        return const SyncError(SyncErrorCode.unknown, 'notHttps');
    }
  }

  SyncError _mapCryptoError(VaultCryptoError e) {
    switch (e.code) {
      case VaultCryptoCode.wrongPasswordOrKey:
        return const SyncError(SyncErrorCode.wrongPasswordOrKey);
      case VaultCryptoCode.tampered:
        return const SyncError(SyncErrorCode.tamperedData);
      case VaultCryptoCode.kdfParamsTooLarge:
        return const SyncError(SyncErrorCode.kdfParamsTooLarge);
      case VaultCryptoCode.unsupportedVersion:
        return const SyncError(SyncErrorCode.unsupportedProtocol);
      case VaultCryptoCode.payloadTooLarge:
        return const SyncError(SyncErrorCode.payloadTooLarge);
      case VaultCryptoCode.malformed:
      case VaultCryptoCode.unsupportedKdf:
        return const SyncError(SyncErrorCode.malformedHeader);
    }
  }

  Future<T> _guard<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on SyncProviderException catch (e) {
      throw _mapProviderError(e);
    }
  }

  Future<WriteResult> _putWithParents(
    _Session session,
    String path,
    Uint8List bytes, {
    String? ifMatch,
    bool createOnly = false,
  }) async {
    try {
      return await session.provider.put(
        path,
        bytes,
        ifMatch: ifMatch,
        createOnly: createOnly,
      );
    } on SyncProviderException catch (e) {
      if (e.kind == ProviderErrorKind.notFound) {
        final lastSlash = path.lastIndexOf('/');
        if (lastSlash != -1) {
          final parentDir = path.substring(0, lastSlash);
          await session.provider.ensureCollection(parentDir);
          return await session.provider.put(
            path,
            bytes,
            ifMatch: ifMatch,
            createOnly: createOnly,
          );
        }
      }
      rethrow;
    }
  }

  /// GET; a 404 yields null, any other failure throws the mapped error.
  Future<DownloadedObject?> _tryGet(_Session session, String path) async {
    try {
      return await session.provider.get(path);
    } on SyncProviderException catch (e) {
      if (e.kind == ProviderErrorKind.notFound) return null;
      throw _mapProviderError(e);
    }
  }

  Future<DownloadedObject> _guardGet(_Session session, String path) async =>
      await _tryGet(session, path) ??
      (throw const SyncError(SyncErrorCode.objectNotFound));

  static String _revIdOf(String path) {
    final base = path.split('/').last;
    return base.endsWith('.enc') ? base.substring(0, base.length - 4) : base;
  }

  /// Runs [fn] over [items] with at most [n] in flight. All started work
  /// finishes before the first error (if any) is rethrown, so nothing keeps
  /// running in the background after the pass ends.
  Future<void> _forEachConcurrent<T>(
    List<T> items,
    int n,
    Future<void> Function(T) fn,
  ) async {
    var next = 0;
    Object? firstError;
    StackTrace? firstStack;
    Future<void> worker() async {
      while (firstError == null && next < items.length) {
        final item = items[next++];
        try {
          await fn(item);
        } catch (e, st) {
          firstError ??= e;
          firstStack ??= st;
        }
      }
    }

    await Future.wait([for (var i = 0; i < n; i++) worker()]);
    if (firstError != null) {
      Error.throwWithStackTrace(firstError!, firstStack!);
    }
  }

  // ── Download ──────────────────────────────────────────────────────────────

  Future<void> _downloadNew() async {
    final session = _session!;
    List<RemoteObject> remote;
    try {
      remote = await _guard(() => session.provider.list('v2/objects'));
    } on SyncError catch (e) {
      // 404 on v2/objects/ means an empty vault, not a masked failure.
      if (e.code == SyncErrorCode.objectNotFound) return;
      rethrow;
    }
    final known = await _store.allRevisionIds();
    final skipped = await _store.allSkippedIds();
    final cands = remote.where((o) {
      if (o.isDirectory || !o.path.endsWith('.enc')) return false;
      final id = _revIdOf(o.path);
      return !known.contains(id) && !skipped.contains(id);
    }).toList();
    if (cands.isEmpty) return;

    final validated = <_ValidatedRevision>[];
    Object? error;
    StackTrace? stack;
    try {
      await _forEachConcurrent(cands, 2, (o) async {
        final v = await _downloadAndValidate(session, o);
        if (v != null) validated.add(v);
      });
    } catch (e, st) {
      error = e;
      stack = st;
    }
    // Keep progress: apply what was validated even if another object failed.
    await _applyInOrder(validated);
    if (error != null) Error.throwWithStackTrace(error, stack!);
  }

  /// Downloads and fully validates one remote object. Returns null when the
  /// object is skipped (permanently or because it vanished). Throws
  /// [SyncError] for transient failures and unsupported protocol versions.
  Future<_ValidatedRevision?> _downloadAndValidate(
    _Session session,
    RemoteObject o,
  ) async {
    final revId = _revIdOf(o.path);
    final size = o.size;
    if (size != null && size > kMaxObjectBytes) {
      await _store.markSkipped(revId, 'oversize');
      return null;
    }
    final DownloadedObject dl;
    try {
      dl = await session.provider.get(o.path);
    } on SyncProviderException catch (e) {
      if (e.kind == ProviderErrorKind.notFound) return null;
      if (e.kind == ProviderErrorKind.payloadTooLarge) {
        await _store.markSkipped(revId, 'oversize');
        return null;
      }
      throw _mapProviderError(e);
    }
    final RevisionEnvelope envelope;
    try {
      envelope = _crypto.parseEnvelope(dl.bytes);
    } on VaultCryptoError catch (e) {
      if (e.code == VaultCryptoCode.unsupportedVersion) {
        // Halts the whole pass; the object is NOT skipped permanently.
        throw const SyncError(SyncErrorCode.unsupportedProtocol);
      }
      await _store.markSkipped(revId, 'envelope:${e.code.name}');
      return null;
    }
    if (envelope.revisionId != revId) {
      await _store.markSkipped(revId, 'name-mismatch');
      return null;
    }

    final Map<String, Object?> payload;
    if (envelope.protocolVersion == kVaultProtocolVersionV2) {
      var keyId = envelope.keyId!;
      if (!session.vault.keys.containsKey(keyId)) {
        await _refreshKeys(session);
      }
      if (!session.vault.keys.containsKey(keyId)) {
        if (session.lockedKeyIds.contains(keyId)) {
          await _store.markSkipped(revId, 'locked-key');
        } else {
          await _store.markSkipped(revId, 'unknown-key');
        }
        return null;
      }
      try {
        payload = await _crypto.decryptRevisionV2(
          kvault: session.vault.keys[keyId]!,
          objectBytes: dl.bytes,
        );
      } on VaultCryptoError catch (e) {
        // NEVER store undecryptable payloads.
        await _store.markSkipped(revId, 'decrypt:${e.code.name}');
        return null;
      }
    } else {
      // Version 1 (migrated legacy object, no key_id)
      Map<String, Object?>? decrypted;
      for (final entry in session.vault.legacyKeys.entries) {
        try {
          decrypted = await _crypto.decryptLegacyRevision(
            kvault: entry.value,
            legacyVaultId: entry.key,
            objectBytes: dl.bytes,
          );
          break;
        } catch (_) {}
      }
      if (decrypted == null) {
        await _store.markSkipped(revId, 'decrypt:legacy-failed');
        return null;
      }
      payload = decrypted;
    }

    final ParsedRevision parsed;
    try {
      parsed = EntitySnapshots.parse(payload);
    } on SnapshotFormatError {
      await _store.markSkipped(revId, 'bad-payload');
      return null;
    }
    return _ValidatedRevision(
      path: o.path,
      etag: dl.etag,
      bytes: dl.bytes,
      envelope: envelope,
      parsed: parsed,
    );
  }

  static int _typeRank(String t) => switch (t) {
        EntitySnapshots.tagType => 0,
        EntitySnapshots.categoryType => 1,
        _ => 2,
      };

  /// Applies validated revisions parents-first (tags, categories, records;
  /// then by creation time).
  Future<List<ParsedRevision>> _applyInOrder(
      List<_ValidatedRevision> validated) async {
    final pending = List.of(validated)
      ..sort((a, b) {
        final t = _typeRank(a.parsed.entityType)
            .compareTo(_typeRank(b.parsed.entityType));
        if (t != 0) return t;
        final c = a.parsed.createdAt.compareTo(b.parsed.createdAt);
        return c != 0 ? c : a.parsed.revisionId.compareTo(b.parsed.revisionId);
      });
    final appliedIds = <String>{};
    final applied = <ParsedRevision>[];
    var progress = true;
    while (progress && pending.isNotEmpty) {
      progress = false;
      for (final v in List.of(pending)) {
        var ready = true;
        for (final p in v.parsed.parents) {
          if (!appliedIds.contains(p) && !await _store.hasRevision(p)) {
            ready = false;
            break;
          }
        }
        if (!ready) continue;
        await _applyOne(v);
        appliedIds.add(v.parsed.revisionId);
        applied.add(v.parsed);
        pending.remove(v);
        progress = true;
      }
    }
    return applied;
  }

  Future<void> _applyOne(_ValidatedRevision v) async {
    final p = v.parsed;
    await _db.transaction(() async {
      final now = DateTime.now().toUtc();
      await _store.insertRevision(RevisionsCompanion.insert(
        revisionId: p.revisionId,
        entityType: p.entityType,
        entityId: p.entityId,
        parentsJson: Value(jsonEncode(p.parents)),
        // The ORIGINAL object bytes, so re-upload / verification is exact.
        payloadJson: utf8.decode(v.bytes),
        createdAt: p.createdAt,
        receivedAt: now,
      ));
      final heads = await _store.computeHeads(p.entityType, p.entityId);
      if (heads.length == 1) {
        // Apply only when this revision IS the head: a late-arriving ancestor
        // must not roll the entity back.
        if (heads.first.revisionId == p.revisionId) {
          await _applier.apply(p);
        }
        final open = await _store.openConflictFor(p.entityId);
        if (open != null) {
          await _store.markConflictResolved(open.id, heads.first.revisionId);
        }
      } else if (heads.length > 1) {
        await _store.upsertOpenConflict(
          entityId: p.entityId,
          entityType: p.entityType,
          headRevisionIds: heads.map((h) => h.revisionId).toList(),
        );
      }
      await _store.putReceipt(p.revisionId, v.path, v.etag);
    });
  }

  // ── Upload ────────────────────────────────────────────────────────────────

  Future<void> _uploadOutbox() async {
    final session = _session!;
    final pending = await _store.pendingOutbox(limit: 100);
    await _forEachConcurrent(pending, 2, (e) => _uploadOne(session, e));
  }

  bool _bytesEqual(Uint8List a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _uploadOne(_Session session, OutboxData entry) async {
    final rev = await _store.getRevision(entry.revisionId);
    if (rev == null) {
      await _store.markOutboxDone(entry.operationId);
      return;
    }
    final bytes = Uint8List.fromList(utf8.encode(rev.payloadJson));
    final path = 'v2/objects/${rev.revisionId}.enc';
    await _store.markOutboxUploading(entry.operationId);
    try {
      if (entry.attemptCount > 0) {
        // The previous attempt may have succeeded (e.g. timeout after the
        // server stored it): check the server state before re-uploading.
        final existing = await _tryGet(session, path);
        if (existing != null && _bytesEqual(existing.bytes, bytes)) {
          await _confirmUploaded(entry, rev.revisionId, path, existing.etag);
          return;
        }
      }
      if (session.caps?.supportsConditionalCreate == true) {
        try {
          await _guard(
              () => _putWithParents(session, path, bytes, createOnly: true));
        } on SyncError catch (e) {
          if (e.code == SyncErrorCode.preconditionFailed) {
            final existing = await _guardGet(session, path);
            if (_bytesEqual(existing.bytes, bytes)) {
              await _confirmUploaded(
                  entry, rev.revisionId, path, existing.etag);
              return;
            }
            throw const SyncError(SyncErrorCode.contentConflict);
          }
          rethrow;
        }
      } else {
        await _putWithoutConditions(session, entry, rev.revisionId, path, bytes);
        return;
      }
      // Step 6: confirm the object is complete and matches before "done".
      final verify = await _guardGet(session, path);
      if (!_bytesEqual(verify.bytes, bytes)) {
        throw const SyncError(SyncErrorCode.verifyFailed);
      }
      await _confirmUploaded(entry, rev.revisionId, path, verify.etag);
    } on SyncError catch (e) {
      if (e.code == SyncErrorCode.contentConflict) rethrow;
      if (e.code == SyncErrorCode.unauthorized ||
          e.code == SyncErrorCode.forbidden ||
          e.code == SyncErrorCode.insufficientStorage) {
        rethrow;
      }
      await _markRetry(entry, e.code);
      if (e.code == SyncErrorCode.networkUnavailable ||
          e.code == SyncErrorCode.timeout ||
          e.code == SyncErrorCode.rateLimited) {
        rethrow;
      }
    }
  }

  /// Spec §11.3 step 5 fallback for servers without conditional writes:
  /// check-then-put, then verify by reading back.
  Future<void> _putWithoutConditions(
    _Session session,
    OutboxData entry,
    String revisionId,
    String path,
    Uint8List bytes,
  ) async {
    final existing = await _tryGet(session, path);
    if (existing != null) {
      if (_bytesEqual(existing.bytes, bytes)) {
        await _confirmUploaded(entry, revisionId, path, existing.etag);
        return;
      }
      throw const SyncError(SyncErrorCode.contentConflict);
    }
    await _guard(() => _putWithParents(session, path, bytes));
    final verify = await _guardGet(session, path);
    if (!_bytesEqual(verify.bytes, bytes)) {
      throw const SyncError(SyncErrorCode.verifyFailed);
    }
    await _confirmUploaded(entry, revisionId, path, verify.etag);
  }

  Future<void> _confirmUploaded(
    OutboxData entry,
    String revisionId,
    String path,
    String? etag,
  ) =>
      _db.transaction(() async {
        await _store.markOutboxDone(entry.operationId);
        await _store.putReceipt(revisionId, path, etag);
      });

  Future<void> _markRetry(OutboxData entry, SyncErrorCode code) {
    final attempt = entry.attemptCount + 1;
    return _store.markOutboxFailed(
      entry.operationId,
      code.name,
      DateTime.now().toUtc().add(_retryPolicy.delayForAttempt(attempt)),
      attempt,
    );
  }

  // ── SyncActions ───────────────────────────────────────────────────────────

  @override
  Future<void> setEnabled(bool enabled) async {
    if (!enabled) return disableSync();
    await ensureInitialized();
    if (_session == null && !await _restoreSession()) {
      throw const SyncError(SyncErrorCode.notJoined);
    }
    await _store.setEnabled(true);
    _stateEnabled = true;
    _authPaused = false;
    _emitOverview();
    await syncNow();
  }

  /// Stops network tasks and (optionally) forgets credentials. NEVER touches
  /// the user data tables.
  @override
  Future<void> disableSync({bool removeCredentials = false}) async {
    _debounce?.cancel();
    _stateEnabled = false;
    final state = await _store.getState();
    if (state != null) await _store.setEnabled(false);
    _session?.provider.close();
    _session = null;
    SyncSessionHolder.current = null;
    if (removeCredentials) {
      final keys2Json = await _secureStore.read(_keys2Key);
      if (keys2Json != null) {
        try {
          final entries = jsonDecode(keys2Json) as List;
          for (final e in entries) {
            if (e is Map && e['key_id'] is String) {
              await _secureStore.delete(_kvault2Key(e['key_id'] as String));
            }
          }
        } catch (_) {}
      }
      await _secureStore.delete(_keys2Key);
      if (state != null) {
        await _secureStore.delete('suicun.sync.kvault.${state.vaultId}');
      }
      await _configStore.clearConfig();
    }
    _authPaused = false;
    _emitOverview();
  }

  @override
  Future<RemoteVaultCheck> checkRemoteVault(WebdavConfig config) async {
    final provider = _providerFactory(config);
    try {
      List<RemoteObject> keyObjs = const [];
      try {
        keyObjs = await provider.list('v2/keys');
      } on SyncProviderException catch (e) {
        if (e.kind != ProviderErrorKind.notFound) {
          throw _mapProviderError(e);
        }
      }
      final hasV2 = keyObjs.any((o) => !o.isDirectory && o.path.endsWith('.json'));
      if (hasV2) return RemoteVaultCheck.hasVault;

      try {
        final obj = await provider.get('header.json');
        try {
          VaultHeader.parse(utf8.decode(obj.bytes));
          return RemoteVaultCheck.hasV1Vault;
        } catch (_) {
          return RemoteVaultCheck.noVault;
        }
      } on SyncProviderException catch (e) {
        if (e.kind == ProviderErrorKind.notFound) {
          return RemoteVaultCheck.noVault;
        }
        throw _mapProviderError(e);
      }
    } finally {
      provider.close();
    }
  }

  @override
  Future<void> createVault(WebdavConfig config, String password) async {
    if (password.isEmpty) {
      throw ArgumentError('password must not be empty');
    }
    final provider = _providerFactory(config);
    var ok = false;
    try {
      _lastCreateJoinedExisting = false;
      List<RemoteObject> existingKeyFiles = const [];
      try {
        existingKeyFiles = await provider.list('v2/keys');
      } on SyncProviderException catch (e) {
        if (e.kind != ProviderErrorKind.notFound) {
          throw _mapProviderError(e);
        }
      }

      final validKeyObjs = <RemoteObject>[];
      for (final f in existingKeyFiles) {
        if (f.isDirectory || !f.path.endsWith('.json')) continue;
        try {
          final dl = await provider.get(f.path);
          final obj = VaultKeyObject.parse(utf8.decode(dl.bytes));
          if (obj.protocolVersion > kVaultProtocolVersionV2) {
            throw const SyncError(SyncErrorCode.unsupportedProtocol);
          }
          validKeyObjs.add(f);
        } on SyncError {
          rethrow;
        } catch (_) {
          // Skip malformed key files
          continue;
        }
      }

      if (validKeyObjs.isNotEmpty) {
        provider.close();
        _lastCreateJoinedExisting = true;
        return await joinVault(config, password: password);
      }

      await provider.ensureCollection('v2/keys');
      await provider.ensureCollection('v2/objects');

      final created = await _crypto.createKeyObject(password: password);
      final keyPath = 'v2/keys/${created.keyId}.${created.variant}.json';
      await provider.put(keyPath, Uint8List.fromList(utf8.encode(created.keyJson)));

      Capabilities? caps;
      try {
        caps = await provider.probe();
      } catch (_) {}

      final session = MultiKeySession(
        keys: {created.keyId: created.kvault},
      );
      await _finishJoinV2(config, provider, session, caps, password);
      // A freshly created vault starts empty on the server: publish what this
      // device already has. (joinVault deliberately does NOT do this.)
      await backfillLocalEntities();
      _pendingRecoveryKey = created.recoveryKey;
      ok = true;
    } finally {
      if (!ok) provider.close();
    }
  }

  /// Enqueues snapshots of all live local categories, tags and records that
  /// have no revisions yet. Idempotent. Requires an active vault session.
  /// Entities in the trash stay local-only. Returns the number enqueued.
  Future<int> backfillLocalEntities() async {
    var enqueued = 0;
    await _db.transaction(() async {
      Future<bool> fresh(String type, String id) async =>
          (await _store.computeHeads(type, id)).isEmpty;

      // Categories and tags first so records reference known entities.
      final cats = await (_db.select(_db.categories)
            ..where((c) => c.deletedAt.isNull()))
          .get();
      for (final c in cats) {
        if (!await fresh(EntitySnapshots.categoryType, c.id)) continue;
        await syncEnqueuer.enqueueCategorySnapshot(
            id: c.id, name: c.name, color: c.color);
        enqueued++;
      }
      final tags = await (_db.select(_db.tags)
            ..where((t) => t.deletedAt.isNull()))
          .get();
      for (final t in tags) {
        if (!await fresh(EntitySnapshots.tagType, t.id)) continue;
        await syncEnqueuer.enqueueTagSnapshot(id: t.id, name: t.name);
        enqueued++;
      }
      final records = await (_db.select(_db.records)
            ..where((r) => r.deletedAt.isNull()))
          .get();
      for (final r in records) {
        if (!await fresh(EntitySnapshots.recordType, r.id)) continue;
        final links = await (_db.select(_db.recordTags)
              ..where((rt) => rt.recordId.equals(r.id)))
            .get();
        await syncEnqueuer.enqueueRecordSnapshot(
          recordId: r.id,
          title: r.title,
          body: r.body,
          categoryId: r.categoryId,
          tagIds: links.map((l) => l.tagId).toList(),
          isFavorite: r.isFavorite,
          createdAt: r.createdAt,
          updatedAt: r.updatedAt,
        );
        enqueued++;
      }
    });
    return enqueued;
  }

  @override
  Future<void> joinVault(
    WebdavConfig config, {
    String? password,
    String? recoveryKey,
  }) async {
    final hasPassword = password != null && password.isNotEmpty;
    final hasKey = recoveryKey != null && recoveryKey.isNotEmpty;
    if (!hasPassword && !hasKey) {
      throw ArgumentError('password or recoveryKey is required');
    }
    final credential = hasPassword ? password : recoveryKey!;
    final provider = _providerFactory(config);
    var ok = false;
    try {
      List<RemoteObject> existingKeyFiles = const [];
      try {
        existingKeyFiles = await provider.list('v2/keys');
      } on SyncProviderException catch (e) {
        if (e.kind != ProviderErrorKind.notFound) {
          throw _mapProviderError(e);
        }
      }

      final keyFiles = existingKeyFiles.where((f) => !f.isDirectory && f.path.endsWith('.json')).toList();
      if (keyFiles.isEmpty) {
        // Check header.json
        try {
          final headerObj = await provider.get('header.json');
          VaultHeader.parse(utf8.decode(headerObj.bytes));
          throw const SyncError(SyncErrorCode.needsMigration);
        } on SyncProviderException catch (e) {
          if (e.kind == ProviderErrorKind.notFound) {
            throw const SyncError(SyncErrorCode.vaultNotFound);
          }
          throw _mapProviderError(e);
        } on SyncError {
          rethrow;
        } catch (_) {
          throw const SyncError(SyncErrorCode.vaultNotFound);
        }
      }

      final unlockedKeys = <String, Uint8List>{};
      final legacyKeys = <String, Uint8List>{};
      final lockedKeys = <String>[];
      final allKeys = <String>[];

      for (final kf in keyFiles) {
        final dl = await provider.get(kf.path);
        final VaultKeyObject parsed;
        try {
          parsed = VaultKeyObject.parse(utf8.decode(dl.bytes));
        } catch (_) {
          continue;
        }
        if (parsed.protocolVersion > kVaultProtocolVersionV2) {
          throw const SyncError(SyncErrorCode.unsupportedProtocol);
        }
        allKeys.add(parsed.keyId);

        UnlockedKey? uk;
        if (hasPassword) {
          try {
            uk = await _crypto.openKeyObjectWithPassword(utf8.decode(dl.bytes), password);
          } catch (_) {}
        } else {
          try {
            uk = await _crypto.openKeyObjectWithRecoveryKey(utf8.decode(dl.bytes), recoveryKey!);
          } catch (_) {}
        }

        if (uk != null) {
          unlockedKeys[uk.keyId] = uk.kvault;
          if (uk.legacyVaultId != null) {
            legacyKeys[uk.legacyVaultId!] = uk.kvault;
          }
        } else {
          lockedKeys.add(parsed.keyId);
        }
      }

      if (unlockedKeys.isEmpty) {
        throw const SyncError(SyncErrorCode.wrongPasswordOrKey);
      }

      Capabilities? caps;
      try {
        caps = await provider.probe();
      } catch (_) {}

      final session = MultiKeySession(
        keys: unlockedKeys,
        legacyKeys: legacyKeys,
      );
      await _finishJoinV2(config, provider, session, caps, credential, lockedKeys: lockedKeys, allKeys: allKeys);
      ok = true;
    } finally {
      if (!ok) provider.close();
    }
  }

  Future<void> _finishJoinV2(
    WebdavConfig config,
    SyncProvider provider,
    MultiKeySession session,
    Capabilities? caps,
    String? credential, {
    List<String>? lockedKeys,
    List<String>? allKeys,
  }) async {
    final v2VaultId = await _vaultIdForDirectory(config.directory);
    final existing = await _store.getState();
    final deviceId = (existing != null && existing.vaultId == v2VaultId)
        ? existing.deviceId
        : _uuid.v4();

    await _db.transaction(() => _store.saveState(
          vaultId: v2VaultId,
          deviceId: deviceId,
          protocolVersion: 2,
          enabled: true,
        ));
    await _configStore.saveConfig(config);

    // Save kvault2 and keys2
    for (final e in session.keys.entries) {
      await _secureStore.write(_kvault2Key(e.key), base64Encode(e.value));
    }
    await _persistKeysIndex(session);

    final old = _session;
    if (old != null && !identical(old.provider, provider)) {
      old.provider.close();
    }
    SyncSessionHolder.current = session;
    _session = _Session(
      config: config,
      provider: provider,
      vault: session,
      deviceId: deviceId,
      caps: caps,
      credential: credential,
      lockedKeyIds: lockedKeys,
      allKeyIds: allKeys ?? session.keys.keys.toList(),
    );
    _initFuture ??= Future.value();
    _stateEnabled = true;
    _authPaused = false;
    _lastError = null;
    _emitOverview();
  }

  @override
  Future<MigrationReport> migrateV1ToV2(WebdavConfig config, String password) async {
    if (password.isEmpty) {
      throw ArgumentError('password must not be empty');
    }
    final provider = _providerFactory(config);
    try {
      final DownloadedObject headerObj;
      try {
        headerObj = await provider.get('header.json');
      } on SyncProviderException catch (e) {
        if (e.kind == ProviderErrorKind.notFound) {
          throw const SyncError(SyncErrorCode.vaultNotFound);
        }
        throw _mapProviderError(e);
      }

      final VaultHeader v1Header;
      try {
        v1Header = VaultHeader.parse(utf8.decode(headerObj.bytes));
      } catch (_) {
        throw const SyncError(SyncErrorCode.malformedHeader);
      }

      final VaultSession v1Session;
      try {
        v1Session = await _crypto.openWithPassword(utf8.decode(headerObj.bytes), password);
      } on VaultCryptoError catch (e) {
        throw _mapCryptoError(e);
      }

      // Build v2 key object: origin v1-migrated, NEW random key_id/variant, SAME K_vault
      final v2KeyObj = await _crypto.buildMigratedKeyObject(
        v1Header: v1Header,
        kvault: v1Session.kvault,
        password: password,
      );
      final keyId = v2KeyObj.keyId;
      final variant = v2KeyObj.variant;

      await provider.put('v2/keys/$keyId.$variant.json', Uint8List.fromList(utf8.encode(v2KeyObj.toJsonString())));

      // Copy objects/ -> v2/objects/
      List<RemoteObject> v1Objects = const [];
      try {
        v1Objects = await provider.list('objects');
      } on SyncProviderException catch (e) {
        if (e.kind != ProviderErrorKind.notFound) {
          throw _mapProviderError(e);
        }
      }

      var copied = 0;
      var skipped = 0;
      for (final obj in v1Objects) {
        if (obj.isDirectory || !obj.path.endsWith('.enc')) continue;
        final filename = obj.path.split('/').last;
        final dl = await provider.get(obj.path);
        final destPath = 'v2/objects/$filename';
        final existing = await _tryGetSessionProvider(provider, destPath);
        if (existing != null && _bytesEqual(existing.bytes, dl.bytes)) {
          skipped++;
        } else {
          await provider.put(destPath, dl.bytes);
          copied++;
        }
      }

      // LAST step only: rename header.json -> header.json.migrated-backup
      await provider.move('header.json', 'header.json.migrated-backup');

      // On success, join the new v2 vault
      Capabilities? caps;
      try {
        caps = await provider.probe();
      } catch (_) {}

      final session = MultiKeySession(
        keys: {keyId: v1Session.kvault},
        legacyKeys: {v1Header.vaultId: v1Session.kvault},
      );
      await _finishJoinV2(config, provider, session, caps, password);

      return MigrationReport(
        keyId: keyId,
        copiedObjects: copied,
        skippedObjects: skipped,
      );
    } catch (_) {
      provider.close();
      rethrow;
    }
  }

  Future<DownloadedObject?> _tryGetSessionProvider(SyncProvider provider, String path) async {
    try {
      return await provider.get(path);
    } on SyncProviderException catch (e) {
      if (e.kind == ProviderErrorKind.notFound) return null;
      throw _mapProviderError(e);
    }
  }

  @override
  Future<int> unlockKeys({String? password, String? recoveryKey}) async {
    final session = _session;
    if (session == null) return 0;
    final hasPassword = password != null && password.isNotEmpty;
    final hasKey = recoveryKey != null && recoveryKey.isNotEmpty;
    if (!hasPassword && !hasKey) return 0;

    final cred = hasPassword ? password : recoveryKey!;
    session.credential ??= cred;

    var newlyUnlocked = 0;
    final toRemove = <String>[];

    List<RemoteObject> keyObjs = const [];
    try {
      keyObjs = await session.provider.list('v2/keys');
    } catch (_) {}

    for (final keyId in List<String>.from(session.lockedKeyIds)) {
      final matchingFile = keyObjs.firstWhere(
        (o) => o.path.startsWith('v2/keys/$keyId.'),
        orElse: () => RemoteObject(path: ''),
      );
      if (matchingFile.path.isEmpty) continue;

      final DownloadedObject dl;
      try {
        dl = await session.provider.get(matchingFile.path);
      } catch (_) {
        continue;
      }

      UnlockedKey? uk;
      if (hasPassword) {
        try {
          uk = await _crypto.openKeyObjectWithPassword(utf8.decode(dl.bytes), password);
        } catch (_) {}
      } else {
        try {
          uk = await _crypto.openKeyObjectWithRecoveryKey(utf8.decode(dl.bytes), recoveryKey!);
        } catch (_) {}
      }

      if (uk != null) {
        session.vault.keys[uk.keyId] = uk.kvault;
        if (uk.legacyVaultId != null) {
          session.vault.legacyKeys[uk.legacyVaultId!] = uk.kvault;
        }
        await _secureStore.write(_kvault2Key(uk.keyId), base64Encode(uk.kvault));
        toRemove.add(keyId);
        newlyUnlocked++;
      }
    }

    session.lockedKeyIds.removeWhere(toRemove.contains);

    if (newlyUnlocked > 0) {
      await _store.unmarkSkippedByReason(['locked-key', 'unknown-key']);
      session.vault.activeKeyId = MultiKeySession.pickActiveKeyId(session.vault.keys.keys);
      await _persistKeysIndex(session.vault);
      _emitOverview();
    }

    return newlyUnlocked;
  }

  /// Recovery on a new device.
  @override
  Stream<RecoveryProgress> recoverFromRemote(
    WebdavConfig config, {
    String? password,
    String? recoveryKey,
  }) {
    final ctrl = StreamController<RecoveryProgress>();
    unawaited(_runRecovery(ctrl, config, password, recoveryKey));
    return ctrl.stream;
  }

  Future<void> _runRecovery(
    StreamController<RecoveryProgress> ctrl,
    WebdavConfig config,
    String? password,
    String? recoveryKey,
  ) async {
    var total = 0;
    var done = 0;
    var failed = 0;
    var restored = 0;
    void emit(String phase, {bool finished = false, String? error}) {
      if (ctrl.isClosed) return;
      ctrl.add(RecoveryProgress(
        phase: phase,
        totalObjects: total,
        doneObjects: done,
        failedObjects: failed,
        recordsRestored: restored,
        done: finished,
        error: error,
      ));
    }

    SyncProvider? provider;
    var handedOver = false;
    try {
      final hasPassword = password != null && password.isNotEmpty;
      final hasKey = recoveryKey != null && recoveryKey.isNotEmpty;
      if (!hasPassword && !hasKey) {
        throw ArgumentError('password or recoveryKey is required');
      }
      final credential = hasPassword ? password : recoveryKey!;
      emit('connecting');
      await ensureInitialized();
      provider = _providerFactory(config);

      List<RemoteObject> existingKeyFiles = const [];
      try {
        existingKeyFiles = await provider.list('v2/keys');
      } on SyncProviderException catch (e) {
        if (e.kind != ProviderErrorKind.notFound) {
          throw _mapProviderError(e);
        }
      }

      final keyFiles = existingKeyFiles.where((f) => !f.isDirectory && f.path.endsWith('.json')).toList();
      if (keyFiles.isEmpty) {
        throw const SyncError(SyncErrorCode.vaultNotFound);
      }

      final unlockedKeys = <String, Uint8List>{};
      final legacyKeys = <String, Uint8List>{};
      final lockedKeys = <String>[];
      final allKeys = <String>[];

      for (final kf in keyFiles) {
        final dl = await provider.get(kf.path);
        final VaultKeyObject parsed;
        try {
          parsed = VaultKeyObject.parse(utf8.decode(dl.bytes));
        } catch (_) {
          continue;
        }
        if (parsed.protocolVersion > kVaultProtocolVersionV2) {
          throw const SyncError(SyncErrorCode.unsupportedProtocol);
        }
        allKeys.add(parsed.keyId);

        UnlockedKey? uk;
        if (hasPassword) {
          try {
            uk = await _crypto.openKeyObjectWithPassword(utf8.decode(dl.bytes), password);
          } catch (_) {}
        } else {
          try {
            uk = await _crypto.openKeyObjectWithRecoveryKey(utf8.decode(dl.bytes), recoveryKey!);
          } catch (_) {}
        }

        if (uk != null) {
          unlockedKeys[uk.keyId] = uk.kvault;
          if (uk.legacyVaultId != null) {
            legacyKeys[uk.legacyVaultId!] = uk.kvault;
          }
        } else {
          lockedKeys.add(parsed.keyId);
        }
      }

      if (unlockedKeys.isEmpty) {
        throw const SyncError(SyncErrorCode.wrongPasswordOrKey);
      }

      final vault = MultiKeySession(keys: unlockedKeys, legacyKeys: legacyKeys);
      Capabilities? caps;
      try {
        caps = await provider.probe();
      } catch (_) {
        caps = null; // best effort
      }
      final temp = _Session(
        config: config,
        provider: provider,
        vault: vault,
        deviceId: _uuid.v4(),
        caps: caps,
        credential: credential,
        lockedKeyIds: lockedKeys,
        allKeyIds: allKeys,
      );

      emit('listing');
      List<RemoteObject> remote;
      try {
        remote = await _guard(() => provider!.list('v2/objects'));
      } on SyncError catch (e) {
        if (e.code != SyncErrorCode.objectNotFound) rethrow;
        remote = const [];
      }
      final known = await _store.allRevisionIds();
      final skipped = await _store.allSkippedIds();
      final ids = <String>[
        for (final o in remote)
          if (!o.isDirectory &&
              o.path.endsWith('.enc') &&
              !known.contains(_revIdOf(o.path)) &&
              !skipped.contains(_revIdOf(o.path)))
            _revIdOf(o.path),
      ];
      total = ids.length;
      emit('listing');

      emit('downloading');
      final validated = <_ValidatedRevision>[];
      SyncError? firstError;
      await _forEachConcurrent(ids, 2, (id) async {
        try {
          if (await _store.hasRevision(id)) {
            done++;
            return;
          }
          final v = await _downloadAndValidate(
            temp,
            RemoteObject(path: 'v2/objects/$id.enc'),
          );
          if (v != null) validated.add(v);
          done++;
        } catch (e) {
          failed++;
          if (e is SyncError) {
            firstError ??= e;
          } else {
            firstError ??= const SyncError(SyncErrorCode.unknown);
          }
        }
        emit('downloading');
      });

      emit('rebuilding');
      final applied = await _applyInOrder(validated);
      restored = {
        for (final p in applied)
          if (p.entityType == EntitySnapshots.recordType && !p.deleted)
            p.entityId,
      }.length;
      emit('rebuilding');

      if (failed > 0) {
        throw firstError ?? const SyncError(SyncErrorCode.unknown);
      }
      await _finishJoinV2(config, provider, vault, caps, credential, lockedKeys: lockedKeys, allKeys: allKeys);
      handedOver = true;
      emit('done', finished: true);
    } on SyncError catch (e) {
      emit('error', finished: true, error: e.message(english: _isEnglish));
    } on ArgumentError {
      emit('error',
          finished: true,
          error: const SyncError(SyncErrorCode.unknown)
              .message(english: _isEnglish));
    } catch (_) {
      emit('error',
          finished: true,
          error: const SyncError(SyncErrorCode.unknown)
              .message(english: _isEnglish));
    } finally {
      if (!handedOver) provider?.close();
      await ctrl.close();
    }
  }

  // ── Conflicts ─────────────────────────────────────────────────────────────

  Revision _pickRemoteHead(List<Revision> heads) {
    final remote = heads.where((h) => !h.isLocal).toList();
    final pool = remote.isEmpty ? heads : remote;
    return pool.reduce((a, b) => b.createdAt.isAfter(a.createdAt) ? b : a);
  }

  Future<ParsedRevision> _decryptHead(Revision head) async {
    final payload = await _decryptStoredPayload(head.payloadJson);
    return EntitySnapshots.parse(payload);
  }

  Future<Map<String, Object?>> _decryptStoredPayload(String payloadJson) async {
    final session = _session!;
    final objectBytes = Uint8List.fromList(utf8.encode(payloadJson));
    final envelope = _crypto.parseEnvelope(objectBytes);

    if (envelope.protocolVersion == kVaultProtocolVersionV2) {
      final keyId = envelope.keyId!;
      final key = session.vault.keys[keyId];
      if (key == null) {
        throw const SyncError(SyncErrorCode.wrongPasswordOrKey);
      }
      return _crypto.decryptRevisionV2(
        kvault: key,
        objectBytes: objectBytes,
      );
    } else {
      // Legacy v1 revision
      for (final entry in session.vault.legacyKeys.entries) {
        try {
          return await _crypto.decryptLegacyRevision(
            kvault: entry.value,
            legacyVaultId: entry.key,
            objectBytes: objectBytes,
          );
        } catch (_) {}
      }
      throw const SyncError(SyncErrorCode.wrongPasswordOrKey);
    }
  }

  Future<({bool deleted, Map<String, Object?> snapshot})> _buildLocalSnapshot(
      String type, String id) async {
    switch (type) {
      case EntitySnapshots.recordType:
        final row = await (_db.select(_db.records)..where((r) => r.id.equals(id)))
            .getSingleOrNull();
        if (row == null || row.deletedAt != null) {
          return (deleted: true, snapshot: EntitySnapshots.tombstone());
        }
        final tags = await (_db.select(_db.recordTags)
              ..where((rt) => rt.recordId.equals(id)))
            .get();
        return (
          deleted: false,
          snapshot: EntitySnapshots.recordSnapshot(
            title: row.title,
            body: row.body,
            categoryId: row.categoryId,
            tagIds: tags.map((t) => t.tagId).toList(),
            isFavorite: row.isFavorite,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt,
          ),
        );
      case EntitySnapshots.categoryType:
        final row = await (_db.select(_db.categories)
              ..where((c) => c.id.equals(id)))
            .getSingleOrNull();
        if (row == null || row.deletedAt != null) {
          return (deleted: true, snapshot: EntitySnapshots.tombstone());
        }
        return (
          deleted: false,
          snapshot:
              EntitySnapshots.categorySnapshot(name: row.name, color: row.color),
        );
      default:
        final row = await (_db.select(_db.tags)..where((t) => t.id.equals(id)))
            .getSingleOrNull();
        if (row == null || row.deletedAt != null) {
          return (deleted: true, snapshot: EntitySnapshots.tombstone());
        }
        return (
          deleted: false,
          snapshot: EntitySnapshots.tagSnapshot(name: row.name),
        );
    }
  }

  Future<Map<String, Object?>> _buildMergedSnapshot(
    String type,
    String id,
    String mergedTitle,
    String mergedBody,
  ) async {
    final base = await _buildLocalSnapshot(type, id);
    switch (type) {
      case EntitySnapshots.recordType:
        final s = base.snapshot;
        final now = DateTime.now().toUtc();
        return EntitySnapshots.recordSnapshot(
          title: mergedTitle,
          body: mergedBody,
          categoryId: s['category_id'] as String?,
          tagIds: ((s['tag_ids'] as List?) ?? const []).cast<String>(),
          isFavorite: (s['is_favorite'] as bool?) ?? false,
          createdAt: s['created_at'] is String
              ? DateTime.parse(s['created_at']! as String)
              : now,
          updatedAt: now,
        );
      case EntitySnapshots.categoryType:
        return EntitySnapshots.categorySnapshot(
          name: mergedTitle,
          color: (base.snapshot['color'] as String?) ?? '#4866D5',
        );
      default:
        return EntitySnapshots.tagSnapshot(name: mergedTitle);
    }
  }

  @override
  Future<void> resolveConflict(
    String conflictId,
    ConflictChoice choice, {
    String? mergedTitle,
    String? mergedBody,
  }) async {
    final conflict = await _store.getConflict(conflictId);
    if (conflict == null) {
      throw const SyncError(SyncErrorCode.unknown, 'conflict not found');
    }
    if (conflict.resolutionRevisionId != null) return;
    if (_session == null) throw const SyncError(SyncErrorCode.notJoined);
    if (choice == ConflictChoice.manualMerge &&
        (mergedTitle == null || mergedBody == null)) {
      throw ArgumentError('mergedTitle and mergedBody are required');
    }
    final type = conflict.entityType;
    final entityId = conflict.entityId;
    final heads = await _store.computeHeads(type, entityId);
    if (heads.length <= 1) {
      await _store.markConflictResolved(
          conflictId, heads.isEmpty ? '' : heads.first.revisionId);
      _emitConflicts();
      _emitOverview();
      return;
    }
    final parentIds = heads.map((h) => h.revisionId).toList();
    final remoteHead = _pickRemoteHead(heads);

    switch (choice) {
      case ConflictChoice.keepBoth:
        final rp = await _decryptHead(remoteHead);
        final newEntityId = _uuid.v4();
        await _db.transaction(() async {
          final newRevId = await syncEnqueuer.enqueueParsed(
            entityType: type,
            entityId: newEntityId,
            parents: const [],
            deleted: rp.deleted,
            snapshot: rp.snapshot,
          );
          await _applier.apply(ParsedRevision(
            revisionId: newRevId,
            entityType: type,
            entityId: newEntityId,
            parents: const [],
            createdAt: DateTime.now().toUtc(),
            deleted: rp.deleted,
            snapshot: rp.snapshot,
          ));
        });
        await _db.transaction(() async {
          final local = await _buildLocalSnapshot(type, entityId);
          final resId = await syncEnqueuer.enqueueParsed(
            entityType: type,
            entityId: entityId,
            parents: parentIds,
            deleted: local.deleted,
            snapshot: local.snapshot,
          );
          await _store.markConflictResolved(conflictId, resId);
        });
      case ConflictChoice.keepLocal:
        await _db.transaction(() async {
          final local = await _buildLocalSnapshot(type, entityId);
          final resId = await syncEnqueuer.enqueueParsed(
            entityType: type,
            entityId: entityId,
            parents: parentIds,
            deleted: local.deleted,
            snapshot: local.snapshot,
          );
          // The local state already is the winner: nothing to apply.
          await _store.markConflictResolved(conflictId, resId);
        });
      case ConflictChoice.keepRemote:
        final rp = await _decryptHead(remoteHead);
        await _db.transaction(() async {
          final resId = await syncEnqueuer.enqueueParsed(
            entityType: type,
            entityId: entityId,
            parents: parentIds,
            deleted: rp.deleted,
            snapshot: rp.snapshot,
          );
          await _applyWinner(type, entityId, resId, parentIds, rp.deleted,
              rp.snapshot);
          await _store.markConflictResolved(conflictId, resId);
        });
      case ConflictChoice.manualMerge:
        final built =
            await _buildMergedSnapshot(type, entityId, mergedTitle!, mergedBody!);
        await _db.transaction(() async {
          final resId = await syncEnqueuer.enqueueParsed(
            entityType: type,
            entityId: entityId,
            parents: parentIds,
            deleted: false,
            snapshot: built,
          );
          await _applyWinner(type, entityId, resId, parentIds, false, built);
          await _store.markConflictResolved(conflictId, resId);
        });
    }
    _emitConflicts();
    _emitOverview();
    notifyLocalChange();
  }

  Future<void> _applyWinner(
    String type,
    String entityId,
    String revisionId,
    List<String> parents,
    bool deleted,
    Map<String, Object?> snapshot,
  ) =>
      _applier.apply(ParsedRevision(
        revisionId: revisionId,
        entityType: type,
        entityId: entityId,
        parents: parents,
        createdAt: DateTime.now().toUtc(),
        deleted: deleted,
        snapshot: snapshot,
      ));

  Future<List<ConflictInfo>> _buildConflictInfos() async {
    if (_session == null) return const [];
    final out = <ConflictInfo>[];
    for (final c in await _store.openConflicts()) {
      final heads = await _store.computeHeads(c.entityType, c.entityId);
      if (heads.length <= 1) continue;
      final local = await _buildLocalSnapshot(c.entityType, c.entityId);
      final remoteHead = _pickRemoteHead(heads);
      final ParsedRevision rp;
      try {
        rp = await _decryptHead(remoteHead);
      } catch (_) {
        continue;
      }
      String titleOf(Map<String, Object?> s) => c.entityType ==
              EntitySnapshots.recordType
          ? (s['title'] as String? ?? '')
          : (s['name'] as String? ?? '');
      String bodyOf(Map<String, Object?> s) => c.entityType ==
              EntitySnapshots.recordType
          ? (s['body'] as String? ?? '')
          : '';
      DateTime? localUpdated;
      if (c.entityType == EntitySnapshots.recordType) {
        final row = await (_db.select(_db.records)
              ..where((r) => r.id.equals(c.entityId)))
            .getSingleOrNull();
        localUpdated = row?.updatedAt;
      }
      localUpdated ??= heads
          .where((h) => h.isLocal)
          .map((h) => h.createdAt)
          .fold<DateTime?>(
              null, (a, b) => a == null || b.isAfter(a) ? b : a);
      out.add(ConflictInfo(
        id: c.id,
        entityId: c.entityId,
        entityType: c.entityType,
        localTitle: titleOf(local.snapshot),
        localBody: bodyOf(local.snapshot),
        remoteTitle: titleOf(rp.snapshot),
        remoteBody: bodyOf(rp.snapshot),
        localUpdatedAt: (localUpdated ?? c.createdAt).toUtc(),
        remoteUpdatedAt: remoteHead.createdAt.toUtc(),
      ));
    }
    return out;
  }
}
