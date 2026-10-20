// test/widget/privacy_policy_page_test.dart
// Widget tests for the in-app Privacy Policy page:
// 1) zh locale renders all sections (incl. new 备份与导出 / 联系我们), no EN titles.
// 2) en locale renders all sections (incl. Backup & Export / Contact Us), no ZH titles.
// 3) Tapping the contact email launches mailto:yuliuslux@outlook.com.
// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:suicun/features/settings/presentation/privacy_policy_page.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

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

Future<void> _pumpPage(WidgetTester tester, Locale locale) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const PrivacyPolicyPage(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late FakeUrlLauncher fakeUrlLauncher;

  setUp(() {
    fakeUrlLauncher = FakeUrlLauncher();
    UrlLauncherPlatform.instance = fakeUrlLauncher;
  });

  testWidgets('zh locale: all sections, new wording, no EN titles',
      (tester) async {
    await _pumpPage(tester, const Locale('zh'));

    expect(find.text('数据存储'), findsOneWidget);
    expect(find.textContaining('SQLCipher'), findsOneWidget);
    expect(find.textContaining('系统照片选择器'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('备份与导出'), 200);
    expect(find.text('备份与导出'), findsOneWidget);
    expect(find.textContaining('Argon2id'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('联系我们'), 200);
    expect(find.text('联系我们'), findsOneWidget);
    expect(find.textContaining('yuliuslux@outlook.com'), findsOneWidget);

    // 单一语言：不得出现英文版章节标题。
    expect(find.text('Data Storage'), findsNothing);
    expect(find.text('Contact Us'), findsNothing);
    expect(find.text('Backup & Export'), findsNothing);
  });

  testWidgets('en locale: all sections, new wording, no ZH titles',
      (tester) async {
    await _pumpPage(tester, const Locale('en'));

    expect(find.text('Data Storage'), findsOneWidget);
    expect(find.textContaining('SQLCipher'), findsOneWidget);
    expect(find.textContaining('system photo picker'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Backup & Export'), 200);
    expect(find.text('Backup & Export'), findsOneWidget);
    expect(find.textContaining('Argon2id'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Contact Us'), 200);
    expect(find.text('Contact Us'), findsOneWidget);
    expect(find.textContaining('yuliuslux@outlook.com'), findsOneWidget);

    // 单一语言：不得出现中文版章节标题。
    expect(find.text('数据存储'), findsNothing);
    expect(find.text('联系我们'), findsNothing);
    expect(find.text('备份与导出'), findsNothing);
  });

  testWidgets('tapping the email launches mailto:', (tester) async {
    await _pumpPage(tester, const Locale('en'));

    await tester.scrollUntilVisible(find.text('yuliuslux@outlook.com'), 200);
    await tester.tap(find.text('yuliuslux@outlook.com'));
    await tester.pump();

    expect(fakeUrlLauncher.launchedUrls,
        contains('mailto:yuliuslux@outlook.com'));
  });
}
