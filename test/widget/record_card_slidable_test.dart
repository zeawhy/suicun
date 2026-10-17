// test/widget/record_card_slidable_test.dart
// Tests for left-swipe action pane on RecordCard.

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suicun/features/records/domain/record_model.dart';
import 'package:suicun/features/records/presentation/home_sort_provider.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';
import 'package:suicun/shared/widgets/record_card.dart';

RecordDetail createMockRecord({
  String id = 'record-1',
  String title = '测试记录标题',
  String body = '测试记录详情内容',
  bool isFavorite = false,
}) {
  final now = DateTime.now();
  return RecordDetail(
    record: RecordModel(
      id: id,
      title: title,
      body: body,
      isFavorite: isFavorite,
      createdAt: now,
      updatedAt: now,
    ),
    tags: const [],
  );
}

Widget createTestWidget({
  required RecordDetail record,
  bool isMultiSelectMode = false,
  bool isQuickAccess = false,
  VoidCallback? onQuickAccessToggle,
  VoidCallback? onAnySlideAction,
  bool showSwipeHint = false,
  VoidCallback? onEdit,
  VoidCallback? onDelete,
  VoidCallback? onFavoriteToggle,
  Locale locale = const Locale('zh'),
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SlidableAutoCloseBehavior(
        child: ListView(
          children: [
            RecordCard(
              record: record,
              sortMode: RecordSortMode.byUpdatedAt,
              isSelected: false,
              isMultiSelectMode: isMultiSelectMode,
              onTap: () {},
              onLongPress: () {},
              onFavoriteToggle: onFavoriteToggle ?? () {},
              isQuickAccess: isQuickAccess,
              onQuickAccessToggle: onQuickAccessToggle ?? () {},
              onAnySlideAction: onAnySlideAction,
              showSwipeHint: showSwipeHint,
              onEdit: onEdit ?? () {},
              onChangeCategory: () {},
              onDelete: onDelete ?? () {},
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
  testWidgets('left-drag reveals action pane and triggers onQuickAccessToggle (unpinned)',
      (tester) async {
    var quickAccessToggled = false;
    final record = createMockRecord(isFavorite: false);

    await tester.pumpWidget(
      createTestWidget(
        record: record,
        isQuickAccess: false,
        onQuickAccessToggle: () => quickAccessToggled = true,
      ),
    );
    await tester.pumpAndSettle();

    // Drag left to reveal end actions
    await tester.drag(find.byType(RecordCard), const Offset(-300, 0));
    await tester.pumpAndSettle();

    // Verify pin icon and label for unpinned record
    expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);
    expect(find.text('设为常用'), findsOneWidget);

    // Tap quick access action
    await tester.tap(find.byIcon(Icons.push_pin_outlined));
    await tester.pumpAndSettle();

    expect(quickAccessToggled, isTrue);
  });

  testWidgets('left-drag reveals unpin action when record is already quick access',
      (tester) async {
    var quickAccessToggled = false;
    final record = createMockRecord(isFavorite: true);

    await tester.pumpWidget(
      createTestWidget(
        record: record,
        isQuickAccess: true,
        onQuickAccessToggle: () => quickAccessToggled = true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(RecordCard), const Offset(-300, 0));
    await tester.pumpAndSettle();

    expect(find.widgetWithIcon(SlidableAction, Icons.push_pin), findsOneWidget);
    expect(find.text('取消常用'), findsOneWidget);

    await tester.tap(find.widgetWithIcon(SlidableAction, Icons.push_pin));
    await tester.pumpAndSettle();

    expect(quickAccessToggled, isTrue);
  });

  testWidgets('left-drag reveals edit action and triggers onEdit',
      (tester) async {
    var editCalled = false;
    final record = createMockRecord();

    await tester.pumpWidget(
      createTestWidget(
        record: record,
        onEdit: () => editCalled = true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(RecordCard), const Offset(-300, 0));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    expect(editCalled, isTrue);
  });

  testWidgets('left-drag delete action: cancels deletion when dialog is dismissed',
      (tester) async {
    var deleteCalled = false;
    final record = createMockRecord();

    await tester.pumpWidget(
      createTestWidget(
        record: record,
        onDelete: () => deleteCalled = true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(RecordCard), const Offset(-300, 0));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    // Tap delete button in slidable actions
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    // Confirm dialog should be visible
    expect(find.text('删除这条记录？'), findsOneWidget);
    expect(find.text('删除后可以在回收站中恢复。'), findsOneWidget);

    // Tap cancel
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    // Dialog should be dismissed, onDelete must NOT be called
    expect(find.text('删除这条记录？'), findsNothing);
    expect(deleteCalled, isFalse);
  });

  testWidgets('left-drag delete action: confirms deletion and calls onDelete',
      (tester) async {
    var deleteCalled = false;
    final record = createMockRecord();

    await tester.pumpWidget(
      createTestWidget(
        record: record,
        onDelete: () => deleteCalled = true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(RecordCard), const Offset(-300, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('删除这条记录？'), findsOneWidget);
    expect(find.text('删除后可以在回收站中恢复。'), findsOneWidget);

    // Tap confirm button
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    // Dialog dismissed and onDelete must be called
    expect(find.text('删除这条记录？'), findsNothing);
    expect(deleteCalled, isTrue);
  });

  testWidgets('slidable is disabled in multi-select mode', (tester) async {
    final record = createMockRecord();

    await tester.pumpWidget(
      createTestWidget(
        record: record,
        isMultiSelectMode: true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(RecordCard), const Offset(-300, 0));
    await tester.pumpAndSettle();

    // Actions should not be revealed
    expect(find.byIcon(Icons.push_pin_outlined), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });
}
