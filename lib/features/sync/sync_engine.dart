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
  });

  final WebdavConfig config;
  final SyncProvider provider;
  final VaultSession vault;
  final String deviceId;
  Capabilities? caps;
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

  static String _kvaultKey(String vaultId) => 'suicun.sync.kvault.$vaultId';

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

  /// Rebuilds [_session] from stored config + K_vault. Returns false when the
  /// credentials are missing.
  Future<bool> _restoreSession([SyncStateData? known]) async {
    final state = known ?? await _store.getState();
    if (state == null) return false;
    final config = await _configStore.loadConfig();
    final kvaultB64 = await _secureStore.read(_kvaultKey(state.vaultId));
    if (config == null || kvaultB64 == null) return false;
    final vault = VaultSession(
      vaultId: state.vaultId,
      kvault: Uint8List.fromList(base64Decode(kvaultB64)),
    );
    _session?.provider.close();
    _session = _Session(
      config: config,
      provider: _providerFactory(config),
      vault: vault,
      deviceId: state.deviceId,
    );
    SyncSessionHolder.current = vault;
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
    return SyncOverview(
      enabled: _session != null && _stateEnabled,
      syncing: _syncing,
      lastSuccessAt: state?.lastSuccessAt,
      pendingCount: await _store.pendingOutboxCount(),
      conflictCount: await _store.openConflictCount(),
      vaultId: _session?.vault.vaultId ?? state?.vaultId,
      lastError: _lastError?.message(english: _isEnglish),
    );
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

    // Step 1: header / protocol check. Unknown protocol versions halt the pass
    // and are never overwritten.
    final headerObj = await _tryGet(session, 'header.json');
    if (headerObj == null) throw const SyncError(SyncErrorCode.vaultNotFound);
    final VaultHeader header;
    try {
      header = VaultHeader.parse(utf8.decode(headerObj.bytes));
    } on VaultCryptoError catch (e) {
      throw _mapCryptoError(e);
    } on FormatException {
      throw const SyncError(SyncErrorCode.malformedHeader);
    }
    if (header.protocolVersion != kVaultProtocolVersion) {
      throw const SyncError(SyncErrorCode.unsupportedProtocol);
    }
    if (header.vaultId != session.vault.vaultId) {
      throw const SyncError(SyncErrorCode.headerMismatch);
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
      remote = await _guard(() => session.provider.list('objects'));
    } on SyncError catch (e) {
      // 404 on objects/ means an empty vault, not a masked failure.
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
    if (envelope.vaultId != session.vault.vaultId) {
      await _store.markSkipped(revId, 'vault-mismatch');
      return null;
    }
    if (envelope.revisionId != revId) {
      await _store.markSkipped(revId, 'name-mismatch');
      return null;
    }
    final Map<String, Object?> payload;
    try {
      payload = await _crypto.decryptRevision(
        session: session.vault,
        objectBytes: dl.bytes,
      );
    } on VaultCryptoError catch (e) {
      // NEVER store undecryptable payloads.
      await _store.markSkipped(revId, 'decrypt:${e.code.name}');
      return null;
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
  /// then by creation time). A revision whose parents are neither stored nor
  /// applied in this pass is left unapplied and NOT stored: it is downloaded
  /// again on a later pass, once the parent has arrived. (Tradeoff: repeated
  /// downloads of such orphans, in exchange for never storing a revision with
  /// a dangling parent.) Returns the revisions applied.
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
    final path = 'objects/${rev.revisionId}.enc';
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
              () => session.provider.put(path, bytes, createOnly: true));
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
    await _guard(() => session.provider.put(path, bytes));
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
      if (state != null) await _secureStore.delete(_kvaultKey(state.vaultId));
      await _configStore.clearConfig();
    }
    _authPaused = false;
    _emitOverview();
  }

  @override
  Future<RemoteVaultCheck> checkRemoteVault(WebdavConfig config) async {
    final provider = _providerFactory(config);
    try {
      final DownloadedObject obj;
      try {
        obj = await provider.get('header.json');
      } on SyncProviderException catch (e) {
        if (e.kind == ProviderErrorKind.notFound) {
          return RemoteVaultCheck.noVault;
        }
        throw _mapProviderError(e);
      }
      try {
        VaultHeader.parse(utf8.decode(obj.bytes));
      } on VaultCryptoError {
        throw const SyncError(SyncErrorCode.malformedHeader);
      } on FormatException {
        throw const SyncError(SyncErrorCode.malformedHeader);
      }
      return RemoteVaultCheck.hasVault;
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
      final caps = await _guard(provider.probe);
      if (!caps.supportsConditionalCreate) {
        throw const SyncError(SyncErrorCode.conditionalWriteUnsupported);
      }
      final CreatedVault created;
      try {
        created = await _crypto.createVault(password: password);
      } on VaultCryptoError {
        throw const SyncError(SyncErrorCode.malformedHeader);
      }
      try {
        await provider.put(
          'header.json',
          Uint8List.fromList(utf8.encode(created.headerJson)),
          createOnly: true,
        );
      } on SyncProviderException catch (e) {
        if (e.kind == ProviderErrorKind.preconditionFailed) {
          // Lost the creation race: another device created the vault first.
          return await joinVault(config, password: password);
        }
        throw _mapProviderError(e);
      }
      await _finishJoin(config, provider, created.session, caps);
      _pendingRecoveryKey = created.recoveryKey;
      ok = true;
    } finally {
      if (!ok) provider.close();
    }
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
    final provider = _providerFactory(config);
    var ok = false;
    try {
      final headerJson = await _fetchHeaderJson(provider);
      final VaultSession vault;
      try {
        vault = hasPassword
            ? await _crypto.openWithPassword(headerJson, password)
            : await _crypto.openWithRecoveryKey(headerJson, recoveryKey!);
      } on VaultCryptoError catch (e) {
        throw _mapCryptoError(e);
      }
      final caps = await _guard(provider.probe);
      await _finishJoin(config, provider, vault, caps);
      ok = true;
    } finally {
      if (!ok) provider.close();
    }
  }

  Future<String> _fetchHeaderJson(SyncProvider provider) async {
    try {
      final obj = await provider.get('header.json');
      return utf8.decode(obj.bytes);
    } on SyncProviderException catch (e) {
      if (e.kind == ProviderErrorKind.notFound) {
        throw const SyncError(SyncErrorCode.vaultNotFound);
      }
      throw _mapProviderError(e);
    } on FormatException {
      throw const SyncError(SyncErrorCode.malformedHeader);
    }
  }

  /// Persists the join and activates the session. Takes ownership of
  /// [provider]. Joining a different vault replaces the previous join
  /// (already-synced data of the old vault stays in the local database).
  Future<void> _finishJoin(
    WebdavConfig config,
    SyncProvider provider,
    VaultSession vault,
    Capabilities? caps,
  ) async {
    final existing = await _store.getState();
    final deviceId = (existing != null && existing.vaultId == vault.vaultId)
        ? existing.deviceId
        : _uuid.v4();
    await _db.transaction(() => _store.saveState(
          vaultId: vault.vaultId,
          deviceId: deviceId,
          enabled: true,
        ));
    await _configStore.saveConfig(config);
    await _secureStore.write(
        _kvaultKey(vault.vaultId), base64Encode(vault.kvault));
    final old = _session;
    if (old != null && !identical(old.provider, provider)) {
      old.provider.close();
    }
    SyncSessionHolder.current = vault;
    _session = _Session(
      config: config,
      provider: provider,
      vault: vault,
      deviceId: deviceId,
      caps: caps,
    );
    _initFuture ??= Future.value();
    _stateEnabled = true;
    _authPaused = false;
    _lastError = null;
    _emitOverview();
  }

  /// Recovery on a new device. The local database is encrypted with this
  /// device's own key (opened at startup); recovery merges idempotently
  /// (insertRevision is DoNothing, snapshot apply is an upsert), so running it
  /// again never duplicates data.
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
      emit('connecting');
      await ensureInitialized();
      provider = _providerFactory(config);
      final headerJson = await _fetchHeaderJson(provider);
      final VaultSession vault;
      try {
        vault = hasPassword
            ? await _crypto.openWithPassword(headerJson, password)
            : await _crypto.openWithRecoveryKey(headerJson, recoveryKey!);
      } on VaultCryptoError catch (e) {
        throw _mapCryptoError(e);
      }
      final current = _session;
      if (current != null && current.vault.vaultId != vault.vaultId) {
        // Never overwrite an existing join with a different vault.
        throw const SyncError(SyncErrorCode.headerMismatch);
      }
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
      );

      emit('listing');
      List<RemoteObject> remote;
      try {
        remote = await _guard(() => provider!.list('objects'));
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
            RemoteObject(path: 'objects/$id.enc'),
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
        // Progress is kept (applied revisions are stored); a re-run fetches
        // only what is still missing.
        throw firstError ?? const SyncError(SyncErrorCode.unknown);
      }
      await _finishJoin(config, provider, vault, caps);
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
    final session = _session!;
    final payload = await _crypto.decryptRevision(
      session: session.vault,
      objectBytes: Uint8List.fromList(utf8.encode(head.payloadJson)),
    );
    return EntitySnapshots.parse(payload);
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
