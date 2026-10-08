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

    // Each card has more_horiz popup menu, no standalone star button
    expect(find.byIcon(Icons.more_horiz), findsNWidgets(2));
    expect(find.byIcon(Icons.star_border), findsNothing);

    // Only the favorited record shows the small star
    final starFinder = find.byIcon(Icons.star_rounded);
    expect(starFinder, findsOneWidget);
    final iconWidget = tester.widget<Icon>(starFinder);
    expect(iconWidget.size, 14.0);
  });

  testWidgets(
      'd. bottom-left settings button exists (icon + Settings text) and navigates to settings',
      (tester) async {
    await pumpApp(tester, db);

    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Tap settings button
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    // Navigated to settings page
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);
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

    // Drag down on the ListView to trigger overscroll
    await tester.drag(find.byType(ListView), const Offset(0, 200));
    await tester.pumpAndSettle();

    // Search bar expands
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });
}
