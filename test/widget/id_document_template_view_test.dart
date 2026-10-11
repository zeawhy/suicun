// test/widget/id_document_template_view_test.dart
// Widget tests for ID Document Template View:
// 1) Field labels render correctly.
// 2) Document number is masked by default with ••••••.
// 3) Eye icon toggles document number visibility.
// 4) Edit mode renders dropdown, text fields, and photo picker buttons.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suicun/features/records/presentation/template_views/id_document_template_view.dart';
import 'package:suicun/features/records/presentation/template_views/template_detector.dart';
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
    SharedPreferences.setMockInitialValues({});
  });

  group('IdDocumentTemplateView widget tests', () {
    testWidgets(
      'renders field labels, masks document number by default, and toggles eye visibility',
      (tester) async {
        const testData = IdDocumentTemplateData(
          docType: '身份证',
          name: '张三',
          docNumber: '110101199003072345',
          validUntil: '2035-12-31',
          notes: '个人证件备注',
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

        // 1. Verify field labels
        expect(find.text('证件类型'), findsOneWidget);
        expect(find.text('姓名'), findsOneWidget);
        expect(find.text('证件号码'), findsOneWidget);
        expect(find.text('有效期至'), findsOneWidget);
        expect(find.text('备注'), findsOneWidget);

        // 2. Verify non-sensitive text values rendered
        expect(find.text('身份证'), findsOneWidget);
        expect(find.text('张三'), findsOneWidget);
        expect(find.text('2035-12-31'), findsOneWidget);
        expect(find.text('个人证件备注'), findsOneWidget);

        // 3. Document number masked by default
        expect(find.byKey(const Key('id_doc_number_masked_text')), findsOneWidget);
        expect(find.text('••••••'), findsOneWidget);
        expect(find.text('110101199003072345'), findsNothing);

        // 4. Tap eye toggle icon to show real document number
        final toggleFinder = find.byKey(const Key('id_doc_number_toggle_obscure'));
        expect(toggleFinder, findsOneWidget);
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
      'editing mode renders dropdown, input fields, and photo picker buttons',
      (tester) async {
        String lastBody = '';

        await tester.pumpWidget(
          createTestWidget(
            child: IdDocumentTemplateView(
              data: const IdDocumentTemplateData(),
              record: null,
              isEditing: true,
              rawBody: '证件类型：\n姓名：\n证件号码：\n有效期至：\n证件照片正面：\n证件照片反面：\n备注：',
              onEdit: () {},
              onBodyChanged: (b) => lastBody = b,
              categoryRow: const Text('CategoryRow'),
              tagRow: const Text('TagRow'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify editor widgets are present
        expect(find.byKey(const Key('id_doc_type_dropdown')), findsOneWidget);
        expect(find.byKey(const Key('id_doc_name_field')), findsOneWidget);
        expect(find.byKey(const Key('id_doc_number_field')), findsOneWidget);
        expect(find.byKey(const Key('id_doc_valid_until_field')), findsOneWidget);
        expect(find.byKey(const Key('id_doc_notes_field')), findsOneWidget);

        // 2. Photo buttons
        expect(find.byKey(const Key('id_photo_front_camera_button')), findsOneWidget);
        expect(find.byKey(const Key('id_photo_front_gallery_button')), findsOneWidget);
        expect(find.byKey(const Key('id_photo_back_camera_button')), findsOneWidget);
        expect(find.byKey(const Key('id_photo_back_gallery_button')), findsOneWidget);

        // 3. Enter values and verify _syncBody updates
        await tester.enterText(find.byKey(const Key('id_doc_name_field')), '李四');
        await tester.enterText(
          find.byKey(const Key('id_doc_number_field')),
          '440301199201011234',
        );
        await tester.pumpAndSettle();

        expect(lastBody.contains('姓名：李四'), isTrue);
        expect(lastBody.contains('证件号码：440301199201011234'), isTrue);
      },
    );

    testWidgets(
      'english locale renders english labels and obscures document number',
      (tester) async {
        const testData = IdDocumentTemplateData(
          docType: 'Passport',
          name: 'John Doe',
          docNumber: 'E12345678',
          validUntil: '2030-01-01',
          notes: 'Travel document',
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

        expect(find.text('Document type'), findsOneWidget);
        expect(find.text('Name'), findsOneWidget);
        expect(find.text('Document number'), findsOneWidget);
        expect(find.text('Valid until'), findsOneWidget);
        expect(find.text('Notes'), findsOneWidget);

        expect(find.text('••••••'), findsOneWidget);
        expect(find.text('E12345678'), findsNothing);

        await tester.tap(find.byKey(const Key('id_doc_number_toggle_obscure')));
        await tester.pumpAndSettle();

        expect(find.text('E12345678'), findsOneWidget);
        expect(find.text('••••••'), findsNothing);
      },
    );
  });
}
