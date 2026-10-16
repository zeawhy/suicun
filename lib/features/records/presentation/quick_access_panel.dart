// lib/features/records/presentation/quick_access_panel.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suicun/features/records/domain/record_model.dart';
import 'package:suicun/features/records/presentation/id_presentation_page.dart';
import 'package:suicun/features/records/presentation/template_views/template_detector.dart';

enum QuickRecordType {
  idDocument,
  password,
  address,
  memo,
}

/// Visual presentation definition for each quick-access category type.
class QuickTypeStyle {
  const QuickTypeStyle({
    required this.backgroundColor,
    required this.borderColor,
    required this.accentColor,
    required this.icon,
    required this.actionLabel,
    required this.actionIcon,
  });

  final Color backgroundColor;
  final Color borderColor;
  final Color accentColor;
  final IconData icon;
  final String actionLabel;
  final IconData actionIcon;
}

/// Returns the quick-access categorization for [record].
QuickRecordType getQuickRecordType(RecordDetail record) {
  final catName = record.category?.name ?? '';
  final body = record.body;
  final title = record.title;

  if (isIdDocumentTemplate(body) ||
      catName.contains('证件') ||
      catName.toLowerCase().contains('id') ||
      title.contains('证件') ||
      title.contains('身份证') ||
      title.contains('护照') ||
      title.contains('驾驶证') ||
      body.contains('证件号码') ||
      body.contains('证件照片') ||
      body.contains('Document number')) {
    return QuickRecordType.idDocument;
  }

  if (isPasswordTemplate(body) ||
      catName.contains('密码') ||
      catName.toLowerCase().contains('password') ||
      catName.contains('账号') ||
      title.contains('密码') ||
      body.contains('密码：') ||
      body.contains('Password:')) {
    return QuickRecordType.password;
  }

  if (catName.contains('地址') ||
      title.contains('地址') ||
      title.toLowerCase().contains('address') ||
      (isContactTemplate(body) &&
          (parseContactTemplate(body)?.address?.trim().isNotEmpty ?? false))) {
    return QuickRecordType.address;
  }

  return QuickRecordType.memo;
}

/// Returns the visual styling and action label for [type].
QuickTypeStyle getQuickTypeStyle(QuickRecordType type, bool isDark) {
  if (isDark) {
    switch (type) {
      case QuickRecordType.idDocument:
        return const QuickTypeStyle(
          backgroundColor: Color(0xFF1E2630),
          borderColor: Color(0xFF2C394A),
          accentColor: Color(0xFF90B8DE),
          icon: Icons.badge_outlined,
          actionLabel: '出示',
          actionIcon: Icons.visibility_outlined,
        );
      case QuickRecordType.password:
        return const QuickTypeStyle(
          backgroundColor: Color(0xFF1B2A22),
          borderColor: Color(0xFF264032),
          accentColor: Color(0xFF81C784),
          icon: Icons.lock_outline,
          actionLabel: '复制',
          actionIcon: Icons.copy_rounded,
        );
      case QuickRecordType.address:
        return const QuickTypeStyle(
          backgroundColor: Color(0xFF2D231A),
          borderColor: Color(0xFF453423),
          accentColor: Color(0xFFFFB74D),
          icon: Icons.location_on_outlined,
          actionLabel: '复制',
          actionIcon: Icons.copy_rounded,
        );
      case QuickRecordType.memo:
        return const QuickTypeStyle(
          backgroundColor: Color(0xFF26251E),
          borderColor: Color(0xFF3B392B),
          accentColor: Color(0xFFE6C875),
          icon: Icons.edit_note_outlined,
          actionLabel: '查看',
          actionIcon: Icons.arrow_forward_rounded,
        );
    }
  }

  switch (type) {
    case QuickRecordType.idDocument:
      return const QuickTypeStyle(
        backgroundColor: Color(0xFFF1F5F9), // 证件蓝灰
        borderColor: Color(0xFFCBD5E1),
        accentColor: Color(0xFF334155),
        icon: Icons.badge_outlined,
        actionLabel: '出示',
        actionIcon: Icons.visibility_outlined,
      );
    case QuickRecordType.password:
      return const QuickTypeStyle(
        backgroundColor: Color(0xFFEDF7F2), // 密码墨绿
        borderColor: Color(0xFFC7E6D5),
        accentColor: Color(0xFF1B5E20),
        icon: Icons.lock_outline,
        actionLabel: '复制',
        actionIcon: Icons.copy_rounded,
      );
    case QuickRecordType.address:
      return const QuickTypeStyle(
        backgroundColor: Color(0xFFFFF7ED), // 地址暖橙
        borderColor: Color(0xFFFFE3D1),
        accentColor: Color(0xFFC2410C),
        icon: Icons.location_on_outlined,
        actionLabel: '复制',
        actionIcon: Icons.copy_rounded,
      );
    case QuickRecordType.memo:
      return const QuickTypeStyle(
        backgroundColor: Color(0xFFFAF7EE), // 备忘米黄
        borderColor: Color(0xFFEFE6CC),
        accentColor: Color(0xFF785700),
        icon: Icons.edit_note_outlined,
        actionLabel: '查看',
        actionIcon: Icons.arrow_forward_rounded,
      );
  }
}

