// test/backup_reminder_test.dart
// Tests for backup reminder banner and settings backup status:
// 1. 2 条记录、未备份 → 不显示
// 2. 5 条记录、未备份 → 显示
// 3. 保存过证件、首次安装不足 1 天 → 不显示；超过 1 天 → 显示
// 4. 点 ✕ → 13 天内不显示，14 天后显示，并出现「不再提醒」
// 5. 点「不再提醒」→ 永不显示
// 6. 已出现 3 次 → 不再显示
// 7. 导出加密备份后 → 不显示
// 8. 开启同步后 → 不显示
// 9. 上次备份超过 30 天并且之后修改了 5 条 → 显示「已 30 天未备份」
// 10. 设置页备份状态文案在 3 种情况下都正确
// 11. 用 widget 测试检查：关闭按钮、「备份」按钮的颜色不是默认颜色，并且触控区域 ≥ 48×48

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suicun/features/backup/data/backup_providers.dart';
import 'package:suicun/features/records/domain/record_model.dart';
import 'package:suicun/features/records/presentation/home_page.dart';
import 'package:suicun/features/records/presentation/records_notifier.dart';
import 'package:suicun/features/settings/presentation/settings_page.dart';
import 'package:suicun/features/sync/sync_contract.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';
import 'package:suicun/shared/theme/app_theme.dart';

List<RecordDetail> _createMockRecords(int count, {DateTime? updatedAt}) {
  final now = updatedAt ?? DateTime.now().toUtc();
  return List.generate(
    count,
    (i) => RecordDetail(
      record: RecordModel(
        id: 'rec_$i',
        title: 'Title $i',
        body: 'Body $i',
        isFavorite: false,
        createdAt: now,
        updatedAt: now,
      ),
      category: null,
      tags: const [],
    ),
  );
}

