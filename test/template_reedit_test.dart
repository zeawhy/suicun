// test/template_reedit_test.dart
// Round 10 §4: regression tests for "template disappears when re-editing".
//
// Root cause was in edit_record_page.dart: template view selection depended
// on `(_isNew || !_bodyEditing)`, and the ✏️ button set `_bodyEditing = true`,
// flipping every template check to false and dropping into the plain-text
// editor. Fixed by introducing an independent `_templateEditing` state and
// making view selection depend on the body text only.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suicun/core/crypto/key_value_store.dart';
import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/core/database/providers.dart';
import 'package:suicun/features/records/data/quick_access_storage.dart';
import 'package:suicun/features/records/data/record_repository.dart';
import 'package:suicun/features/records/presentation/edit_record_page.dart';
import 'package:suicun/features/records/presentation/template_views/blank_template_view.dart';
import 'package:suicun/features/records/presentation/template_views/contact_template_view.dart';
import 'package:suicun/features/records/presentation/template_views/idea_template_view.dart';
import 'package:suicun/features/records/presentation/template_views/password_template_view.dart';
import 'package:suicun/features/records/presentation/template_views/template_detector.dart';
import 'package:suicun/features/security/data/app_lock_service.dart';
import 'package:suicun/features/security/data/security_providers.dart';
import 'package:suicun/features/sync/sync_contract.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';
import 'package:suicun/shared/theme/app_theme.dart';