/// Extracts a concise subtitle for [record] based on its type.
String getQuickSubtitle(RecordDetail record, QuickRecordType type) {
  switch (type) {
    case QuickRecordType.idDocument:
      final idData = parseIdDocumentTemplate(record.body);
      if (idData?.docNumber != null && idData!.docNumber!.trim().isNotEmpty) {
        final raw = idData.docNumber!.trim();
        if (raw.length <= 6) return '******';
        return '尾号 ${raw.substring(raw.length - 4)}';
      }
      if (idData?.docType != null && idData!.docType!.trim().isNotEmpty) {
        return idData.docType!.trim();
      }
      return '证件信息';

    case QuickRecordType.password:
      final pwdData = parsePasswordTemplate(record.body);
      if (pwdData?.username != null && pwdData!.username!.trim().isNotEmpty) {
        return pwdData.username!.trim();
      }
      if (pwdData?.website != null && pwdData!.website!.trim().isNotEmpty) {
        return pwdData.website!.trim();
      }
      return '账号密码';

    case QuickRecordType.address:
      final contactData = parseContactTemplate(record.body);
      if (contactData?.address != null &&
          contactData!.address!.trim().isNotEmpty) {
        return contactData.address!.trim();
      }
      for (final line in record.body.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty && !trimmed.startsWith('姓名') && !trimmed.startsWith('电话')) {
          return trimmed.replaceAll(RegExp(r'^地址[:：]\s*'), '');
        }
      }
      return '地址信息';

    case QuickRecordType.memo:
      for (final line in record.body.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) return trimmed;
      }
      return '备忘笔记';
  }
}

/// Executes the quick action for [record] (show / copy password / copy address / view).
Future<void> executeQuickAction({
  required BuildContext context,
  required RecordDetail record,
  required void Function(RecordDetail r) onOpenRecord,
}) async {
  final type = getQuickRecordType(record);
  switch (type) {
    case QuickRecordType.idDocument:
      onOpenRecord(record);
      await IdPresentationPage.show(context, record);
      break;

    case QuickRecordType.password:
      onOpenRecord(record);
      final pwdData = parsePasswordTemplate(record.body);
      final textToCopy = pwdData?.password?.isNotEmpty == true
          ? pwdData!.password!
          : record.body;
      await Clipboard.setData(ClipboardData(text: textToCopy));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已复制密码到剪贴板'),
          duration: Duration(seconds: 2),
        ),
      );
      break;

    case QuickRecordType.address:
      onOpenRecord(record);
      final contactData = parseContactTemplate(record.body);
      final textToCopy = contactData?.address?.isNotEmpty == true
          ? contactData!.address!
          : (record.body.isNotEmpty ? record.body : record.title);
      await Clipboard.setData(ClipboardData(text: textToCopy));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已复制地址到剪贴板'),
          duration: Duration(seconds: 2),
        ),
      );
      break;

    case QuickRecordType.memo:
      onOpenRecord(record);
      break;
  }
}

/// Ephemeral in-memory flag for dismissing the quick-access empty hint.
class QuickAccessDismissedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void dismiss() => state = true;
}

final quickAccessDismissedProvider =
    NotifierProvider<QuickAccessDismissedNotifier, bool>(
  QuickAccessDismissedNotifier.new,
);

/// The 2-column grid of rounded quick-access blocks (up to 6 items).
/// Shows a gentle empty state if no quick access items are set.
class QuickAccessGrid extends ConsumerWidget {
  const QuickAccessGrid({
    super.key,
    required this.records,
    required this.onRecordAction,
    required this.onLongPress,
  });

