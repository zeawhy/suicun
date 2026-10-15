// test/widget/blank_template_view_test.dart
// Widget tests for Blank Template Reading View (BlankTemplateView):
// 1) Reading view renders header card with title and body content.
// 2) Empty body renders bodyHint placeholder.
// 3) Tapping the body card enters edit mode (TextField for body appears).
// 4) Tapping the pencil icon in header card enters edit mode.
// 5) Non-template freeform text routes to BlankTemplateView (not the legacy fallback Column).

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/core/database/providers.dart';
import 'package:suicun/features/records/presentation/template_views/blank_template_view.dart';
import 'package:suicun/features/sync/sync_contract.dart';
import 'package:suicun/main.dart';

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

  testWidgets(
      'renders header card title and body content in reading mode, and non-template routes to BlankTemplateView',
      (tester) async {
    await pumpApp(tester);

    // 1. Create a blank note with title and body
    await openEditor(tester);

    await tester.enterText(findByHint('Title (optional)'), 'My Daily Log');
    await tester.enterText(
      findByHint("Write down info you'll want to find later…"),
      'Had an insightful conversation with the team today.',
    );

    // Wait for auto-save debounce (500ms)
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    // Go back to record list
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Verify record is in the list
    expect(find.text('My Daily Log'), findsOneWidget);

    // 2. Open the note into reading mode
    await tester.tap(find.text('My Daily Log'));
    await tester.pumpAndSettle();

    // Verify BlankTemplateView is rendered (not old fallback Column)
    expect(find.byType(BlankTemplateView), findsOneWidget);

    // AppBar title shows "Note record"
    expect(find.text('Note record'), findsOneWidget);

    // Header card shows the title
    expect(find.text('My Daily Log'), findsWidgets);

    // Content shows body text
    expect(
      find.text('Had an insightful conversation with the team today.'),
      findsOneWidget,
    );

    // Legacy edit TextFields should not exist in reading mode
    expect(findByHint('Title (optional)'), findsNothing);
  });

  testWidgets('empty body renders bodyHint placeholder in BlankTemplateView',
      (tester) async {
    await pumpApp(tester);

    // 1. Create a blank note with only title and empty body
    await openEditor(tester);

    await tester.enterText(findByHint('Title (optional)'), 'Empty Note Title');

    // Wait for auto-save debounce
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    // Go back to record list
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Empty Note Title'), findsOneWidget);

    // 2. Open into viewing mode
    await tester.tap(find.text('Empty Note Title'));
    await tester.pumpAndSettle();

    expect(find.byType(BlankTemplateView), findsOneWidget);

    // Should display bodyHint placeholder ("Write down info you'll want to find later…")
    expect(
      find.text("Write down info you'll want to find later…"),
      findsOneWidget,
    );
  });

  testWidgets('tapping body card enters edit mode', (tester) async {
    await pumpApp(tester);

    // 1. Create a note
    await openEditor(tester);

    await tester.enterText(findByHint('Title (optional)'), 'Tap Body Test');
    await tester.enterText(
      findByHint("Write down info you'll want to find later…"),
      'Click me to edit',
    );

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    // 2. Open in view mode
    await tester.tap(find.text('Tap Body Test'));
    await tester.pumpAndSettle();

    expect(find.byType(BlankTemplateView), findsOneWidget);

    // 3. Tap body card
    await tester.tap(find.text('Click me to edit'));
    await tester.pumpAndSettle();

    // BlankTemplateView should be replaced with edit mode (TextFields visible)
    expect(find.byType(BlankTemplateView), findsNothing);
    expect(findByHint('Title (optional)'), findsOneWidget);
    expect(
      findByHint("Write down info you'll want to find later…"),
      findsOneWidget,
    );
  });

  testWidgets('tapping pencil edit button in header enters edit mode',
      (tester) async {
    await pumpApp(tester);

    // 1. Create a note
    await openEditor(tester);

    await tester.enterText(findByHint('Title (optional)'), 'Pencil Test');
    await tester.enterText(
      findByHint("Write down info you'll want to find later…"),
      'Testing the pencil button',
    );

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    // 2. Open in view mode
    await tester.tap(find.text('Pencil Test'));
    await tester.pumpAndSettle();

    expect(find.byType(BlankTemplateView), findsOneWidget);

    // 3. Tap the pencil edit button
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    // Should switch to edit mode
    expect(find.byType(BlankTemplateView), findsNothing);
    expect(findByHint('Title (optional)'), findsOneWidget);
    expect(
      findByHint("Write down info you'll want to find later…"),
      findsOneWidget,
    );
  });
}
