// lib/shared/widgets/record_card.dart

import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:suicun/features/records/domain/record_model.dart';
import 'package:suicun/features/records/presentation/home_sort_provider.dart';
import 'package:suicun/features/records/presentation/search/pinyin_search_helper.dart';
import 'package:suicun/features/records/presentation/template_views/id_photo_storage.dart';
import 'package:suicun/features/records/presentation/template_views/template_detector.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';
import 'package:suicun/shared/theme/app_theme.dart';
import 'package:suicun/shared/utils/date_formatter.dart';

/// Normalized template types for card rendering and core action dispatch.
enum RecordCardTemplateType {
  password,
  idDocument,
  contact,
  todo,
  idea,
  note,
}

class RecordCard extends StatelessWidget {
  const RecordCard({
    super.key,
    required this.record,
    this.searchQuery,
    required this.sortMode,
    required this.isSelected,
    required this.isMultiSelectMode,
    required this.onTap,
    required this.onLongPress,
    required this.onFavoriteToggle,
    required this.onPinToggle,
    required this.onEdit,
    required this.onChangeCategory,
    required this.onDelete,
    required this.untitledLabel,
    required this.uncategorizedLabel,
  });

  final RecordDetail record;
  final String? searchQuery;
  final RecordSortMode sortMode;
  final bool isSelected;
  final bool isMultiSelectMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onFavoriteToggle;

  /// Callback when pinning/unpinning is toggled via slide action.
  /// Note: The data model has no dedicated pinned field, so pinning is mapped
  /// to toggling [isFavorite] without DB schema changes.
  final VoidCallback onPinToggle;
  final VoidCallback onEdit;

  /// 保留该回调以维持调用方 API 稳定；卡片右上角菜单已移除，
  /// 修改分类改在编辑页内完成。
  final VoidCallback onChangeCategory;
  final VoidCallback onDelete;
  final String untitledLabel;
  final String uncategorizedLabel;

  static RecordCardTemplateType _detectTemplateType(String body) {
    if (isPasswordTemplate(body)) return RecordCardTemplateType.password;
    if (isIdDocumentTemplate(body)) return RecordCardTemplateType.idDocument;
    if (isContactTemplate(body)) return RecordCardTemplateType.contact;
    if (isTodoTemplate(body)) return RecordCardTemplateType.todo;
    if (isIdeaTemplate(body)) return RecordCardTemplateType.idea;
    return RecordCardTemplateType.note;
  }

  static IconData _iconForTemplate(RecordCardTemplateType type) {
    return switch (type) {
      RecordCardTemplateType.password => Icons.lock_outline,
      RecordCardTemplateType.idDocument => Icons.badge_outlined,
      RecordCardTemplateType.contact => Icons.person_outline,
      RecordCardTemplateType.todo => Icons.check_box_outlined,
      RecordCardTemplateType.idea => Icons.lightbulb_outline,
      RecordCardTemplateType.note => Icons.article_outlined,
    };
  }

  static String? _extractCoreCopyableText(
    RecordCardTemplateType type,
    String body,
  ) {
    switch (type) {
      case RecordCardTemplateType.password:
        final data = parsePasswordTemplate(body);
        if (data?.password != null && data!.password!.isNotEmpty) {
          return data.password;
        }
        if (data?.username != null && data!.username!.isNotEmpty) {
          return data.username;
        }
        return null;
      case RecordCardTemplateType.idDocument:
        final data = parseIdDocumentTemplate(body);
        if (data?.docNumber != null && data!.docNumber!.isNotEmpty) {
          return data.docNumber;
        }
        return null;
      case RecordCardTemplateType.contact:
        final data = parseContactTemplate(body);
        if (data?.phone != null && data!.phone!.isNotEmpty) {
          return data.phone;
        }
        if (data?.email != null && data!.email!.isNotEmpty) {
          return data.email;
        }
        if (data?.address != null && data!.address!.isNotEmpty) {
          return data.address;
        }
        return null;
      case RecordCardTemplateType.todo:
      case RecordCardTemplateType.idea:
      case RecordCardTemplateType.note:
        return null;
    }
  }

  static String _maskDocNumber(String raw) {
    if (raw.isEmpty) return '******';
    if (raw.length <= 6) return '******';
    final start = raw.substring(0, 4);
    final end = raw.substring(raw.length - 4);
    return '$start${'*' * (raw.length - 8).clamp(2, 8)}$end';
  }

