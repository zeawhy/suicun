// test/widget/phase3_p2_layout_test.dart
// Verification tests for Phase 3 (P2: 布局与信息架构, T11-T15)

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/core/database/providers.dart';
import 'package:suicun/features/records/data/quick_access_storage.dart';
import 'package:suicun/features/records/data/record_repository.dart';
import 'package:suicun/core/crypto/key_value_store.dart';
import 'package:suicun/features/security/data/app_lock_service.dart';
import 'package:suicun/features/security/data/security_providers.dart';
import 'package:suicun/features/settings/presentation/settings_page.dart';
import 'package:suicun/features/sync/sync_contract.dart';
import 'package:suicun/main.dart';
import 'package:suicun/shared/widgets/record_card.dart';

Future<void> pumpApp(
  WidgetTester tester,
  AppDatabase db, {
  Map<String, Object> initialPrefs = const {},
  Locale locale = const Locale('zh'),
}) async {
  SharedPreferences.setMockInitialValues({
    'onboarding_clipboard_asked': true,
    ...initialPrefs,
  });
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
        appLockServiceProvider.overrideWithValue(
          AppLockService(store: MemoryKeyValueStore()),
        ),
      ],
      child: SuicunApp(locale: locale),
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

  group('T11: 搜索态精简', () {
    testWidgets('进入搜索态后隐藏常用与分类tab，输入前显示空搜索提示，搜索是全局的并支持取消恢复', (tester) async {
      final repo = RecordRepository(db);
      final r1 = await repo.createRecord(title: '工作记录', body: '内容一', isFavorite: true);
      await repo.createRecord(title: '生活备忘', body: '内容二');

      // 启动并配置常用
      await pumpApp(
        tester,
        db,
        initialPrefs: {
          QuickAccessKeys.quickAccessRecordIds: [r1.id],
        },
      );

      // 初始：常用区域与分类 Tab 可见
      expect(find.byType(RecordCard), findsNWidgets(2));
      expect(find.text('全部'), findsOneWidget);
      expect(find.text('常用'), findsOneWidget);

      // 点击收藏 tab 过滤
      await tester.tap(find.text('收藏'));
      await tester.pumpAndSettle();
      expect(find.text('工作记录'), findsOneWidget);
      expect(find.text('生活备忘'), findsNothing);

      // 点击搜索按钮展开搜索态
      await tester.tap(find.byTooltip('搜索'));
      await tester.pumpAndSettle();

      // 1. showQuickAndRecent 为 false（常用区域隐藏）
      expect(find.text('常用'), findsNothing);

      // 2. 分类 tab 不渲染
      expect(find.text('全部'), findsNothing);

      // 3. 搜索框 placeholder 符合 spec
      expect(find.text('搜索标题、内容，支持拼音首字母'), findsOneWidget);

      // 4. query 为空时不渲染记录卡片，显示居中提示与 search 图标
      expect(find.byType(RecordCard), findsNothing);
      expect(find.text('输入关键词搜索全部记录'), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);

      // 5. 输入关键词后，全局搜索命中记录（包括生活备忘，证明分类已在进入搜索时重置为全局）
      await tester.enterText(find.byType(TextField), '生活');
      await tester.pumpAndSettle();
      expect(find.text('生活备忘'), findsOneWidget);
      expect(find.text('输入关键词搜索全部记录'), findsNothing);

      // 6. 取消搜索后，恢复原收藏筛选与分类 Tab
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('全部'), findsOneWidget);
      expect(find.text('工作记录'), findsOneWidget);
      expect(find.text('生活备忘'), findsNothing); // 依然在收藏筛选下
    });
  });

  group('T12: 分类 tab 渐隐、管理入口与收藏图标', () {
    testWidgets('分类栏包含右侧渐隐、管理按钮与收藏 star 图标', (tester) async {
      final repo = RecordRepository(db);
      await repo.createRecord(title: '测试记录', body: '测试');

      await pumpApp(tester, db);

      // 包含管理分类按钮，tooltip 为管理分类，图标为 Icons.tune_rounded
      final manageButtonFinder = find.byTooltip('管理分类');
      expect(manageButtonFinder, findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);

      // 包含 ShaderMask
      expect(find.byType(ShaderMask), findsWidgets);

      // 收藏 tab 前有 14dp 的 Icons.star_rounded
      final favTabIcon = find.descendant(
        of: find.widgetWithText(InkWell, '收藏'),
        matching: find.byIcon(Icons.star_rounded),
      );
      expect(favTabIcon, findsOneWidget);
    });
  });

  group('T13: 释放底栏，设置移到顶部左侧，FAB 悬浮', () {
    testWidgets('顶部左侧包含菜单按钮打开设置抽屉，FAB 悬浮且无底栏白条', (tester) async {
      await pumpApp(tester, db);

      // 底部无 BottomNavigationBar 容器
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.bottomNavigationBar, isNull);

      // 顶部左侧有 menu_rounded 按钮，tooltip 为设置
      final menuFinder = find.byIcon(Icons.menu_rounded);
      expect(menuFinder, findsOneWidget);
      expect(find.byTooltip('设置'), findsOneWidget);

      // FAB 已移出 Scaffold，改为 Stack 中的 Positioned（Round 6 §2）
      // 不再使用 floatingActionButton / floatingActionButtonLocation
      expect(scaffold.floatingActionButton, isNull);
      expect(scaffold.floatingActionButtonLocation, isNull);
      // FAB 应在 Stack 中通过 Positioned 定位
      expect(find.byType(Positioned), findsWidgets);

      // 点击菜单按钮打开设置抽屉
      await tester.tap(menuFinder);
      await tester.pumpAndSettle();
      expect(find.byType(SettingsView), findsOneWidget);

      // 点击返回关闭设置抽屉
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(SettingsView), findsNothing);

      // 打开 Speed Dial
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('空白速记'), findsOneWidget);

      // 返回键优先关闭 Speed Dial
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('空白速记'), findsNothing);
    });
  });

  group('T14: 记录少时显示快速添加', () {
    testWidgets('有 1 条记录时显示快速添加区块及 4 个模板胶囊', (tester) async {
      final repo = RecordRepository(db);
      await repo.createRecord(title: '单条记录', body: '测试');

      await pumpApp(tester, db);

      // 存在快速添加标题
      expect(find.text('快速添加'), findsOneWidget);

      // 包含 4 个模板胶囊
      expect(find.byKey(const Key('quick_add_item_blank')), findsOneWidget);
      expect(find.byKey(const Key('quick_add_item_id_document')), findsOneWidget);
      expect(find.byKey(const Key('quick_add_item_password')), findsOneWidget);
      expect(find.byKey(const Key('quick_add_item_address')), findsOneWidget);
    });

    testWidgets('记录数 >= 3 时不显示快速添加区块', (tester) async {
      final repo = RecordRepository(db);
      await repo.createRecord(title: '记录 1', body: '测试 1');
      await repo.createRecord(title: '记录 2', body: '测试 2');
      await repo.createRecord(title: '记录 3', body: '测试 3');

      await pumpApp(tester, db);

      expect(find.text('快速添加'), findsNothing);
      expect(find.byKey(const Key('quick_add_item_blank')), findsNothing);
    });
  });

  group('T15: 设置页信息架构', () {
    testWidgets('设置页包含备份与同步、安全与隐私、危险操作分组且主题支持弹窗单选', (tester) async {
      await pumpApp(tester, db);

      // 打开设置
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();

      // 校验前部区域分组与项
      expect(find.text('外观'), findsOneWidget);
      expect(find.text('数据'), findsOneWidget);

      // 主题 tile 点击弹出底部单选 sheet
      expect(find.text('跟随系统'), findsOneWidget);
      await tester.tap(find.text('主题'));
      await tester.pumpAndSettle();

      // Sheet 中有 3 个选项，当前选中项带勾选图标
      expect(find.text('深色'), findsOneWidget);
      expect(find.text('浅色'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);

      // 选择深色模式
      await tester.tap(find.text('深色'));
      await tester.pumpAndSettle();
      expect(find.text('深色'), findsOneWidget);

      final settingsScrollable = find.descendant(
        of: find.byType(SettingsView),
        matching: find.byType(Scrollable),
      );

      // 滚动至 备份与同步
      await tester.scrollUntilVisible(
        find.text('备份与同步'),
        50.0,
        scrollable: settingsScrollable,
      );
      await tester.pumpAndSettle();
      expect(find.text('备份与同步'), findsOneWidget);
      expect(find.text('备份与导出'), findsOneWidget);
      expect(find.text('WebDAV 同步'), findsOneWidget);

      // 滚动至 安全与隐私
      await tester.scrollUntilVisible(
        find.text('安全与隐私'),
        50.0,
        scrollable: settingsScrollable,
      );
      await tester.pumpAndSettle();
      expect(find.text('安全与隐私'), findsOneWidget);
      expect(find.text('应用锁'), findsOneWidget);
      expect(find.text('未开启'), findsOneWidget);
      expect(find.text('剪贴板识别'), findsOneWidget);

      // 滚动到最底部，校验 关于 与 危险操作
      await tester.scrollUntilVisible(
        find.text('危险操作'),
        50.0,
        scrollable: settingsScrollable,
      );
      await tester.pumpAndSettle();

      expect(find.text('关于'), findsOneWidget);
      expect(find.text('危险操作'), findsOneWidget);
      expect(find.text('清除全部数据'), findsOneWidget);
    });
  });
}
