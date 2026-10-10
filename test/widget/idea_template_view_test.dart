// test/widget/idea_template_view_test.dart
// Widget tests for Idea Template Reading View:
// 1) Idea template body renders hero idea content + source + next action, and edit button works.
// 2) Source URL is clickable and copies link with snackbar.
// 3) Non-template text falls back to generic rendering.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/core/database/providers.dart';
import 'package:suicun/features/records/presentation/template_views/idea_template_view.dart';
import 'package:suicun/features/records/presentation/template_views/template_detector.dart';
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

  testWidgets(
      'idea template body renders hero idea content, source, and next action, and edit button works',
      (tester) async {
    await pumpApp(tester);

    // 1. Create an idea record via card form
    await tester.tap(find.byTooltip('New Record'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quick idea'));
    await tester.pumpAndSettle();

    // IdeaTemplateView should be rendered directly in creation mode
    expect(find.byType(IdeaTemplateView), findsOneWidget);
    expect(find.byKey(const Key('template_title_field')), findsOneWidget);
    expect(find.byKey(const Key('idea_idea_field')), findsOneWidget);
    expect(find.byKey(const Key('idea_source_field')), findsOneWidget);
    expect(find.byKey(const Key('idea_next_action_field')), findsOneWidget);

    // Fill title and fields directly inside the card form
    await tester.enterText(
        find.byKey(const Key('template_title_field')), 'App Redesign');
    await tester.enterText(
        find.byKey(const Key('idea_idea_field')), 'Build a modern reader UI');
    await tester.enterText(
        find.byKey(const Key('idea_source_field')), 'Team brainstorming');
    await tester.enterText(
        find.byKey(const Key('idea_next_action_field')),
        'Create mockup in Figma');

    // Wait for auto-save debounce (500ms)
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    // Go back to record list
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Verify record is in the list
    expect(find.text('App Redesign'), findsOneWidget);

    // 2. Open the record into viewing mode
    await tester.tap(find.text('App Redesign'));
    await tester.pumpAndSettle();

    // IdeaTemplateView should be rendered
    expect(find.byType(IdeaTemplateView), findsOneWidget);

    // AppBar title shows "Idea record"
    expect(find.text('Idea record'), findsOneWidget);

    // Verify fields rendered
    expect(find.text('Build a modern reader UI'), findsOneWidget);
    expect(find.text('Team brainstorming'), findsOneWidget);
    expect(find.text('Create mockup in Figma'), findsOneWidget);

    // Verify labels rendered
    expect(find.text('Idea'), findsOneWidget);
    expect(find.text('Source'), findsOneWidget);
    expect(find.text('Next action'), findsOneWidget);

    // Verify lightbulb icon and rocket icon
    expect(find.byIcon(Icons.lightbulb_outline), findsOneWidget);
    expect(find.byIcon(Icons.rocket_launch_outlined), findsOneWidget);

    // 3. Tap the pencil edit button to enter edit mode
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    // Should switch to edit mode (TextField with hint 'Title (optional)')
    expect(find.byType(IdeaTemplateView), findsNothing);
    expect(findByHint('Title (optional)'), findsOneWidget);
  });

  testWidgets('source URL is clickable and copies link with snackbar',
      (tester) async {
    final ideaData = parseIdeaTemplate(
      'Idea: Deep learning for audio synthesis\nSource: https://example.com/paper\nNext action: Read section 3',
    )!;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: IdeaTemplateView(
            data: ideaData,
            record: null,
            onEdit: () {},
            categoryRow: const SizedBox(),
            tagRow: const SizedBox(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(IdeaTemplateView), findsOneWidget);
    expect(find.text('https://example.com/paper'), findsOneWidget);

    // Tap the URL
    await tester.tap(find.text('https://example.com/paper'));
    await tester.pump();

    // Verify SnackBar appears
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Link copied'), findsOneWidget);

    // Let the SnackBar dismiss
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('non-template text falls back to generic rendering',
      (tester) async {
    await pumpApp(tester);

    // 1. Create a blank note with freeform text
    await tester.tap(find.byTooltip('New Record'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blank note'));
    await tester.pumpAndSettle();

    await tester.enterText(findByHint('Title (optional)'), 'Random Thoughts');
    await tester.enterText(
      findByHint("Write down info you'll want to find later…"),
      'Just random musings without idea template structure.',
    );

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    // 2. Open the note in view mode
    await tester.tap(find.text('Random Thoughts'));
    await tester.pumpAndSettle();

    // IdeaTemplateView should NOT be used
    expect(find.byType(IdeaTemplateView), findsNothing);
    // Generic rich text rendering should be displayed
    expect(
      find.text('Just random musings without idea template structure.'),
      findsOneWidget,
    );
  });
}
