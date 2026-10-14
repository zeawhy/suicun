// lib/shared/widgets/record_list_tile.dart
// Home/trash list row, restyled to match the design mockups:
// colored rounded icon block, bold title, 2-line gray body preview,
// "category · yyyy/MM/dd" meta line, gold star (favorites only) + ⋮ menu.

import 'package:flutter/material.dart';
import 'package:suicun/features/records/domain/record_model.dart';
import 'package:suicun/shared/utils/date_formatter.dart';

class RecordListTile extends StatelessWidget {
  const RecordListTile({
    super.key,
    required this.record,
    required this.isSelected,
    required this.isMultiSelectMode,
    required this.onTap,
    required this.onLongPress,
    required this.onFavoriteToggle,
    required this.untitledLabel,
    this.favoriteTooltip,
    this.unfavoriteTooltip,
    this.deleteLabel,
    this.onDelete,
  });

  final RecordDetail record;
  final bool isSelected;
  final bool isMultiSelectMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onFavoriteToggle;
  final String untitledLabel;

  /// Shown on the gold star (favorites only). Falls back to a generic label.
  final String? favoriteTooltip;

  /// Shown in the ⋮ menu for the favorite/unfavorite action.
  final String? unfavoriteTooltip;

  /// Shown in the ⋮ menu for the delete action. When null the menu item
  /// still appears with a generic label.
  final String? deleteLabel;

  /// Called from the ⋮ menu. When null, the delete menu item is hidden.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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

    final categoryColor = record.category != null
        ? _parseColor(record.category!.color)
        : colorScheme.primary;
    final dateStr = DateFormatter.formatYmd(record.updatedAt);
    final metaStr = record.category != null
        ? '${record.category!.name} · $dateStr'
        : dateStr;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isMultiSelectMode)
                Padding(
                  padding: const EdgeInsets.only(right: 12.0, top: 4.0),
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (_) => onTap(),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                  ),
                ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: categoryColor.withValues(alpha: 0.20),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Icon(
                    record.category != null
                        ? Icons.folder_rounded
                        : Icons.description_outlined,
                    color: categoryColor,
                    size: 24,
                    semanticLabel: record.category?.name,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: titleColor,
                            ),
                          ),
                        ),
                        if (record.isFavorite)
                          IconButton(
                            icon: const Icon(Icons.star,
                                color: Color(0xFFF5A623), size: 22),
                            onPressed: onFavoriteToggle,
                            tooltip: favoriteTooltip ?? 'Favorite',
                            constraints: const BoxConstraints(
                                minWidth: 48, minHeight: 48),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                        SizedBox(
                          width: 40,
                          height: 48,
                          child: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert),
                            tooltip: 'More',
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            onSelected: (value) {
                              switch (value) {
                                case 'favorite':
                                  onFavoriteToggle();
                                case 'delete':
                                  onDelete?.call();
                              }
                            },
                            itemBuilder: (ctx) => [
                              PopupMenuItem(
                                value: 'favorite',
                                child: Row(
                                  children: [
                                    Icon(
                                      record.isFavorite
                                          ? Icons.star_border_rounded
                                          : Icons.star_rounded,
                                      size: 20,
                                      color: record.isFavorite
                                          ? null
                                          : const Color(0xFFF5A623),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(record.isFavorite
                                        ? (unfavoriteTooltip ?? 'Unfavorite')
                                        : (favoriteTooltip ?? 'Favorite')),
                                  ],
                                ),
                              ),
                              if (onDelete != null)
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
                                        deleteLabel ?? 'Delete',
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
                    if (bodyPreview.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        bodyPreview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
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
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: categoryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                        Expanded(
                          child: Text(
                            metaStr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              letterSpacing: 0.2,
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
    );
  }

  Color _parseColor(String hexStr) {
    hexStr = hexStr.toUpperCase().replaceAll('#', '');
    if (hexStr.length == 6) {
      hexStr = 'FF$hexStr';
    }
    return Color(int.tryParse(hexStr, radix: 16) ?? 0xFF4866D5);
  }
}
