// test/widget/todo_template_view_test.dart
// Widget tests for Todo Template Reading View:
// 1) Todo template body renders task list and 0/3 progress.
// 2) Tapping checkbox marks item as done, updates progress to 1/3, and auto-saves (persists after reopening).
// 3) Mixed text (todo lines + normal text) falls back to generic rendering.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/core/database/providers.dart';
import 'package:suicun/features/records/presentation/template_views/template_detector.dart';
import 'package:suicun/features/records/presentation/template_views/todo_template_view.dart';
import 'package:suicun/features/sync/sync_contract.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';
import 'package:suicun/main.dart';

Finder findByHint(String hint) => find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          (w.decoration?.hintText == hint ||
              (w.decoration?.hint is Text &&
                  ((w.decoration!.hint as Text).data == hint))),
    );

void main() {
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpApp(WidgetTester tester) async {
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

  group('Todo template detector', () {
    test('identifies all checklist lines as todo template', () {
      final data = parseTodoTemplate('☐ Task 1\n☑ Task 2\n☐ Task 3');
      expect(data, isNotNull);
      expect(data!.items.length, 3);
      expect(data.items[0].checked, isFalse);
      expect(data.items[0].content, 'Task 1');
      expect(data.items[0].lineIndex, 0);

      expect(data.items[1].checked, isTrue);
      expect(data.items[1].content, 'Task 2');
      expect(data.items[1].lineIndex, 1);

      expect(data.items[2].checked, isFalse);
      expect(data.items[2].content, 'Task 3');
      expect(data.items[2].lineIndex, 2);
    });

    test('preserves original lineIndex when empty lines exist', () {
      final data = parseTodoTemplate('☐ Task 1\n\n☑ Task 2');
      expect(data, isNotNull);
      expect(data!.items.length, 2);
      expect(data.items[0].lineIndex, 0);
      expect(data.items[1].lineIndex, 2);
    });

    test('returns null for mixed or non-checklist text', () {
      expect(parseTodoTemplate('☐ Task 1\nNormal line'), isNull);
      expect(parseTodoTemplate(''), isNull);
      expect(parseTodoTemplate('   \n  '), isNull);
      expect(parseTodoTemplate('Just text'), isNull);
    });
  });

  testWidgets(
      'todo template body renders task list and 0/3 progress, tapping checkbox updates to 1/3 and persists after re-opening',
      (tester) async {
    await pumpApp(tester);

    // 1. Create a todo record via To-do template (card form)
    await tester.longPress(find.byTooltip('New Record'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('To-do list'));
    await tester.pumpAndSettle();

    // TodoTemplateView should be rendered directly in creation mode
    expect(find.byType(TodoTemplateView), findsOneWidget);
    expect(find.byKey(const Key('template_title_field')), findsOneWidget);
    expect(find.byKey(const Key('todo_item_field_0')), findsOneWidget);
    expect(find.byKey(const Key('todo_item_field_1')), findsOneWidget);
    expect(find.byKey(const Key('todo_item_field_2')), findsOneWidget);

    // Fill title
    await tester.enterText(
        find.byKey(const Key('template_title_field')), 'Trip Checklist');

    // Wait for auto-save debounce (500ms)
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    // Go back to record list
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Verify record in list
    expect(find.text('Trip Checklist'), findsOneWidget);

    // 2. Open record into viewing mode
    await tester.tap(find.text('Trip Checklist'));
    await tester.pumpAndSettle();

    // TodoTemplateView should be rendered
    expect(find.byType(TodoTemplateView), findsOneWidget);
    expect(find.text('To-do record'), findsOneWidget);

    // Initial progress is 0 of 3 done
    expect(find.text('0 of 3 done'), findsOneWidget);

    // Tasks are rendered
    expect(find.text('Task one'), findsOneWidget);
    expect(find.text('Task two'), findsOneWidget);
    expect(find.text('Task three'), findsOneWidget);

    // All checkboxes are unchecked
    var checkboxes = tester.widgetList<Checkbox>(find.byType(Checkbox)).toList();
    expect(checkboxes.length, 3);
    expect(checkboxes[0].value, isFalse);
    expect(checkboxes[1].value, isFalse);
    expect(checkboxes[2].value, isFalse);

    // 3. Tap the first checkbox
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    // First item is now checked, progress is 1 of 3 done
    expect(find.text('1 of 3 done'), findsOneWidget);
    checkboxes = tester.widgetList<Checkbox>(find.byType(Checkbox)).toList();
    expect(checkboxes[0].value, isTrue);
    expect(checkboxes[1].value, isFalse);
    expect(checkboxes[2].value, isFalse);

    // Wait for auto-save debounce (500ms)
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    // Go back to record list
    await tester.pageBack();
    await tester.pumpAndSettle();

    // 4. Re-open the record and verify persistence
    await tester.tap(find.text('Trip Checklist').first);
    await tester.pumpAndSettle();

    expect(find.byType(TodoTemplateView), findsOneWidget);
    expect(find.text('1 of 3 done'), findsOneWidget);
    checkboxes = tester.widgetList<Checkbox>(find.byType(Checkbox)).toList();
    expect(checkboxes[0].value, isTrue);
    expect(checkboxes[1].value, isFalse);
    expect(checkboxes[2].value, isFalse);

    // 5. Verify edit button switches to edit mode
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(TodoTemplateView), findsNothing);
    expect(findByHint('Title (optional)'), findsOneWidget);
  });

  testWidgets('mixed text falls back to generic rendering', (tester) async {
    await pumpApp(tester);

    // 1. Create a note with mixed text
    await tester.tap(find.byTooltip('New Record'));
    await tester.pumpAndSettle();

    await tester.enterText(findByHint('Title (optional)'), 'Mixed Plan');
    await tester.enterText(
      findByHint("Write down info you'll want to find later…"),
      '☐ Task one\nSome general notes here\n☐ Task two',
    );

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    // 2. Open note in viewing mode
    await tester.tap(find.text('Mixed Plan'));
    await tester.pumpAndSettle();

    // TodoTemplateView should NOT be used
    expect(find.byType(TodoTemplateView), findsNothing);
    // Generic rendering shows the text
    expect(find.textContaining('Some general notes here'), findsOneWidget);
  });

  testWidgets('renders in Chinese locale with correct progress and title',
      (tester) async {
    final todoData = parseTodoTemplate('☐ 事项一\n☑ 事项二\n☐ 事项三')!;
    int? toggledIndex;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TodoTemplateView(
            data: todoData,
            record: null,
            onEdit: () {},
            onToggle: (index) => toggledIndex = index,
            categoryRow: const SizedBox(),
            tagRow: const SizedBox(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TodoTemplateView), findsOneWidget);
    expect(find.text('已完成 1 / 3'), findsOneWidget);
    expect(find.text('事项一'), findsOneWidget);
    expect(find.text('事项二'), findsOneWidget);
    expect(find.text('事项三'), findsOneWidget);

    // Tap first item text to toggle
    await tester.tap(find.text('事项一'));
    await tester.pumpAndSettle();
    expect(toggledIndex, 0);
  });
}
