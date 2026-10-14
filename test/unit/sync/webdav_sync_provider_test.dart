// test/unit/sync/webdav_sync_provider_test.dart
// Stage C: tests for WebdavSyncProvider using a scripted MockClient.

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:suicun/features/sync/sync_provider.dart';
import 'package:suicun/features/sync/webdav_sync_provider.dart';
import 'package:suicun/services/webdav_service.dart';

const _config = WebdavConfig(
  serverUrl: 'https://dav.example.com',
  username: 'alice',
  password: 's3cret-pass',
  directory: '/suicun vault',
);

final _authValue = 'Basic ${base64Encode(utf8.encode('alice:s3cret-pass'))}';

WebdavSyncProvider _provider(http.Client c) => WebdavSyncProvider(
      config: _config,
      client: c,
      random: Random(5),
    );

Matcher _providerError(ProviderErrorKind kind) => throwsA(
      isA<SyncProviderException>().having((e) => e.kind, 'kind', kind),
    );

http.Response _res(int status,
        {String body = '', Map<String, String> headers = const {}}) =>
    http.Response(body, status, headers: headers);

const _multistatus = '''<?xml version="1.0" encoding="utf-8"?>
<D:multistatus xmlns:D="DAV:">
  <D:response>
    <D:href>/suicun%20vault/objects/</D:href>
    <D:propstat><D:prop><D:resourcetype><D:collection/></D:resourcetype></D:prop>
    <D:status>HTTP/1.1 200 OK</D:status></D:propstat>
  </D:response>
  <D:response>
    <D:href>/suicun%20vault/objects/a%20b.enc</D:href>
    <D:propstat><D:prop>
      <D:getetag>"etag-1"</D:getetag>
      <D:getcontentlength>123</D:getcontentlength>
      <D:resourcetype/>
    </D:prop><D:status>HTTP/1.1 200 OK</D:status></D:propstat>
  </D:response>
  <D:response>
    <D:href>https://dav.example.com/suicun%20vault/objects/c.enc</D:href>
    <D:propstat><D:prop>
      <D:getetag>W/"etag-2"</D:getetag>
      <D:getcontentlength>45</D:getcontentlength>
    </D:prop></D:propstat>
  </D:response>
  <D:response>
    <D:href>/elsewhere/x.enc</D:href>
  </D:response>
</D:multistatus>''';

