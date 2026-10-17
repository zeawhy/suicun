// test/widget/phase2_p1_interaction_test.dart
// Verification tests for Phase 2 (P1: 交互概念收敛, T6-T10)

import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/core/database/providers.dart';
import 'package:suicun/features/categories/domain/category_model.dart';
import 'package:suicun/features/records/data/quick_access_storage.dart';
import 'package:suicun/features/records/data/record_repository.dart';
import 'package:suicun/features/records/domain/record_model.dart';
import 'package:suicun/features/records/presentation/home_sort_provider.dart';
import 'package:suicun/features/records/presentation/quick_access_panel.dart';
import 'package:suicun/features/sync/sync_contract.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';
import 'package:suicun/main.dart';
import 'package:suicun/shared/theme/app_theme.dart';
import 'package:suicun/shared/widgets/record_card.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.dir);
  final Directory dir;

  @override
  Future<String?> getApplicationDocumentsPath() async => dir.path;
}

const kTransparentImageBytes = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

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
      ],
      child: SuicunApp(locale: locale),
    ),
  );
  await tester.pumpAndSettle();
}

Widget wrapCards(List<RecordDetail> records) {
  return MaterialApp(
    theme: AppTheme.lightTheme(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SlidableAutoCloseBehavior(
        child: ListView(
          children: [
            for (final record in records)
              RecordCard(
                record: record,
                sortMode: RecordSortMode.byUpdatedAt,
                isSelected: false,
                isMultiSelectMode: false,
                isQuickAccess: false,
                onQuickAccessToggle: () {},
                onFavoriteToggle: () {},
                onTap: () {},
                onLongPress: () {},
                onEdit: () {},
                onChangeCategory: () {},
                onDelete: () {},
                untitledLabel: '无标题',
                uncategorizedLabel: '未分类',
              ),
          ],
        ),
      ),
    ),
  );
}

