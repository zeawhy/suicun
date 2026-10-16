// test/widget/quick_access_redesign_test.dart

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/core/database/providers.dart';
import 'package:suicun/features/records/data/quick_access_storage.dart';
import 'package:suicun/features/records/data/record_repository.dart';
import 'package:suicun/features/records/domain/record_model.dart';
import 'package:suicun/features/records/presentation/id_presentation_page.dart';
import 'package:suicun/features/records/presentation/quick_access_panel.dart';
import 'package:suicun/features/sync/sync_contract.dart';
import 'package:suicun/main.dart';

Future<void> pumpApp(
  WidgetTester tester,
  AppDatabase db, {
  Map<String, Object> initialPrefs = const {},
  Locale? locale,
}) async {
  SharedPreferences.setMockInitialValues(initialPrefs);
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

  group('任务 1：常用大方块与空态提示', () {
    testWidgets('常用区为空时显示温和空态提示', (tester) async {
      final repo = RecordRepository(db);
      await repo.createRecord(title: '我的记事', body: '普通内容');

      await pumpApp(tester, db);

      // Verify the gentle empty hint is shown
      expect(find.text('长按任意记录可设为常用'), findsOneWidget);
    });

    testWidgets('有常用记录时显示收纳大方块及快捷动作按钮', (tester) async {
      final repo = RecordRepository(db);
      final r1 = await repo.createRecord(
        title: '身份证件',
        body: '证件类型：身份证\n姓名：李四\n证件号码：110101199003072345',
      );
      final r2 = await repo.createRecord(
        title: '路由器密码',
        body: '网站/应用：WiFi\n用户名：admin\n密码：secret123',
      );

      await pumpApp(
        tester,
        db,
        initialPrefs: {
          QuickAccessKeys.quickAccessRecordIds: [r1.id, r2.id],
        },
      );

      // Verify "常用" header is shown
      expect(find.text('常用'), findsOneWidget);
      expect(find.text('2/6'), findsOneWidget);

      // Verify quick action labels: 证件 -> 出示, 密码 -> 复制
      expect(find.byTooltip('出示'), findsOneWidget);
      expect(find.byTooltip('复制'), findsOneWidget);

      // Verify titles inside blocks
      expect(find.text('身份证件'), findsWidgets);
      expect(find.text('路由器密码'), findsWidgets);
    });

    testWidgets('长按记录可设为常用并在顶部网格呈现', (tester) async {
      final repo = RecordRepository(db);
      await repo.createRecord(title: '工作便签', body: '备忘事项');

      await pumpApp(tester, db);

      // Initially gentle empty hint is shown
      expect(find.text('长按任意记录可设为常用'), findsOneWidget);

      // Long press on the record card
      await tester.longPress(find.text('工作便签'));
      await tester.pumpAndSettle();

      // Bottom sheet appears with "设为常用" (or "Set as quick access" in en locale)
      final setQuickAccessFinder = find.byWidgetPredicate(
        (w) => w is Text && (w.data == '设为常用' || w.data == 'Set as quick access'),
      );
      expect(setQuickAccessFinder, findsOneWidget);
      await tester.tap(setQuickAccessFinder);
      await tester.pumpAndSettle();

      // Now "常用" section appears with the item and "查看" action
      expect(find.text('常用'), findsOneWidget);
      expect(find.byTooltip('查看'), findsOneWidget);
    });
  });

  group('任务 2：出示模式', () {
    testWidgets('点击出示进入全屏出示模式，包含顶部标题与底部 4 个操作', (tester) async {
      final now = DateTime.now().toUtc();
      final sampleRecord = RecordDetail(
        record: RecordModel(
          id: 'test_id_1',
          title: '居民身份证',
          body: '证件类型：身份证\n姓名：张三\n证件号码：110101199001011234',
          isFavorite: false,
          createdAt: now,
          updatedAt: now,
        ),
        tags: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: IdPresentationPage(record: sampleRecord),
        ),
      );
      await tester.pumpAndSettle();

      // Verify top header
      expect(find.textContaining('居民身份证'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Verify 4 bottom buttons: 横屏, 号码, 复制号码, 放大
      expect(find.text('横屏'), findsOneWidget);
      expect(find.text('隐藏号码'), findsOneWidget);
      expect(find.text('复制号码'), findsOneWidget);
      expect(find.text('放大'), findsOneWidget);

      // Tap toggle number visibility
      await tester.tap(find.text('隐藏号码'));
      await tester.pumpAndSettle();
      expect(find.text('显示号码'), findsOneWidget);
    });
  });

  group('任务 3：拼音首字母搜索与最近搜索', () {
    testWidgets('搜索框 placeholder 为「搜索标题、内容，支持拼音首字母」', (tester) async {
      await pumpApp(tester, db, locale: const Locale('zh'));

      // Expand search
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();

      expect(find.text('搜索标题、内容，支持拼音首字母'), findsOneWidget);
    });

    testWidgets('拼音首字母匹配：输入 sfz 搜到身份证，输入 dz 搜到地址', (tester) async {
      final repo = RecordRepository(db);
      await repo.createRecord(title: '二代身份证', body: '个人证件号码');
      await repo.createRecord(title: '公司地址', body: '北京市朝阳区');
      await repo.createRecord(title: '备忘备忘', body: '普通内容');

      await pumpApp(tester, db);

      // Open search
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();

      // Enter 'sfz'
      await tester.enterText(find.byType(TextField), 'sfz');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('二代身份证'), findsOneWidget);
      expect(find.text('公司地址'), findsNothing);
      expect(find.text('备忘备忘'), findsNothing);

      // Enter 'dz'
      await tester.enterText(find.byType(TextField), 'dz');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('公司地址'), findsOneWidget);
      expect(find.text('二代身份证'), findsNothing);
    });

    testWidgets('搜索框下方显示「最近搜索」chips，点击 chip 直接触发搜索', (tester) async {
      final repo = RecordRepository(db);
      await repo.createRecord(title: '身份证件', body: '号码');
      await repo.createRecord(title: '银行账户', body: '账号');

      await pumpApp(
        tester,
        db,
        initialPrefs: {
          QuickAccessKeys.recentSearchQueries: ['sfz', '银行'],
        },
      );

      // Open search
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();

      // Verify chips are displayed
      expect(find.text('sfz'), findsOneWidget);
      expect(find.text('银行'), findsOneWidget);

      // Tap '银行' chip
      await tester.tap(find.text('银行'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Search field is updated to '银行' and shows matching record
      expect(find.text('银行账户'), findsOneWidget);
      expect(find.text('身份证件'), findsNothing);
    });
  });

  group('P0-1 & P0-2：常用面板截断修复与尾号副标题', () {
    test('getQuickSubtitle idDocument 尾号显示与短数字保护', () {
      final now = DateTime.now().toUtc();
      // >= 8 位纯数字
      final rec1 = RecordDetail(
        record: RecordModel(
          id: '1',
          title: '身份证',
          body: '证件类型：身份证\n证件号码：330102199003074829',
          isFavorite: false,
          createdAt: now,
          updatedAt: now,
        ),
        tags: const [],
      );
      expect(getQuickSubtitle(rec1, QuickRecordType.idDocument), '尾号 4829');

      // 带 X
      final rec2 = RecordDetail(
        record: RecordModel(
          id: '2',
          title: '身份证',
          body: '证件类型：身份证\n证件号码：11010119900307234X',
          isFavorite: false,
          createdAt: now,
          updatedAt: now,
        ),
        tags: const [],
      );
      expect(getQuickSubtitle(rec2, QuickRecordType.idDocument), '尾号 234X');

      // <= 6 位短数字
      final rec3 = RecordDetail(
        record: RecordModel(
          id: '3',
          title: '临时证件',
          body: '证件类型：通行证\n证件号码：123456',
          isFavorite: false,
          createdAt: now,
          updatedAt: now,
        ),
        tags: const [],
      );
      expect(getQuickSubtitle(rec3, QuickRecordType.idDocument), '******');
    });

    testWidgets('count == 0 时可点击 × 关闭按钮隐藏引导条', (tester) async {
      await pumpApp(tester, db);

      expect(find.text('长按任意记录可设为常用'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('长按任意记录可设为常用'), findsNothing);
    });

    testWidgets('count == 1、2、3 项时的布局尺寸与表现', (tester) async {
      final repo = RecordRepository(db);
      final r1 = await repo.createRecord(title: '记录1', body: '普通内容1');
      final r2 = await repo.createRecord(title: '记录2', body: '普通内容2');
      final r3 = await repo.createRecord(title: '记录3', body: '普通内容3');

      // count == 1
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                child: QuickAccessGrid(
                  records: [r1],
                  onRecordAction: (_) {},
                  onLongPress: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('记录1'), findsOneWidget);
      final cardFinder1 = find.ancestor(
        of: find.text('记录1'),
        matching: find.byType(SizedBox),
      ).first;
      final size1 = tester.getSize(cardFinder1);
      // 通栏宽度 400 - horizontal padding 32 = 368
      expect(size1.width, closeTo(368, 1));

      // count == 2
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                child: QuickAccessGrid(
                  records: [r1, r2],
                  onRecordAction: (_) {},
                  onLongPress: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('记录1'), findsOneWidget);
      expect(find.text('记录2'), findsOneWidget);
      final cardFinder2 = find.ancestor(
        of: find.text('记录1'),
        matching: find.byType(SizedBox),
      ).first;
      final size2 = tester.getSize(cardFinder2);
      // (368 - 8) / 2 = 180
      expect(size2.width, closeTo(180, 1));

      // count >= 3
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                child: QuickAccessGrid(
                  records: [r1, r2, r3],
                  onRecordAction: (_) {},
                  onLongPress: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('记录1'), findsOneWidget);
      expect(find.text('记录2'), findsOneWidget);
      final cardFinder3 = find.ancestor(
        of: find.text('记录1'),
        matching: find.byType(SizedBox),
      ).first;
      final size3 = tester.getSize(cardFinder3);
      // (368 - 8) / 2.25 = 160
      expect(size3.width, closeTo(160, 1));
    });
  });
}
