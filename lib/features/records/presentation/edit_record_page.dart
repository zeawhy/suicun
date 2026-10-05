import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:suicun/core/database/providers.dart';
import 'package:suicun/features/records/domain/record_model.dart';
import 'package:suicun/features/records/presentation/edit_record_notifier.dart';
import 'package:suicun/features/records/presentation/records_notifier.dart';
import 'package:suicun/features/tags/domain/tag_model.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';

class EditRecordPage extends ConsumerStatefulWidget {
  const EditRecordPage({super.key, this.recordId});

  final String? recordId;

  @override
  ConsumerState<EditRecordPage> createState() => _EditRecordPageState();
}

class _EditRecordPageState extends ConsumerState<EditRecordPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _bodyController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _onChanged() {
    ref.read(editRecordProvider(widget.recordId).notifier).onInputChanged(
          _titleController.text,
          _bodyController.text,
        );
  }

  Future<void> _pickCategory(
    AppLocalizations l10n,
    RecordDetail? record,
  ) async {
    final categories =
        await ref.read(categoryRepositoryProvider).getAllCategories();
    if (!mounted) return;
    final selected = await showDialog<String?>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.selectCategory),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('__none__'),
            child: Text(l10n.uncategorized),
          ),
          for (final c in categories)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(c.id),
              child: Row(
                children: [
                  _ColorDot(color: _parseColor(c.color)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(c.name)),
                  if (record?.categoryId == c.id)
                    const Icon(Icons.check, size: 18),
                ],
              ),
            ),
        ],
      ),
    );
    if (selected == null) return;
    await ref
        .read(editRecordProvider(widget.recordId).notifier)
        .setCategory(selected == '__none__' ? null : selected);
  }

  Future<void> _pickTags(
    AppLocalizations l10n,
    RecordDetail? record,
  ) async {
    final tagRepo = ref.read(tagRepositoryProvider);
    final allTags = await tagRepo.getAllTags();
    if (!mounted) return;
    final selectedIds =
        (record?.tags ?? <TagModel>[]).map((t) => t.id).toSet();
    final newTagController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.selectTags),
        content: SizedBox(
          width: double.maxFinite,
          child: StatefulBuilder(
            builder: (ctx, setDialogState) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final t in allTags)
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(t.name),
                          value: selectedIds.contains(t.id),
                          onChanged: (v) => setDialogState(() {
                            if (v == true) {
                              selectedIds.add(t.id);
                            } else {
                              selectedIds.remove(t.id);
                            }
                          }),
                        ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: newTagController,
                        decoration: InputDecoration(
                          hintText: l10n.tagName,
                          isDense: true,
                        ),
                        onSubmitted: (_) {},
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: l10n.addTag,
                      onPressed: () async {
                        final name = newTagController.text.trim();
                        if (name.isEmpty) return;
                        final created =
                            await tagRepo.findOrCreateTag(name);
                        setDialogState(() {
                          allTags.add(created);
                          selectedIds.add(created.id);
                          newTagController.clear();
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
    newTagController.dispose();
    if (confirmed == true) {
      await ref
          .read(editRecordProvider(widget.recordId).notifier)
          .setTags(selectedIds.toList());
    }
  }

  Future<void> _deleteRecord(AppLocalizations l10n, RecordDetail? record) async {
    if (record == null) {
      if (mounted) context.pop();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.recordDeleted),
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
    if (confirmed != true || !mounted) return;
    final repo = ref.read(recordRepositoryProvider);
    await ref.read(editRecordProvider(widget.recordId).notifier).flush();
    await repo.softDeleteRecord(record.id);
    ref.invalidate(recordsListProvider);
    ref.invalidate(trashListProvider);
    if (!mounted) return;
    context.pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.recordDeleted),
        action: SnackBarAction(
          label: l10n.undoDelete,
          onPressed: () async {
            await repo.restoreRecord(record.id);
            ref.invalidate(recordsListProvider);
            ref.invalidate(trashListProvider);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(editRecordProvider(widget.recordId));

    if (!_initialized && state.record != null) {
      _titleController.text = state.record!.title;
      _bodyController.text = state.record!.body;
      _initialized = true;
    }

    final record = state.record;

    return PopScope(
      onPopInvokedWithResult: (_, __) async {
        await ref.read(editRecordProvider(widget.recordId).notifier).flush();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_buildSaveStatus(state.saveState, l10n),
              style: const TextStyle(fontSize: 14)),
          actions: [
            IconButton(
              icon: Icon(
                record?.isFavorite == true ? Icons.star : Icons.star_border,
                color: record?.isFavorite == true ? Colors.amber : null,
              ),
              onPressed: () {
                ref
                    .read(editRecordProvider(widget.recordId).notifier)
                    .toggleFavorite();
              },
              tooltip:
                  record?.isFavorite == true ? l10n.unfavorite : l10n.favorite,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'category':
                    _pickCategory(l10n, record);
                  case 'tags':
                    _pickTags(l10n, record);
                  case 'delete':
                    _deleteRecord(l10n, record);
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                    value: 'category', child: Text(l10n.selectCategory)),
                PopupMenuItem(value: 'tags', child: Text(l10n.selectTags)),
                PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    hintText: l10n.titleHint,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
                  onChanged: (_) => _onChanged(),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: TextField(
                    controller: _bodyController,
                    decoration: InputDecoration(
                      hintText: l10n.bodyHint,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                    ),
                    style: Theme.of(context).textTheme.bodyLarge,
                    keyboardType: TextInputType.multiline,
                    maxLines: null,
                    expands: true,
                    onChanged: (_) => _onChanged(),
                  ),
                ),
              ),
              _MetaBar(
                record: record,
                uncategorizedLabel: l10n.uncategorized,
                onCategoryTap: () => _pickCategory(l10n, record),
                onTagsTap: () => _pickTags(l10n, record),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildSaveStatus(SaveState state, AppLocalizations l10n) {
    switch (state) {
      case SaveState.saving:
        return l10n.saving;
      case SaveState.saved:
        return l10n.saved;
      case SaveState.error:
        return l10n.saveFailed;
    }
  }
}

/// Bottom bar showing the record's current category and tags.
class _MetaBar extends StatelessWidget {
  const _MetaBar({
    required this.record,
    required this.uncategorizedLabel,
    required this.onCategoryTap,
    required this.onTagsTap,
  });

  final RecordDetail? record;
  final String uncategorizedLabel;
  final VoidCallback onCategoryTap;
  final VoidCallback onTagsTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = record?.category;
    final tags = record?.tags ?? const <TagModel>[];

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: onCategoryTap,
            icon: category != null
                ? _ColorDot(color: _parseColor(category.color))
                : const Icon(Icons.folder_outlined, size: 18),
            label: Text(
              category?.name ?? uncategorizedLabel,
              style: theme.textTheme.labelMedium,
            ),
          ),
          TextButton.icon(
            onPressed: onTagsTap,
            icon: const Icon(Icons.label_outlined, size: 18),
            label: Text(
              tags.isEmpty
                  ? '#'
                  : tags.map((t) => '#${t.name}').take(3).join(' '),
              style: theme.textTheme.labelMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

Color _parseColor(String hexStr) {
  hexStr = hexStr.toUpperCase().replaceAll('#', '');
  if (hexStr.length == 6) hexStr = 'FF$hexStr';
  return Color(int.tryParse(hexStr, radix: 16) ?? 0xFF4866D5);
}
