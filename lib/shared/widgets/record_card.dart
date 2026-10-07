// lib/shared/widgets/record_card.dart

import 'package:flutter/material.dart';
import 'package:suicun/features/records/domain/record_model.dart';
import 'package:suicun/features/records/presentation/home_sort_provider.dart';
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
    required this.onEdit,
    required this.onChangeCategory,
    required this.onDelete,
    required this.untitledLabel,
    required this.uncategorizedLabel,
    this.favoriteTooltip,
    this.unfavoriteTooltip,
  });

  final RecordDetail record;
  final RecordSortMode sortMode;
  final bool isSelected;
  final bool isMultiSelectMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onEdit;
  final VoidCallback onChangeCategory;
  final VoidCallback onDelete;
  final String untitledLabel;
  final String uncategorizedLabel;
  final String? favoriteTooltip;
  final String? unfavoriteTooltip;

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
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(16),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                        ),
                      ),
                      if (bodyPreview.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          bodyPreview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
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
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  icon: Icon(
                    record.isFavorite ? Icons.star : Icons.star_border,
                    color: record.isFavorite
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
                  tooltip: record.isFavorite
                      ? (unfavoriteTooltip ?? l10n.unfavorite)
                      : (favoriteTooltip ?? l10n.favorite),
                  onPressed: onFavoriteToggle,
                ),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz),
                    tooltip: 'More',
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          onEdit();
                        case 'changeCategory':
                          onChangeCategory();
                        case 'favorite':
                          onFavoriteToggle();
                        case 'delete':
                          onDelete();
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(Icons.edit_outlined, size: 20),
                            const SizedBox(width: 12),
                            Text(l10n.editInfo),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'changeCategory',
                        child: Row(
                          children: [
                            const Icon(Icons.folder_outlined, size: 20),
                            const SizedBox(width: 12),
                            Text(l10n.changeCategory),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'favorite',
                        child: Row(
                          children: [
                            Icon(
                              record.isFavorite
                                  ? Icons.star_border
                                  : Icons.star_outline,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(record.isFavorite
                                ? l10n.unfavorite
                                : l10n.favorite),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: colorScheme.error,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              l10n.delete,
                              style: TextStyle(color: colorScheme.error),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
