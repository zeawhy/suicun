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
import 'package:suicun/features/sync/sync_contract.dart';
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

Future<void> pumpPage(
  WidgetTester tester,
  WebdavService fake, {
  SyncOverview overview = const SyncOverview(enabled: false, syncing: false),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        webdavServiceProvider.overrideWithValue(fake),
        syncOverviewProvider
            .overrideWith((ref) => Stream<SyncOverview>.value(overview)),
        conflictsProvider
            .overrideWith((ref) => Stream<List<ConflictInfo>>.value(const [])),
        syncActionsProvider.overrideWithValue(_FakeSyncActions()),
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

/// Minimal fake so the page's action handlers resolve during widget tests.
class _FakeSyncActions implements SyncActions {
  @override
  Future<void> syncNow() async {}

  @override
  Future<void> setEnabled(bool enabled) async {}

  @override
  Future<void> disableSync({bool removeCredentials = false}) async {}

  @override
  Future<RemoteVaultCheck> checkRemoteVault(WebdavConfig config) async =>
      RemoteVaultCheck.noVault;

  @override
  Future<void> createVault(WebdavConfig config, String password) async {}

  @override
  Future<void> joinVault(
    WebdavConfig config, {
    String? password,
    String? recoveryKey,
  }) async {}

  @override
  Stream<RecoveryProgress> recoverFromRemote(
    WebdavConfig config, {
    String? password,
    String? recoveryKey,
  }) =>
      const Stream.empty();

  @override
  Future<void> resolveConflict(
    String conflictId,
    ConflictChoice choice, {
    String? mergedTitle,
    String? mergedBody,
  }) async {}

  @override
  String? consumePendingRecoveryKey() => null;
}

Finder _fieldAt(int index) => find.byType(TextField).at(index);

void main() {
  testWidgets('shows disabled status and disabled sync button when not enabled',
      (tester) async {
    await pumpPage(tester, _FakeWebdavService());

    // Status card + setup card both reflect the disabled state.
    expect(find.text('Sync disabled'), findsWidgets);
    expect(find.text('WebDAV Sync'), findsWidgets);

    // "Sync Now" is rendered but disabled while sync is not enabled.
    final syncNow = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Sync Now'));
    expect(syncNow.onPressed, isNull);
  });

  testWidgets('shows enabled status when the engine reports enabled',
      (tester) async {
    await pumpPage(
      tester,
      _FakeWebdavService(),
      overview: const SyncOverview(enabled: true, syncing: false),
    );

    expect(find.text('Sync enabled'), findsOneWidget);
    final syncNow = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Sync Now'));
    expect(syncNow.onPressed, isNotNull);
  });

  testWidgets('empty form shows validation errors on test connection',
      (tester) async {
    await pumpPage(tester, _FakeWebdavService());

    await tester.ensureVisible(find.text('Test Connection'));
    await tester.pumpAndSettle();
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

    await tester.ensureVisible(find.text('Test Connection'));
    await tester.pumpAndSettle();
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

    await tester.ensureVisible(find.text('Test Connection'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test Connection'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Connection failed'), findsOneWidget);
    expect(find.textContaining('认证失败'), findsOneWidget);
  });

  testWidgets('password visibility toggle works', (tester) async {
    await pumpPage(tester, _FakeWebdavService());

    await tester.ensureVisible(find.byTooltip('Show password'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Show password'), findsOneWidget);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(find.byTooltip('Hide password'), findsOneWidget);
  });
}
