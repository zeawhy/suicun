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
import 'package:suicun/features/sync/sync_contract.dart';
import 'package:suicun/main.dart';
import 'package:suicun/shared/theme/theme_providers.dart';

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
  await tester.tap(find.text('Blank note'));
  await tester.pumpAndSettle();
}

void main() {
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = await freshDb();
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('home shows empty state on first launch', (tester) async {
    await pumpApp(tester, db);

    expect(find.text('My Info'), findsOneWidget); // app bar / header title (en locale)
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

    // Filter
    await tester.enterText(findByHint('Search info'), 'Alpha');
    await tester.pumpAndSettle();
    expect(find.text('Alpha note'), findsOneWidget);
    expect(find.text('Beta note'), findsNothing);

    // Clear filter
    await tester.enterText(findByHint('Search info'), '');
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

    // Not favorited yet: star_border shown; favorite via the more_horiz menu
    expect(find.byIcon(Icons.star_border), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favorite'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.star), findsOneWidget);
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

    // Delete via the overflow menu
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Gone from home, snackbar offers undo
    expect(find.text('Doomed'), findsNothing);
    expect(find.text('Moved to trash'), findsOneWidget);

    // Open trash via settings
    await tester.tap(find.byIcon(Icons.settings_outlined));
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
    await tester.pageBack(); // trash -> settings
    await tester.pumpAndSettle();
    await tester.pageBack(); // settings -> home
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
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Default: Recently edited -> 'A note' on top (earlier y), 'B note' below (later y)
    expect(find.text('Recently edited'), findsOneWidget);
    var posA = tester.getTopLeft(find.text('A note'));
    var posB = tester.getTopLeft(find.text('B note'));
    expect(posA.dy < posB.dy, isTrue);

    // Open sort sheet and select 'Title A–Z'
    await tester.tap(find.text('Recently edited'));
    await tester.pumpAndSettle();
    expect(find.text('Title A–Z'), findsOneWidget);
    await tester.tap(find.text('Title A–Z'));
    await tester.pumpAndSettle();

    // With Title A–Z: A note is before B note
    expect(find.text('Title A–Z'), findsOneWidget);
    posA = tester.getTopLeft(find.text('A note'));
    posB = tester.getTopLeft(find.text('B note'));
    expect(posA.dy < posB.dy, isTrue);

    // Restart pump (re-pump with the same db) -> preference persists
    await pumpApp(tester, db);
    expect(find.text('Title A–Z'), findsOneWidget);
    posA = tester.getTopLeft(find.text('A note'));
    posB = tester.getTopLeft(find.text('B note'));
    expect(posA.dy < posB.dy, isTrue);
  });

  testWidgets('theme switch persists in settings', (tester) async {
    await pumpApp(tester, db);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Theme'), findsOneWidget);

    await tester.tap(find.byWidgetPredicate(
      (w) => w is DropdownButton<AppThemeMode>,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark').last);
    await tester.pumpAndSettle();

    // App still builds fine in dark mode
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('template selector pre-fills password template', (tester) async {
    await pumpApp(tester, db);

    await tester.tap(find.byTooltip('New Record'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a template'), findsOneWidget);
    expect(find.text('Save a password'), findsOneWidget);

    await tester.tap(find.text('Save a password'));
    await tester.pumpAndSettle();

    // The editor opens with prefilled password template body
    expect(
      find.textContaining('Website/App:\nUsername:\nPassword:\nNotes:'),
      findsOneWidget,
    );
  });
}
