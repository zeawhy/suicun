// test/widget/action_bubble_test.dart
// §7 记录详情页「⋯」气泡菜单：只保留「加入常用/移出常用」和「删除」两项。

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/core/database/providers.dart';
import 'package:suicun/features/sync/sync_contract.dart';
import 'package:suicun/main.dart';
import 'package:suicun/shared/widgets/action_bubble.dart';

Future<void> pumpApp(WidgetTester tester, AppDatabase db) async {
  SharedPreferences.setMockInitialValues({
    'onboarding_clipboard_asked': true,
  });
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

Finder findByHint(String hint) => find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          (w.decoration?.hintText == hint ||
              (w.decoration?.hint is Text &&
                  ((w.decoration!.hint as Text).data == hint))),
    );

Future<void> openEditor(WidgetTester tester) async {
  await tester.tap(find.byTooltip('New Record'));
  await tester.pumpAndSettle();
  final blankFinder = find.byKey(const Key('speed_dial_item_blank'));
  if (blankFinder.evaluate().isNotEmpty) {
    await tester.tap(blankFinder);
    await tester.pumpAndSettle();
  }
}

/// 新建一条标题为 [title] 的记录并回到首页。
Future<void> createRecord(WidgetTester tester, String title) async {
  await openEditor(tester);
  await tester.enterText(findByHint('Title (optional)'), title);
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
  await tester.pageBack();
  await tester.pumpAndSettle();
  expect(find.text(title), findsOneWidget);
}

/// 在首页点开标题为 [title] 的记录进入详情页。
Future<void> openRecord(WidgetTester tester, String title) async {
  await tester.tap(find.text(title).first);
  await tester.pumpAndSettle();
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('⋯ menu shows pin + delete bubble, no category/tags',
      (tester) async {
    await pumpApp(tester, db);
    await createRecord(tester, 'Bubble A');
    await openRecord(tester, 'Bubble A');

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();

    // 两行：加入常用 + 删除
    expect(find.text('Add to quick access'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    // 菜单里不再有分类/标签
    expect(find.text('Select category'), findsNothing);
    expect(find.text('Select tags'), findsNothing);
  });

  testWidgets('tapping outside closes the bubble', (tester) async {
    await pumpApp(tester, db);
    await createRecord(tester, 'Bubble B');
    await openRecord(tester, 'Bubble B');

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    expect(find.text('Add to quick access'), findsOneWidget);

    // 点遮罩关闭
    await tester.tapAt(const Offset(10, 300));
    await tester.pumpAndSettle();
    expect(find.text('Add to quick access'), findsNothing);
  });

  testWidgets('pin then unpin via bubble', (tester) async {
    await pumpApp(tester, db);
    await createRecord(tester, 'Bubble C');
    await openRecord(tester, 'Bubble C');

    // 加入常用
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to quick access'));
    await tester.pumpAndSettle();
    expect(find.text('Add to quick access'), findsNothing);

    // 再打开：显示移出常用 + 实心图钉
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    expect(find.text('Remove from quick access'), findsOneWidget);
    expect(find.byIcon(Icons.push_pin), findsOneWidget);

    // 移出常用
    await tester.tap(find.text('Remove from quick access'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    expect(find.text('Add to quick access'), findsOneWidget);
  });

  testWidgets('disabled bubble row is greyed but still tappable',
      (tester) async {
    // 直接测 showActionBubble：disabled 行 40% 透明但可点击。
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              final key = GlobalKey();
              return ElevatedButton(
                key: key,
                onPressed: () => showActionBubble(
                  context: context,
                  anchorKey: key,
                  items: [
                    ActionBubbleItem(
                      icon: Icons.push_pin_outlined,
                      label: 'Add to quick access',
                      enabled: false,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Quick access is full (max 6)')),
                        );
                      },
                    ),
                  ],
                ),
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Add to quick access'), findsOneWidget);
    // 置灰
    expect(
      find.ancestor(
        of: find.text('Add to quick access'),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Opacity &&
              (w.opacity - 0.4).abs() < 0.01,
        ),
      ),
      findsOneWidget,
    );

    // 点击置灰行：气泡关闭并执行 onTap（弹出提示）
    await tester.tap(find.text('Add to quick access'));
    await tester.pumpAndSettle();
    expect(find.text('Add to quick access'), findsNothing);
    expect(find.text('Quick access is full (max 6)'), findsOneWidget);
  });

  testWidgets('delete via bubble shows confirm dialog with new copy',
      (tester) async {
    await pumpApp(tester, db);
    await createRecord(tester, 'Bubble E');
    await openRecord(tester, 'Bubble E');

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // §7.3 新文案
    expect(find.text('Delete this record?'), findsOneWidget);
    expect(find.text('You can restore it from Trash.'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // 回到首页 + snackbar 可撤销
    expect(find.text('Bubble E'), findsNothing);
    expect(find.text('Moved to Trash'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
  });
}
