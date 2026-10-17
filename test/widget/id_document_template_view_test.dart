// test/widget/id_document_template_view_test.dart
// Widget tests for ID Document Template View (Round 5: read-only view backed
// by IdDocData — editing moved to IdDocForm):
// 1) Field labels render correctly.
// 2) Document number is masked by default with ••••••.
// 3) Eye icon toggles document number visibility.
// 4) Localized type name shown on the ID card; read mode has no edit widgets.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suicun/features/records/domain/id_doc_data.dart';
import 'package:suicun/features/records/presentation/template_views/id_document_template_view.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';

Widget createTestWidget({
  required Widget child,
  Locale locale = const Locale('zh'),
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: child,
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'onboarding_clipboard_asked': true});
  });

  group('IdDocumentTemplateView widget tests', () {
    testWidgets(
      'renders field labels, masks document number by default, and toggles eye visibility',
      (tester) async {
        final testData = IdDocData(
          type: 'cn_resident_id',
          name: '张三',
          number: '110101199003072345',
          noExpiry: true,
          note: '个人证件备注',
        );

        await tester.pumpWidget(
          createTestWidget(
            child: IdDocumentTemplateView(
              data: testData,
              record: null,
              onEdit: () {},
              categoryRow: const Text('CategoryRow'),
              tagRow: const Text('TagRow'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify field labels.
        expect(find.text('姓名'), findsOneWidget);
        expect(find.text('证件号码'), findsOneWidget);
        expect(find.text('有效期至'), findsOneWidget);
        expect(find.text('备注'), findsOneWidget);

        // 2. Verify values rendered. Localized type name lives on the ID
        // card; the name appears both on the card and in the fields card.
        expect(find.text('中国居民身份证'), findsOneWidget);
        expect(find.text('张三'), findsNWidgets(2));
        expect(find.text('长期'), findsWidgets);
        expect(find.text('个人证件备注'), findsOneWidget);

        // 2b. Read mode shows the ID card view with hint + present button.
        expect(find.text('长按卡片复制号码'), findsOneWidget);
        expect(find.text('全屏查看'), findsOneWidget);

        // 3. Document number masked by default
        expect(find.byKey(const Key('id_doc_number_masked_text')), findsOneWidget);
        expect(find.text('••••••'), findsOneWidget);
        expect(find.text('110101199003072345'), findsNothing);

        // 4. Tap eye toggle icon to show real document number
        final toggleFinder = find.byKey(const Key('id_doc_number_toggle_obscure'));
        expect(toggleFinder, findsOneWidget);
        await tester.ensureVisible(toggleFinder);
        await tester.pumpAndSettle();
        await tester.tap(toggleFinder);
        await tester.pumpAndSettle();

        expect(find.text('110101199003072345'), findsOneWidget);
        expect(find.text('••••••'), findsNothing);

        // 5. Tap eye toggle icon again to obscure document number
        await tester.tap(toggleFinder);
        await tester.pumpAndSettle();

        expect(find.text('••••••'), findsOneWidget);
        expect(find.text('110101199003072345'), findsNothing);
      },
    );

    testWidgets(
      'read mode has no editing widgets',
      (tester) async {
        final testData = IdDocData(
          type: 'passport',
          name: '李四',
          number: 'E12345678',
        );

        await tester.pumpWidget(
          createTestWidget(
            child: IdDocumentTemplateView(
              data: testData,
              record: null,
              onEdit: () {},
              categoryRow: const Text('CategoryRow'),
              tagRow: const Text('TagRow'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // No edit-mode widgets exist anymore (editing moved to IdDocForm).
        expect(find.byKey(const Key('id_doc_type_dropdown')), findsNothing);
        expect(find.byKey(const Key('id_doc_name_field')), findsNothing);
        expect(find.byKey(const Key('id_doc_number_field')), findsNothing);
        expect(find.byKey(const Key('id_doc_valid_until_field')), findsNothing);
        expect(find.byKey(const Key('id_doc_notes_field')), findsNothing);
        expect(find.byKey(const Key('id_photo_front_camera_button')), findsNothing);

        // Read-mode content is present.
        expect(find.text('护照'), findsOneWidget);
        expect(find.text('李四'), findsNWidgets(2));
      },
    );

    testWidgets(
      'english locale renders english labels and obscures document number',
      (tester) async {
        final testData = IdDocData(
          type: 'passport',
          name: 'John Doe',
          number: 'E12345678',
          noExpiry: true,
          note: 'Travel document',
        );

        await tester.pumpWidget(
          createTestWidget(
            locale: const Locale('en'),
            child: IdDocumentTemplateView(
              data: testData,
              record: null,
              onEdit: () {},
              categoryRow: const Text('CategoryRow'),
              tagRow: const Text('TagRow'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Name'), findsOneWidget);
        expect(find.text('Document number'), findsOneWidget);
        expect(find.text('Valid until'), findsOneWidget);
        expect(find.text('Notes'), findsOneWidget);

        // Localized type name is shown on the ID card.
        expect(find.text('Passport'), findsOneWidget);
        expect(find.text('No expiry'), findsWidgets);

        expect(find.text('••••••'), findsOneWidget);
        expect(find.text('E12345678'), findsNothing);

        final enToggleFinder =
            find.byKey(const Key('id_doc_number_toggle_obscure'));
        await tester.ensureVisible(enToggleFinder);
        await tester.pumpAndSettle();
        await tester.tap(enToggleFinder);
        await tester.pumpAndSettle();

        expect(find.text('E12345678'), findsOneWidget);
        expect(find.text('••••••'), findsNothing);
      },
    );
  });
}
