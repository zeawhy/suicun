// test/widget/smart_suggest_test.dart
// Widget tests for the smart category suggestion badge on the edit page:
// - typing matching keywords shows the "Smart suggestion" badge and chips
// - typing without matching keywords shows no suggestions
// - tapping suggestion chip or manually picking category stops further suggestions
// - service error does not crash UI
// - sync-recovered default categories show suggestions

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/core/database/providers.dart';
import 'package:suicun/features/categories/data/category_repository.dart';
import 'package:suicun/features/sync/entity_snapshot.dart';
import 'package:suicun/main.dart';
import 'package:suicun/services/auto_category_service.dart';

import 'record_workflow_test.dart' show findByHint, freshDb;

Future<ProviderContainer> pumpAppWithContainer(
  WidgetTester tester,
  AppDatabase db, {
  AutoCategoryService? autoCategoryService,
}) async {
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      if (autoCategoryService != null)
        autoCategoryServiceProvider.overrideWithValue(autoCategoryService),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const SuicunApp(),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

class _FailingAutoCategoryService extends AutoCategoryService {
  _FailingAutoCategoryService(super.categoryRepository);

  @override
  Future<List<CategorySuggestion>> suggestCategories({
    String? title,
    String? body,
    int limit = 2,
  }) async {
    throw Exception('simulated service failure');
  }
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await freshDb();
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('typing matching keywords shows the smart suggestion badge',
      (tester) async {
    final container = await pumpAppWithContainer(tester, db);

    // Seed a category with keywords.
    final categoryRepo = container.read(categoryRepositoryProvider);
    final cat = await categoryRepo.createCategory('Dev', '#4866D5');
    await container
        .read(autoCategoryServiceProvider)
        .setKeywords(cat.id, ['flutter']);

    // Open a new record and type matching text.
    await tester.tap(find.byTooltip('New Record'));
    await tester.pumpAndSettle();
    await tester.enterText(findByHint('Title (optional)'), 'flutter notes');
    // 500ms auto-save debounce + 1200ms suggestion debounce + save roundtrip.
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pumpAndSettle();

    // Suggestion badge shown with candidate chip.
    expect(find.text('Dev'), findsWidgets);
    expect(find.text('Smart suggestion'), findsOneWidget);
  });

  testWidgets('typing without matching keywords shows no suggestion badge',
      (tester) async {
    final container = await pumpAppWithContainer(tester, db);

    final categoryRepo = container.read(categoryRepositoryProvider);
    final cat = await categoryRepo.createCategory('Dev', '#4866D5');
    await container
        .read(autoCategoryServiceProvider)
        .setKeywords(cat.id, ['flutter']);

    await tester.tap(find.byTooltip('New Record'));
    await tester.pumpAndSettle();
    await tester.enterText(findByHint('Title (optional)'), 'random cooking recipe');
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pumpAndSettle();

    expect(find.text('Smart suggestion'), findsNothing);
  });

  testWidgets(
      'tapping suggestion chip applies category and prevents further suggestions',
      (tester) async {
    final container = await pumpAppWithContainer(tester, db);

    final categoryRepo = container.read(categoryRepositoryProvider);
    final cat = await categoryRepo.createCategory('Dev', '#4866D5');
    await container
        .read(autoCategoryServiceProvider)
        .setKeywords(cat.id, ['flutter']);

    await tester.tap(find.byTooltip('New Record'));
    await tester.pumpAndSettle();
    await tester.enterText(findByHint('Title (optional)'), 'flutter notes');
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pumpAndSettle();

    expect(find.text('Smart suggestion'), findsOneWidget);

    // Tap the suggestion chip.
    await tester.tap(find.text('Dev').last);
    await tester.pumpAndSettle();

    // Suggestion row should disappear.
    expect(find.text('Smart suggestion'), findsNothing);

    // Typing more text should NOT bring suggestion row back.
    await tester.enterText(
        findByHint('Title (optional)'), 'flutter notes more flutter');
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pumpAndSettle();

    expect(find.text('Smart suggestion'), findsNothing);
  });

  testWidgets('manually picking category prevents further suggestions',
      (tester) async {
    final container = await pumpAppWithContainer(tester, db);

    final categoryRepo = container.read(categoryRepositoryProvider);
    await categoryRepo.createCategory('Dev', '#4866D5');
    await categoryRepo.createCategory('Other', '#333333');

    await tester.tap(find.byTooltip('New Record'));
    await tester.pumpAndSettle();

    // Tap category row to manually pick "Other"
    await tester.tap(find.text('Category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other'));
    await tester.pumpAndSettle();

    // Now type keywords for Dev.
    await tester.enterText(findByHint('Title (optional)'), 'flutter notes');
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pumpAndSettle();

    // Should not show suggestions because user explicitly picked a category.
    expect(find.text('Smart suggestion'), findsNothing);
  });

  testWidgets('service error does not crash UI and editing continues',
      (tester) async {
    final failingService =
        _FailingAutoCategoryService(CategoryRepository(db));

    await pumpAppWithContainer(
      tester,
      db,
      autoCategoryService: failingService,
    );

    await tester.tap(find.byTooltip('New Record'));
    await tester.pumpAndSettle();
    await tester.enterText(findByHint('Title (optional)'), 'some text');
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pumpAndSettle();

    // UI did not crash and no unhandled exception occurred.
    expect(tester.takeException(), isNull);
    expect(find.text('Smart suggestion'), findsNothing);
    expect(find.byType(TextField), findsWidgets);
  });

  testWidgets(
      'sync-downloaded category without keywords is seeded and suggests in UI',
      (tester) async {
    // Simulate sync download of a category before user starts editing.
    final applier = SnapshotApplier(db);
    final rev = ParsedRevision(
      revisionId: 'rev-cat-work-1',
      entityType: EntitySnapshots.categoryType,
      entityId: 'sync-cat-work-id',
      parents: const [],
      createdAt: DateTime.now().toUtc(),
      deleted: false,
      snapshot: {'name': '工作', 'color': '#4A7DDC'},
    );
    await applier.apply(rev);

    await pumpAppWithContainer(tester, db);

    // Open new record and type seed keyword '开会' or '项目'.
    await tester.tap(find.byTooltip('New Record'));
    await tester.pumpAndSettle();
    await tester.enterText(findByHint('Title (optional)'), '项目汇报');
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pumpAndSettle();

    // Sync-downloaded category now has seed keywords and shows suggestion badge!
    expect(find.text('工作'), findsWidgets);
    expect(find.text('Smart suggestion'), findsOneWidget);
  });
}
