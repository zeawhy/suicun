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
  });

  final RecordDetail record;
  final bool isSelected;
  final bool isMultiSelectMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onFavoriteToggle;
  final String untitledLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    
    final displayTitle = record.title.isNotEmpty ? record.title : untitledLabel;
    
    // Get the first two non-empty lines of the body for the preview
    final bodyLines = record.body
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(2)
        .toList();
    final bodyPreview = bodyLines.join('\n');

    final dateStr = DateFormatter.formatRelative(record.updatedAt, locale);

    return Card(
      color: isSelected ? theme.colorScheme.primaryContainer : theme.cardTheme.color,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isMultiSelectMode)
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (_) => onTap(),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            semanticsLabel: displayTitle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            record.isFavorite ? Icons.star : Icons.star_border,
                            color: record.isFavorite ? Colors.amber : theme.colorScheme.onSurfaceVariant,
                          ),
                          onPressed: onFavoriteToggle,
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          padding: EdgeInsets.zero,
                          tooltip: record.isFavorite ? 'Unfavorite' : 'Favorite',
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
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        semanticsLabel: bodyPreview,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (record.category != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _parseColor(record.category!.color).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              record.category!.name,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: _parseColor(record.category!.color),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        ...record.tags.take(2).map((t) => Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(
                            '#${t.name}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )),
                        const Spacer(),
                        Text(
                          dateStr,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
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
