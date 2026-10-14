// lib/features/records/presentation/template_views/todo_template_view.dart
// Reading view for todo template notes.

import 'package:flutter/material.dart';
import 'package:suicun/features/records/domain/record_model.dart';
import 'package:suicun/features/records/presentation/template_views/template_detector.dart';
import 'package:suicun/features/records/presentation/template_views/template_header_card.dart';
import 'package:suicun/features/records/presentation/template_views/updated_at_text.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';

class TodoTemplateView extends StatefulWidget {
  const TodoTemplateView({
    super.key,
    required this.data,
    required this.record,
    required this.onEdit,
    required this.onToggle,
    required this.categoryRow,
    required this.tagRow,
    this.suggestionRow,
    this.isEditing = false,
    this.titleController,
    this.onTitleChanged,
    this.onBodyChanged,
    this.rawBody,
  });

  final TodoTemplateData data;
  final RecordDetail? record;
  final VoidCallback onEdit;
  final void Function(int lineIndex) onToggle;
  final Widget categoryRow;
  final Widget tagRow;
  final Widget? suggestionRow;
  final bool isEditing;
  final TextEditingController? titleController;
  final ValueChanged<String>? onTitleChanged;
  final ValueChanged<String>? onBodyChanged;
  final String? rawBody;

  @override
  State<TodoTemplateView> createState() => _TodoTemplateViewState();
}

class _TodoItemEntry {
  _TodoItemEntry({
    required this.checked,
    required this.controller,
  });

  bool checked;
  final TextEditingController controller;
}

class _TodoTemplateViewState extends State<TodoTemplateView> {
  late List<_TodoItemEntry> _items;

  @override
  void initState() {
    super.initState();
    _initItems();
  }

  void _initItems() {
    _items = widget.data.items.map((item) {
      return _TodoItemEntry(
        checked: item.checked,
        controller: TextEditingController(text: item.content),
      );
    }).toList();
    if (_items.isEmpty) {
      _items.add(_TodoItemEntry(
        checked: false,
        controller: TextEditingController(),
      ));
    }
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.controller.dispose();
    }
    super.dispose();
  }

  void _syncBody() {
    final buffer = StringBuffer();
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (i > 0) buffer.write('\n');
      buffer.write(item.checked ? '☑ ' : '☐ ');
      buffer.write(item.controller.text);
    }
    widget.onBodyChanged?.call(buffer.toString());
  }

  void _addItem() {
    setState(() {
      _items.add(_TodoItemEntry(
        checked: false,
        controller: TextEditingController(),
      ));
    });
    _syncBody();
  }

  void _removeItem(int index) {
    if (_items.length > 1) {
      _items[index].controller.dispose();
      setState(() {
        _items.removeAt(index);
      });
    } else {
      _items[0].controller.clear();
      setState(() {
        _items[0].checked = false;
      });
    }
    _syncBody();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final title = widget.record?.title.isNotEmpty == true
        ? widget.record!.title
        : l10n.untitledRecord;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Header card (Checklist icon + title + pencil edit button)
        TemplateHeaderCard(
          title: title,
          icon: Icons.checklist_rounded,
          onEdit: widget.onEdit,
          titleController: widget.titleController,
          onTitleChanged: widget.onTitleChanged,
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
              widget.categoryRow,
              if (widget.suggestionRow != null) widget.suggestionRow!,
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              widget.tagRow,
            ],
          ),
        ),

        // 4. Updated at relative time or auto-save hint
        if (widget.isEditing)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 14),
            child: Row(
              children: [
                Icon(
                  Icons.cloud_done_outlined,
                  size: 14,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.autoSaveHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (widget.record != null)
          UpdatedAtText(dateTime: widget.record!.updatedAt),
      ],
    );
  }

  Widget _buildTasksCard(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    final int total;
    final int done;
    if (widget.isEditing) {
      total = _items.length;
      done = _items.where((e) => e.checked).length;
    } else {
      total = widget.data.items.length;
      done = widget.data.items.where((e) => e.checked).length;
    }
    final progress = total > 0 ? done / total : 0.0;
    final isZh = Localizations.localeOf(context).languageCode == 'zh';

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
          if (widget.isEditing) ...[
            for (var i = 0; i < _items.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              _buildEditableTaskItem(i, _items[i], theme, colorScheme, l10n),
            ],
            Divider(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
            InkWell(
              onTap: _addItem,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.add, size: 20, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      isZh ? '添加事项' : 'Add task',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            for (var i = 0; i < widget.data.items.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              _buildTaskItem(widget.data.items[i], theme, colorScheme),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildEditableTaskItem(
    int index,
    _TodoItemEntry item,
    ThemeData theme,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Checkbox(
            value: item.checked,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: (v) {
              setState(() {
                item.checked = v ?? false;
              });
              _syncBody();
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              key: Key('todo_item_field_$index'),
              controller: item.controller,
              decoration: InputDecoration(
                hintText: l10n.notFilled,
                hintStyle: TextStyle(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: item.checked
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.onSurface,
                decoration: item.checked ? TextDecoration.lineThrough : null,
                decorationColor: colorScheme.onSurfaceVariant,
              ),
              textInputAction: TextInputAction.next,
              onChanged: (_) => _syncBody(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: l10n.delete,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            onPressed: () => _removeItem(index),
          ),
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
      onTap: () => widget.onToggle(item.lineIndex),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Checkbox(
              value: item.checked,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (_) => widget.onToggle(item.lineIndex),
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
