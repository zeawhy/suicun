// lib/features/sync/webdav_sync_provider.dart
// Stage C: WebDAV implementation of SyncProvider (HTTPS only, manual redirects).

import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpDate;
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../../services/webdav_service.dart';
import 'sync_provider.dart';

const int _maxObjectResponseBytes = 16 * 1024 * 1024;
const int _maxXmlResponseBytes = 8 * 1024 * 1024;
const int _maxRedirectHops = 5;

/// WebDAV storage for the sync vault.
///
/// The vault root is `<serverUrl><directory>`. Vault-relative paths such as
/// `header.json` or `objects/<id>.enc` are mapped under it with every path
/// segment URL-encoded. Credentials are sent via HTTP Basic auth and are never
/// included in exception details.
class WebdavSyncProvider implements SyncProvider {
  WebdavSyncProvider({
    required WebdavConfig config,
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
    Random? random,
  })  : _client = client ?? http.Client(),
        _random = random ?? Random.secure() {
    final url = WebdavService.sanitizeUrl(config.serverUrl);
    if (!url.toLowerCase().startsWith('https://')) {
      _client.close();
      throw const SyncProviderException(ProviderErrorKind.notHttps);
    }
    final base = Uri.tryParse(url);
    if (base == null || base.host.isEmpty) {
      _client.close();
      throw const SyncProviderException(
        ProviderErrorKind.protocolError,
        detail: 'invalid server url',
      );
    }
    _rootSegments = [
      ...base.pathSegments.where((s) => s.isNotEmpty),
      ...WebdavService.normalizeDirectory(config.directory)
          .split('/')
          .where((s) => s.isNotEmpty),
    ];
    _origin = Uri(
      scheme: 'https',
      host: base.host,
      port: base.hasPort ? base.port : null,
    );
    _authorization = 'Basic '
        '${base64Encode(utf8.encode('${config.username}:${config.password}'))}';
  }

  final http.Client _client;
  final Random _random;
  final Duration timeout;

  late final List<String> _rootSegments;
  late final Uri _origin;
  late final String _authorization;

  // ---------------------------------------------------------------- URLs

  List<String> _relSegments(String path) {
    final segs = path.split('/').where((s) => s.isNotEmpty).toList();
    if (segs.any((s) => s == '.' || s == '..')) {
      throw const SyncProviderException(
        ProviderErrorKind.protocolError,
        detail: 'invalid path',
      );
    }
    return segs;
  }

  Uri _uriFor(String path, {bool collection = false}) {
    final segs = [..._rootSegments, ..._relSegments(path)];
    return _origin.replace(pathSegments: [...segs, if (collection) '']);
  }

  static bool _sameOrigin(Uri a, Uri b) =>
      a.scheme == b.scheme &&
      a.host == b.host &&
      (a.hasPort ? a.port : 443) == (b.hasPort ? b.port : 443);

  // ----------------------------------------------------------- transport

  Future<_Response> _send(
    String method,
    Uri uri, {
    Map<String, String> headers = const {},
    List<int>? body,
    int maxBytes = _maxObjectResponseBytes,
  }) async {
    var current = uri;
    var withAuth = true;
    for (var hop = 0; hop <= _maxRedirectHops; hop++) {
      final res =
          await _once(method, current, withAuth, headers, body, maxBytes);
      if (!const {301, 302, 303, 307, 308}.contains(res.status)) return res;
      if (hop == _maxRedirectHops) break;
      final location = res.headers['location'];
      if (location == null || location.isEmpty) {
        throw SyncProviderException(
          ProviderErrorKind.protocolError,
          statusCode: res.status,
          detail: 'redirect without location',
        );
      }
      final Uri next;
      try {
        next = current.resolve(location);
      } on FormatException {
        throw SyncProviderException(
          ProviderErrorKind.protocolError,
          statusCode: res.status,
          detail: 'invalid redirect location',
        );
      }
      if (next.scheme != 'https') {
        throw SyncProviderException(
          ProviderErrorKind.redirectBlocked,
          statusCode: res.status,
          detail: 'redirect to non-https',
        );
      }
      if (!_sameOrigin(current, next)) {
        if (method != 'GET' && method != 'PROPFIND') {
          throw SyncProviderException(
            ProviderErrorKind.redirectBlocked,
            statusCode: res.status,
            detail: 'cross-origin redirect for $method',
          );
        }
        withAuth = false;
      }
      current = next;
    }
    throw const SyncProviderException(
      ProviderErrorKind.protocolError,
      detail: 'too many redirects',
    );
  }

