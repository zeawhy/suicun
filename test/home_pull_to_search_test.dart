// test/home_pull_to_search_test.dart
// Verification tests for pull-to-search trigger logic on the HomePage.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/core/database/providers.dart';
import 'package:suicun/features/records/data/record_repository.dart';
import 'package:suicun/features/sync/sync_contract.dart';
import 'package:suicun/main.dart';
import 'package:suicun/shared/widgets/record_card.dart';

Future<void> pumpApp(
  WidgetTester tester,
  AppDatabase db, {
  Locale locale = const Locale('zh'),
}) async {
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
      child: SuicunApp(locale: locale),
    ),
  );
  await tester.pumpAndSettle();
}

/// Helper that begins a pull-down gesture from the top:
/// First moves by 20px to break touch slop and win vertical drag,
/// then moves by [overscrollDistance] downwards.
Future<TestGesture> pullFromTop(WidgetTester tester, double overscrollDistance) async {
  final gesture = await tester.startGesture(tester.getCenter(find.byType(CustomScrollView)));
  // Break touch slop to begin vertical scroll
  await gesture.moveBy(const Offset(0, 20));
  await tester.pump();
  // Move down to create overscroll
  await gesture.moveBy(Offset(0, overscrollDistance));
  await tester.pump();
  return gesture;
}

void main() {
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'onboarding_clipboard_asked': true});
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('1. 在顶部下拉 40px 后松手 → 不打开搜索', (tester) async {
    final repo = RecordRepository(db);
    for (int i = 0; i < 5; i++) {
      await repo.createRecord(title: 'Record $i', body: 'Body $i');
    }
    await pumpApp(tester, db);

    expect(find.byType(TextField), findsNothing);

    // Pull down 40px from top
    final gesture = await pullFromTop(tester, 40);

    // Visual indicator shows "下拉搜索"
    expect(find.text('下拉搜索'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();

    // Search bar is not opened
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('2. 在顶部下拉 100px 后松手 → 打开搜索', (tester) async {
    final repo = RecordRepository(db);
    for (int i = 0; i < 5; i++) {
      await repo.createRecord(title: 'Record $i', body: 'Body $i');
    }
    await pumpApp(tester, db);

    expect(find.byType(TextField), findsNothing);

    // Pull down 100px from top
    final gesture = await pullFromTop(tester, 100);

    // Visual indicator shows "松开搜索"
    expect(find.text('松开搜索'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();

    // Search bar is opened
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('3. 下拉 100px 后推回 20px 再松手 → 不打开', (tester) async {
    final repo = RecordRepository(db);
    for (int i = 0; i < 5; i++) {
      await repo.createRecord(title: 'Record $i', body: 'Body $i');
    }
    await pumpApp(tester, db);

    expect(find.byType(TextField), findsNothing);

    final gesture = await pullFromTop(tester, 100);
    expect(find.text('松开搜索'), findsOneWidget);

    // Push back up 20px (100 - 20 = 80 < 88)
    await gesture.moveBy(const Offset(0, -20));
    await tester.pump();

    // Indicator reverts to "下拉搜索"
    expect(find.text('下拉搜索'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();

    // Search bar is not opened
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('4. 从列表中间快速向上 fling 到顶部 → 不打开', (tester) async {
    final repo = RecordRepository(db);
    for (int i = 0; i < 20; i++) {
      await repo.createRecord(title: 'Record $i', body: 'Body $i');
    }
    await pumpApp(tester, db);

    // Scroll down into the list
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();

    // Fast fling up to top
    await tester.fling(find.byType(CustomScrollView), const Offset(0, 1000), 2000);
    await tester.pumpAndSettle();

    // Search bar should not open from inertial overscroll
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('5. 从列表中间拖到顶部后继续下拉 100px（同一次拖动）→ 不打开', (tester) async {
    final repo = RecordRepository(db);
    for (int i = 0; i < 20; i++) {
      await repo.createRecord(title: 'Record $i', body: 'Body $i');
    }
    await pumpApp(tester, db);

    // Scroll down so offset > 0
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();

    // In the middle of list, start a single drag towards top and overscroll by 100px
    final gesture = await tester.startGesture(tester.getCenter(find.byType(CustomScrollView)));
    // Break touch slop and scroll back to top
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 300));
    await tester.pump();
    // Continue dragging down 100px in the same gesture
    await gesture.moveBy(const Offset(0, 100));
    await tester.pump();

    await gesture.up();
    await tester.pumpAndSettle();

    // Search bar should not open because drag did not start at top
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('6. 多选模式下在顶部下拉 100px → 不打开', (tester) async {
    final repo = RecordRepository(db);
    for (int i = 0; i < 5; i++) {
      await repo.createRecord(title: 'Record $i', body: 'Body $i');
    }
    await pumpApp(tester, db);

    // Long press a card to open action sheet, then tap multi-select
    await tester.longPress(find.byType(RecordCard).first);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.checklist_rounded));
    await tester.pumpAndSettle();

    // Now in multi-select mode: top app bar shows close button with tooltip '取消'
    expect(find.byTooltip('取消'), findsOneWidget);

    // Pull down 100px
    final gesture = await pullFromTop(tester, 100);

    await gesture.up();
    await tester.pumpAndSettle();

    // Search bar should not open in multi-select mode
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('7. 右上角搜索按钮仍然正常', (tester) async {
    final repo = RecordRepository(db);
    for (int i = 0; i < 5; i++) {
      await repo.createRecord(title: 'Record $i', body: 'Body $i');
    }
    await pumpApp(tester, db);

    expect(find.byType(TextField), findsNothing);

    // Tap search icon button in app bar
    await tester.tap(find.byTooltip('搜索'));
    await tester.pumpAndSettle();

    // Search bar is opened
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);

    // Cancel closes it
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('8. 卡片处于左滑展开状态下在顶部下拉 100px → 不打开', (tester) async {
    final repo = RecordRepository(db);
    for (int i = 0; i < 5; i++) {
      await repo.createRecord(title: 'Record $i', body: 'Body $i');
    }
    await pumpApp(tester, db);

    // Swipe first card left to reveal actions
    await tester.drag(find.byType(RecordCard).first, const Offset(-300, 0));
    await tester.pumpAndSettle();

    // Action pane is visible (delete icon button)
    expect(find.byIcon(Icons.delete_outline), findsWidgets);

    // Pull down 100px
    final gesture = await pullFromTop(tester, 100);
    await gesture.up();
    await tester.pumpAndSettle();

    // Search bar should not open while a card is swiped open
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('9. 视觉提示（英文语言与主色图标）及震动反馈', (tester) async {
    final repo = RecordRepository(db);
    for (int i = 0; i < 5; i++) {
      await repo.createRecord(title: 'Record $i', body: 'Body $i');
    }

    final hapticCalls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          hapticCalls.add(call.arguments as String);
        }
        return null;
      },
    );

    await pumpApp(tester, db, locale: const Locale('en'));

    // Pull down 40px in English
    final gesture = await pullFromTop(tester, 40);

    // Below threshold in English
    expect(find.text('Pull to search'), findsOneWidget);
    expect(hapticCalls, isEmpty);

    // Pull past threshold (88px) to 100px
    await gesture.moveBy(const Offset(0, 60)); // 40 + 60 = 100px
    await tester.pump();

    // Reached threshold in English
    expect(find.text('Release to search'), findsOneWidget);
    expect(hapticCalls, contains('HapticFeedbackType.selectionClick'));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
  });
}
