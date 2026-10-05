// test/widget/webdav_sync_page_test.dart
// Widget tests for the WebDAV sync page honesty rules:
// - status card never claims completion, shows "not configured" when empty
// - "Sync now" is disabled with the stage-C note
// - validation errors shown per field
// - "Test connection" uses the service result (mocked here)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suicun/features/settings/presentation/webdav_sync_page.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';
import 'package:suicun/services/webdav_service.dart';

class _FakeWebdavService extends WebdavService {
  _FakeWebdavService() : super();

  WebdavConfig? saved;
  WebdavProbeResult probeResult = const WebdavProbeResult(ok: true);

  @override
  Future<WebdavConfig?> loadConfig() async => saved;

  @override
  Future<void> saveConfig(WebdavConfig config) async {
    saved = config;
  }

  @override
  Future<WebdavProbeResult> testConnection(WebdavConfig config) async =>
      probeResult;
}

Future<void> pumpPage(WidgetTester tester, WebdavService fake) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        webdavServiceProvider.overrideWithValue(fake),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const WebdavSyncPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _fieldAt(int index) => find.byType(TextField).at(index);

void main() {
  testWidgets('shows not-configured status and disabled sync button',
      (tester) async {
    await pumpPage(tester, _FakeWebdavService());

    expect(find.text('Sync not configured'), findsOneWidget);
    expect(find.text('WebDAV Sync'), findsOneWidget);

    final syncNow =
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Sync Now'));
    expect(syncNow.onPressed, isNull);
    expect(
        find.text('Sync engine in development (Stage C)'), findsWidgets);
  });

  testWidgets('empty form shows validation errors on test connection',
      (tester) async {
    await pumpPage(tester, _FakeWebdavService());

    await tester.tap(find.text('Test Connection'));
    await tester.pumpAndSettle();

    // Service returns Chinese messages; they must be shown, not swallowed.
    expect(find.text('请输入 WebDAV 服务器地址'), findsOneWidget);
    expect(find.text('请输入用户名'), findsOneWidget);
  });

  testWidgets('successful probe shows success and saves config',
      (tester) async {
    final fake = _FakeWebdavService();
    await pumpPage(tester, fake);

    await tester.enterText(_fieldAt(0), 'https://dav.example.com');
    await tester.enterText(_fieldAt(1), 'alice');
    await tester.enterText(_fieldAt(2), 's3cret');
    await tester.pump();

    await tester.tap(find.text('Test Connection'));
    await tester.pumpAndSettle();

    expect(find.text('Connection successful'), findsOneWidget);
    expect(fake.saved, isNotNull);
    expect(fake.saved!.serverUrl, 'https://dav.example.com');
    expect(fake.saved!.username, 'alice');
  });

  testWidgets('failed probe shows the failure reason', (tester) async {
    final fake = _FakeWebdavService()
      ..probeResult = const WebdavProbeResult(
        ok: false,
        failure: WebdavProbeFailure.unauthorized,
        detail: '认证失败（HTTP 401），请检查用户名和密码',
      );
    await pumpPage(tester, fake);

    await tester.enterText(_fieldAt(0), 'https://dav.example.com');
    await tester.enterText(_fieldAt(1), 'alice');
    await tester.enterText(_fieldAt(2), 'wrong');
    await tester.pump();

    await tester.tap(find.text('Test Connection'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Connection failed'), findsOneWidget);
    expect(find.textContaining('认证失败'), findsOneWidget);
  });

  testWidgets('password visibility toggle works', (tester) async {
    await pumpPage(tester, _FakeWebdavService());

    expect(find.byTooltip('Show password'), findsOneWidget);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(find.byTooltip('Hide password'), findsOneWidget);
  });
}