/// Pumps a plain MaterialApp, then pushes [EditRecordPage] for [recordId]
/// so there is a real back stack (needed for the PopScope back-key test).
Future<void> pumpEditPage(
  WidgetTester tester,
  AppDatabase db,
  String recordId, {
  Locale locale = const Locale('zh'),
}) async {
  SharedPreferences.setMockInitialValues({
    'onboarding_clipboard_asked': true,
  });
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWith((ref) => Future.value(prefs)),
        syncOverviewProvider.overrideWith(
          (ref) => Stream<SyncOverview>.value(
            const SyncOverview(enabled: false, syncing: false),
          ),
        ),
        appLockServiceProvider.overrideWithValue(
          AppLockService(store: MemoryKeyValueStore()),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        theme: AppTheme.lightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EditRecordPage(recordId: recordId),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final navigator =
      tester.state<NavigatorState>(find.byType(Navigator).first);
  navigator.push(
    MaterialPageRoute(builder: (_) => EditRecordPage(recordId: recordId)),
  );
  await tester.pumpAndSettle();
}

/// Matches the plain-text body TextField of the raw-text editor by its
/// body-hint decoration — absent when a template form is shown.
Finder _plainBodyEditor() => find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          w.decoration?.hintText == '写下以后还要找的信息……',
      description: 'plain-text body editor',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Round 10: template re-edit keeps the form', () {
    testWidgets('1. 密码记录点 ✏️ 后仍是表单，无纯文本编辑器', (tester) async {
      const body = '网站/应用：你莫说\n用户名：民主评议\n密码：7373uur\n备注：';
      final repo = RecordRepository(db);
      final rec = await repo.createRecord(title: '我的密码', body: body);

      await pumpEditPage(tester, db, rec.id);

      // Reading state shows the template card.
      expect(find.byType(PasswordTemplateView), findsOneWidget);

      // Tap ✏️ (header card edit button).
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      // Still the template form, now editable: 4 field inputs found.
      expect(find.byType(PasswordTemplateView), findsOneWidget);
      expect(find.byKey(const Key('password_website_field')), findsOneWidget);
      expect(find.byKey(const Key('password_username_field')), findsOneWidget);
      expect(find.byKey(const Key('password_password_field')), findsOneWidget);
      expect(find.byKey(const Key('password_notes_field')), findsOneWidget);
      // No plain-text body editor anywhere.
      expect(_plainBodyEditor(), findsNothing);
      // Title editable inside the card.
      expect(find.byKey(const Key('template_title_field')), findsOneWidget);
      // Structured records: no ☑ quick-insert and no format toolbar.
      expect(find.byIcon(Icons.check_box_outlined), findsNothing);

      // Title change works in edit mode.
      await tester.enterText(
          find.byKey(const Key('template_title_field')), '新标题');
      await tester.pump(const Duration(milliseconds: 600));

      // Done exits editing back to the reading card.
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      expect(find.text('新标题'), findsOneWidget);
      expect(find.byKey(const Key('password_website_field')), findsNothing);

      // Body still a parseable Chinese template.
      final updated = await repo.getRecord(rec.id);
      expect(updated, isNotNull);
      expect(parsePasswordTemplate(updated!.body), isNotNull);
      expect(updated.body, contains('网站/应用：'));
      expect(updated.body, contains('密码：'));
      expect(updated.title, '新标题');
    });

    testWidgets('2. 改密码字段后完成，阅读态显示新密码', (tester) async {
      const body = '网站/应用：app\n用户名：u\n密码：old\n备注：';
      final repo = RecordRepository(db);
      final rec = await repo.createRecord(title: 't', body: body);

      await pumpEditPage(tester, db, rec.id);
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('password_password_field')), 'newpass123');
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      // Reading state: tap the eye to reveal, new password shown.
      await tester.tap(find.byIcon(Icons.visibility_outlined).first);
      await tester.pumpAndSettle();
      expect(find.text('newpass123'), findsOneWidget);

      final updated = await repo.getRecord(rec.id);
      expect(parsePasswordTemplate(updated!.body), isNotNull);
      expect(updated.body, contains('密码：newpass123'));
    });

    testWidgets('3. 英文模板：备注写 密码：xxx 不改标签语言', (tester) async {
      const body =
          'Website/App: MyApp\nUsername: user1\nPassword: secret1\nNotes: 密码：xxx';
      final repo = RecordRepository(db);
      final rec = await repo.createRecord(title: 'en', body: body);

      await pumpEditPage(
        tester,
        db,
        rec.id,
        locale: const Locale('en'),
      );
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('password_notes_field')), '密码：yyy');
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      final updated = await repo.getRecord(rec.id);
      expect(parsePasswordTemplate(updated!.body), isNotNull);
      // Labels stay English.
      expect(updated.body, contains('Website/App:'));
      expect(updated.body, contains('Notes:'));
      expect(updated.body, isNot(contains('网站/应用')));
      expect(updated.body, isNot(contains('用户名')));
    });

    testWidgets('4. 联系人（只有地址、多行地址）重新编辑', (tester) async {
      const body = '地址：北京市朝阳区\n某某街道1号\n备注：';
      final repo = RecordRepository(db);
      final rec = await repo.createRecord(title: '朋友', body: body);

      await pumpEditPage(tester, db, rec.id);
      expect(find.byType(ContactTemplateView), findsOneWidget);

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(ContactTemplateView), findsOneWidget);
      expect(find.byKey(const Key('contact_address_field')), findsOneWidget);
      expect(_plainBodyEditor(), findsNothing);

      // Edit the notes field; the multi-line address must survive the
      // edit round-trip untouched.
      await tester.enterText(
          find.byKey(const Key('contact_notes_field')), '老同学');
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      // Address renders as SelectableText in the reading card, still
      // multi-line and unchanged.
      expect(
        find.byWidgetPredicate(
          (w) => w is SelectableText && w.data == '北京市朝阳区\n某某街道1号',
          description: 'read-view address text',
        ),
        findsOneWidget,
      );

      final updated = await repo.getRecord(rec.id);
      expect(parseContactTemplate(updated!.body), isNotNull);
      expect(updated.body, contains('地址：'));
      expect(updated.body, contains('某某街道1号'));
      expect(updated.body, contains('备注：老同学'));
    });

    testWidgets('5. 灵感记录重新编辑', (tester) async {
      const body = '灵感：早起跑步\n来源：朋友推荐\n下一步行动：定闹钟';
      final repo = RecordRepository(db);
      final rec = await repo.createRecord(title: '想法', body: body);

      await pumpEditPage(tester, db, rec.id);
      expect(find.byType(IdeaTemplateView), findsOneWidget);

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(IdeaTemplateView), findsOneWidget);
      expect(find.byKey(const Key('idea_idea_field')), findsOneWidget);
      expect(_plainBodyEditor(), findsNothing);

      await tester.enterText(find.byKey(const Key('idea_idea_field')), '晚上跑步');
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      expect(find.text('晚上跑步'), findsOneWidget);

      final updated = await repo.getRecord(rec.id);
      expect(parseIdeaTemplate(updated!.body), isNotNull);
      expect(updated.body, contains('灵感：'));
    });

    testWidgets('6. 空白笔记点正文仍进纯文本编辑（回归）', (tester) async {
      const body = '这是一条普通笔记';
      final repo = RecordRepository(db);
      final rec = await repo.createRecord(title: '笔记', body: body);

      await pumpEditPage(tester, db, rec.id);
      expect(find.byType(BlankTemplateView), findsOneWidget);

      // Tap the body text to enter plain-text editing.
      await tester.tap(find.text(body));
      await tester.pumpAndSettle();

      expect(find.byType(BlankTemplateView), findsNothing);
      expect(_plainBodyEditor(), findsOneWidget);
    });

    testWidgets('7. 编辑中清空所有字段，视图仍是该模板表单', (tester) async {
      const body = '网站/应用：a\n用户名：b\n密码：c\n备注：d';
      final repo = RecordRepository(db);
      final rec = await repo.createRecord(title: 't', body: body);

      await pumpEditPage(tester, db, rec.id);
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      for (final key in [
        const Key('password_website_field'),
        const Key('password_username_field'),
        const Key('password_password_field'),
        const Key('password_notes_field'),
      ]) {
        await tester.enterText(find.byKey(key), '');
      }
      await tester.pump(const Duration(milliseconds: 600));

      // Locked kind: still the password form, never jumps to another view.
      expect(find.byType(PasswordTemplateView), findsOneWidget);
      expect(find.byKey(const Key('password_website_field')), findsOneWidget);
      expect(_plainBodyEditor(), findsNothing);
    });
    testWidgets('8. 返回键第一次只退出编辑并保存，第二次离开页面', (tester) async {
      const body = '网站/应用：a\n用户名：b\n密码：c\n备注：d';
      final repo = RecordRepository(db);
      final rec = await repo.createRecord(title: 't', body: body);

      await pumpEditPage(tester, db, rec.id);
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('password_website_field')), findsOneWidget);

      // First back: exits editing only, keeps the form card.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('password_website_field')), findsNothing);
      expect(find.byType(PasswordTemplateView), findsOneWidget);

      // Second back: leaves the page.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(PasswordTemplateView), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });
  });
}
