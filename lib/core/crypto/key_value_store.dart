// lib/core/crypto/key_value_store.dart
// Minimal key-value store abstraction for secrets.
//
// Production uses [SecureStorageKeyValueStore] (flutter_secure_storage,
// backed by Android Keystore). Tests use [MemoryKeyValueStore].
// The abstraction keeps security-critical code unit-testable without
// platform channels.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Minimal async key-value store for secrets.
abstract interface class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// [KeyValueStore] backed by the platform secure storage (Android Keystore).
class SecureStorageKeyValueStore implements KeyValueStore {
  SecureStorageKeyValueStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  // Android default: AES-256-GCM data encryption with RSA-OAEP key wrapping
  // in the Android Keystore (flutter_secure_storage 11.x default options).
  static const _options = AndroidOptions();

  @override
  Future<String?> read(String key) =>
      _storage.read(key: key, aOptions: _options);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value, aOptions: _options);

  @override
  Future<void> delete(String key) =>
      _storage.delete(key: key, aOptions: _options);
}

/// In-memory [KeyValueStore] for tests. NOT for production use.
class MemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> _map = {};

  @override
  Future<String?> read(String key) async => _map[key];

  @override
  Future<void> write(String key, String value) async {
    _map[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _map.remove(key);
  }
}
