// test/widget/contact_template_view_test.dart
// ignore_for_file: depend_on_referenced_packages
// Widget tests for Contact Template Reading View:
// 1) Contact template body renders name in header + phone/email/address rows.
// 2) Phone/email labels and clickable buttons exist and trigger launchUrl / copy fallback.
// 3) Non-template text falls back to generic rendering.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/core/database/providers.dart';
import 'package:suicun/features/records/presentation/template_views/contact_template_view.dart';
import 'package:suicun/features/records/presentation/template_views/template_detector.dart';
import 'package:suicun/features/sync/sync_contract.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';
import 'package:suicun/main.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

Finder findByHint(String hint) => find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          (w.decoration?.hintText == hint ||
              (w.decoration?.hint is Text &&
                  ((w.decoration!.hint as Text).data == hint))),
    );

class FakeUrlLauncher extends Fake
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  final List<String> launchedUrls = [];
  bool shouldSucceed = true;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrls.add(url);
    return shouldSucceed;
  }
}

void main() {
  late AppDatabase db;
  late FakeUrlLauncher fakeUrlLauncher;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    fakeUrlLauncher = FakeUrlLauncher();
    UrlLauncherPlatform.instance = fakeUrlLauncher;
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

  group('Contact Template Detector', () {
    test('detects Chinese and English contact template format', () {
      const zhBody = '姓名：张三\n电话：13800138000\n邮箱：zhangsan@example.com\n地址：北京市海淀区\n备注：朋友';
      expect(isContactTemplate(zhBody), isTrue);
      final zhData = parseContactTemplate(zhBody)!;
      expect(zhData.name, '张三');
      expect(zhData.phone, '13800138000');
      expect(zhData.email, 'zhangsan@example.com');
      expect(zhData.address, '北京市海淀区');
      expect(zhData.notes, '朋友');

      const enBody = 'Name: Alice\nPhone: +1 555-0199\nEmail: alice@example.com\nAddress: 123 Main St\nNotes: Colleague';
      expect(isContactTemplate(enBody), isTrue);
      final enData = parseContactTemplate(enBody)!;
      expect(enData.name, 'Alice');
      expect(enData.phone, '+1 555-0199');
      expect(enData.email, 'alice@example.com');
      expect(enData.address, '123 Main St');
      expect(enData.notes, 'Colleague');
    });

    test('accepts subset containing at least one anchor field', () {
      const phoneOnly = '电话：10086';
      expect(isContactTemplate(phoneOnly), isTrue);
      final data = parseContactTemplate(phoneOnly)!;
      expect(data.phone, '10086');
      expect(data.name, isNull);

      const notesOnly = '备注：这是一条普通备注';
      // Without anchor (name/phone/email), this should NOT be detected as contact template
      expect(isContactTemplate(notesOnly), isFalse);
    });

    test('returns null for non-template or password/idea body', () {
      const passwordBody = '网站：example.com\n密码：123456';
      expect(isContactTemplate(passwordBody), isFalse);

      const ideaBody = '灵感：一个点子\n来源：网络';
      expect(isContactTemplate(ideaBody), isFalse);

      const mixedBody = '姓名：张三\n自由文本行没有冒号';
      expect(isContactTemplate(mixedBody), isFalse);
    });
  });

  group('Contact Template View Widget', () {
    testWidgets(
        'contact template body renders name header + phone, email, address rows, and edit button works',
        (tester) async {
      await pumpApp(tester);

      // 1. Create a contact record via card form
      await tester.longPress(find.byTooltip('New Record'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Contact'));
      await tester.pumpAndSettle();

      // ContactTemplateView should be rendered directly in creation mode
      expect(find.byType(ContactTemplateView), findsOneWidget);
      expect(find.byKey(const Key('template_title_field')), findsOneWidget);
      expect(find.byKey(const Key('contact_name_field')), findsOneWidget);
      expect(find.byKey(const Key('contact_phone_field')), findsOneWidget);
      expect(find.byKey(const Key('contact_email_field')), findsOneWidget);
      expect(find.byKey(const Key('contact_address_field')), findsOneWidget);
      expect(find.byKey(const Key('contact_notes_field')), findsOneWidget);

      // Enter title and fields directly into the card form
      await tester.enterText(
          find.byKey(const Key('template_title_field')), 'Alice Card');
      await tester.enterText(
          find.byKey(const Key('contact_name_field')), 'Alice Smith');
      await tester.enterText(
          find.byKey(const Key('contact_phone_field')), '13800138000');
      await tester.enterText(
          find.byKey(const Key('contact_email_field')), 'alice@example.com');
      await tester.enterText(
          find.byKey(const Key('contact_address_field')), '42 Silicon Way');
      await tester.enterText(
          find.byKey(const Key('contact_notes_field')), 'Met at conference');

      // Auto-save debounce
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      // Back to record list
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Alice Card'), findsOneWidget);

      // 2. Open the record in reading mode
      await tester.tap(find.text('Alice Card'));
      await tester.pumpAndSettle();

      // ContactTemplateView is rendered
      expect(find.byType(ContactTemplateView), findsOneWidget);

      // AppBar shows Contact record
      expect(find.text('Contact record'), findsOneWidget);

      // Header card displays name "Alice Smith" and person outline icon
      expect(find.text('Alice Smith'), findsOneWidget);
      expect(find.byIcon(Icons.person_outline), findsOneWidget);

      // Since name is present in header, field card does not repeat name row
      // Values are rendered
      expect(find.text('13800138000'), findsOneWidget);
      expect(find.text('alice@example.com'), findsOneWidget);
      expect(find.text('42 Silicon Way'), findsOneWidget);
      expect(find.text('Met at conference'), findsOneWidget);

      // Labels are rendered
      expect(find.text('Phone'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Address'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);

      // 3. Tap edit button to switch back to editing mode
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(ContactTemplateView), findsNothing);
      expect(findByHint('Title (optional)'), findsOneWidget);
    });

    testWidgets(
        'phone and email buttons launch tel: and mailto: URLs, fallback copies to clipboard',
        (tester) async {
      final contactData = parseContactTemplate(
        'Name: Bob\nPhone: 10086\nEmail: bob@test.com\nAddress: Main Road',
      )!;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ContactTemplateView(
              data: contactData,
              record: null,
              onEdit: () {},
              categoryRow: const SizedBox(),
              tagRow: const SizedBox(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ContactTemplateView), findsOneWidget);

      // Verify phone and email action buttons exist
      final phoneBtn = find.byIcon(Icons.phone_outlined);
      final emailBtn = find.byIcon(Icons.email_outlined);
      expect(phoneBtn, findsOneWidget);
      expect(emailBtn, findsOneWidget);

      // Tap phone button -> calls launchUrl with tel:10086
      await tester.tap(phoneBtn);
      await tester.pumpAndSettle();
      expect(fakeUrlLauncher.launchedUrls, contains('tel:10086'));

      // Tap email button -> calls launchUrl with mailto:bob@test.com
      await tester.tap(emailBtn);
      await tester.pumpAndSettle();
      expect(fakeUrlLauncher.launchedUrls, contains('mailto:bob@test.com'));

      // Now test fallback to clipboard when launchUrl returns false
      fakeUrlLauncher.shouldSucceed = false;
      await tester.tap(phoneBtn);
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Copied'), findsOneWidget);
    });

    testWidgets('non-template text falls back to generic rendering',
        (tester) async {
      await pumpApp(tester);

      await tester.tap(find.byTooltip('New Record'));
      await tester.pumpAndSettle();

      await tester.enterText(findByHint('Title (optional)'), 'Casual Note');
      await tester.enterText(
        findByHint("Write down info you'll want to find later…"),
        'Contact me anytime at the office.',
      );

      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Casual Note'));
      await tester.pumpAndSettle();

      // ContactTemplateView should NOT be used
      expect(find.byType(ContactTemplateView), findsNothing);
      expect(
        find.text('Contact me anytime at the office.'),
        findsOneWidget,
      );
    });
  });
}
