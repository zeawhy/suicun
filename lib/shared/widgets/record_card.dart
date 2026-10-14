import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:suicun/features/records/domain/record_model.dart';
import 'package:suicun/features/records/presentation/home_sort_provider.dart';
import 'package:suicun/features/records/presentation/template_views/id_photo_storage.dart';
import 'package:suicun/features/records/presentation/template_views/template_detector.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';
import 'package:suicun/shared/theme/app_theme.dart';
import 'package:suicun/shared/utils/date_formatter.dart';

class RecordCard extends StatelessWidget {
  const RecordCard({
    super.key,
    required this.record,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    final displayTitle =
        record.title.isNotEmpty ? record.title : untitledLabel;
    final titleColor =
        record.title.isNotEmpty ? colorScheme.onSurface : colorScheme.onSurfaceVariant;

    final bodyLines = record.body
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(2)
        .toList();
    final bodyPreview = bodyLines.join('\n');

    final locale = Localizations.localeOf(context).toString();
    final timeStr = sortMode == RecordSortMode.byCreatedAt
        ? '${l10n.createdAtPrefix} ${DateFormatter.formatCardTime(record.createdAt, locale)}'
        : DateFormatter.formatCardTime(record.updatedAt, locale);
    final categoryName = record.category?.name ?? uncategorizedLabel;
    final metaText = '$categoryName · $timeStr';

    final categoryColor = AppTheme.getCategoryColor(
      record.category?.name,
      record.category?.color,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Slidable(
        key: ValueKey(record.id),
        enabled: !isMultiSelectMode,
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
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    borderRadius: BorderRadius.circular(12),
                    onTap: onTap,
                    onLongPress: onLongPress,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildThumbnail(),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      displayTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 16,
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
                                      size: 20,
                                    ),
                                    color: record.isFavorite
                                        ? colorScheme.primary
                                        : colorScheme.onSurfaceVariant,
                                    tooltip: record.isFavorite
                                        ? l10n.unfavorite
                                        : l10n.favorite,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: onFavoriteToggle,
                                  ),
                                ],
                              ),
                              if (bodyPreview.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  bodyPreview,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colorScheme.onSurfaceVariant,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  if (record.category != null) ...[
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: categoryColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Expanded(
                                    child: Text(
                                      metaText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
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
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

Future<void> _confirmDelete(
    BuildContext context, AppLocalizations l10n) async {
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
          padding: const EdgeInsets.only(right: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              file,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}
