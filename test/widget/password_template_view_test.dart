// test/widget/password_template_view_test.dart
// Widget tests for Password Template Reading View:
// 1) Password template body renders structured cards and masks password by default (••••••).
// 2) Tapping the eye icon reveals the real password, tapping again masks it.
// 3) Non-template text falls back to generic rendering.

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
      'password template body renders cards and masks password, toggles visibility, and edit button works',
      (tester) async {
    await pumpApp(tester);

    // 1. Create a password record via card form
    await tester.tap(find.byTooltip('New Record'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save a password'));
    await tester.pumpAndSettle();

    // PasswordTemplateView should be rendered directly in creation mode
    expect(find.byType(PasswordTemplateView), findsOneWidget);
    expect(find.byKey(const Key('template_title_field')), findsOneWidget);
    expect(find.byKey(const Key('password_website_field')), findsOneWidget);
    expect(find.byKey(const Key('password_username_field')), findsOneWidget);
    expect(find.byKey(const Key('password_password_field')), findsOneWidget);
    expect(find.byKey(const Key('password_notes_field')), findsOneWidget);

    // Fill title and fields directly inside the card form
    await tester.enterText(
        find.byKey(const Key('template_title_field')), 'My GitHub');
    await tester.enterText(
        find.byKey(const Key('password_website_field')), 'https://github.com');
    await tester.enterText(
        find.byKey(const Key('password_username_field')), 'testuser');
    await tester.enterText(
        find.byKey(const Key('password_password_field')), 'secret_password_123');
    await tester.enterText(
        find.byKey(const Key('password_notes_field')), 'personal account');

    // Wait for auto-save debounce (500ms)
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    // Go back to record list
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Verify record is in the list
    expect(find.text('My GitHub'), findsOneWidget);

    // 2. Open the record into viewing mode
    await tester.tap(find.text('My GitHub'));
    await tester.pumpAndSettle();

    // PasswordTemplateView should be rendered
    expect(find.byType(PasswordTemplateView), findsOneWidget);

    // AppBar title shows "Password record" (in English locale default) or "密码记录"
    expect(find.text('Password record'), findsOneWidget);

    // Verify fields rendered
    expect(find.text('https://github.com'), findsOneWidget);
    expect(find.text('testuser'), findsOneWidget);
    expect(find.text('personal account'), findsOneWidget);

    // Verify password is masked with •••••• and secret is NOT visible
    expect(find.text('••••••'), findsOneWidget);
    expect(find.text('secret_password_123'), findsNothing);

    // 3. Tap the eye icon to reveal the password
    final eyeIconFinder = find.byIcon(Icons.visibility_outlined);
    expect(eyeIconFinder, findsOneWidget);
    await tester.tap(eyeIconFinder);
    await tester.pumpAndSettle();

    // Now secret is visible and masked text is gone
    expect(find.text('secret_password_123'), findsOneWidget);
    expect(find.text('••••••'), findsNothing);

    // 4. Tap the eye-off icon to mask it again
    final eyeOffFinder = find.byIcon(Icons.visibility_off_outlined);
    expect(eyeOffFinder, findsOneWidget);
    await tester.tap(eyeOffFinder);
    await tester.pumpAndSettle();

    expect(find.text('••••••'), findsOneWidget);
    expect(find.text('secret_password_123'), findsNothing);

    // 5. Tap the pencil edit button to enter edit mode
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    // Should switch to edit mode (TextField with hint 'Title (optional)')
    expect(find.byType(PasswordTemplateView), findsNothing);
    expect(findByHint('Title (optional)'), findsOneWidget);
  });

  testWidgets('non-template text falls back to generic rendering',
      (tester) async {
    await pumpApp(tester);

    // 1. Create a blank note with freeform text
    await tester.tap(find.byTooltip('New Record'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blank note'));
    await tester.pumpAndSettle();

    await tester.enterText(findByHint('Title (optional)'), 'General Note');
    await tester.enterText(
      findByHint("Write down info you'll want to find later…"),
      'Just some normal notes without password structure.',
    );

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    // 2. Open the note in view mode
    await tester.tap(find.text('General Note'));
    await tester.pumpAndSettle();

    // PasswordTemplateView should NOT be used
    expect(find.byType(PasswordTemplateView), findsNothing);
    // Generic rich text rendering should be displayed
    expect(
      find.text('Just some normal notes without password structure.'),
      findsOneWidget,
    );
  });
}
