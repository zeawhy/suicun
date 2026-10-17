// test/widget/id_card_view_test.dart
// Widget tests for IdCardView (spec §2.11):
// - zh/en locales: localized type name, masked number, flip hint
// - eye toggle shows full number; long-press copies raw number
// - no back photo: tap does not flip, hint is idCardHintNoFlip
// - custom "other" type name shown as-is
// - no mixed-language UI text

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suicun/features/records/presentation/template_views/id_card_view.dart';
import 'package:suicun/features/records/presentation/template_views/id_doc_type.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';

// 1x1 transparent PNG.
const _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

Widget buildTestCard({
  required IdDocTypeKey docTypeKey,
  required String docTypeLabel,
  String? name,
  String? docNumber,
  String? validUntil,
  File? frontPhoto,
  File? backPhoto,
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
        child: IdCardView(
          docTypeKey: docTypeKey,
          docTypeLabel: docTypeLabel,
          name: name,
          docNumber: docNumber,
          validUntil: validUntil,
          frontPhoto: frontPhoto,
          backPhoto: backPhoto,
          onPresent: () {},
          onSharePhoto: (_, __) async {},
          onSavePhoto: (_, __) async {},
        ),
      ),
    ),
  );
}

File makePhotoFile(String name) {
  final file = File('${Directory.systemTemp.path}/$name.png');
  file.writeAsBytesSync(base64Decode(_pngBase64));
  return file;
}

String? _mockClipboardText;