  Future<void> _handleCopy(
    BuildContext context,
    String text,
    AppLocalizations l10n,
  ) async {
    await HapticFeedback.lightImpact();
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isZh ? '已复制到剪贴板' : 'Copied to clipboard'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final suiColors = theme.suiColors;
    final l10n = AppLocalizations.of(context);

    final displayTitle =
        record.title.isNotEmpty ? record.title : untitledLabel;
    final titleColor = record.title.isNotEmpty
        ? colorScheme.onSurface
        : colorScheme.onSurfaceVariant;

    final locale = Localizations.localeOf(context).toString();
    final timeStr = sortMode == RecordSortMode.byCreatedAt
        ? '${l10n.createdAtPrefix} ${DateFormatter.formatCardTime(record.createdAt, locale)}'
        : DateFormatter.formatCardTime(record.updatedAt, locale);
    final categoryName = record.category?.name ?? uncategorizedLabel;

    final categoryColor = suiColors.colorForCategory(
      record.category?.name,
      record.category?.color,
    );

    final templateType = _detectTemplateType(record.body);
    final copyableText = _extractCoreCopyableText(templateType, record.body);
    final templateIcon = _iconForTemplate(templateType);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Slidable(
        key: ValueKey(record.id),
        enabled: !isMultiSelectMode,
        closeOnScroll: true,
        dragStartBehavior: DragStartBehavior.start,
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => onPinToggle(),
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              icon: record.isFavorite
                  ? Icons.push_pin
                  : Icons.push_pin_outlined,
              label: record.isFavorite
                  ? l10n.unpinRecord
                  : l10n.pinRecord,
              borderRadius: BorderRadius.circular(14),
            ),
            SlidableAction(
              onPressed: (_) => onEdit(),
              backgroundColor: colorScheme.secondary,
              foregroundColor: colorScheme.onSecondary,
              icon: Icons.edit_outlined,
              label: l10n.editInfo,
              borderRadius: BorderRadius.circular(14),
            ),
            SlidableAction(
              onPressed: (actionCtx) =>
                  _confirmDelete(context, l10n),
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
              icon: Icons.delete_outline,
              label: l10n.delete,
              borderRadius: BorderRadius.circular(14),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colorScheme.outlineVariant,
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (isMultiSelectMode)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (_) => onTap(),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                  ),
                ),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: onTap,
                    onLongPress: onLongPress,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── 第一层（头部行）：模板类型图标 + 标题 + 置顶图标 + 右侧一键复制按钮 ──
                        Row(
                          children: [
                            Icon(
                              templateIcon,
                              size: 16,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: searchQuery != null && searchQuery!.isNotEmpty
                                  ? Text.rich(
                                      TextSpan(
                                        children: buildHighlightedSpans(
                                          text: displayTitle,
                                          query: searchQuery!,
                                          baseStyle: theme.textTheme.titleMedium?.copyWith(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: titleColor,
                                          ),
                                          highlightStyle: theme.textTheme.titleMedium?.copyWith(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.primary,
                                            backgroundColor: colorScheme.primary.withValues(alpha: 0.15),
                                          ),
                                        ),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : Text(
                                      displayTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: titleColor,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: Icon(
                                record.isFavorite
                                    ? Icons.star_rounded
                                    : Icons.star_outline,
                                size: 19,
                              ),
                              color: record.isFavorite
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                              tooltip: record.isFavorite
                                  ? l10n.unfavorite
                                  : l10n.favorite,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              onPressed: onFavoriteToggle,
                            ),
                            if (copyableText != null && copyableText.isNotEmpty) ...[
                              const SizedBox(width: 2),
                              IconButton(
                                icon: const Icon(
                                  Icons.copy_rounded,
                                  size: 16,
                                ),
                                color: colorScheme.onSurfaceVariant,
                                tooltip: l10n.copied,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                                onPressed: () =>
                                    _handleCopy(context, copyableText, l10n),
                              ),
                            ],
                          ],
                        ),

                        // ── 第二层（内容区）：普通笔记最多2行摘要；证件/密码展示脱敏主字段，等宽数字 ──
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildThumbnail(),
                            Expanded(
                              child: _buildContent(
                                context,
                                theme,
                                colorScheme,
                                templateType,
                              ),
                            ),
                          ],
                        ),

                        // ── 第三层（底栏）：分类圆点标签 + 标签列表 + 右侧相对更新时间 ──
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (record.category != null) ...[
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: categoryColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                categoryName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (record.tags.isNotEmpty)
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  physics: const NeverScrollableScrollPhysics(),
                                  child: Row(
                                    children: record.tags.take(3).map((tag) {
                                      return Container(
                                        margin: const EdgeInsets.only(right: 6),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colorScheme.surfaceContainerHigh,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '#${tag.name}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color:
                                                colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              )
                            else
                              const Spacer(),
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // 左滑提示：纯视觉指示符，不可点击
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.keyboard_double_arrow_left,
                  size: 18,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    RecordCardTemplateType type,
  ) {
    switch (type) {
      case RecordCardTemplateType.password:
        final pwd = parsePasswordTemplate(record.body);
        final username = pwd?.username?.trim();
        final hasUsername = username != null && username.isNotEmpty;
        final baseStyle = theme.textTheme.bodyMedium?.copyWith(
          fontSize: 13,
          color: colorScheme.onSurfaceVariant,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
        final highlightStyle = baseStyle?.copyWith(
          fontWeight: FontWeight.bold,
          color: colorScheme.primary,
          backgroundColor: colorScheme.primary.withValues(alpha: 0.15),
        );
        return Text.rich(
          TextSpan(
            children: [
              if (hasUsername) ...[
                if (searchQuery != null && searchQuery!.isNotEmpty)
                  ...buildHighlightedSpans(
                    text: '$username  ·  ',
                    query: searchQuery!,
                    baseStyle: baseStyle,
                    highlightStyle: highlightStyle,
                  )
                else
                  TextSpan(text: '$username  ·  '),
              ],
              const TextSpan(
                text: '••••••••',
                style: TextStyle(letterSpacing: 1.5),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: baseStyle,
        );

      case RecordCardTemplateType.idDocument:
        final idData = parseIdDocumentTemplate(record.body);
        final docType = idData?.docType?.trim();
        final num = idData?.docNumber?.trim() ?? '';
        final maskedNum = _maskDocNumber(num);
        final prefix =
            (docType != null && docType.isNotEmpty) ? '$docType: ' : '';
        final fullText = '$prefix$maskedNum';
        final baseStyle = theme.textTheme.bodyMedium?.copyWith(
          fontSize: 13,
          color: colorScheme.onSurfaceVariant,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
        if (searchQuery != null && searchQuery!.isNotEmpty) {
          final highlightStyle = baseStyle?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
            backgroundColor: colorScheme.primary.withValues(alpha: 0.15),
          );
          return Text.rich(
            TextSpan(
              children: buildHighlightedSpans(
                text: fullText,
                query: searchQuery!,
                baseStyle: baseStyle,
                highlightStyle: highlightStyle,
              ),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }
        return Text(
          fullText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: baseStyle,
        );

      case RecordCardTemplateType.contact:
        final cData = parseContactTemplate(record.body);
        final phone = cData?.phone?.trim();
        final email = cData?.email?.trim();
        final address = cData?.address?.trim();
        final text = (phone != null && phone.isNotEmpty)
            ? phone
            : ((email != null && email.isNotEmpty)
                ? email
                : (address ?? ''));
        if (text.isEmpty) {
          return _buildDefaultBody(theme, colorScheme);
        }
        final baseStyle = theme.textTheme.bodyMedium?.copyWith(
          fontSize: 13,
          color: colorScheme.onSurfaceVariant,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
        if (searchQuery != null && searchQuery!.isNotEmpty) {
          final highlightStyle = baseStyle?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
            backgroundColor: colorScheme.primary.withValues(alpha: 0.15),
          );
          return Text.rich(
            TextSpan(
              children: buildHighlightedSpans(
                text: text,
                query: searchQuery!,
                baseStyle: baseStyle,
                highlightStyle: highlightStyle,
              ),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }
        return Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: baseStyle,
        );

      case RecordCardTemplateType.todo:
      case RecordCardTemplateType.idea:
      case RecordCardTemplateType.note:
        return _buildDefaultBody(theme, colorScheme);
    }
  }

  Widget _buildDefaultBody(ThemeData theme, ColorScheme colorScheme) {
    final bodyLines = record.body
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(2)
        .toList();
    if (bodyLines.isEmpty) return const SizedBox.shrink();
    final bodyText = bodyLines.join('\n');
    final baseStyle = theme.textTheme.bodyMedium?.copyWith(
      fontSize: 13,
      color: colorScheme.onSurfaceVariant,
      height: 1.35,
    );
    if (searchQuery != null && searchQuery!.isNotEmpty) {
      final highlightStyle = baseStyle?.copyWith(
        fontWeight: FontWeight.bold,
        color: colorScheme.primary,
        backgroundColor: colorScheme.primary.withValues(alpha: 0.15),
      );
      return Text.rich(
        TextSpan(
          children: buildHighlightedSpans(
            text: bodyText,
            query: searchQuery!,
            baseStyle: baseStyle,
            highlightStyle: highlightStyle,
          ),
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }
    return Text(
      bodyText,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: baseStyle,
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteRecordTitle),
        content: Text(l10n.deleteRecordConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      onDelete();
    }
  }

  Widget _buildThumbnail() {
    final idData = parseIdDocumentTemplate(record.body);
    final photoPath = idData?.photoFront?.isNotEmpty == true
        ? idData!.photoFront
        : (idData?.photoBack?.isNotEmpty == true ? idData!.photoBack : null);
    if (photoPath == null) return const SizedBox.shrink();

    return FutureBuilder<File?>(
      future: resolveIdPhoto(photoPath),
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file == null) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(right: 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.file(
              file,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}
