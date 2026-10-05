// test/unit/webdav_service_test.dart
// Unit tests for WebDAV config validation, connection probing and
// credential storage. No real network is used: the HTTP client is mocked
// via package:http/testing.dart and secure storage is an in-memory fake.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:suicun/services/webdav_service.dart';

/// In-memory fake for FlutterSecureStorage (no platform channels in tests).
class FakeSecureStorage extends FlutterSecureStorage {
  final Map<String, String> store = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      store.remove(key);
    } else {
      store[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      store[key];

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    store.remove(key);
  }
}

const _validConfig = WebdavConfig(
  serverUrl: 'https://dav.example.com',
  username: 'user',
  password: 'secret',
  directory: '/suicun/',
);

WebdavService serviceWith({
  int statusCode = 207,
  Object? throwError,
  FakeSecureStorage? storage,
  void Function(http.BaseRequest request)? onRequest,
}) {
  final client = MockClient((http.Request request) async {
    onRequest?.call(request);
    if (throwError != null) throw throwError;
    return http.Response('<ok/>', statusCode);
  });
  return WebdavService(client: client, storage: storage ?? FakeSecureStorage());
}

void main() {
  group('validateConfig', () {
    test('valid config passes', () {
      expect(WebdavService().validateConfig(_validConfig), isEmpty);
    });

    test('rejects non-https URL', () {
      final errors = WebdavService().validateConfig(const WebdavConfig(
        serverUrl: 'http://dav.example.com',
        username: 'u',
        password: 'p',
        directory: '/suicun/',
      ));
      expect(errors, isNotEmpty);
      expect(errors.join(), contains('https://'));
    });

    test('rejects empty server URL', () {
      final errors = WebdavService().validateConfig(const WebdavConfig(
        serverUrl: '  ',
        username: 'u',
        password: 'p',
        directory: '/suicun/',
      ));
      expect(errors, isNotEmpty);
    });

    test('rejects malformed URL', () {
      final errors = WebdavService().validateConfig(const WebdavConfig(
        serverUrl: 'https://',
        username: 'u',
        password: 'p',
        directory: '/suicun/',
      ));
      expect(errors, isNotEmpty);
    });

    test('rejects empty username', () {
      final errors = WebdavService().validateConfig(const WebdavConfig(
        serverUrl: 'https://dav.example.com',
        username: '   ',
        password: 'p',
        directory: '/suicun/',
      ));
      expect(errors, isNotEmpty);
    });

    test('rejects empty directory', () {
      final errors = WebdavService().validateConfig(const WebdavConfig(
        serverUrl: 'https://dav.example.com',
        username: 'u',
        password: 'p',
        directory: '',
      ));
      expect(errors, isNotEmpty);
    });

    test('directory normalization hints', () {
      final svc = WebdavService();
      const base = WebdavConfig(
        serverUrl: 'https://dav.example.com',
        username: 'u',
        password: 'p',
        directory: '/suicun/',
      );
      expect(svc.validateConfig(base), isEmpty);
      // Missing leading slash.
      expect(
        svc.validateConfig(const WebdavConfig(
          serverUrl: 'https://dav.example.com',
          username: 'u',
          password: 'p',
          directory: 'suicun/',
        )),
        isNotEmpty,
      );
      // Missing trailing slash.
      expect(
        svc.validateConfig(const WebdavConfig(
          serverUrl: 'https://dav.example.com',
          username: 'u',
          password: 'p',
          directory: '/suicun',
        )),
        isNotEmpty,
      );
    });

    test('never throws on garbage input', () {
      expect(
        () => WebdavService().validateConfig(const WebdavConfig(
          serverUrl: '::::',
          username: '',
          password: '',
          directory: '',
        )),
        returnsNormally,
      );
    });
  });

  group('testConnection', () {
    test('207 and 2xx map to ok', () async {
      for (final code in [200, 207]) {
        final result =
            await serviceWith(statusCode: code).testConnection(_validConfig);
        expect(result.ok, isTrue, reason: 'HTTP $code');
        expect(result.failure, isNull);
      }
    });

    test('sends a real PROPFIND with Depth: 1 and Basic auth', () async {
      http.BaseRequest? captured;
      final service = serviceWith(onRequest: (r) => captured = r);
      final result = await service.testConnection(_validConfig);
      expect(result.ok, isTrue);
      expect(captured, isNotNull);
      expect(captured!.method, 'PROPFIND');
      expect(captured!.headers['Depth'], '1');
      final auth = captured!.headers['Authorization'];
      expect(auth, startsWith('Basic '));
      expect(
        utf8.decode(base64Decode(auth!.substring('Basic '.length))),
        'user:secret',
      );
      expect(captured!.url.toString(), 'https://dav.example.com/suicun/');
    });

    test('401/403 map to unauthorized', () async {
      for (final code in [401, 403]) {
        final result =
            await serviceWith(statusCode: code).testConnection(_validConfig);
        expect(result.ok, isFalse);
        expect(result.failure, WebdavProbeFailure.unauthorized);
      }
    });

    test('404 maps to notFound', () async {
      final result =
          await serviceWith(statusCode: 404).testConnection(_validConfig);
      expect(result.ok, isFalse);
      expect(result.failure, WebdavProbeFailure.notFound);
    });

    test('5xx maps to serverError', () async {
      for (final code in [500, 503]) {
        final result =
            await serviceWith(statusCode: code).testConnection(_validConfig);
        expect(result.ok, isFalse);
        expect(result.failure, WebdavProbeFailure.serverError);
      }
    });

    test('timeout maps to timeout', () async {
      final result = await serviceWith(
        throwError: TimeoutException('too slow'),
      ).testConnection(_validConfig);
      expect(result.ok, isFalse);
      expect(result.failure, WebdavProbeFailure.timeout);
    });

    test('socket errors map to network', () async {
      final result = await serviceWith(
        throwError: const SocketException('connection refused'),
      ).testConnection(_validConfig);
      expect(result.ok, isFalse);
      expect(result.failure, WebdavProbeFailure.network);
    });

    test('unexpected status codes map to unknown', () async {
      final result =
          await serviceWith(statusCode: 302).testConnection(_validConfig);
      expect(result.ok, isFalse);
      expect(result.failure, WebdavProbeFailure.unknown);
    });

    test('non-https returns notHttps without sending a request', () async {
      var called = false;
      final service = serviceWith(onRequest: (_) => called = true);
      const config = WebdavConfig(
        serverUrl: 'http://dav.example.com',
        username: 'u',
        password: 'p',
        directory: '/suicun/',
      );
      final result = await service.testConnection(config);
      expect(result.ok, isFalse);
      expect(result.failure, WebdavProbeFailure.notHttps);
      expect(called, isFalse);
    });

    test('detail never contains the password', () async {
      final result = await serviceWith(statusCode: 401).testConnection(
        const WebdavConfig(
          serverUrl: 'https://dav.example.com',
          username: 'user',
          password: 's3cr3t-p4ssw0rd',
          directory: '/suicun/',
        ),
      );
      expect(result.detail ?? '', isNot(contains('s3cr3t-p4ssw0rd')));
    });
  });

  group('save/load/clearConfig', () {
    test('loadConfig returns null when nothing was saved', () async {
      final service = WebdavService(storage: FakeSecureStorage());
      expect(await service.loadConfig(), isNull);
    });

    test('save then load round-trips the config', () async {
      final storage = FakeSecureStorage();
      final service = WebdavService(storage: storage);
      await service.saveConfig(_validConfig);
      final loaded = await service.loadConfig();
      expect(loaded, isNotNull);
      expect(loaded!.serverUrl, 'https://dav.example.com');
      expect(loaded.username, 'user');
      expect(loaded.password, 'secret');
      expect(loaded.directory, '/suicun/');
      // Credentials went to secure storage (all four keys present).
      expect(storage.store.length, 4);
    });

    test('save normalizes serverUrl and directory', () async {
      final service = WebdavService(storage: FakeSecureStorage());
      await service.saveConfig(const WebdavConfig(
        serverUrl: 'https://dav.example.com/  ',
        username: 'user',
        password: 'secret',
        directory: 'suicun',
      ));
      final loaded = await service.loadConfig();
      expect(loaded, isNotNull);
      expect(loaded!.serverUrl, 'https://dav.example.com/');
      expect(loaded.directory, '/suicun/');
    });

    test('clearConfig removes the saved config', () async {
      final service = WebdavService(storage: FakeSecureStorage());
      await service.saveConfig(_validConfig);
      expect(await service.loadConfig(), isNotNull);
      await service.clearConfig();
      expect(await service.loadConfig(), isNull);
    });
  });
}
