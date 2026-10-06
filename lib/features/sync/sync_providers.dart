// lib/features/sync/sync_providers.dart
// Stage C: Riverpod wiring of the sync engine.

import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:suicun/core/crypto/key_value_store.dart';
import 'package:suicun/core/database/providers.dart';
import 'package:suicun/features/sync/sync_engine.dart';
import 'package:suicun/services/webdav_service.dart';

/// The single sync engine instance. Local edits trigger it through the
/// enqueuer's [SyncEnqueuer.onEnqueued] hook.
final syncEngineProvider = Provider<SyncEngine>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final enqueuer = ref.watch(syncEnqueuerProvider);
  final engine = SyncEngine(
    db: db,
    configStore: _WebdavServiceAdapter(ref.watch(webdavServiceProvider)),
    secureStore: SecureStorageKeyValueStore(),
    syncEnqueuer: enqueuer,
  );
  enqueuer.onEnqueued = engine.notifyLocalChange;
  unawaited(engine.ensureInitialized());
  ref.onDispose(() {
    enqueuer.onEnqueued = null;
    engine.dispose();
  });
  return engine;
});

class _WebdavServiceAdapter implements WebdavConfigStore {
  _WebdavServiceAdapter(this._s);

  final WebdavService _s;

  @override
  Future<WebdavConfig?> loadConfig() => _s.loadConfig();

  @override
  Future<void> saveConfig(WebdavConfig c) => _s.saveConfig(c);

  @override
  Future<void> clearConfig() => _s.clearConfig();
}
