// test/widget/phase_b_home_details_test.dart
// Tests for Phase B: 首页细节 (B1, B2, B3, B4)

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suicun/core/crypto/key_value_store.dart';
import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/core/database/providers.dart';
import 'package:suicun/features/categories/data/category_repository.dart';
import 'package:suicun/features/records/data/quick_access_storage.dart';
import 'package:suicun/features/records/data/record_repository.dart';
import 'package:suicun/features/records/domain/record_model.dart';
import 'package:suicun/features/records/presentation/home_sort_provider.dart';
import 'package:suicun/features/records/presentation/id_presentation_page.dart';
import 'package:suicun/features/records/presentation/quick_access_panel.dart';
import 'package:suicun/features/security/data/app_lock_service.dart';
import 'package:suicun/features/security/data/security_providers.dart';
import 'package:suicun/features/sync/sync_contract.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';
import 'package:suicun/main.dart';
import 'package:suicun/shared/theme/app_theme.dart';
import 'package:suicun/shared/widgets/record_card.dart';

Future<void> pumpApp(
  WidgetTester tester,
  AppDatabase db, {
  Map<String, Object> initialPrefs = const {},
  Locale locale = const Locale('zh'),
}) async {
  SharedPreferences.setMockInitialValues({
    'onboarding_clipboard_asked': true,
    'swipe_hint_seen': false,
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

  Widget wrapWithTheme(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.lightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
  }

  group('B1: 左滑提示改叠加', () {
    final now = DateTime.now();
    final sampleRecord = RecordDetail(
      record: RecordModel(
        id: 'rec-1',
        title: '测试卡片',
        body: '证件类型：身份证\n证件号码：110101199003072391',
        isFavorite: false,
        createdAt: now,
        updatedAt: now,
      ),
      tags: const [],
    );

    Widget buildCard({required bool showSwipeHint}) {
      return wrapWithTheme(
        RecordCard(
          record: sampleRecord,
          sortMode: RecordSortMode.byUpdatedAt,
          isSelected: false,
          isMultiSelectMode: false,
          untitledLabel: '未命名记录',
          uncategorizedLabel: '未分类',
          onTap: () {},
          onLongPress: () {},
          onFavoriteToggle: () {},
          isQuickAccess: false,
          onQuickAccessToggle: () {},
          onEdit: () {},
          onChangeCategory: () {},
          onDelete: () {},
          showSwipeHint: showSwipeHint,
        ),
      );
    }

    testWidgets('星标和时间位置在有无提示时完全对齐', (tester) async {
      // 1. 无左滑提示
      await tester.pumpWidget(buildCard(showSwipeHint: false));
      await tester.pumpAndSettle();

      final starFinderNoHint = find.byIcon(Icons.star_outline);
      final starTopRightNoHint = tester.getTopRight(starFinderNoHint);

      // 2. 有左滑提示
      await tester.pumpWidget(buildCard(showSwipeHint: true));
      await tester.pumpAndSettle();

      final starFinderWithHint = find.byIcon(Icons.star_outline);
      final starTopRightWithHint = tester.getTopRight(starFinderWithHint);

      // x 坐标必须完全一致，不受提示图标影响
      expect(starTopRightWithHint.dx, equals(starTopRightNoHint.dx));

      // 且提示图标是 IgnorePointer(ignoring: true) 包裹的叠加元素
      expect(find.byIcon(Icons.keyboard_double_arrow_left), findsOneWidget);
      final ignorePointer = tester.widget<IgnorePointer>(
        find.ancestor(
          of: find.byIcon(Icons.keyboard_double_arrow_left),
          matching: find.byWidgetPredicate((w) => w is IgnorePointer && w.ignoring),
        ),
      );
      expect(ignorePointer.ignoring, isTrue);
    });
  });

  group('B2: 智能默认标题 displayTitleFor', () {
    final now = DateTime.now();

    testWidgets('RecordCard, QuickAccessCapsule, RecentItemChip, IdPresentationPage 统一使用智能标题',
        (tester) async {
      final idRecord = RecordDetail(
        record: RecordModel(
          id: 'id-doc-1',
          title: '', // 空标题
          body: '证件类型：居民身份证\n姓名：王小二\n证件号码：110101199003072391',
          isFavorite: false,
          createdAt: now,
          updatedAt: now,
        ),
        tags: const [],
      );

      // 1. RecordCard
      await tester.pumpWidget(wrapWithTheme(
        RecordCard(
          record: idRecord,
          sortMode: RecordSortMode.byUpdatedAt,
          isSelected: false,
          isMultiSelectMode: false,
          untitledLabel: '未命名记录',
          uncategorizedLabel: '未分类',
          onTap: () {},
          onLongPress: () {},
          onFavoriteToggle: () {},
          isQuickAccess: false,
          onQuickAccessToggle: () {},
          onEdit: () {},
          onChangeCategory: () {},
          onDelete: () {},
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('China Resident ID · 王小二'), findsOneWidget);

      // 2. QuickAccessGrid 中的胶囊
      await tester.pumpWidget(wrapWithTheme(
        QuickAccessGrid(
          records: [idRecord],
          onRecordAction: (_) {},
          onLongPress: (_) {},
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('China Resident ID · 王小二'), findsOneWidget);

      // 3. RecentOpenedBar 中的 chip
      await tester.pumpWidget(wrapWithTheme(
        RecentOpenedBar(
          records: [idRecord],
          onTap: (_) {},
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('China Resident ID · 王小二'), findsOneWidget);

      // 4. IdPresentationPage 顶部出示标题
      await tester.pumpWidget(wrapWithTheme(
        IdPresentationPage(record: idRecord),
      ));
      await tester.pumpAndSettle();
      expect(find.text('China Resident ID · 王小二'), findsWidgets);

      // 清理 IdPresentationPage 退出时的计时器
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('EditRecordPage 保存证件模板时若标题为空自动写入智能标题', (tester) async {
      final repo = RecordRepository(db);
      final r = await repo.createRecord(
        title: '',
        body: '证件类型：护照\n姓名：李四\n证件号码：E88888888',
      );

      await pumpApp(tester, db);

      // 首页由于智能标题已显示 "护照 · 李四"
      expect(find.text('护照 · 李四'), findsOneWidget);

      // 点击该卡片进入编辑页
      await tester.tap(find.text('护照 · 李四'));
      await tester.pumpAndSettle();

      // 返回首页触发 PopScope 保存
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // 检查数据库记录标题已被自动填充持久化
      final updated = await repo.getRecord(r.id);
      expect(updated?.title, equals('护照 · 李四'));
    });
  });

  group('B3: 常用标记 📌 条件显示', () {
    testWidgets('常用面板可见时不显示 📌，筛选态显示 📌', (tester) async {
      final repo = RecordRepository(db);
      final catRepo = CategoryRepository(db);
      final cat = await catRepo.createCategory('个人', '#4A90E2');

      final r1 = await repo.createRecord(
        title: '常用证件',
        body: '证件类型：身份证\n证件号码：110101199003072391',
        categoryId: cat.id,
      );
      await repo.createRecord(
        title: '普通笔记',
        body: '普通的备忘内容',
        categoryId: cat.id,
      );

      // 将 r1 设为常用
      await pumpApp(
        tester,
        db,
        initialPrefs: {
          QuickAccessKeys.quickAccessRecordIds: [r1.id],
        },
      );

      // 1. 首页默认态（常用面板可见）：列表卡片中不显示 📌
      // (此时列表中只有滑动操作菜单可能有 pin icon，卡片标题旁没有 12dp 的 push_pin)
      final pushPinsInHeader = tester
          .widgetList<Icon>(find.byIcon(Icons.push_pin))
          .where((icon) => icon.size == 12)
          .toList();
      expect(pushPinsInHeader, isEmpty);

      // 2. 点击分类栏中的「个人」标签进入筛选态（常用面板隐藏）
      final categoryTab = find.descendant(
        of: find.byType(SliverPersistentHeader),
        matching: find.text('个人'),
      );
      await tester.tap(categoryTab);
      await tester.pumpAndSettle();

      // 筛选态下常用面板已隐藏，r1 列表中显示 📌
      final pushPinsInFilter = tester
          .widgetList<Icon>(find.byIcon(Icons.push_pin))
          .where((icon) => icon.size == 12)
          .toList();
      expect(pushPinsInFilter.length, 1);
    });
  });

  group('B4: 快速添加 4 列网格', () {
    testWidgets('快速添加使用 4 列 GridView 竖排呈现', (tester) async {
      final repo = RecordRepository(db);
      await repo.createRecord(title: '单条测试记录', body: '测试内容');

      await pumpApp(tester, db);

      // 1. 存在快速添加标题
      expect(find.text('快速添加'), findsOneWidget);

      // 2. 存在 4 列 GridView
      final gridFinder = find.byType(GridView);
      expect(gridFinder, findsOneWidget);

      final gridView = tester.widget<GridView>(gridFinder);
      final delegate =
          gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 4);

      // 3. 4 个快速添加入口均存在
      expect(find.byKey(const Key('quick_add_item_blank')), findsOneWidget);
      expect(
          find.byKey(const Key('quick_add_item_id_document')), findsOneWidget);
      expect(find.byKey(const Key('quick_add_item_password')), findsOneWidget);
      expect(find.byKey(const Key('quick_add_item_address')), findsOneWidget);

      // 4. 每个入口包含 40dp 圆形图标容器和 12sp 文字
      final iconContainers = tester.widgetList<Container>(
        find.descendant(
          of: find.byKey(const Key('quick_add_item_blank')),
          matching: find.byType(Container),
        ),
      );
      final roundContainer = iconContainers.firstWhere(
        (c) => c.constraints?.maxWidth == 40 && c.constraints?.maxHeight == 40,
      );
      expect(roundContainer, isNotNull);

      final text = tester.widget<Text>(find.text('空白速记'));
      expect(text.style?.fontSize, 12);
    });
  });
}
