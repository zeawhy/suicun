// test/blank_reedit_test.dart
// Blank note focus and re-edit regression tests covering spec items 1-7:
// 1. 已有空白笔记 → 点 ✏️ → 点标题输入框 → 仍在编辑模式，标题可输入。
// 2. 编辑正文 → 点标题 → 再点正文 → 全程不退出编辑，内容已自动保存。
// 3. 编辑中点空白处 → 键盘收起，仍在编辑模式。
// 4. 点「完成」→ 退出编辑，显示阅读视图，标题和正文是修改后的内容。
// 5. 编辑中按返回 → 退出编辑但不离开页面；再按返回 → 离开页面。
// 6. 在空白笔记编辑中输入「密码：123」→ 编辑期间仍是空白笔记编辑器；点「完成」后才按密码模板显示。
// 7. 密码、联系人、灵感的重新编辑行为不变（回归）。

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
import 'package:suicun/features/security/data/app_lock_service.dart';
import 'package:suicun/features/security/data/security_providers.dart';
import 'package:suicun/features/sync/sync_contract.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';
import 'package:suicun/shared/theme/app_theme.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Blank note focus and re-edit suite', () {
    testWidgets('1. 已有空白笔记 → 点 ✏️ → 点标题输入框 → 仍在编辑模式，标题可输入', (tester) async {
      final repo = RecordRepository(db);
      final rec = await repo.createRecord(title: '初始标题', body: '初始正文');

      await pumpEditPage(tester, db, rec.id);
      expect(find.byType(BlankTemplateView), findsOneWidget);

      // Tap ✏️ in header card to enter editing.
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(BlankTemplateView), findsNothing);
      expect(find.byKey(const Key('record_title_field')), findsOneWidget);
      expect(find.byKey(const Key('record_body_field')), findsOneWidget);

      // Tap title input field
      await tester.tap(find.byKey(const Key('record_title_field')));
      await tester.pumpAndSettle();

      // Still in editing mode, title has focus and is editable.
      expect(find.byType(BlankTemplateView), findsNothing);
      expect(find.byKey(const Key('record_title_field')), findsOneWidget);
      final titleEditable = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const Key('record_title_field')),
          matching: find.byType(EditableText),
        ),
      );
      expect(titleEditable.focusNode.hasFocus, isTrue);

      await tester.enterText(
        find.byKey(const Key('record_title_field')),
        '新标题',
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('新标题'), findsOneWidget);
    });

    testWidgets('2. 编辑正文 → 点标题 → 再点正文 → 全程不退出编辑，内容已自动保存', (tester) async {
      final repo = RecordRepository(db);
      final rec = await repo.createRecord(title: '标题A', body: '正文A');

      await pumpEditPage(tester, db, rec.id);
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      // Edit body
      await tester.enterText(find.byKey(const Key('record_body_field')), '正文B');
      await tester.pump(const Duration(milliseconds: 100));

      // Tap title
      await tester.tap(find.byKey(const Key('record_title_field')));
      await tester.pumpAndSettle();
      expect(find.byType(BlankTemplateView), findsNothing);
      expect(find.byKey(const Key('record_body_field')), findsOneWidget);

      // Edit title
      await tester.enterText(find.byKey(const Key('record_title_field')), '标题B');
      await tester.pump(const Duration(milliseconds: 100));

      // Tap body again
      await tester.tap(find.byKey(const Key('record_body_field')));
      await tester.pumpAndSettle();
      expect(find.byType(BlankTemplateView), findsNothing);

      // Wait for debounce auto-save (500ms)
      await tester.pump(const Duration(milliseconds: 600));

      final updated = await repo.getRecord(rec.id);
      expect(updated, isNotNull);
      expect(updated!.title, '标题B');
      expect(updated.body, '正文B');
    });

    testWidgets('3. 编辑中点空白处 → 键盘收起，仍在编辑模式', (tester) async {
      final repo = RecordRepository(db);
      final rec = await repo.createRecord(title: '标题', body: '正文');

      await pumpEditPage(tester, db, rec.id);
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      // Focus body field
      await tester.tap(find.byKey(const Key('record_body_field')));
      await tester.pumpAndSettle();
      final bodyEditable = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const Key('record_body_field')),
          matching: find.byType(EditableText),
        ),
      );
      expect(bodyEditable.focusNode.hasFocus, isTrue);

      // Tap blank area (center of scaffold + vertical offset below content)
      final center = tester.getCenter(find.byType(Scaffold));
      await tester.tapAt(Offset(center.dx, center.dy + 150));
      await tester.pumpAndSettle();

      // Keyboard collapsed: body field lost focus
      expect(bodyEditable.focusNode.hasFocus, isFalse);

      // Still in editing mode!
      expect(find.byType(BlankTemplateView), findsNothing);
      expect(find.byKey(const Key('record_title_field')), findsOneWidget);
      expect(find.byKey(const Key('record_body_field')), findsOneWidget);
      expect(find.text('完成'), findsOneWidget);
    });

    testWidgets('4. 点「完成」→ 退出编辑，显示阅读视图，标题和正文是修改后的内容', (tester) async {
      final repo = RecordRepository(db);
      final rec = await repo.createRecord(title: '老标题', body: '老正文');

      await pumpEditPage(tester, db, rec.id);
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('record_title_field')),
        '新标题',
      );
      await tester.enterText(
        find.byKey(const Key('record_body_field')),
        '新正文',
      );
      await tester.pump(const Duration(milliseconds: 600));

      // Tap 完成
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      // Reading view is displayed
      expect(find.byType(BlankTemplateView), findsOneWidget);
      expect(find.byKey(const Key('record_title_field')), findsNothing);
      expect(find.byKey(const Key('record_body_field')), findsNothing);
      expect(find.text('新标题'), findsWidgets);
      expect(find.text('新正文'), findsOneWidget);

      final updated = await repo.getRecord(rec.id);
      expect(updated!.title, '新标题');
      expect(updated.body, '新正文');
    });

    testWidgets('5. 编辑中按返回 → 退出编辑但不离开页面；再按返回 → 离开页面', (tester) async {
      final repo = RecordRepository(db);
      final rec = await repo.createRecord(title: '老标题', body: '老正文');

      await pumpEditPage(tester, db, rec.id);
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('record_title_field')),
        '返回标题',
      );
      await tester.enterText(
        find.byKey(const Key('record_body_field')),
        '返回正文',
      );

      // First back press: exits edit mode but does not leave page
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byType(BlankTemplateView), findsOneWidget);
      expect(find.byKey(const Key('record_title_field')), findsNothing);
      expect(find.text('open'), findsNothing);
      expect(find.text('返回正文'), findsOneWidget);

      // Second back press: leaves the page
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byType(BlankTemplateView), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets(
      '6. 在空白笔记编辑中输入「密码：123」→ 编辑期间仍是空白笔记编辑器；点「完成」后才按密码模板显示',
      (tester) async {
        final repo = RecordRepository(db);
        final rec = await repo.createRecord(title: '测试密码', body: '初始内容');

        await pumpEditPage(tester, db, rec.id);
        expect(find.byType(BlankTemplateView), findsOneWidget);

        await tester.tap(find.byIcon(Icons.edit_outlined));
        await tester.pumpAndSettle();

        const passwordBody = '网站/应用：MyApp\n用户名：admin\n密码：123\n备注：';
        await tester.enterText(
          find.byKey(const Key('record_body_field')),
          passwordBody,
        );
        await tester.pump(const Duration(milliseconds: 600));

        // During editing: still the plain/blank editor, not PasswordTemplateView!
        expect(find.byType(PasswordTemplateView), findsNothing);
        expect(find.byKey(const Key('record_body_field')), findsOneWidget);

        // Tap 完成
        await tester.tap(find.text('完成'));
        await tester.pumpAndSettle();

        // After Done: now displayed as password template!
        expect(find.byKey(const Key('record_body_field')), findsNothing);
        expect(find.byType(PasswordTemplateView), findsOneWidget);
      },
    );

    testWidgets('7. 密码、联系人、灵感的重新编辑行为不变（回归）', (tester) async {
      final repo = RecordRepository(db);

      // 1. Password record
      const pwdBody = '网站/应用：test\n用户名：u\n密码：p\n备注：';
      final pwdRec = await repo.createRecord(title: '密码记录', body: pwdBody);
      await pumpEditPage(tester, db, pwdRec.id);
      expect(find.byType(PasswordTemplateView), findsOneWidget);
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('password_website_field')), findsOneWidget);
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('password_website_field')), findsNothing);
      expect(find.byType(PasswordTemplateView), findsOneWidget);

      // Exit to 'open'
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);

      // 2. Contact record
      const contactBody = '姓名：张三\n电话：13800138000\n备注：';
      final contactRec =
          await repo.createRecord(title: '联系人', body: contactBody);
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      nav.push(
        MaterialPageRoute(
          builder: (_) => EditRecordPage(recordId: contactRec.id),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ContactTemplateView), findsOneWidget);
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('contact_name_field')), findsOneWidget);
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('contact_name_field')), findsNothing);
      expect(find.byType(ContactTemplateView), findsOneWidget);

      // Exit to 'open'
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);

      // 3. Idea record
      const ideaBody = '灵感：新想法\n来源：思考\n下一步行动：写代码';
      final ideaRec = await repo.createRecord(title: '灵感', body: ideaBody);
      nav.push(
        MaterialPageRoute(
          builder: (_) => EditRecordPage(recordId: ideaRec.id),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(IdeaTemplateView), findsOneWidget);
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('idea_idea_field')), findsOneWidget);
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('idea_idea_field')), findsNothing);
      expect(find.byType(IdeaTemplateView), findsOneWidget);
    });
  });
}