Widget _buildTestApp({
  required Widget child,
  List<RecordDetail> records = const [],
  bool syncEnabled = false,
  Locale locale = const Locale('zh'),
  ThemeData? theme,
  int? lastBackupAtOverride,
  Key? key,
}) {
  return ProviderScope(
    key: key ?? UniqueKey(),
    overrides: [
      recordsListProvider.overrideWith((ref) => Future.value(records)),
      syncOverviewProvider.overrideWith(
        (ref) => Stream.value(
          SyncOverview(enabled: syncEnabled, syncing: false),
        ),
      ),
      lastEncryptedBackupAtProvider.overrideWith(
        (ref) => Future.value(lastBackupAtOverride),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: theme ?? AppTheme.lightTheme(),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('1. 2 条记录、未备份 → 不显示', (tester) async {
    SharedPreferences.setMockInitialValues({
      'first_launch_at': DateTime.now().millisecondsSinceEpoch,
    });

    await tester.pumpWidget(
      _buildTestApp(
        child: const BackupReminderBanner(),
        records: _createMockRecords(2),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('数据只存在这台手机上，建议备份'), findsNothing);
  });

  testWidgets('2. 5 条记录、未备份 → 显示', (tester) async {
    SharedPreferences.setMockInitialValues({
      'first_launch_at': DateTime.now().millisecondsSinceEpoch,
    });

    await tester.pumpWidget(
      _buildTestApp(
        child: const BackupReminderBanner(),
        records: _createMockRecords(5),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('数据只存在这台手机上，建议备份'), findsOneWidget);
    expect(find.text('备份'), findsOneWidget);
    expect(find.text('不再提醒'), findsNothing);
  });

  testWidgets('3. 保存过证件、首次安装不足 1 天 → 不显示；超过 1 天 → 显示', (tester) async {
    final now = DateTime.now();

    // 不足 1 天
    SharedPreferences.setMockInitialValues({
      'id_doc_saved_once': true,
      'first_launch_at':
          now.subtract(const Duration(hours: 12)).millisecondsSinceEpoch,
    });

    await tester.pumpWidget(
      _buildTestApp(
        child: const BackupReminderBanner(),
        records: const [],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('数据只存在这台手机上，建议备份'), findsNothing);

    // 超过 1 天
    SharedPreferences.setMockInitialValues({
      'id_doc_saved_once': true,
      'first_launch_at':
          now.subtract(const Duration(hours: 25)).millisecondsSinceEpoch,
    });

    await tester.pumpWidget(
      _buildTestApp(
        child: const BackupReminderBanner(),
        records: const [],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('数据只存在这台手机上，建议备份'), findsOneWidget);
  });

  testWidgets('4. 点 ✕ → 13 天内不显示，14 天后显示，并出现「不再提醒」', (tester) async {
    final now = DateTime.now();

    // 初始显示并点击 ✕
    SharedPreferences.setMockInitialValues({
      'first_launch_at':
          now.subtract(const Duration(days: 2)).millisecondsSinceEpoch,
    });

    await tester.pumpWidget(
      _buildTestApp(
        child: const BackupReminderBanner(),
        records: _createMockRecords(5),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('数据只存在这台手机上，建议备份'), findsOneWidget);
    expect(find.text('不再提醒'), findsNothing);

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    expect(find.text('数据只存在这台手机上，建议备份'), findsNothing);

    // 13 天后检查：不显示
    SharedPreferences.setMockInitialValues({
      'backup_reminder_shown_count': 1,
      'backup_reminder_dismissed_at':
          now.subtract(const Duration(days: 13)).millisecondsSinceEpoch,
      'first_launch_at':
          now.subtract(const Duration(days: 15)).millisecondsSinceEpoch,
    });

    await tester.pumpWidget(
      _buildTestApp(
        child: BackupReminderBanner(key: UniqueKey()),
        records: _createMockRecords(5),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('数据只存在这台手机上，建议备份'), findsNothing);

    // 14 天后检查：显示，并出现「不再提醒」
    SharedPreferences.setMockInitialValues({
      'backup_reminder_shown_count': 1,
      'backup_reminder_dismissed_at':
          now.subtract(const Duration(days: 14, seconds: 10)).millisecondsSinceEpoch,
      'first_launch_at':
          now.subtract(const Duration(days: 16)).millisecondsSinceEpoch,
    });

    await tester.pumpWidget(
      _buildTestApp(
        child: BackupReminderBanner(key: UniqueKey()),
        records: _createMockRecords(5),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('数据只存在这台手机上，建议备份'), findsOneWidget);
    expect(find.text('不再提醒'), findsOneWidget);
  });

  testWidgets('5. 点「不再提醒」→ 永不显示', (tester) async {
    final now = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'backup_reminder_shown_count': 1,
      'backup_reminder_dismissed_at':
          now.subtract(const Duration(days: 14, seconds: 10)).millisecondsSinceEpoch,
      'first_launch_at':
          now.subtract(const Duration(days: 16)).millisecondsSinceEpoch,
    });

    await tester.pumpWidget(
      _buildTestApp(
        child: const BackupReminderBanner(),
        records: _createMockRecords(5),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('不再提醒'), findsOneWidget);
    await tester.tap(find.text('不再提醒'));
    await tester.pumpAndSettle();

    expect(find.text('数据只存在这台手机上，建议备份'), findsNothing);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('backup_reminder_never'), isTrue);

    // 之后即使过了 100 天也不显示
    await tester.pumpWidget(
      _buildTestApp(
        child: const BackupReminderBanner(),
        records: _createMockRecords(5),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('数据只存在这台手机上，建议备份'), findsNothing);
  });

  testWidgets('6. 已出现 3 次 → 不再显示', (tester) async {
    final now = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'backup_reminder_shown_count': 3,
      'first_launch_at':
          now.subtract(const Duration(days: 100)).millisecondsSinceEpoch,
    });

    await tester.pumpWidget(
      _buildTestApp(
        child: const BackupReminderBanner(),
        records: _createMockRecords(5),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('数据只存在这台手机上，建议备份'), findsNothing);
  });

  testWidgets('7. 导出加密备份后 → 不显示', (tester) async {
    final now = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'last_encrypted_backup_at': now.millisecondsSinceEpoch,
      'first_launch_at':
          now.subtract(const Duration(days: 10)).millisecondsSinceEpoch,
    });

    await tester.pumpWidget(
      _buildTestApp(
        child: const BackupReminderBanner(),
        records: _createMockRecords(5),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('数据只存在这台手机上，建议备份'), findsNothing);
  });

  testWidgets('8. 开启同步后 → 不显示', (tester) async {
    final now = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'first_launch_at':
          now.subtract(const Duration(days: 10)).millisecondsSinceEpoch,
    });

    await tester.pumpWidget(
      _buildTestApp(
        child: const BackupReminderBanner(),
        records: _createMockRecords(5),
        syncEnabled: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('数据只存在这台手机上，建议备份'), findsNothing);
  });

  testWidgets('9. 上次备份超过 30 天并且之后修改了 5 条 → 显示「已 30 天未备份」', (tester) async {
    final now = DateTime.now();
    final backupTime = now.subtract(const Duration(days: 35));

    SharedPreferences.setMockInitialValues({
      'last_encrypted_backup_at': backupTime.millisecondsSinceEpoch,
      'first_launch_at':
          now.subtract(const Duration(days: 50)).millisecondsSinceEpoch,
    });

    // 5 条在备份之后更新的记录
    final recentRecords = _createMockRecords(
      5,
      updatedAt: now.subtract(const Duration(days: 2)).toUtc(),
    );

    await tester.pumpWidget(
      _buildTestApp(
        child: const BackupReminderBanner(),
        records: recentRecords,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('已 30 天未备份'), findsOneWidget);
    expect(find.text('备份'), findsOneWidget);
  });

  testWidgets('10. 设置页备份状态文案在 3 种情况下都正确', (tester) async {
    final now = DateTime.now();

    // 10.1: 从未备份 (中文 & 英文)
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      _buildTestApp(
        child: const SettingsView(),
        syncEnabled: false,
        locale: const Locale('zh'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('从未备份'), findsOneWidget);

    await tester.pumpWidget(
      _buildTestApp(
        child: const SettingsView(),
        syncEnabled: false,
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Never backed up'), findsOneWidget);

    // 10.2: 上次备份：x 天前 (中文 & 英文)
    final threeDaysAgo = now.subtract(const Duration(days: 3));
    SharedPreferences.setMockInitialValues({
      'last_encrypted_backup_at': threeDaysAgo.millisecondsSinceEpoch,
    });
    await tester.pumpWidget(
      _buildTestApp(
        child: const SettingsView(),
        syncEnabled: false,
        locale: const Locale('zh'),
        lastBackupAtOverride: threeDaysAgo.millisecondsSinceEpoch,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('上次备份：3 天前'), findsOneWidget);

    await tester.pumpWidget(
      _buildTestApp(
        child: const SettingsView(),
        syncEnabled: false,
        locale: const Locale('en'),
        lastBackupAtOverride: threeDaysAgo.millisecondsSinceEpoch,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Last backup: 3 days ago'), findsOneWidget);

    // 英文单数：1 day ago
    final oneDayAgo = now.subtract(const Duration(days: 1));
    await tester.pumpWidget(
      _buildTestApp(
        child: const SettingsView(),
        syncEnabled: false,
        locale: const Locale('en'),
        lastBackupAtOverride: oneDayAgo.millisecondsSinceEpoch,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Last backup: 1 day ago'), findsOneWidget);

    // 10.3: 已开启自动备份 (中文 & 英文)
    await tester.pumpWidget(
      _buildTestApp(
        child: const SettingsView(),
        syncEnabled: true,
        locale: const Locale('zh'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('已开启自动备份'), findsOneWidget);

    await tester.pumpWidget(
      _buildTestApp(
        child: const SettingsView(),
        syncEnabled: true,
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Auto backup on'), findsOneWidget);
  });

  testWidgets(
      '11. 用 widget 测试检查：关闭按钮、「备份」按钮的颜色不是默认颜色，并且触控区域 ≥ 48×48',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'first_launch_at': DateTime.now().millisecondsSinceEpoch,
    });

    // 浅色模式测试
    await tester.pumpWidget(
      _buildTestApp(
        child: const BackupReminderBanner(),
        records: _createMockRecords(5),
        theme: AppTheme.lightTheme(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. 关闭按钮触控区域 ≥ 48x48
    final closeFinder = find.byType(IconButton);
    expect(closeFinder, findsOneWidget);
    final closeSize = tester.getSize(closeFinder);
    expect(closeSize.width, greaterThanOrEqualTo(48.0));
    expect(closeSize.height, greaterThanOrEqualTo(48.0));

    // 2. 关闭按钮颜色检查 (浅色 #5B6578)
    final closeIconButton = tester.widget<IconButton>(closeFinder);
    expect(closeIconButton.color, const Color(0xFF5B6578));
    expect(closeIconButton.tooltip, isNotNull);

    // 3. 「备份」按钮触控区域 ≥ 48x48
    final backupBtnFinder = find.widgetWithText(TextButton, '备份');
    expect(backupBtnFinder, findsOneWidget);
    final backupBtnSize = tester.getSize(backupBtnFinder);
    expect(backupBtnSize.width, greaterThanOrEqualTo(48.0));
    expect(backupBtnSize.height, greaterThanOrEqualTo(48.0));

    // 4. 「备份」按钮文字颜色检查 (浅色 #3265E5)
    final backupBtn = tester.widget<TextButton>(backupBtnFinder);
    final resolvedColor =
        backupBtn.style?.foregroundColor?.resolve(const <WidgetState>{});
    expect(resolvedColor, const Color(0xFF3265E5));

    // 深色模式测试
    await tester.pumpWidget(
      _buildTestApp(
        child: const BackupReminderBanner(),
        records: _createMockRecords(5),
        theme: AppTheme.darkTheme(),
      ),
    );
    await tester.pumpAndSettle();

    final darkCloseButton = tester.widget<IconButton>(closeFinder);
    expect(darkCloseButton.color, const Color(0xFFA7B1C2));

    final darkBackupBtn = tester.widget<TextButton>(backupBtnFinder);
    final darkResolvedColor =
        darkBackupBtn.style?.foregroundColor?.resolve(const <WidgetState>{});
    expect(darkResolvedColor, const Color(0xFF8FB0F5));
  });
}
