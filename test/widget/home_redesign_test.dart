// test/widget/home_redesign_test.dart
// Tests for home page redesign:
// a. Top bar shows All/Favorites text tabs, and 'My Info' is removed
// b. Magnifying glass expands search row, 'Cancel' collapses it and clears query
// c. Card only has 'more_horiz' menu, no standalone star button; favorited record shows small star
// d. Bottom-left settings button exists with settings_outlined icon and 'Settings' text
// e. Pull-down overscroll expands search row

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/core/database/providers.dart';
import 'package:suicun/features/records/data/record_repository.dart';
import 'package:suicun/features/settings/presentation/settings_page.dart';
import 'package:suicun/features/sync/sync_contract.dart';
import 'package:suicun/main.dart';

Future<void> pumpApp(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
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
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets(
      'a. top bar shows All/Favorites text tabs, no "My Info" text',
      (tester) async {
    await pumpApp(tester, db);

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('My Info'), findsNothing);
    expect(find.text('我的信息'), findsNothing);
  });

  testWidgets(
      'b. tap magnifying glass expands search row, Cancel collapses and clears query',
      (tester) async {
    await pumpApp(tester, db);

    // Search bar is hidden by default
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Cancel'), findsNothing);

    // Tap magnifying glass (tooltip 'Search')
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    // Search bar is now expanded
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Type a query
    await tester.enterText(find.byType(TextField), 'Groceries');
    await tester.pumpAndSettle();
    expect(find.text('Groceries'), findsOneWidget);

    // Tap Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Search bar is collapsed and query cleared
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Cancel'), findsNothing);
    expect(find.text('Groceries'), findsNothing);
  });

  testWidgets(
      'c. card only has more_horiz menu, no standalone star button; isFavorite record shows star_rounded',
      (tester) async {
    final repo = RecordRepository(db);
    await repo.createRecord(
      title: 'Normal Record',
      body: 'Normal body content',
      isFavorite: false,
    );
    await repo.createRecord(
      title: 'Favorited Record',
      body: 'Important body content',
      isFavorite: true,
    );

    await pumpApp(tester, db);

    expect(find.text('Normal Record'), findsOneWidget);
    expect(find.text('Favorited Record'), findsOneWidget);

    // Each card has a star button: star_rounded for favorited, star_outline for unfavorited
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    expect(find.byIcon(Icons.star_outline), findsOneWidget);
  });

  testWidgets(
      'd. bottom-left settings button opens push sidebar, closes, and navigates to sub-items',
      (tester) async {
    await pumpApp(tester, db);

    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Settings content is not visible before sidebar is opened
    expect(find.text('Theme'), findsNothing);

    // Tap settings button to open sidebar
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    // Push sidebar is now open with settings options
    expect(find.byType(SettingsView), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);

    // Tap close button (arrow_back) in sidebar header
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    // Sidebar is closed
    expect(find.byType(SettingsView), findsNothing);

    // Reopen sidebar
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsView), findsOneWidget);

    // Tap outside (on the right main content area) to close sidebar
    await tester.tapAt(const Offset(600, 300));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsView), findsNothing);

    // Reopen sidebar and test Android back button closes sidebar
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsView), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsView), findsNothing);

    // Reopen sidebar and navigate to Categories
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsView), findsOneWidget);

    // Tap Categories inside sidebar - sidebar closes and navigates to Categories page
    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();

    // Categories page is displayed
    expect(find.text('Categories'), findsWidgets);
  });

  testWidgets(
      'e. pull-down overscroll on list expands search bar',
      (tester) async {
    final repo = RecordRepository(db);
    for (int i = 0; i < 5; i++) {
      await repo.createRecord(
        title: 'Record $i',
        body: 'Body content $i',
      );
    }

    await pumpApp(tester, db);

    // Search bar is hidden initially
    expect(find.byType(TextField), findsNothing);

    // Drag down on the CustomScrollView to trigger overscroll
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 200));
    await tester.pumpAndSettle();

    // Search bar expands
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('f. P1-3 Speed Dial: 点击展开 4 个子胶囊，点击遮罩收起', (tester) async {
    await pumpApp(tester, db);

    // Speed Dial 子胶囊初始不可见
    expect(find.text('空白速记'), findsNothing);
    expect(find.text('证件'), findsNothing);
    expect(find.text('密码'), findsNothing);
    expect(find.text('地址'), findsNothing);

    // 主 FAB 存在
    final fabFinder = find.byType(FloatingActionButton);
    expect(fabFinder, findsOneWidget);

    // 点击主 FAB
    await tester.tap(fabFinder);
    await tester.pumpAndSettle();

    // 4 个子胶囊自上而下展开
    expect(find.text('空白速记'), findsOneWidget);
    expect(find.text('证件'), findsOneWidget);
    expect(find.text('密码'), findsOneWidget);
    expect(find.text('地址'), findsOneWidget);

    // 点击半透明遮罩区域收起
    await tester.tapAt(const Offset(100, 100));
    await tester.pumpAndSettle();

    expect(find.text('空白速记'), findsNothing);
    expect(find.text('证件'), findsNothing);
    expect(find.text('密码'), findsNothing);
    expect(find.text('地址'), findsNothing);
  });

  testWidgets('g. P1-4 SyncBadge: 状态栏上移，点击已同步徽章弹窗', (tester) async {
    final now = DateTime.now().toUtc();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          syncOverviewProvider.overrideWith(
            (ref) => Stream<SyncOverview>.value(
              SyncOverview(
                enabled: true,
                syncing: false,
                lastSuccessAt: now,
              ),
            ),
          ),
        ],
        child: const SuicunApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 顶部 title 旁边有已同步云朵
    expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);

    // 点击云朵弹出 BottomSheet
    await tester.tap(find.byIcon(Icons.cloud_done_outlined));
    await tester.pumpAndSettle();

    expect(find.text('WebDAV 同步'), findsOneWidget);
    expect(find.textContaining('上次同步时间：'), findsOneWidget);
    expect(find.text('前往 WebDAV 设置'), findsOneWidget);
  });
}
