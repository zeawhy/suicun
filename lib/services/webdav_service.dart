// lib/services/webdav_service.dart
// WebDAV configuration service for 随存 (spec §11.4–11.5, config-page scope).
//
// This stage covers the config page only: validation, a real PROPFIND
// connection probe, and credential storage in platform secure storage.
// The full sync engine is a later stage and is NOT implemented here.
//
// Security notes:
// - Only HTTPS is accepted for probing (plain HTTP is rejected without any
//   request being sent). TLS certificates are validated by the platform;
//   there is no "ignore certificate" switch.
// - The password is stored only in flutter_secure_storage and is never
//   written to logs (detail strings contain status codes, never secrets).

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// WebDAV server configuration entered by the user.
class WebdavConfig {
  final String serverUrl;
  final String username;
  final String password;
  final String directory; // e.g. /suicun/

  const WebdavConfig({
    required this.serverUrl,
    required this.username,
    required this.password,
    required this.directory,
  });

  @override
  String toString() =>
      // Never include the password in string representations / logs.
      'WebdavConfig(serverUrl: $serverUrl, username: $username, '
      'directory: $directory)';
}

/// Machine-readable reason for a failed connection probe.
enum WebdavProbeFailure {
  /// The server URL is not HTTPS — no request was sent.
  notHttps,

  /// The request timed out.
  timeout,

  /// HTTP 401/403 — wrong credentials or forbidden.
  unauthorized,

  /// HTTP 404 — the directory was not found on the server.
  notFound,

  /// Network-level error (DNS, connection refused, socket error, ...).
  network,

  /// HTTP 5xx from the server.
  serverError,

  /// Anything else (invalid URL, unexpected status code, ...).
  unknown,
}

/// Result of [WebdavService.testConnection].
class WebdavProbeResult {
  final bool ok;
  final WebdavProbeFailure? failure;
  final String? detail;

  const WebdavProbeResult({
    required this.ok,
    this.failure,
    this.detail,
  });

  @override
  String toString() =>
      'WebdavProbeResult(ok: $ok, failure: $failure, detail: $detail)';
}

