// test/widget/category_display_name_test.dart
// Tests for categoryDisplayName(): built-in Chinese stored names resolve to
// the current locale; user-created names pass through unchanged.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suicun/features/categories/presentation/category_display_name.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';

Widget _harness(Locale locale, String storedName) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Text(categoryDisplayName(context, storedName)),
    ),
  );
}

void main() {
  testWidgets('built-in names follow Chinese locale', (tester) async {
    await tester.pumpWidget(_harness(const Locale('zh'), '工作'));
    expect(find.text('工作'), findsOneWidget);

    await tester.pumpWidget(_harness(const Locale('zh'), '待办'));
    expect(find.text('待办'), findsOneWidget);
  });

  testWidgets('built-in names follow English locale', (tester) async {
    await tester.pumpWidget(_harness(const Locale('en'), '工作'));
    expect(find.text('Work'), findsOneWidget);

    await tester.pumpWidget(_harness(const Locale('en'), '学习'));
    expect(find.text('Study'), findsOneWidget);

    await tester.pumpWidget(_harness(const Locale('en'), '生活'));
    expect(find.text('Life'), findsOneWidget);

    await tester.pumpWidget(_harness(const Locale('en'), '灵感'));
    expect(find.text('Ideas'), findsOneWidget);

    await tester.pumpWidget(_harness(const Locale('en'), '待办'));
    expect(find.text('To Do'), findsOneWidget);
  });

  testWidgets('user-created names pass through unchanged', (tester) async {
    await tester.pumpWidget(_harness(const Locale('en'), '我的收藏'));
    expect(find.text('我的收藏'), findsOneWidget);

    await tester.pumpWidget(_harness(const Locale('zh'), 'My Custom'));
    expect(find.text('My Custom'), findsOneWidget);
  });
}
