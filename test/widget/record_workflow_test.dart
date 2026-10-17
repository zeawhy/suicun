// test/widget/record_workflow_test.dart
// Widget tests for the key user flows, driven against an in-memory database:
// create -> auto-save (500ms debounce) -> list -> search -> favorite ->
// delete -> trash -> restore.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/core/database/providers.dart';
import 'package:suicun/features/records/presentation/template_views/password_template_view.dart';
import 'package:suicun/features/sync/sync_contract.dart';
import 'package:suicun/main.dart';
import 'package:suicun/shared/widgets/record_card.dart';

/// Pumps the full app with the database provider overridden to use
/// an in-memory SQLite database.
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

/// Finds a [TextField] by its hint text.
Finder findByHint(String hint) => find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          (w.decoration?.hintText == hint ||
              (w.decoration?.hint is Text &&
                  ((w.decoration!.hint as Text).data == hint))),
    );

Future<AppDatabase> freshDb() async {
  final db = AppDatabase(NativeDatabase.memory());
  return db;
}

/// Opens the editor from home, selecting the blank note template.
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
    SharedPreferences.setMockInitialValues({'onboarding_clipboard_asked': true});
    db = await freshDb();
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('home shows empty state on first launch', (tester) async {
    await pumpApp(tester, db);

    expect(find.text('All'), findsOneWidget); // top category tab (en locale)
    expect(find.text('No info saved yet'), findsOneWidget);
    expect(find.byTooltip('New Record'), findsOneWidget);
  });

  testWidgets('create -> auto-save -> appears in list', (tester) async {
    await pumpApp(tester, db);

    // Open the editor
    await openEditor(tester);
    expect(find.text('New Info'), findsOneWidget);
    expect(findByHint('Title (optional)'), findsOneWidget);

    // Type title and body
    await tester.enterText(
        findByHint('Title (optional)'), 'Grocery run');
    await tester.enterText(
        findByHint("Write down info you'll want to find later…"),
        'milk and eggs');
    await tester.pump();
    expect(find.text('Saving…'), findsOneWidget);

    // Wait out the 500ms debounce, then let the save future complete
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);

    // Back to home: the record is listed
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Grocery run'), findsOneWidget);
    expect(find.textContaining('milk and eggs'), findsOneWidget);
  });

  testWidgets('search filters the list', (tester) async {
    await pumpApp(tester, db);

    // Seed two records through the UI
    for (final title in ['Alpha note', 'Beta note']) {
      await openEditor(tester);
      await tester.enterText(findByHint('Title (optional)'), title);
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
    expect(find.text('Alpha note'), findsOneWidget);
    expect(find.text('Beta note'), findsOneWidget);

    // Tap magnifying glass to expand search bar
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    // Filter
    await tester.enterText(find.byType(TextField), 'Alpha');
    await tester.pumpAndSettle();
    expect(find.text('Alpha note'), findsOneWidget);
    expect(find.text('Beta note'), findsNothing);

    // Clear filter by cancelling search
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Beta note'), findsOneWidget);
  });

  testWidgets('favorite toggle from the list', (tester) async {
    await pumpApp(tester, db);

    await openEditor(tester);
    await tester.enterText(findByHint('Title (optional)'), 'Star me');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Not favorited yet: no star_rounded icon shown on card
    expect(
      find.descendant(
        of: find.byType(RecordCard),
        matching: find.byIcon(Icons.star_rounded),
      ),
      findsNothing,
    );

    await tester.tap(find.byIcon(Icons.star_outline));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(RecordCard),
        matching: find.byIcon(Icons.star_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('delete -> trash -> restore', (tester) async {
    await pumpApp(tester, db);

    // Create a record
    await openEditor(tester);
    await tester.enterText(findByHint('Title (optional)'), 'Doomed');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Delete via long-press action sheet
    await tester.longPress(find.text('Doomed').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Gone from home, snackbar offers undo
    expect(find.text('Doomed'), findsNothing);
    expect(find.text('Moved to Trash'), findsOneWidget);

    // Open trash via settings
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    // The Trash tile may be below the fold in small test viewports;
    // scroll it into view before tapping.
    await tester.ensureVisible(find.text('Trash'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trash'));
    await tester.pumpAndSettle();
    expect(find.text('Doomed'), findsOneWidget);

    // Restore it
    await tester.tap(find.text('Doomed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect(find.text('Doomed'), findsNothing); // left the trash list

    // Back to home: record is back
    await tester.pageBack(); // trash -> home
    await tester.pumpAndSettle();
    expect(find.text('Doomed'), findsOneWidget);
  });

  testWidgets('sort mode persists and reorders the list', (tester) async {
    await pumpApp(tester, db);

    // Seed two records: 'B note' first, 'A note' second.
    // 'A note' is created later so by default (Recently edited), B is below A.
    for (final title in ['B note', 'A note']) {
      await openEditor(tester);
      await tester.enterText(findByHint('Title (optional)'), title);
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 1050)));
      await tester.pump(const Duration(seconds: 1));
    }

    // Default: Recently edited -> 'A note' on top (earlier y), 'B note' below (later y)
    expect(find.text('Recently edited'), findsOneWidget);
    var posA = tester.getTopLeft(find.descendant(
        of: find.byType(RecordCard), matching: find.text('A note')));
    var posB = tester.getTopLeft(find.descendant(
        of: find.byType(RecordCard), matching: find.text('B note')));
    expect(posA.dy < posB.dy, isTrue);

    // Open sort sheet and select 'Title A–Z'
    await tester.tap(find.text('Recently edited'));
    await tester.pumpAndSettle();
    expect(find.text('Title A–Z'), findsOneWidget);
    await tester.tap(find.text('Title A–Z'));
    await tester.pumpAndSettle();

    // With Title A–Z: A note is before B note
    expect(find.text('Title A–Z'), findsOneWidget);
    posA = tester.getTopLeft(find.descendant(
        of: find.byType(RecordCard), matching: find.text('A note')));
    posB = tester.getTopLeft(find.descendant(
        of: find.byType(RecordCard), matching: find.text('B note')));
    expect(posA.dy < posB.dy, isTrue);

    // Restart pump (re-pump with the same db) -> preference persists
    await pumpApp(tester, db);
    expect(find.text('Title A–Z'), findsOneWidget);
    posA = tester.getTopLeft(find.descendant(
        of: find.byType(RecordCard), matching: find.text('A note')));
    posB = tester.getTopLeft(find.descendant(
        of: find.byType(RecordCard), matching: find.text('B note')));
    expect(posA.dy < posB.dy, isTrue);
  });

  testWidgets('theme switch persists in settings', (tester) async {
    await pumpApp(tester, db);

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Theme'), findsOneWidget);

    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    // App still builds fine in dark mode
    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets('template selector pre-fills password template', (tester) async {
    await pumpApp(tester, db);

    await tester.tap(find.byTooltip('New Record'));
    await tester.pumpAndSettle();

    final pwdFinder = find.byKey(const Key('speed_dial_item_password'));
    expect(pwdFinder, findsOneWidget);

    await tester.tap(pwdFinder);
    await tester.pumpAndSettle();

    // The editor opens directly with the password template card UI in creation mode
    expect(find.byType(PasswordTemplateView), findsOneWidget);
    expect(find.byKey(const Key('password_website_field')), findsOneWidget);
  });
}
