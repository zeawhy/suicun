// lib/features/records/presentation/template_views/todo_template_view.dart
// Reading view for todo template notes.

import 'package:flutter/material.dart';
import 'package:suicun/features/records/domain/record_model.dart';
import 'package:suicun/features/records/presentation/template_views/template_detector.dart';
import 'package:suicun/features/records/presentation/template_views/template_header_card.dart';
import 'package:suicun/features/records/presentation/template_views/updated_at_text.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';

class TodoTemplateView extends StatelessWidget {
  const TodoTemplateView({
    super.key,
    required this.data,
    required this.record,
    required this.onEdit,
    required this.onToggle,
    required this.categoryRow,
    required this.tagRow,
    this.suggestionRow,
  });

  final TodoTemplateData data;
  final RecordDetail? record;
  final VoidCallback onEdit;
  final void Function(int lineIndex) onToggle;
  final Widget categoryRow;
  final Widget tagRow;
  final Widget? suggestionRow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final title = record?.title.isNotEmpty == true
        ? record!.title
        : l10n.untitledRecord;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Header card (Checklist icon + title + pencil edit button)
        TemplateHeaderCard(
          title: title,
          icon: Icons.checklist_rounded,
          onEdit: onEdit,
        ),
        const SizedBox(height: 16),

        // 2. Task list card (Progress row + items)
        _buildTasksCard(context, theme, colorScheme, l10n),
        const SizedBox(height: 16),

        // 3. Category & Tag rows container
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Column(
            children: [
              categoryRow,
              if (suggestionRow != null) suggestionRow!,
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              tagRow,
            ],
          ),
        ),

        // 4. Updated at relative time
        if (record != null)
          UpdatedAtText(dateTime: record!.updatedAt),
      ],
    );
  }

  Widget _buildTasksCard(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    final total = data.items.length;
    final done = data.items.where((e) => e.checked).length;
    final progress = total > 0 ? done / total : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top progress row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Text(
                  l10n.todoProgress(done, total),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          // Checklist items
          for (var i = 0; i < data.items.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            _buildTaskItem(data.items[i], theme, colorScheme),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskItem(
    TodoTemplateItem item,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return InkWell(
      onTap: () => onToggle(item.lineIndex),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Checkbox(
              value: item.checked,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (_) => onToggle(item.lineIndex),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.content,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: item.checked
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.onSurface,
                  decoration: item.checked
                      ? TextDecoration.lineThrough
                      : null,
                  decorationColor: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
