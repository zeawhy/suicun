// test/widget/record_card_gradient_test.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suicun/features/categories/domain/category_model.dart';
import 'package:suicun/features/records/domain/record_model.dart';
import 'package:suicun/features/records/presentation/home_sort_provider.dart';
import 'package:suicun/features/tags/domain/tag_model.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';
import 'package:suicun/shared/theme/app_theme.dart';
import 'package:suicun/shared/widgets/record_card.dart';

Widget wrapCard({
  required RecordDetail record,
  ThemeData? theme,
  Locale locale = const Locale('zh'),
}) {
  return MaterialApp(
    theme: theme ?? AppTheme.lightTheme(),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: RecordCard(
        record: record,
        sortMode: RecordSortMode.byUpdatedAt,
        isSelected: false,
        isMultiSelectMode: false,
        onTap: () {},
        onLongPress: () {},
        onFavoriteToggle: () {},
        isQuickAccess: false,
        onQuickAccessToggle: () {},
        onEdit: () {},
        onChangeCategory: () {},
        onDelete: () {},
        untitledLabel: '无标题',
        uncategorizedLabel: '未分类',
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RecordCard Three-Level Gradient & Actions', () {
    testWidgets('password record shows lock icon, masked password, and copy button',
        (tester) async {
      String? copiedData;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedData = (call.arguments as Map)['text'] as String?;
            return null;
          }
          if (call.method == 'HapticFeedback.vibrate') {
            return null;
          }
          return null;
        },
      );

      final now = DateTime.now();
      final record = RecordDetail(
        record: RecordModel(
          id: 'pwd-1',
          title: 'GitHub 账号',
          body: '网站/应用：github.com\n用户名：octocat\n密码：SecretP@ss123\n备注：开发用',
          isFavorite: true,
          createdAt: now,
          updatedAt: now,
        ),
        category: const CategoryModel(
          id: 'cat-1',
          name: '工作',
          color: '#3265E5',
        ),
        tags: [
          TagModel(id: 't-1', name: 'dev'),
        ],
      );

      await tester.pumpWidget(wrapCard(record: record));
      await tester.pumpAndSettle();

      // Level 1: Lock icon + Title + Star + Copy button
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.text('GitHub 账号'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      expect(find.byIcon(Icons.copy_rounded), findsOneWidget);

      // Level 2: Masked dots displayed, original password hidden
      expect(find.textContaining('••••••••'), findsOneWidget);
      expect(find.text('SecretP@ss123'), findsNothing);

      // Level 3: Category dot + tag + relative time
      expect(find.text('工作'), findsOneWidget);
      expect(find.text('#dev'), findsOneWidget);

      // Tap copy button -> copies original password and shows SnackBar
      await tester.tap(find.byIcon(Icons.copy_rounded));
      await tester.pumpAndSettle();

      expect(copiedData, 'SecretP@ss123');
      expect(find.text('已复制到剪贴板'), findsOneWidget);
    });

    testWidgets('id document record shows badge icon, masked number, and copies docNumber',
        (tester) async {
      String? copiedData;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedData = (call.arguments as Map)['text'] as String?;
            return null;
          }
          return null;
        },
      );

      final now = DateTime.now();
      final record = RecordDetail(
        record: RecordModel(
          id: 'id-1',
          title: '居民身份证',
          body: '证件类型：身份证\n姓名：张三\n证件号码：110101199003072345\n有效期至：2030-01-01',
          isFavorite: false,
          createdAt: now,
          updatedAt: now,
        ),
        tags: const [],
      );

      await tester.pumpWidget(wrapCard(record: record));
      await tester.pumpAndSettle();

      // Level 1: Badge icon + Copy button
      expect(find.byIcon(Icons.badge_outlined), findsOneWidget);
      expect(find.byIcon(Icons.copy_rounded), findsOneWidget);

      // Level 2: Masked docNumber
      expect(find.textContaining('1101********2345'), findsOneWidget);
      expect(find.text('110101199003072345'), findsNothing);

      // Tap copy button -> copies raw docNumber
      await tester.tap(find.byIcon(Icons.copy_rounded));
      await tester.pumpAndSettle();

      expect(copiedData, '110101199003072345');
      expect(find.text('已复制到剪贴板'), findsOneWidget);
    });

    testWidgets('plain note does NOT show copy button and displays up to 2 lines summary',
        (tester) async {
      final now = DateTime.now();
      final record = RecordDetail(
        record: RecordModel(
          id: 'note-1',
          title: '日常随想',
          body: '第一行内容概要\n第二行内容概要\n第三行内容不应在卡片中完整展示',
          isFavorite: false,
          createdAt: now,
          updatedAt: now,
        ),
        tags: const [],
      );

      await tester.pumpWidget(wrapCard(record: record));
      await tester.pumpAndSettle();

      // Note icon
      expect(find.byIcon(Icons.article_outlined), findsOneWidget);
      // No copy button
      expect(find.byIcon(Icons.copy_rounded), findsNothing);

      // 2 lines preview
      expect(find.text('第一行内容概要\n第二行内容概要'), findsOneWidget);
      expect(find.textContaining('第三行'), findsNothing);
    });
  });
}