  final List<RecordDetail> records;
  final void Function(RecordDetail record) onRecordAction;
  final void Function(RecordDetail record) onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (records.isEmpty) {
      final isDismissed = ref.watch(quickAccessDismissedProvider);
      if (isDismissed) {
        return const SizedBox.shrink();
      }
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const Spacer(),
            Icon(
              Icons.touch_app_outlined,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              '长按任意记录可设为常用',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w400,
              ),
            ),
            const Spacer(),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                ref.read(quickAccessDismissedProvider.notifier).dismiss();
              },
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final displayRecords = records.take(6).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '常用',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                '${displayRecords.length}/6',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              if (displayRecords.length == 1) {
                return _QuickAccessCapsule(
                  width: totalWidth,
                  record: displayRecords[0],
                  isDark: isDark,
                  onTap: () => onRecordAction(displayRecords[0]),
                  onLongPress: () => onLongPress(displayRecords[0]),
                );
              }
              if (displayRecords.length == 2) {
                final itemWidth = (totalWidth - 8) / 2;
                return Row(
                  children: [
                    Expanded(
                      child: _QuickAccessCapsule(
                        width: itemWidth,
                        record: displayRecords[0],
                        isDark: isDark,
                        onTap: () => onRecordAction(displayRecords[0]),
                        onLongPress: () => onLongPress(displayRecords[0]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _QuickAccessCapsule(
                        width: itemWidth,
                        record: displayRecords[1],
                        isDark: isDark,
                        onTap: () => onRecordAction(displayRecords[1]),
                        onLongPress: () => onLongPress(displayRecords[1]),
                      ),
                    ),
                  ],
                );
              }
              final peekItemWidth = (totalWidth - 8) / 2.25;
              return SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: displayRecords.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final r = displayRecords[index];
                    return _QuickAccessCapsule(
                      width: peekItemWidth,
                      record: r,
                      isDark: isDark,
                      onTap: () => onRecordAction(r),
                      onLongPress: () => onLongPress(r),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuickAccessCapsule extends StatelessWidget {
  const _QuickAccessCapsule({
    required this.width,
    required this.record,
    required this.isDark,
    required this.onTap,
    required this.onLongPress,
  });

  final double width;
  final RecordDetail record;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final type = getQuickRecordType(record);
    final style = getQuickTypeStyle(type, isDark);
    final subtitle = getQuickSubtitle(record, type);
    final title = record.title.isNotEmpty ? record.title : '未命名记录';

    return SizedBox(
      width: width,
      height: 64,
      child: Container(
        decoration: BoxDecoration(
          color: style.backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: style.borderColor, width: 1.2),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            onLongPress: onLongPress,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: style.accentColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      style.icon,
                      size: 16,
                      color: style.accentColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Semantics(
                    label: style.actionLabel,
                    button: true,
                    child: Tooltip(
                      message: style.actionLabel,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: style.accentColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          style.actionIcon,
                          size: 16,
                          color: style.accentColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal bar showing up to 5 recently opened records.
class RecentOpenedBar extends StatelessWidget {
  const RecentOpenedBar({
    super.key,
    required this.records,
    required this.onTap,
  });

  final List<RecordDetail> records;
  final void Function(RecordDetail record) onTap;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final displayRecords = records.take(5).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '最近使用',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final r in displayRecords)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _RecentItemChip(
                      record: r,
                      onTap: () => onTap(r),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentItemChip extends StatelessWidget {
  const _RecentItemChip({
    required this.record,
    required this.onTap,
  });

  final RecordDetail record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final type = getQuickRecordType(record);
    final style = getQuickTypeStyle(type, isDark);
    final title = record.title.isNotEmpty ? record.title : '未命名记录';

    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: style.accentColor,
                ),
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal chips showing recent search queries under the search bar.
class RecentSearchChips extends StatelessWidget {
  const RecentSearchChips({
    super.key,
    required this.queries,
    required this.onSelectQuery,
    required this.onClear,
  });

  final List<String> queries;
  final ValueChanged<String> onSelectQuery;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (queries.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final q in queries)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: Text(
                          q,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        backgroundColor: theme.colorScheme.surfaceContainerLowest,
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        onPressed: () => onSelectQuery(q),
                      ),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, size: 18),
            tooltip: '清空最近搜索',
            onPressed: onClear,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