void main() {
  group('put', () {
    test('createOnly sends If-None-Match and reports created', () async {
      late http.Request seen;
      final p = _provider(MockClient((r) async {
        seen = r;
        return _res(201, headers: {'etag': '"e1"'});
      }));
      final r = await p.put('objects/x.enc', Uint8List.fromList([1, 2]),
          createOnly: true);
      expect(seen.method, 'PUT');
      expect(seen.headers['If-None-Match'], '*');
      expect(seen.headers['If-Match'], isNull);
      expect(seen.headers['Authorization'], _authValue);
      expect(seen.url.toString(),
          'https://dav.example.com/suicun%20vault/objects/x.enc');
      expect(seen.bodyBytes, [1, 2]);
      expect(r.created, isTrue);
      expect(r.statusCode, 201);
      expect(r.etag, '"e1"');
    });

    test('ifMatch sends If-Match, quoting only when needed', () async {
      final seen = <http.Request>[];
      final p = _provider(MockClient((r) async {
        seen.add(r);
        return _res(204);
      }));
      final a = await p.put('header.json', Uint8List(1), ifMatch: '"abc"');
      await p.put('header.json', Uint8List(1), ifMatch: 'abc');
      expect(seen[0].headers['If-Match'], '"abc"');
      expect(seen[1].headers['If-Match'], '"abc"');
      expect(a.created, isFalse);
    });

    test('status mapping', () async {
      final cases = <int, ProviderErrorKind>{
        412: ProviderErrorKind.preconditionFailed,
        401: ProviderErrorKind.unauthorized,
        403: ProviderErrorKind.forbidden,
        404: ProviderErrorKind.notFound,
        409: ProviderErrorKind.notFound,
        429: ProviderErrorKind.rateLimited,
        503: ProviderErrorKind.rateLimited,
        507: ProviderErrorKind.insufficientStorage,
        500: ProviderErrorKind.serverError,
        418: ProviderErrorKind.protocolError,
      };
      for (final e in cases.entries) {
        final p = _provider(MockClient((_) async => _res(e.key)));
        await expectLater(p.put('a', Uint8List(0)), _providerError(e.value),
            reason: '${e.key}');
      }
    });
  });

  group('ensureCollection', () {
    test('creates nested directories top-down using MKCOL', () async {
      final seenUris = <String>[];
      final seenMethods = <String>[];
      final p = _provider(MockClient((r) async {
        seenMethods.add(r.method);
        seenUris.add(r.url.toString());
        return _res(201);
      }));

      await p.ensureCollection('v2/keys');
      expect(seenMethods, ['MKCOL', 'MKCOL']);
      expect(seenUris, [
        'https://dav.example.com/suicun%20vault/v2/',
        'https://dav.example.com/suicun%20vault/v2/keys/',
      ]);
    });

    test('treats 200, 201, 405, and 409 as success (idempotent)', () async {
      final statuses = [201, 200, 405, 409];
      var idx = 0;
      final p = _provider(MockClient((r) async {
        final s = statuses[idx++ % statuses.length];
        return _res(s);
      }));

      // Does not throw
      await p.ensureCollection('a/b/c/d');
    });

    test('maps 401, 403, 507 to expected ProviderErrorKinds', () async {
      final p401 = _provider(MockClient((_) async => _res(401)));
      await expectLater(
        p401.ensureCollection('v2/keys'),
        _providerError(ProviderErrorKind.unauthorized),
      );

      final p403 = _provider(MockClient((_) async => _res(403)));
      await expectLater(
        p403.ensureCollection('v2/keys'),
        _providerError(ProviderErrorKind.forbidden),
      );

      final p507 = _provider(MockClient((_) async => _res(507)));
      await expectLater(
        p507.ensureCollection('v2/keys'),
        _providerError(ProviderErrorKind.insufficientStorage),
      );
    });
  });

  group('get', () {
    test('200 returns bytes and etag', () async {
      final p = _provider(MockClient(
          (_) async => _res(200, body: 'hello', headers: {'etag': '"v1"'})));
      final r = await p.get('header.json');
      expect(utf8.decode(r.bytes), 'hello');
      expect(r.etag, '"v1"');
      expect(r.statusCode, 200);
    });

    test('status mapping', () async {
      Future<void> check(http.Response res, ProviderErrorKind kind) =>
          expectLater(_provider(MockClient((_) async => res)).get('x'),
              _providerError(kind));
      await check(_res(404), ProviderErrorKind.notFound);
      await check(_res(401), ProviderErrorKind.unauthorized);
      await check(_res(403), ProviderErrorKind.forbidden);
      await check(_res(507), ProviderErrorKind.insufficientStorage);
      await check(_res(502), ProviderErrorKind.serverError);
    });

    test('429 carries Retry-After seconds', () async {
      final p = _provider(
          MockClient((_) async => _res(429, headers: {'Retry-After': '120'})));
      await expectLater(
        p.get('x'),
        throwsA(isA<SyncProviderException>()
            .having((e) => e.kind, 'kind', ProviderErrorKind.rateLimited)
            .having((e) => e.retryAfter, 'retryAfter',
                const Duration(seconds: 120))),
      );
    });

    test('503 Retry-After HTTP-date and absent header', () async {
      final when = DateTime.now().toUtc().add(const Duration(seconds: 90));
      final date = _httpDate(when);
      final p1 = _provider(
          MockClient((_) async => _res(503, headers: {'Retry-After': date})));
      try {
        await p1.get('x');
        fail('expected exception');
      } on SyncProviderException catch (e) {
        expect(e.retryAfter!.inSeconds, inInclusiveRange(80, 91));
      }
      final p2 = _provider(MockClient((_) async => _res(503)));
      try {
        await p2.get('x');
        fail('expected exception');
      } on SyncProviderException catch (e) {
        expect(e.retryAfter, isNull);
      }
    });

    test('oversized response is aborted', () async {
      final p = _provider(MockClient.streaming((req, _) async {
        final chunk = Uint8List(1024 * 1024);
        return http.StreamedResponse(
          Stream.fromIterable(List.generate(20, (_) => chunk)),
          200,
        );
      }));
      await expectLater(
          p.get('big'), _providerError(ProviderErrorKind.payloadTooLarge));
    });

    test('network errors and timeouts are mapped', () async {
      final net = _provider(
          MockClient((_) async => throw http.ClientException('boom')));
      await expectLater(
          net.get('x'), _providerError(ProviderErrorKind.network));

      final slow = WebdavSyncProvider(
        config: _config,
        timeout: const Duration(milliseconds: 20),
        client: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          return _res(200);
        }),
      );
      await expectLater(
          slow.get('x'), _providerError(ProviderErrorKind.timeout));
    });
  });

  group('list', () {
    test('parses multistatus and skips self / foreign hrefs', () async {
      late http.Request seen;
      final p = _provider(MockClient((r) async {
        seen = r;
        return _res(207, body: _multistatus);
      }));
      final items = await p.list('objects');
      expect(seen.method, 'PROPFIND');
      expect(seen.headers['Depth'], '1');
      expect(seen.url.path, '/suicun%20vault/objects/');
      expect(items, hasLength(2));
      expect(items[0].path, 'objects/a b.enc');
      expect(items[0].etag, 'etag-1');
      expect(items[0].size, 123);
      expect(items[0].isDirectory, isFalse);
      expect(items[1].path, 'objects/c.enc');
      expect(items[1].etag, 'etag-2');
      expect(items[1].size, 45);
    });

    test('namespace-agnostic: default namespace and other prefixes', () async {
      const xml = '<multistatus xmlns="DAV:"><response>'
          '<href>/suicun%20vault/sub/</href></response>'
          '<response><href>/suicun%20vault/sub/d/</href><propstat><prop>'
          '<resourcetype><collection/></resourcetype></prop></propstat>'
          '</response></multistatus>';
      final p = _provider(MockClient((_) async => _res(207, body: xml)));
      final items = await p.list('sub/');
      expect(items.single.path, 'sub/d');
      expect(items.single.isDirectory, isTrue);
      expect(items.single.etag, isNull);
    });

    test('DOCTYPE / ENTITY responses are rejected', () async {
      for (final evil in [
        '<?xml version="1.0"?><!DOCTYPE foo [<!ENTITY x "y">]>'
            '<d:multistatus xmlns:d="DAV:"/>',
        '<!doctype a><a/>',
        '<!entity x "y"><a/>',
      ]) {
        final p = _provider(MockClient((_) async => _res(207, body: evil)));
        await expectLater(
            p.list('objects'), _providerError(ProviderErrorKind.protocolError));
      }
    });

    test('malformed XML and status mapping', () async {
      await expectLater(
          _provider(MockClient((_) async => _res(207, body: '<a>')))
              .list('objects'),
          _providerError(ProviderErrorKind.protocolError));
      await expectLater(
          _provider(MockClient((_) async => _res(404))).list('objects'),
          _providerError(ProviderErrorKind.notFound));
      await expectLater(
          _provider(MockClient((_) async => _res(401))).list('objects'),
          _providerError(ProviderErrorKind.unauthorized));
    });
  });

  group('security', () {
    test('non-https config is rejected with no request', () {
      var requests = 0;
      final client = MockClient((_) async {
        requests++;
        return _res(200);
      });
      expect(
        () => WebdavSyncProvider(
          config: const WebdavConfig(
            serverUrl: 'http://dav.example.com',
            username: 'a',
            password: 'b',
            directory: '/x',
          ),
          client: client,
        ),
        throwsA(isA<SyncProviderException>()
            .having((e) => e.kind, 'kind', ProviderErrorKind.notHttps)),
      );
      expect(requests, 0);
    });

    test('invisible characters in URL are sanitized', () async {
      late Uri seen;
      final p = WebdavSyncProvider(
        config: const WebdavConfig(
          serverUrl: 'https://dav.example.com\u200b ',
          username: 'a',
          password: 'b',
          directory: 'x',
        ),
        client: MockClient((r) async {
          seen = r.url;
          return _res(200);
        }),
      );
      await p.get('header.json');
      expect(seen.toString(), 'https://dav.example.com/x/header.json');
    });

    test('cross-origin redirect on GET drops Authorization', () async {
      final seen = <http.Request>[];
      final p = _provider(MockClient((r) async {
        seen.add(r);
        if (seen.length == 1) {
          return _res(302, headers: {'location': 'https://cdn.other.net/file'});
        }
        return _res(200, body: 'ok');
      }));
      final r = await p.get('header.json');
      expect(utf8.decode(r.bytes), 'ok');
      expect(seen, hasLength(2));
      expect(seen[0].headers['Authorization'], _authValue);
      expect(seen[0].followRedirects, isFalse);
      expect(seen[1].url.host, 'cdn.other.net');
      expect(seen[1].headers.containsKey('Authorization'), isFalse);
    });

    test('same-origin relative redirect keeps Authorization', () async {
      final seen = <http.Request>[];
      final p = _provider(MockClient((r) async {
        seen.add(r);
        if (seen.length == 1) return _res(301, headers: {'location': '/moved'});
        return _res(200);
      }));
      await p.get('header.json');
      expect(seen[1].url.toString(), 'https://dav.example.com/moved');
      expect(seen[1].headers['Authorization'], _authValue);
    });

    test('cross-origin redirect on PUT is blocked', () async {
      var count = 0;
      final p = _provider(MockClient((r) async {
        count++;
        return _res(307, headers: {'location': 'https://evil.example.org/x'});
      }));
      await expectLater(p.put('a', Uint8List(1)),
          _providerError(ProviderErrorKind.redirectBlocked));
      expect(count, 1);
    });

    test('redirect loops are capped', () async {
      var count = 0;
      final p = _provider(MockClient((r) async {
        count++;
        return _res(302, headers: {'location': '/loop'});
      }));
      await expectLater(
          p.get('x'), _providerError(ProviderErrorKind.protocolError));
      expect(count, 6);
    });

    test('credentials never appear in exception text', () async {
      for (final status in [401, 403, 404, 412, 429, 507, 500]) {
        final p = _provider(MockClient((_) async => _res(status)));
        try {
          await p.put('a', Uint8List(0));
          fail('expected exception');
        } on SyncProviderException catch (e) {
          final text = '${e.toString()}|${e.detail}';
          expect(text.contains(_authValue), isFalse);
          expect(text.contains('s3cret-pass'), isFalse);
          expect(text.contains('alice'), isFalse);
          expect(text.contains(base64Encode(utf8.encode('alice:s3cret-pass'))),
              isFalse);
        }
      }
      final net = _provider(MockClient((r) async =>
          throw http.ClientException('failed ${r.headers['Authorization']}')));
      try {
        await net.get('x');
        fail('expected exception');
      } on SyncProviderException catch (e) {
        expect(e.toString().contains('Basic'), isFalse);
      }
    });
  });

  group('probe', () {
    test('detects conditional create and update; cleans up', () async {
      final seen = <http.Request>[];
      var puts = 0;
      final p = _provider(MockClient((r) async {
        seen.add(r);
        switch (r.method) {
          case 'PUT':
            puts++;
            return _res(puts == 1 ? 201 : 412);
          case 'GET':
            return _res(200, body: 'suicun-probe', headers: {'etag': '"p1"'});
          case 'DELETE':
            return _res(204);
        }
        return _res(500);
      }));
      final caps = await p.probe();
      expect(caps.supportsConditionalCreate, isTrue);
      expect(caps.supportsConditionalUpdate, isTrue);
      expect(seen.map((r) => r.method), ['PUT', 'PUT', 'GET', 'PUT', 'DELETE']);
      expect(seen[0].headers['If-None-Match'], '*');
      expect(seen[3].headers['If-Match'], '"bogus-etag-that-cannot-exist"');
      expect(
          seen[0].url.path,
          matches(
              RegExp(r'^/suicun%20vault/\.probe-[0-9a-f]{16}/probe\.bin$')));
      expect(seen.last.url, seen[0].url);
    });

    test('server ignoring preconditions reports unsupported', () async {
      final seen = <http.Request>[];
      final p = _provider(MockClient((r) async {
        seen.add(r);
        switch (r.method) {
          case 'PUT':
            return _res(r.headers.containsKey('If-Match') ? 204 : 201);
          case 'GET':
            return _res(200, headers: {'etag': '"p1"'});
          default:
            return _res(204);
        }
      }));
      final caps = await p.probe();
      expect(caps.supportsConditionalCreate, isFalse);
      expect(caps.supportsConditionalUpdate, isFalse);
      expect(seen.last.method, 'DELETE');
    });

    test('no ETag skips update test', () async {
      var puts = 0;
      final seen = <String>[];
      final p = _provider(MockClient((r) async {
        seen.add(r.method);
        if (r.method == 'PUT') return _res(++puts == 1 ? 201 : 412);
        return _res(r.method == 'GET' ? 200 : 204);
      }));
      final caps = await p.probe();
      expect(caps.supportsConditionalCreate, isTrue);
      expect(caps.supportsConditionalUpdate, isFalse);
      expect(seen, ['PUT', 'PUT', 'GET', 'DELETE']);
    });

    test('creates the temp collection when PUT gets 409', () async {
      final seen = <String>[];
      var puts = 0;
      final p = _provider(MockClient((r) async {
        seen.add(r.method);
        switch (r.method) {
          case 'PUT':
            puts++;
            if (puts == 1) return _res(409);
            return _res(puts == 2 ? 201 : 412);
          case 'MKCOL':
            return _res(201);
          case 'GET':
            return _res(200, headers: {'etag': '"p"'});
        }
        return _res(204);
      }));
      final caps = await p.probe();
      expect(caps.supportsConditionalCreate, isTrue);
      expect(seen.first, 'PUT');
      expect(seen[1], 'MKCOL');
      expect(seen.where((m) => m == 'DELETE'), hasLength(2));
    });

    test('unauthorized probe still attempts cleanup and throws', () async {
      final seen = <String>[];
      final p = _provider(MockClient((r) async {
        seen.add(r.method);
        return _res(401);
      }));
      await expectLater(
          p.probe(), _providerError(ProviderErrorKind.unauthorized));
      expect(seen, contains('DELETE'));
    });
  });
}

String _httpDate(DateTime t) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  String two(int n) => n.toString().padLeft(2, '0');
  return '${days[t.weekday - 1]}, ${two(t.day)} ${months[t.month - 1]} '
      '${t.year} ${two(t.hour)}:${two(t.minute)}:${two(t.second)} GMT';
}
