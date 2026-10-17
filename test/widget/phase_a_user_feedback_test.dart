import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/core/database/providers.dart';
import 'package:suicun/features/records/data/quick_access_storage.dart';
import 'package:suicun/features/records/domain/record_model.dart';
import 'package:suicun/features/records/presentation/id_presentation_page.dart';
import 'package:suicun/features/settings/data/privacy_prefs.dart';
import 'package:suicun/features/settings/presentation/settings_page.dart';
import 'package:suicun/features/sync/sync_contract.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';
import 'package:suicun/main.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.dir);
  final Directory dir;

  @override
  Future<String?> getApplicationDocumentsPath() async => dir.path;
}

Future<void> pumpApp(
  WidgetTester tester,
  AppDatabase db, {
  Map<String, Object> initialPrefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(initialPrefs);
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWith((ref) => Future.value(prefs)),
        syncOverviewProvider.overrideWith(
          (ref) => Stream<SyncOverview>.value(
            const SyncOverview(enabled: false, syncing: false),
          ),
        ),
      ],
      child: const SuicunApp(locale: Locale('zh')),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  final List<String> hapticFeedbackCalls = [];
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('phase_a_test_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir);
    hapticFeedbackCalls.clear();
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    await p.clear();

    db = AppDatabase(NativeDatabase.memory());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        hapticFeedbackCalls.add(call.arguments as String? ?? 'vibrate');
      }
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.suivault.app/secure'),
      (call) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('github.com/aaassseee/screen_brightness'),
      (call) async {
        if (call.method == 'getApplicationScreenBrightness') return 0.5;
        return null;
      },
    );
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.suivault.app/secure'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('github.com/aaassseee/screen_brightness'),
      null,
    );
  });

  group('A1 & A2: 搜索交互与焦点、空白退出、返回键、FAB隐藏', () {
    testWidgets('overscroll triggers search with focus and haptic feedback', (tester) async {
      await pumpApp(tester, db, initialPrefs: {'onboarding_clipboard_asked': true});

      // Overscroll by dragging downwards on the CustomScrollView
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
      await tester.pumpAndSettle();

      // Search field should be visible
      expect(find.byType(TextField), findsOneWidget);
      // Haptic feedback should have been triggered
      expect(hapticFeedbackCalls, contains('HapticFeedbackType.selectionClick'));
    });

    testWidgets('blank tap on empty search cancels search and hides search bar', (tester) async {
      await pumpApp(tester, db, initialPrefs: {'onboarding_clipboard_asked': true});

      // Open search via search icon button
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      // FAB should be hidden in search state
      expect(find.byKey(const Key('home_speed_dial_fab')), findsNothing);

      // Tap blank area (the empty search prompt SliverFillRemaining)
      await tester.tap(find.text('输入关键词搜索全部记录'));
      await tester.pumpAndSettle();

      // Search canceled, search text field gone
      expect(find.byType(TextField), findsNothing);
      // FAB reappears
      expect(find.byKey(const Key('home_speed_dial_fab')), findsOneWidget);
    });

    testWidgets('back button in search cancels search rather than popping app', (tester) async {
      await pumpApp(tester, db, initialPrefs: {'onboarding_clipboard_asked': true});

      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);

      // Simulate system back button
      final popScopes = tester.widgetList(find.byWidgetPredicate((w) => w is PopScope));
      expect(popScopes.isNotEmpty, isTrue);
      final homePopScope = popScopes.first as PopScope;
      expect(homePopScope.canPop, isFalse);

      // Trigger back navigation
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Search should be canceled and app remains open
      expect(find.byType(TextField), findsNothing);
      expect(find.byKey(const Key('home_speed_dial_fab')), findsOneWidget);
    });
  });

  group('A3: 剪贴板识别授权引导与触发时机', () {
    testWidgets('shows onboarding bottom sheet on first launch when onboarding_clipboard_asked is false', (tester) async {
      await pumpApp(tester, db, initialPrefs: {'onboarding_clipboard_asked': false});

      // Onboarding bottom sheet should appear
      expect(find.text('开启剪贴板识别？'), findsOneWidget);
      expect(find.text('开启'), findsOneWidget);
      expect(find.text('暂不'), findsOneWidget);

      // Tap '开启'
      await tester.tap(find.text('开启'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(PrivacyPrefsKeys.onboardingClipboardAsked), isTrue);
      expect(prefs.getBool(PrivacyPrefsKeys.clipboardSniffEnabled), isTrue);
    });

    testWidgets('selecting 暂不 sets onboarding_clipboard_asked to true but keeps sniffing disabled', (tester) async {
      await pumpApp(tester, db, initialPrefs: {'onboarding_clipboard_asked': false});

      expect(find.text('开启剪贴板识别？'), findsOneWidget);

      // Tap '暂不'
      await tester.tap(find.text('暂不'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(PrivacyPrefsKeys.onboardingClipboardAsked), isTrue);
      expect(prefs.getBool(PrivacyPrefsKeys.clipboardSniffEnabled) ?? false, isFalse);
    });

    testWidgets('settings clear all data clears onboarding_clipboard_asked key', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(PrivacyPrefsKeys.onboardingClipboardAsked, true);
      await prefs.setBool(PrivacyPrefsKeys.presentAutoBrightness, true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWith((ref) => Future.value(prefs)),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('zh'),
            home: Scaffold(body: SettingsView()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to Danger Zone and tap clear all data
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      // ignore: avoid_print
      print('TEST: tapping 清除全部数据');
      await tester.tap(find.text('清除全部数据'));
      await tester.pumpAndSettle();

      // First confirmation dialog: tap '继续'
      // ignore: avoid_print
      print('TEST: tapping 继续, found=${find.text('继续').evaluate().length}');
      await tester.tap(find.text('继续'));
      await tester.pumpAndSettle();

      // Second confirmation dialog: tap '我确认要删除全部数据'
      // ignore: avoid_print
      print('TEST: tapping 我确认要删除全部数据, found=${find.text('我确认要删除全部数据').evaluate().length}');
      await tester.tap(find.text('我确认要删除全部数据'));
      await tester.pumpAndSettle();

      // ignore: avoid_print
      print('TEST: after dialogs, asked=${prefs.getBool(PrivacyPrefsKeys.onboardingClipboardAsked)}');
      // ignore: avoid_print
      print('TEST: snackbar found=${find.text('已清除全部数据').evaluate().length}');

      expect(prefs.containsKey(PrivacyPrefsKeys.onboardingClipboardAsked), isFalse);
      expect(prefs.containsKey(PrivacyPrefsKeys.presentAutoBrightness), isFalse);
    });
  });

  group('A4: 证件出示页亮度控制与360dp无溢出', () {
    testWidgets('IdPresentationPage 5 action buttons do not overflow on 360dp width screen', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = DateTime.now();
      final record = RecordDetail(
        record: RecordModel(
          id: 'test-id-1',
          title: '居民身份证',
          body: '证件类型：居民身份证\n姓名：张三\n证件号码：110101199003072345',
          isFavorite: false,
          createdAt: now,
          updatedAt: now,
        ),
        tags: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: IdPresentationPage(record: record),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('横屏'), findsOneWidget);
      expect(find.text('亮度'), findsOneWidget);
      expect(find.text('隐藏号码'), findsOneWidget);
      expect(find.text('复制号码'), findsOneWidget);
      expect(find.text('放大'), findsOneWidget);

      // Verify no RenderFlex overflow error was logged
      expect(tester.takeException(), isNull);

      // Tap 亮度 button to toggle brightness and pump all animation steps
      await tester.tap(find.text('亮度'));
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 30));
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('present_auto_brightness setting toggle exists in SettingsView', (tester) async {
      SharedPreferences.setMockInitialValues({
        'onboarding_clipboard_asked': true,
      });
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWith((ref) => Future.value(prefs)),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('zh'),
            home: Scaffold(body: SettingsView()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('出示时调高亮度'), findsOneWidget);
      expect(find.text('方便他人查看或扫码'), findsOneWidget);
    });
  });
}