/// Widget tests have no real platform channel: mock clipboard + haptics.
/// Must be installed inside the test body (FakeAsync zone), not in setUp.
void installClipboardMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      switch (call.method) {
        case 'Clipboard.getData':
          return <String, dynamic>{'text': _mockClipboardText};
        case 'Clipboard.setData':
          _mockClipboardText =
              (call.arguments as Map<dynamic, dynamic>)['text'] as String?;
          return null;
        default:
          return null; // HapticFeedback etc.: no-op
      }
    },
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('IdCardView zh locale', () {
    testWidgets(
      'renders ID card with photos: localized type, masked number, flip hint',
      (tester) async {
        final front = makePhotoFile('idcard_front');
        final back = makePhotoFile('idcard_back');

        await tester.pumpWidget(
          buildTestCard(
            docTypeKey: IdDocTypeKey.idCard,
            docTypeLabel: '身份证',
            name: '张三',
            docNumber: '110101199003072345',
            validUntil: '2035-12-31',
            frontPhoto: front,
            backPhoto: back,
          ),
        );
        await tester.pumpAndSettle();

        // Localized type name on the card.
        expect(find.text('身份证'), findsOneWidget);
        // Number masked by default.
        expect(find.text('1101 **** **** **** 2345'), findsOneWidget);
        expect(find.textContaining('110101199003072345'), findsNothing);
        // Flip hint below the card.
        expect(find.text('点击卡片翻面 · 长按复制号码'), findsOneWidget);
        // Present button.
        expect(find.text('出示证件'), findsOneWidget);
        // No mixed-language brand text.
        expect(find.textContaining('SuiVault'), findsNothing);
      },
    );

    testWidgets(
      'eye toggle shows full number; long-press copies raw number',
      (tester) async {
        installClipboardMock();
        _mockClipboardText = null;
        await tester.pumpWidget(
          buildTestCard(
            docTypeKey: IdDocTypeKey.idCard,
            docTypeLabel: '身份证',
            name: '张三',
            docNumber: '110101199003072345',
          ),
        );
        await tester.pumpAndSettle();

        // Tap the eye icon -> full formatted number.
        await tester.tap(find.byKey(const Key('id_card_number_eye')));
        await tester.pumpAndSettle();
        expect(find.text('1101 0119 9003 0723 45'), findsOneWidget);
        expect(find.text('1101 **** **** **** 2345'), findsNothing);

        // Long-press the card -> clipboard gets the raw number (no spaces).
        await tester
            .longPress(find.byKey(const Key('id_card_gesture')));
        await tester.pump();
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        expect(data?.text, '110101199003072345');
      },
    );

    testWidgets(
      'no back photo: tap does not flip, hint is idCardHintNoFlip',
      (tester) async {
        final front = makePhotoFile('idcard_front_only');

        await tester.pumpWidget(
          buildTestCard(
            docTypeKey: IdDocTypeKey.passport,
            docTypeLabel: '护照',
            name: 'John',
            docNumber: 'E12345678',
            frontPhoto: front,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('长按卡片复制号码'), findsOneWidget);
        expect(find.text('点击卡片翻面 · 长按复制号码'), findsNothing);

        await tester.tap(find.byKey(const Key('id_card_gesture')));
        await tester.pumpAndSettle();

        // Still the front: no back-side content.
        expect(find.text('翻回正面'), findsNothing);
        expect(find.text('护照'), findsOneWidget);
      },
    );

    testWidgets(
      'tap card flips to back when a back photo exists',
      (tester) async {
        final front = makePhotoFile('idcard_front2');
        final back = makePhotoFile('idcard_back2');

        await tester.pumpWidget(
          buildTestCard(
            docTypeKey: IdDocTypeKey.idCard,
            docTypeLabel: '身份证',
            name: '张三',
            docNumber: '110101199003072345',
            frontPhoto: front,
            backPhoto: back,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('id_card_gesture')));
        await tester.pumpAndSettle();

        expect(find.text('翻回正面'), findsOneWidget);
        expect(find.text('点击查看'), findsOneWidget);
      },
    );

    testWidgets(
      'custom other type name is shown as-is',
      (tester) async {
        await tester.pumpWidget(
          buildTestCard(
            docTypeKey: IdDocTypeKey.other,
            docTypeLabel: '学生卡',
            name: '李四',
            docNumber: '123456',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('学生卡'), findsOneWidget);
        // Short number fully masked.
        expect(find.text('******'), findsOneWidget);
      },
    );
  });

  group('IdCardView en locale', () {
    testWidgets(
      'renders english labels with no chinese UI text',
      (tester) async {
        final front = makePhotoFile('idcard_front_en');
        final back = makePhotoFile('idcard_back_en');

        await tester.pumpWidget(
          buildTestCard(
            docTypeKey: IdDocTypeKey.idCard,
            docTypeLabel: 'ID Card',
            name: 'John Doe',
            docNumber: '110101199003072345',
            validUntil: '2035-12-31',
            frontPhoto: front,
            backPhoto: back,
            locale: const Locale('en'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('ID Card'), findsOneWidget);
        expect(find.text('1101 **** **** **** 2345'), findsOneWidget);
        expect(
          find.text('Tap to flip · Long-press to copy number'),
          findsOneWidget,
        );
        expect(find.text('Show document'), findsOneWidget);
        expect(find.text('Valid until 2035-12-31'), findsOneWidget);
        // No chinese UI text.
        expect(find.textContaining('随存'), findsNothing);
        expect(find.textContaining('身份证'), findsNothing);
      },
    );
  });

  group('IdCardView dark mode', () {
    testWidgets(
      'renders without overflow in dark mode',
      (tester) async {
        final front = makePhotoFile('idcard_front_dark');
        final back = makePhotoFile('idcard_back_dark');

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh'),
            theme: ThemeData.dark(),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: IdCardView(
                  docTypeKey: IdDocTypeKey.passport,
                  docTypeLabel: '护照',
                  name: '王五',
                  docNumber: 'E12345678',
                  validUntil: '2030-01-01',
                  frontPhoto: front,
                  backPhoto: back,
                  onPresent: () {},
                  onSharePhoto: (_, __) async {},
                  onSavePhoto: (_, __) async {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('护照'), findsOneWidget);
        expect(find.text('E1*****78'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('localizedDocType', () {
    testWidgets(
      'known types follow locale; custom other shown as-is',
      (tester) async {
        String? zhPassport;
        String? zhCustom;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (ctx) {
                zhPassport =
                    localizedDocType(ctx, IdDocTypeKey.passport, '护照');
                zhCustom =
                    localizedDocType(ctx, IdDocTypeKey.other, '学生卡');
                return const SizedBox();
              },
            ),
          ),
        );
        expect(zhPassport, '护照');
        expect(zhCustom, '学生卡');

        String? enPassport;
        String? enOther;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (ctx) {
                enPassport =
                    localizedDocType(ctx, IdDocTypeKey.passport, '护照');
                enOther = localizedDocType(ctx, IdDocTypeKey.other, '其他');
                return const SizedBox();
              },
            ),
          ),
        );
        // Stored chinese name is re-localized to english; the stored body
        // itself is never rewritten.
        expect(enPassport, 'Passport');
        expect(enOther, 'Other');
      },
    );
  });
}
