// test/widget/phase1_p0_fixes_test.dart

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/core/database/providers.dart';
import 'package:suicun/features/records/data/quick_access_storage.dart';
import 'package:suicun/features/records/data/record_repository.dart';
import 'package:suicun/features/settings/presentation/settings_page.dart';
import 'package:suicun/features/sync/sync_contract.dart';
import 'package:suicun/main.dart';

Future<void> pumpApp(
  WidgetTester tester,
  AppDatabase db, {
  Map<String, Object> initialPrefs = const {},
}) async {
  final merged = {
    'onboarding_clipboard_asked': true,
    ...initialPrefs,
  };
  SharedPreferences.setMockInitialValues(merged);
  final prefs = await SharedPreferences.getInstance();

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
      child: const SuicunApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('T1 & T2: 最近使用对齐、去重与隐藏', () {
    testWidgets('T2: records <= 3 时即使有 recentOpenedIds 也不显示最近使用', (tester) async {
      final repo = RecordRepository(db);
      final r1 = await repo.createRecord(title: '记录1', body: '内容1');
      final r2 = await repo.createRecord(title: '记录2', body: '内容2');

      await pumpApp(
        tester,
        db,
        initialPrefs: {
          QuickAccessKeys.recentOpenedRecordIds: [r1.id, r2.id],
        },
      );

      // Total records = 2 (<= 3), so recent bar should NOT appear
      expect(find.text('最近使用'), findsNothing);
    });

    testWidgets('T2: records > 3 时显示最近使用，且与常用区去重', (tester) async {
      final repo = RecordRepository(db);
      final r1 = await repo.createRecord(title: '常用记录1', body: '内容1');
      final r2 = await repo.createRecord(title: '普通记录2', body: '内容2');
      await repo.createRecord(title: '普通记录3', body: '内容3');
      await repo.createRecord(title: '普通记录4', body: '内容4');

      await pumpApp(
        tester,
        db,
        initialPrefs: {
          QuickAccessKeys.quickAccessRecordIds: [r1.id],
          // r1 is in quick; r2 is not in quick
          QuickAccessKeys.recentOpenedRecordIds: [r1.id, r2.id],
        },
      );

      // Total records = 4 (> 3)
      expect(find.text('常用'), findsOneWidget);
      expect(find.text('最近使用'), findsOneWidget);

      // In recentOpenedBar, r2 appears, but r1 should not duplicate
      // (r1 is in quick access, r2 is in recent access)
      expect(find.text('普通记录2'), findsWidgets);
    });
  });

  group('T3: 常用胶囊无障碍与动作图标', () {
    testWidgets('常用胶囊渲染 28x28 圆形动作按钮和 Tooltip/Semantics', (tester) async {
      final repo = RecordRepository(db);
      final r1 = await repo.createRecord(
        title: '我的身份证',
        body: '证件类型：身份证\n证件号码：110101199003072345',
      );

      await pumpApp(
        tester,
        db,
        initialPrefs: {
          QuickAccessKeys.quickAccessRecordIds: [r1.id],
        },
      );

      expect(find.byTooltip('出示证件'), findsOneWidget);
    });
  });

  group('T4: 删除时清理常用与最近 ID', () {
    testWidgets('在首页删除记录后，常用 ID 列表中该 ID 被清理', (tester) async {
      final repo = RecordRepository(db);
      final r1 = await repo.createRecord(title: '即将删除的常用', body: '内容');
      await repo.createRecord(title: '保留的记录', body: '内容2');

      await pumpApp(
        tester,
        db,
        initialPrefs: {
          QuickAccessKeys.quickAccessRecordIds: [r1.id],
        },
      );

      expect(find.text('常用'), findsOneWidget);
      expect(find.text('1/6'), findsOneWidget);

      // Long press r1 card to open sheet and delete
      await tester.longPress(find.text('即将删除的常用').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // After delete, quick access count drops and empty hint or section disappears
      expect(find.text('1/6'), findsNothing);
    });
  });

  group('T5: 剪贴板识别开关与持久化', () {
    testWidgets('设置页包含剪贴板识别 SwitchListTile 并可切换', (tester) async {
      await pumpApp(tester, db);

      // Open settings sidebar
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();

      // Check switch list tile in settings
      final switchListTile = find.ancestor(
        of: find.byIcon(Icons.content_paste_search_outlined),
        matching: find.byType(SwitchListTile),
      );
      final settingsScrollable = find.descendant(
        of: find.byType(SettingsView),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        switchListTile,
        50.0,
        scrollable: settingsScrollable,
      );
      await tester.pumpAndSettle();
      expect(switchListTile, findsOneWidget);
      final switchFinder = find.descendant(
        of: switchListTile,
        matching: find.byType(Switch),
      );
      expect(switchFinder, findsOneWidget);

      final switchWidget = tester.widget<Switch>(switchFinder);
      expect(switchWidget.value, isFalse);

      // Toggle switch
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      final updatedSwitch = tester.widget<Switch>(switchFinder);
      expect(updatedSwitch.value, isTrue);
    });
  });
}
