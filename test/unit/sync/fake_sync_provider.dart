// test/unit/sync/fake_sync_provider.dart
// In-memory fake SyncProvider for fault-injection unit tests.

import 'dart:typed_data';

import 'package:suicun/features/sync/sync_provider.dart';

class StoredObject {
  const StoredObject({
    required this.bytes,
    required this.etag,
  });

  final Uint8List bytes;
  final String etag;
}

class FakeSyncProvider implements SyncProvider {
  FakeSyncProvider({
    this.supportsConditionalCreate = true,
    this.supportsConditionalUpdate = true,
    Map<String, StoredObject>? initialStorage,
  }) : storage = initialStorage ?? <String, StoredObject>{};

  final Map<String, StoredObject> storage;
  bool supportsConditionalCreate;
  bool supportsConditionalUpdate;

  // Fault injection controls
  bool offline = false;
  final Set<String> failOnGet = <String>{};
  final Set<String> failOnPut = <String>{};
  bool timeoutAfterPut = false;
  final Map<String, int> forcePutStatus = <String, int>{};
  int? forceListStatus;
  Duration? putRetryAfter;

  final List<String> requestLog = <String>[];
  var _etagCounter = 0;

  String _computeEtag(Uint8List bytes) {
    _etagCounter++;
    return '"etag-$_etagCounter-${bytes.length}"';
  }

  void _checkOffline() {
    if (offline) {
      throw const SyncProviderException(ProviderErrorKind.network,
          detail: 'device offline');
    }
  }

  SyncProviderException _mapStatusToException(int status,
      {Duration? retryAfter}) {
    switch (status) {
      case 401:
        return SyncProviderException(ProviderErrorKind.unauthorized,
            statusCode: status);
      case 403:
        return SyncProviderException(ProviderErrorKind.forbidden,
            statusCode: status);
      case 404:
        return SyncProviderException(ProviderErrorKind.notFound,
            statusCode: status);
      case 412:
        return SyncProviderException(ProviderErrorKind.preconditionFailed,
            statusCode: status);
      case 413:
        return SyncProviderException(ProviderErrorKind.payloadTooLarge,
            statusCode: status);
      case 429:
        return SyncProviderException(ProviderErrorKind.rateLimited,
            statusCode: status, retryAfter: retryAfter);
      case 507:
        return SyncProviderException(ProviderErrorKind.insufficientStorage,
            statusCode: status);
      default:
        return SyncProviderException(ProviderErrorKind.serverError,
            statusCode: status);
    }
  }

  @override
  Future<Capabilities> probe() async {
    _checkOffline();
    requestLog.add('PROBE');
    return Capabilities(
      supportsConditionalCreate: supportsConditionalCreate,
      supportsConditionalUpdate: supportsConditionalUpdate,
    );
  }

  @override
  Future<List<RemoteObject>> list(String directory) async {
    _checkOffline();
    requestLog.add('LIST $directory');
    if (forceListStatus != null) {
      throw _mapStatusToException(forceListStatus!);
    }
    final prefix = directory.endsWith('/') ? directory : '$directory/';
    final results = <RemoteObject>[];
    for (final entry in storage.entries) {
      if (entry.key.startsWith(prefix)) {
        results.add(RemoteObject(
          path: entry.key,
          etag: entry.value.etag,
          size: entry.value.bytes.length,
          isDirectory: false,
        ));
      }
    }
    return results;
  }

  @override
  Future<DownloadedObject> get(String path) async {
    _checkOffline();
    requestLog.add('GET $path');
    if (failOnGet.contains(path)) {
      throw const SyncProviderException(ProviderErrorKind.network,
          detail: 'simulated get failure');
    }
    final obj = storage[path];
    if (obj == null) {
      throw const SyncProviderException(ProviderErrorKind.notFound,
          statusCode: 404);
    }
    return DownloadedObject(
      bytes: obj.bytes,
      etag: obj.etag,
      statusCode: 200,
    );
  }

  @override
  Future<WriteResult> put(
    String path,
    Uint8List bytes, {
    String? ifMatch,
    bool createOnly = false,
  }) async {
    _checkOffline();
    requestLog.add('PUT $path');
    if (failOnPut.contains(path)) {
      throw const SyncProviderException(ProviderErrorKind.network,
          detail: 'simulated put failure');
    }
    if (forcePutStatus.containsKey(path)) {
      final status = forcePutStatus[path]!;
      throw _mapStatusToException(status, retryAfter: putRetryAfter);
    }

    final existing = storage[path];

    if (createOnly) {
      if (existing != null) {
        throw const SyncProviderException(
          ProviderErrorKind.preconditionFailed,
          statusCode: 412,
          detail: 'Precondition Failed: resource already exists',
        );
      }
    }

    if (ifMatch != null) {
      if (existing == null || existing.etag != ifMatch) {
        throw const SyncProviderException(
          ProviderErrorKind.preconditionFailed,
          statusCode: 412,
          detail: 'Precondition Failed: ETag mismatch',
        );
      }
    }

    final etag = _computeEtag(bytes);
    storage[path] = StoredObject(bytes: bytes, etag: etag);

    if (timeoutAfterPut) {
      throw const SyncProviderException(
        ProviderErrorKind.timeout,
        detail: 'simulated timeout after server stored bytes',
      );
    }

    return WriteResult(
      statusCode: existing == null ? 201 : 200,
      etag: etag,
      created: existing == null,
    );
  }

  @override
  void close() {}
}