  Future<_Response> _once(
    String method,
    Uri uri,
    bool withAuth,
    Map<String, String> headers,
    List<int>? body,
    int maxBytes,
  ) async {
    final request = http.Request(method, uri)..followRedirects = false;
    request.headers.addAll(headers);
    if (withAuth) request.headers['Authorization'] = _authorization;
    if (body != null) request.bodyBytes = body;
    try {
      return await (() async {
        final streamed = await _client.send(request);
        final declared = streamed.contentLength;
        if (declared != null && declared > maxBytes) {
          throw SyncProviderException(
            ProviderErrorKind.payloadTooLarge,
            statusCode: streamed.statusCode,
          );
        }
        final builder = BytesBuilder(copy: false);
        await for (final chunk in streamed.stream) {
          builder.add(chunk);
          if (builder.length > maxBytes) {
            throw SyncProviderException(
              ProviderErrorKind.payloadTooLarge,
              statusCode: streamed.statusCode,
            );
          }
        }
        return _Response(
          streamed.statusCode,
          {
            for (final e in streamed.headers.entries)
              e.key.toLowerCase(): e.value
          },
          builder.takeBytes(),
        );
      })()
          .timeout(timeout);
    } on SyncProviderException {
      rethrow;
    } on TimeoutException {
      throw const SyncProviderException(ProviderErrorKind.timeout);
    } catch (_) {
      // Do not attach the original error: it may embed URLs/headers.
      throw const SyncProviderException(ProviderErrorKind.network);
    }
  }

  // ------------------------------------------------------ error mapping

  Duration? _retryAfter(Map<String, String> headers) {
    final raw = headers['retry-after']?.trim();
    if (raw == null || raw.isEmpty) return null;
    final secs = int.tryParse(raw);
    if (secs != null) return Duration(seconds: max(0, secs));
    try {
      final diff = HttpDate.parse(raw).difference(DateTime.now().toUtc());
      return diff.isNegative ? Duration.zero : diff;
    } catch (_) {
      return null;
    }
  }

  /// Throws the exception matching an unexpected [res] status.
  Never _fail(_Response res) {
    final s = res.status;
    final ProviderErrorKind kind;
    if (s == 401) {
      kind = ProviderErrorKind.unauthorized;
    } else if (s == 403) {
      kind = ProviderErrorKind.forbidden;
    } else if (s == 404 || s == 409) {
      kind = ProviderErrorKind.notFound;
    } else if (s == 412) {
      kind = ProviderErrorKind.preconditionFailed;
    } else if (s == 429 || s == 503) {
      throw SyncProviderException(
        ProviderErrorKind.rateLimited,
        statusCode: s,
        retryAfter: _retryAfter(res.headers),
      );
    } else if (s == 507) {
      kind = ProviderErrorKind.insufficientStorage;
    } else if (s >= 500) {
      kind = ProviderErrorKind.serverError;
    } else {
      kind = ProviderErrorKind.protocolError;
    }
    throw SyncProviderException(
      kind,
      statusCode: s,
      detail: s == 409 ? 'parent collection missing' : '',
    );
  }

  // ----------------------------------------------------------------- API

  @override
  Future<void> move(String from, String to) async {
    final fromUri = _uriFor(from);
    final toUri = _uriFor(to);
    if (!_sameOrigin(fromUri, toUri)) {
      throw const SyncProviderException(
        ProviderErrorKind.protocolError,
        detail: 'cross-origin move not supported',
      );
    }
    final res = await _send(
      'MOVE',
      fromUri,
      headers: {
        'Destination': toUri.toString(),
        'Overwrite': 'T',
      },
    );
    if (res.status == 201 || res.status == 204) {
      return;
    }
    _fail(res);
  }

  @override
  Future<DownloadedObject> get(String path) async {
    final res = await _send('GET', _uriFor(path));
    if (res.status != 200) _fail(res);
    return DownloadedObject(
      bytes: res.body,
      etag: res.headers['etag'],
      statusCode: res.status,
    );
  }

  @override
  Future<WriteResult> put(
    String path,
    Uint8List bytes, {
    String? ifMatch,
    bool createOnly = false,
  }) =>
      _put(_uriFor(path), bytes, ifMatch: ifMatch, createOnly: createOnly);

  Future<WriteResult> _put(
    Uri uri,
    List<int> bytes, {
    String? ifMatch,
    bool createOnly = false,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/octet-stream',
      if (createOnly) 'If-None-Match': '*',
      if (ifMatch != null) 'If-Match': _quoteEtag(ifMatch),
    };
    final res = await _send('PUT', uri, headers: headers, body: bytes);
    if (res.status == 200 || res.status == 201 || res.status == 204) {
      return WriteResult(
        statusCode: res.status,
        etag: res.headers['etag'],
        created: res.status == 201,
      );
    }
    _fail(res);
  }

  static String _quoteEtag(String etag) {
    final t = etag.trim();
    if (t == '*' || t.startsWith('"') || t.startsWith('W/"')) return t;
    return '"$t"';
  }

