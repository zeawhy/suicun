// test/widget/smart_suggest_test.dart
// Widget test for the smart category suggestion badge on the edit page:
// typing text matching a category's keywords pre-selects the category and
// shows the "Smart suggestion" badge.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/core/database/providers.dart';
import 'package:suicun/main.dart';
import 'package:suicun/services/auto_category_service.dart';

import 'record_workflow_test.dart' show findByHint, freshDb;

Future<ProviderContainer> pumpAppWithContainer(
  WidgetTester tester,
  AppDatabase db,
) async {
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
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

    // Category pre-selected with the smart-suggestion badge.
    expect(find.text('Dev'), findsWidgets);
    expect(find.text('Smart suggestion'), findsOneWidget);
  });
}
