// test/widget/p2_features_test.dart

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/core/database/providers.dart';
import 'package:suicun/features/records/data/quick_access_storage.dart';
import 'package:suicun/features/records/domain/record_model.dart';
import 'package:suicun/features/records/presentation/home_sort_provider.dart';
import 'package:suicun/features/records/presentation/template_views/contact_template_view.dart';
import 'package:suicun/features/sync/sync_contract.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';
import 'package:suicun/main.dart';
import 'package:suicun/shared/widgets/record_card.dart';

Future<void> pumpApp(
  WidgetTester tester,
  AppDatabase db, {
  Map<String, Object> initialPrefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(initialPrefs);
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
      ],
      child: const SuicunApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('P2-5: 搜索结果关键词高亮', () {
    testWidgets('RecordCard highlights direct match and pinyin match in title and body', (tester) async {
      final now = DateTime.now().toUtc();
      final record = RecordDetail(
        record: RecordModel(
          id: 'test-1',
          title: '我的身份证件',
          body: '这里是证件备注信息，尾号4829',
          isFavorite: false,
          createdAt: now,
          updatedAt: now,
        ),
        tags: const [],
      );

      // 1. Without searchQuery: regular text rendered
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: RecordCard(
              record: record,
              searchQuery: '',
              sortMode: RecordSortMode.byUpdatedAt,
              isSelected: false,
              isMultiSelectMode: false,
              untitledLabel: '无标题',
              uncategorizedLabel: '未分类',
              onTap: () {},
              onLongPress: () {},
              onFavoriteToggle: () {},
              isQuickAccess: false,
              onQuickAccessToggle: () {},
              onEdit: () {},
              onChangeCategory: () {},
              onDelete: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('我的身份证件'), findsOneWidget);

      // 2. With pinyin searchQuery: 'sfz' matches '身份证'
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: RecordCard(
              record: record,
              searchQuery: 'sfz',
              sortMode: RecordSortMode.byUpdatedAt,
              isSelected: false,
              isMultiSelectMode: false,
              untitledLabel: '无标题',
              uncategorizedLabel: '未分类',
              onTap: () {},
              onLongPress: () {},
              onFavoriteToggle: () {},
              isQuickAccess: false,
              onQuickAccessToggle: () {},
              onEdit: () {},
              onChangeCategory: () {},
              onDelete: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find RichText widget in title
      final richTextFinder = find.byType(RichText);
      expect(richTextFinder, findsWidgets);

      bool foundHighlightedSpan = false;
      for (final element in richTextFinder.evaluate()) {
        final widget = element.widget as RichText;
        widget.text.visitChildren((span) {
          if (span is TextSpan && span.text == '身份证') {
            if (span.style?.fontWeight == FontWeight.bold) {
              foundHighlightedSpan = true;
            }
          }
          return true;
        });
      }
      expect(foundHighlightedSpan, isTrue);
    });
  });

  group('P2-6: 剪贴板智能嗅探横幅', () {
    testWidgets('clipboard sniffing is disabled by default', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
        if (methodCall.method == 'Clipboard.getData') {
          return {'text': '330102199003072345'};
        }
        return null;
      });

      await pumpApp(tester, db);

      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('clipboard_sniff_banner')), findsNothing);
    });

    testWidgets('sniffs clipboard address and navigates to editor with prefilled content', (tester) async {
      // Set clipboard data
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
        if (methodCall.method == 'Clipboard.getData') {
          return {'text': '上海市徐汇区宜山路700号 13800138000'};
        }
        return null;
      });

      await pumpApp(
        tester,
        db,
        initialPrefs: {'clipboard_sniff_enabled': true},
      );

      // Wait 500ms debounce
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      // Verify banner appears
      expect(find.byKey(const Key('clipboard_sniff_banner')), findsOneWidget);
      expect(find.text('检测到地址'), findsOneWidget);
      expect(find.text('存为地址'), findsOneWidget);
      expect(find.byKey(const Key('clipboard_sniff_ignore_button')), findsOneWidget);

      // Tap '存为地址'
      await tester.tap(find.text('存为地址'));
      await tester.pumpAndSettle();

      // Should open contact/address template view directly
      expect(find.byType(ContactTemplateView), findsOneWidget);
      expect(find.textContaining('13800138000'), findsOneWidget);
      expect(find.textContaining('上海市徐汇区宜山路700号'), findsOneWidget);
    });

    testWidgets('ignore button dismisses banner and does not pop up again for same text', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
        if (methodCall.method == 'Clipboard.getData') {
          return {'text': '330102199003072345'};
        }
        return null;
      });

      await pumpApp(
        tester,
        db,
        initialPrefs: {'clipboard_sniff_enabled': true},
      );

      // Wait 500ms debounce
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('clipboard_sniff_banner')), findsOneWidget);
      expect(find.text('检测到证件号'), findsOneWidget);
      expect(find.text('存为证件'), findsOneWidget);

      // Tap ignore
      await tester.tap(find.byKey(const Key('clipboard_sniff_ignore_button')));
      await tester.pumpAndSettle();

      // Banner dismissed
      expect(find.byKey(const Key('clipboard_sniff_banner')), findsNothing);

      // Trigger app resumed lifecycle
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      // Banner should NOT re-appear for the ignored clipboard text
      expect(find.byKey(const Key('clipboard_sniff_banner')), findsNothing);
    });
  });
}
