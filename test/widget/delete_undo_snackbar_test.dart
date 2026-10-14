// test/widget/delete_undo_snackbar_test.dart
// Tests verifying that the delete undo snackbar auto-dismisses after 4 seconds
// and that the undo action restores the deleted record.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/core/database/providers.dart';
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

  testWidgets('delete on home page: snackbar appears and auto-dismisses after 4s',
      (tester) async {
    await pumpApp(tester, db);

    // Create a record
    await tester.tap(find.byTooltip('New Record'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blank note'));
    await tester.pumpAndSettle();

    await tester.enterText(findByHint('Title (optional)'), 'Record A');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Record A'), findsOneWidget);

    // Delete via overflow menu
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Record is removed, snackbar with undo is shown
    expect(find.text('Record A'), findsNothing);
    expect(find.text('Moved to trash'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    // Advance clock past the 4-second snackbar duration
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    // Verify snackbar is automatically dismissed
    expect(find.text('Moved to trash'), findsNothing);
    expect(find.text('Undo'), findsNothing);
  });

  testWidgets('delete on home page: tapping undo restores record',
      (tester) async {
    await pumpApp(tester, db);

    // Create a record
    await tester.tap(find.byTooltip('New Record'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blank note'));
    await tester.pumpAndSettle();

    await tester.enterText(findByHint('Title (optional)'), 'Record B');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Record B'), findsOneWidget);

    // Delete
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Record B'), findsNothing);
    expect(find.text('Moved to trash'), findsOneWidget);

    // Tap Undo
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    // Record is restored and snackbar is dismissed
    expect(find.text('Record B'), findsOneWidget);
    expect(find.text('Moved to trash'), findsNothing);
  });

  testWidgets('delete from edit page: pops to home and snackbar auto-dismisses after 4s',
      (tester) async {
    await pumpApp(tester, db);

    // Create a record and stay in edit page
    await tester.tap(find.byTooltip('New Record'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blank note'));
    await tester.pumpAndSettle();

    await tester.enterText(findByHint('Title (optional)'), 'Record C');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    // Delete from edit page (popup menu -> Delete)
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Confirm dialog
    expect(find.text('Confirm'), findsOneWidget);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    // Returned to home page, snackbar is visible
    expect(find.text('Record C'), findsNothing);
    expect(find.text('Moved to trash'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    // Advance 4s
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    // Snackbar dismissed
    expect(find.text('Moved to trash'), findsNothing);
  });
}