Widget wrapCard({
  required RecordDetail record,
  bool isQuickAccess = false,
  VoidCallback? onQuickAccessToggle,
  VoidCallback? onFavoriteToggle,
  VoidCallback? onAnySlideAction,
  bool showSwipeHint = false,
  String? searchQuery,
}) {
  return MaterialApp(
    theme: AppTheme.lightTheme(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SlidableAutoCloseBehavior(
        child: ListView(
          children: [
            RecordCard(
              record: record,
              searchQuery: searchQuery,
              sortMode: RecordSortMode.byUpdatedAt,
              isSelected: false,
              isMultiSelectMode: false,
              isQuickAccess: isQuickAccess,
              onQuickAccessToggle: onQuickAccessToggle ?? () {},
              onFavoriteToggle: onFavoriteToggle ?? () {},
              onAnySlideAction: onAnySlideAction,
              showSwipeHint: showSwipeHint,
              onTap: () {},
              onLongPress: () {},
              onEdit: () {},
              onChangeCategory: () {},
              onDelete: () {},
              untitledLabel: '无标题',
              uncategorizedLabel: '未分类',
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late Directory tempDir;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    tempDir = Directory.systemTemp.createTempSync('p2_interaction_test_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir);
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('T6: 收藏 / 常用 交互概念收敛', () {
    testWidgets('RecordCard shows 12dp pin icon when isQuickAccess is true',
        (tester) async {
      final now = DateTime.now();
      final record = RecordDetail(
        record: RecordModel(
          id: 'rec-1',
          title: '常用条目',
          body: '测试内容',
          isFavorite: false,
          createdAt: now,
          updatedAt: now,
        ),
        tags: const [],
      );

      // 1. When isQuickAccess = false: no pin icon in header
      await tester.pumpWidget(wrapCard(record: record, isQuickAccess: false));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.push_pin), findsNothing);

      // 2. When isQuickAccess = true: header shows small pin icon
      await tester.pumpWidget(wrapCard(record: record, isQuickAccess: true));
      await tester.pumpAndSettle();
      final pinIcons = tester.widgetList<Icon>(find.byIcon(Icons.push_pin));
      expect(pinIcons.length, 1);
      expect(pinIcons.first.size, 12);
    });

    testWidgets('Home page left-slide toggles quick access and updates quick access grid',
        (tester) async {
      final repo = RecordRepository(db);
      await repo.createRecord(title: '我的银行卡', body: '普通内容');

      await pumpApp(tester, db);

      // Initially not in quick access grid
      expect(find.text('常用'), findsNothing);

      // Swipe left on the card
      await tester.drag(find.text('我的银行卡'), const Offset(-300, 0));
      await tester.pumpAndSettle();

      // SlidableAction has '设为常用'
      expect(find.text('设为常用'), findsOneWidget);
      await tester.tap(find.text('设为常用'));
      await tester.pumpAndSettle();

      // Now top quick access grid shows '常用' and 1/6
      expect(find.text('常用'), findsOneWidget);
      expect(find.text('1/6'), findsOneWidget);

      // Swipe left again -> now it says '取消常用'
      await tester.drag(find.text('我的银行卡').last, const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.text('取消常用'), findsOneWidget);

      // Tap '取消常用'
      await tester.tap(find.text('取消常用'));
      await tester.pumpAndSettle();

      // Quick access panel disappears
      expect(find.text('常用'), findsNothing);
    });
  });

  group('T7: 最近使用 Chip 图标与分类色统一', () {
    testWidgets('_RecentItemChip renders 14dp icon with category color',
        (tester) async {
      final now = DateTime.now();
      final testCategory = CategoryModel(
        id: 'cat-work',
        name: '工作',
        color: '#3265E5',
      );

      final record = RecordDetail(
        record: RecordModel(
          id: 'rec-recent-1',
          title: '工作便签',
          body: '网站/应用：GitHub\n用户名：admin\n密码：123456',
          categoryId: testCategory.id,
          isFavorite: false,
          createdAt: now,
          updatedAt: now,
        ),
        category: testCategory,
        tags: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: RecentOpenedBar(
              records: [record],
              onTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // RecentOpenedBar displays the chip
      expect(find.text('工作便签'), findsOneWidget);

      // In _RecentItemChip, an Icon with size 14 and category color is rendered
      final iconFinder = find.byIcon(Icons.lock_outline);
      expect(iconFinder, findsOneWidget);
      final iconWidget = tester.widget<Icon>(iconFinder);
      expect(iconWidget.size, 14);
      expect(iconWidget.color, const Color(0xFF3265E5));
    });
  });

  group('T8: 卡片右上角按钮对齐与尺寸', () {
    testWidgets('Header row has title, optional copy button (32x32), and star button (32x32) rightmost',
        (tester) async {
      final now = DateTime.now();
      // Record with copyable text (password)
      final recordWithCopy = RecordDetail(
        record: RecordModel(
          id: 'rec-pwd',
          title: '带复制按钮卡片',
          body: '网站/应用：Test\n用户名：alice\n密码：secret',
          isFavorite: false,
          createdAt: now,
          updatedAt: now,
        ),
        tags: const [],
      );

      // Record without copyable text (memo)
      final recordWithoutCopy = RecordDetail(
        record: RecordModel(
          id: 'rec-memo',
          title: '无复制按钮卡片',
          body: '普通记事备忘',
          isFavorite: true,
          createdAt: now,
          updatedAt: now,
        ),
        tags: const [],
      );

      await tester.pumpWidget(wrapCards([recordWithCopy, recordWithoutCopy]));
      await tester.pumpAndSettle();

      // Both star buttons should have width 32 and height 32
      final starOutlineButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.star_outline),
      );
      expect(starOutlineButton.constraints?.minWidth, 32);
      expect(starOutlineButton.constraints?.maxWidth, 32);
      expect(starOutlineButton.constraints?.minHeight, 32);
      expect(starOutlineButton.constraints?.maxHeight, 32);

      final starRoundedButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.star_rounded),
      );
      expect(starRoundedButton.constraints?.minWidth, 32);
      expect(starRoundedButton.constraints?.maxWidth, 32);
      expect(starRoundedButton.constraints?.minHeight, 32);
      expect(starRoundedButton.constraints?.maxHeight, 32);

      final copyButtons = tester.widgetList<IconButton>(
        find.widgetWithIcon(IconButton, Icons.copy_rounded),
      );
      expect(copyButtons.length, 1);
      expect(copyButtons.first.constraints?.minWidth, 32);
      expect(copyButtons.first.constraints?.maxWidth, 32);
      expect(copyButtons.first.constraints?.minHeight, 32);
      expect(copyButtons.first.constraints?.maxHeight, 32);

      // Right edges of star button on both cards should align
      final star1 = tester.getTopRight(find.byIcon(Icons.star_outline));
      final star2 = tester.getTopRight(find.byIcon(Icons.star_rounded));
      expect(star1.dx, equals(star2.dx));
    });
  });

  group('T9: 左滑提示 « 只引导一次', () {
    testWidgets('showSwipeHint=false does not render keyboard_double_arrow_left',
        (tester) async {
      final now = DateTime.now();
      final record = RecordDetail(
        record: RecordModel(
          id: 'rec-hint',
          title: '测试提示',
          body: '内容',
          isFavorite: false,
          createdAt: now,
          updatedAt: now,
        ),
        tags: const [],
      );

      await tester.pumpWidget(wrapCard(record: record, showSwipeHint: false));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.keyboard_double_arrow_left), findsNothing);

      await tester.pumpWidget(wrapCard(record: record, showSwipeHint: true));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.keyboard_double_arrow_left), findsOneWidget);
    });

    testWidgets('Home page displays swipe hint on first item only before any action is taken',
        (tester) async {
      final repo = RecordRepository(db);
      await repo.createRecord(title: '第一条记录', body: '内容1');
      await repo.createRecord(title: '第二条记录', body: '内容2');

      // 1. Initial launch with swipe_hint_seen = false: exactly 1 hint for the 1st card
      await pumpApp(tester, db, initialPrefs: {QuickAccessKeys.swipeHintSeen: false});
      expect(find.byIcon(Icons.keyboard_double_arrow_left), findsOneWidget);

      // 2. Perform a slide action on the 1st record
      await tester.drag(find.text('第一条记录'), const Offset(-300, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('设为常用'));
      await tester.pumpAndSettle();

      // Swipe hint disappears permanently
      expect(find.byIcon(Icons.keyboard_double_arrow_left), findsNothing);
    });

    testWidgets('Home page does not show swipe hint if swipe_hint_seen is already true in SharedPreferences',
        (tester) async {
      final repo = RecordRepository(db);
      await repo.createRecord(title: '第一条记录', body: '内容1');

      await pumpApp(tester, db, initialPrefs: {QuickAccessKeys.swipeHintSeen: true});
      expect(find.byIcon(Icons.keyboard_double_arrow_left), findsNothing);
    });
  });

  group('T10: 身份证照片缩略图默认模糊', () {
    testWidgets('RecordCard renders blurred image with visibility_off_outlined overlay for idDocument with photo',
        (tester) async {
      final photosDir = Directory('${tempDir.path}/id_photos')..createSync(recursive: true);
      final photoFile = File('${photosDir.path}/front.jpg');
      photoFile.writeAsBytesSync(kTransparentImageBytes);

      final now = DateTime.now();
      final record = RecordDetail(
        record: RecordModel(
          id: 'rec-id-photo',
          title: '居民身份证',
          body: '证件类型：身份证\n姓名：张三\n证件号码：110101199003072345\n证件照片正面：id_photos/front.jpg',
          isFavorite: false,
          createdAt: now,
          updatedAt: now,
        ),
        tags: const [],
      );

      await tester.runAsync(() async {
        await tester.pumpWidget(wrapCard(record: record));
        // Allow the FutureBuilder in _buildThumbnail to resolve
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      // Verify ImageFiltered with blur sigma 8 exists
      final imageFilteredFinder = find.byType(ImageFiltered);
      expect(imageFilteredFinder, findsOneWidget);
      final imageFiltered = tester.widget<ImageFiltered>(imageFilteredFinder);
      expect(imageFiltered.imageFilter, equals(ImageFilter.blur(sigmaX: 8, sigmaY: 8)));

      // Verify centered visibility_off_outlined icon exists
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });
  });
}