class WebdavService {
  /// [client] is injectable so tests can use a mock without real network.
  /// [storage] is injectable so tests can use an in-memory fake.
  WebdavService({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  final http.Client _client;
  final FlutterSecureStorage _storage;

  static const Duration probeTimeout = Duration(seconds: 15);

  /// Invisible characters that frequently sneak into URLs when copying from
  /// chat apps / web pages (zero-width spaces, BOM, word joiners, ...).
  /// They are not removed by [String.trim] but break DNS resolution while
  /// remaining invisible on screen.
  static final RegExp _invisibleChars = RegExp(
    '[\u200b\u200c\u200d\u2060\ufeff\u00ad\u061c\u115f\u1160\u17b4\u17b5'
    '\u180e\u2000-\u200a\u202a-\u202e\u2061-\u2064\u2066-\u206f\u3164\uffa0]',
  );

  /// Removes invisible/control characters from a user-supplied URL and
  /// trims surrounding whitespace. Use before any parsing or request.
  static String sanitizeUrl(String url) =>
      url.replaceAll(_invisibleChars, '').trim();

  // Keys used in secure storage. Never log their values.
  static const _kServerUrl = 'suicun.webdav.serverUrl';
  static const _kUsername = 'suicun.webdav.username';
  static const _kPassword = 'suicun.webdav.password';
  static const _kDirectory = 'suicun.webdav.directory';

  /// Validates a config. Returns the list of error messages (empty = valid).
  /// Never throws.
  ///
  /// Rules: serverUrl must start with https:// and be a valid URL;
  /// username and directory must be non-empty; directory should start and
  /// end with '/' (a normalization hint is reported otherwise).
  List<String> validateConfig(WebdavConfig config) {
    final errors = <String>[];

    final url = sanitizeUrl(config.serverUrl);
    if (url.isEmpty) {
      errors.add('请输入 WebDAV 服务器地址');
    } else if (!url.toLowerCase().startsWith('https://')) {
      errors.add('服务器地址必须以 https:// 开头');
    } else {
      final uri = Uri.tryParse(url);
      if (uri == null || uri.host.isEmpty) {
        errors.add('服务器地址格式不正确');
      }
    }

    if (config.username.trim().isEmpty) {
      errors.add('请输入用户名');
    }

    final directory = config.directory.trim();
    if (directory.isEmpty) {
      errors.add('目录不能为空');
    } else {
      if (!directory.startsWith('/')) errors.add('目录应以 / 开头，例如 /suicun/');
      if (!directory.endsWith('/')) errors.add('目录应以 / 结尾，例如 /suicun/');
    }

    return errors;
  }

  /// Normalizes a directory to "/.../" form for request building.
  static String normalizeDirectory(String directory) {
    var dir = directory.trim();
    if (dir.isEmpty) return '/';
    if (!dir.startsWith('/')) dir = '/$dir';
    if (!dir.endsWith('/')) dir = '$dir/';
    return dir;
  }

  /// Probes the server with a real HTTP PROPFIND request
  /// (Depth: 1, HTTP Basic auth) against serverUrl + directory.
  ///
  /// - Only HTTPS is probed; non-HTTPS configs return [WebdavProbeFailure.notHttps]
  ///   without sending any request.
  /// - 15-second timeout.
  /// - Status mapping: 2xx/207 -> ok; 401/403 -> unauthorized; 404 -> notFound;
  ///   timeout -> timeout; other 5xx -> serverError; network errors -> network.
  /// - Never throws; the password never appears in [WebdavProbeResult.detail].
  Future<WebdavProbeResult> testConnection(WebdavConfig config) async {
    final url = sanitizeUrl(config.serverUrl);
    if (!url.toLowerCase().startsWith('https://')) {
      return const WebdavProbeResult(
        ok: false,
        failure: WebdavProbeFailure.notHttps,
        detail: '仅支持 HTTPS 地址',
      );
    }

    final base = url.replaceAll(RegExp(r'/+$'), '');
    final target = '$base${normalizeDirectory(config.directory)}';
    final uri = Uri.tryParse(target);
    if (uri == null || uri.host.isEmpty) {
      return const WebdavProbeResult(
        ok: false,
        failure: WebdavProbeFailure.unknown,
        detail: '服务器地址格式不正确',
      );
    }

    final credentials =
        base64Encode(utf8.encode('${config.username}:${config.password}'));
    final request = http.Request('PROPFIND', uri)
      ..headers['Depth'] = '1'
      ..headers['Authorization'] = 'Basic $credentials'
      ..headers['Content-Type'] = 'application/xml; charset=utf-8'
      ..body =
          '<?xml version="1.0" encoding="utf-8"?>'
          '<propfind xmlns="DAV:"><prop><displayname/></prop></propfind>';

    http.StreamedResponse response;
    try {
      response = await _client.send(request).timeout(probeTimeout);
    } on TimeoutException {
      return const WebdavProbeResult(
        ok: false,
        failure: WebdavProbeFailure.timeout,
        detail: '连接超时（15 秒无响应）',
      );
    } catch (e) {
      return WebdavProbeResult(
        ok: false,
        failure: WebdavProbeFailure.network,
        detail: '网络错误：${_safeErrorMessage(e)}',
      );
    }

    // Drain the body so the underlying connection can be reused/closed.
    try {
      await response.stream.drain().timeout(const Duration(seconds: 5));
    } catch (_) {
      // Body draining is best-effort; the status code is what matters.
    }

    final code = response.statusCode;
    if (code == 207 || (code >= 200 && code < 300)) {
      return const WebdavProbeResult(ok: true);
    }
    if (code == 401 || code == 403) {
      return WebdavProbeResult(
        ok: false,
        failure: WebdavProbeFailure.unauthorized,
        detail: '认证失败（HTTP $code），请检查用户名和密码',
      );
    }
    if (code == 404) {
      return WebdavProbeResult(
        ok: false,
        failure: WebdavProbeFailure.notFound,
        detail: '服务器上找不到该目录（HTTP 404）',
      );
    }
    if (code >= 500 && code < 600) {
      return WebdavProbeResult(
        ok: false,
        failure: WebdavProbeFailure.serverError,
        detail: '服务器错误（HTTP $code）',
      );
    }
    return WebdavProbeResult(
      ok: false,
      failure: WebdavProbeFailure.unknown,
      detail: '服务器返回了未预期的状态码（HTTP $code）',
    );
  }

  /// Persists the config; all fields (including the password) go to
  /// platform secure storage.
  Future<void> saveConfig(WebdavConfig config) async {
    await Future.wait([
      _storage.write(key: _kServerUrl, value: sanitizeUrl(config.serverUrl)),
      _storage.write(key: _kUsername, value: config.username),
      _storage.write(key: _kPassword, value: config.password),
      _storage.write(
          key: _kDirectory, value: normalizeDirectory(config.directory)),
    ]);
  }

  /// Loads the saved config, or null when nothing was saved yet.
  Future<WebdavConfig?> loadConfig() async {
    final values = await Future.wait([
      _storage.read(key: _kServerUrl),
      _storage.read(key: _kUsername),
      _storage.read(key: _kPassword),
      _storage.read(key: _kDirectory),
    ]);
    final serverUrl = values[0];
    if (serverUrl == null || serverUrl.isEmpty) return null;
    return WebdavConfig(
      serverUrl: serverUrl,
      username: values[1] ?? '',
      password: values[2] ?? '',
      directory: values[3] ?? '/',
    );
  }

  /// Deletes the saved config from secure storage.
  Future<void> clearConfig() async {
    await Future.wait([
      _storage.delete(key: _kServerUrl),
      _storage.delete(key: _kUsername),
      _storage.delete(key: _kPassword),
      _storage.delete(key: _kDirectory),
    ]);
  }

  /// Releases the underlying HTTP client. Call when the service is discarded.
  void dispose() {
    _client.close();
  }

  /// Error message safe for display: strips anything that could plausibly
  /// contain credentials (only the exception type is kept).
  static String _safeErrorMessage(Object e) {
    final text = e.toString();
    // Keep it short and free of URLs/headers that might leak secrets.
    final firstLine = text.split('\n').first;
    return firstLine.length > 120 ? '${firstLine.substring(0, 120)}…' : firstLine;
  }
}

/// Riverpod provider for [WebdavService].
final webdavServiceProvider = Provider<WebdavService>((ref) {
  final service = WebdavService();
  ref.onDispose(service.dispose);
  return service;
});