  @override
  Future<List<RemoteObject>> list(String directory) async {
    final dirSegs = _relSegments(directory);
    final res = await _send(
      'PROPFIND',
      _uriFor(directory, collection: true),
      headers: const {
        'Depth': '1',
        'Content-Type': 'application/xml; charset=utf-8',
      },
      body: utf8.encode(
        '<?xml version="1.0" encoding="utf-8"?>'
        '<d:propfind xmlns:d="DAV:"><d:prop>'
        '<d:getetag/><d:getcontentlength/><d:resourcetype/>'
        '</d:prop></d:propfind>',
      ),
      maxBytes: _maxXmlResponseBytes,
    );
    if (res.status != 207) _fail(res);
    final text = utf8.decode(res.body, allowMalformed: true);
    final lower = text.toLowerCase();
    if (lower.contains('<!doctype') || lower.contains('<!entity')) {
      throw SyncProviderException(
        ProviderErrorKind.protocolError,
        statusCode: res.status,
        detail: 'DTD not allowed',
      );
    }
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(text);
    } on XmlException {
      throw SyncProviderException(
        ProviderErrorKind.protocolError,
        statusCode: res.status,
        detail: 'malformed multistatus',
      );
    }

    final prefix = [..._rootSegments, ...dirSegs];
    final out = <RemoteObject>[];
    for (final response
        in _byLocal(doc.rootElement.descendantElements, 'response')) {
      final href = _text(_firstLocal(response, 'href'));
      if (href == null || href.isEmpty) continue;
      final List<String> segs;
      try {
        segs = Uri.parse(href.trim())
            .pathSegments
            .where((s) => s.isNotEmpty)
            .toList();
      } on FormatException {
        continue;
      }
      if (segs.length <= prefix.length) continue; // the directory itself
      var underDir = true;
      for (var i = 0; i < prefix.length; i++) {
        if (segs[i] != prefix[i]) {
          underDir = false;
          break;
        }
      }
      if (!underDir) continue;

      final prop = _firstLocal(_firstLocal(response, 'propstat'), 'prop');
      final etag = _normalizeEtag(_text(_firstLocal(prop, 'getetag')));
      final size =
          int.tryParse(_text(_firstLocal(prop, 'getcontentlength')) ?? '');
      final isDir =
          _firstLocal(_firstLocal(prop, 'resourcetype'), 'collection') != null;
      out.add(RemoteObject(
        path: [...dirSegs, ...segs.sublist(prefix.length)].join('/'),
        etag: etag,
        size: size,
        isDirectory: isDir,
      ));
    }
    return out;
  }

  static Iterable<XmlElement> _byLocal(Iterable<XmlElement> els, String name) =>
      els.where((e) => e.name.local == name);

  static XmlElement? _firstLocal(XmlElement? parent, String name) {
    if (parent == null) return null;
    for (final e in parent.descendantElements) {
      if (e.name.local == name) return e;
    }
    return null;
  }

  static String? _text(XmlElement? e) => e?.innerText.trim();

  static String? _normalizeEtag(String? raw) {
    if (raw == null) return null;
    var t = raw.trim();
    if (t.startsWith('W/')) t = t.substring(2);
    if (t.length >= 2 && t.startsWith('"') && t.endsWith('"')) {
      t = t.substring(1, t.length - 1);
    }
    return t.isEmpty ? null : t;
  }

  @override
  Future<Capabilities> probe() async {
    final id = List.generate(
      8,
      (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final tmpDir = '.probe-$id';
    final tmpUri = _uriFor(tmpDir, collection: true);
    final fileUri = _uriFor('$tmpDir/probe.bin');
    final payload = utf8.encode('suicun-probe');
    var madeDir = false;
    try {
      // 1. Create the probe object (creating the temp collection if needed).
      try {
        await _put(fileUri, payload, createOnly: true);
      } on SyncProviderException catch (e) {
        if (e.kind != ProviderErrorKind.notFound) rethrow;
        final mk = await _send('MKCOL', tmpUri);
        if (mk.status != 201 && mk.status != 200) _fail(mk);
        madeDir = true;
        await _put(fileUri, payload, createOnly: true);
      }

      // 2. Second create-only PUT must be rejected by a conforming server.
      var conditionalCreate = false;
      try {
        await _put(fileUri, payload, createOnly: true);
      } on SyncProviderException catch (e) {
        if (e.kind != ProviderErrorKind.preconditionFailed) rethrow;
        conditionalCreate = true;
      }

      // 3. A bogus If-Match must be rejected.
      var conditionalUpdate = false;
      final got = await _send('GET', fileUri);
      if (got.status != 200) _fail(got);
      if (got.headers['etag'] != null) {
        try {
          await _put(fileUri, payload,
              ifMatch: '"bogus-etag-that-cannot-exist"');
        } on SyncProviderException catch (e) {
          if (e.kind != ProviderErrorKind.preconditionFailed) rethrow;
          conditionalUpdate = true;
        }
      }
      return Capabilities(
        supportsConditionalCreate: conditionalCreate,
        supportsConditionalUpdate: conditionalUpdate,
      );
    } finally {
      await _delete(fileUri);
      if (madeDir) await _delete(tmpUri);
    }
  }

  /// Best-effort delete used for probe cleanup; errors are ignored.
  Future<void> _delete(Uri uri) async {
    try {
      await _send('DELETE', uri);
    } catch (_) {}
  }

  @override
  void close() => _client.close();
}

class _Response {
  const _Response(this.status, this.headers, this.body);

  final int status;
  final Map<String, String> headers;
  final Uint8List body;
}
