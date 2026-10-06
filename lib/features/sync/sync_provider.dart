// lib/features/sync/sync_provider.dart
// Stage C: storage-agnostic sync provider interface (spec §11.4).

import 'dart:typed_data';

/// Storage backend used by the sync engine.
///
/// All `path` / `directory` arguments are vault-relative (for example
/// `header.json`, `objects/abc.enc`, `objects`); the implementation maps them
/// under its configured server directory. Failures throw
/// [SyncProviderException].
abstract interface class SyncProvider {
  /// Tests the connection and detects conditional-write support using a
  /// dedicated temporary directory.
  Future<Capabilities> probe();

  /// Lists the direct children of [directory] (vault-relative).
  Future<List<RemoteObject>> list(String directory);

  /// Downloads the object at [path].
  Future<DownloadedObject> get(String path);

  /// Uploads [bytes] to [path]. [createOnly] sends `If-None-Match: *`;
  /// [ifMatch] sends `If-Match` with the given ETag.
  Future<WriteResult> put(
    String path,
    Uint8List bytes, {
    String? ifMatch,
    bool createOnly = false,
  });

  void close();
}

class Capabilities {
  const Capabilities({
    required this.supportsConditionalCreate,
    required this.supportsConditionalUpdate,
  });

  final bool supportsConditionalCreate;
  final bool supportsConditionalUpdate;

  @override
  String toString() => 'Capabilities(create: $supportsConditionalCreate, '
      'update: $supportsConditionalUpdate)';
}

class RemoteObject {
  const RemoteObject({
    required this.path,
    this.etag,
    this.size,
    this.isDirectory = false,
  });

  /// Vault-relative path.
  final String path;
  final String? etag;
  final int? size;
  final bool isDirectory;
}

class DownloadedObject {
  const DownloadedObject({
    required this.bytes,
    this.etag,
    required this.statusCode,
  });

  final Uint8List bytes;
  final String? etag;
  final int statusCode;
}

class WriteResult {
  const WriteResult({
    required this.statusCode,
    this.etag,
    required this.created,
  });

  final int statusCode;
  final String? etag;
  final bool created;
}

enum ProviderErrorKind {
  notHttps,
  unauthorized,
  forbidden,
  notFound,
  preconditionFailed,
  rateLimited,
  insufficientStorage,
  serverError,
  network,
  timeout,
  protocolError,
  payloadTooLarge,
  redirectBlocked,
}

class SyncProviderException implements Exception {
  const SyncProviderException(
    this.kind, {
    this.statusCode,
    this.retryAfter,
    this.detail = '',
  });

  final ProviderErrorKind kind;
  final int? statusCode;
  final Duration? retryAfter;

  /// Safe diagnostic only (status codes); never credentials or plaintext.
  final String detail;

  @override
  String toString() => 'SyncProviderException(${kind.name}'
      '${statusCode == null ? '' : ', status: $statusCode'}'
      '${detail.isEmpty ? '' : ', $detail'})';
}
