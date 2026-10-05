// lib/features/records/presentation/edit_record_page.dart
// New/Edit info page, restyled to match the design mockups:
// save-status app bar title, big bold title, tappable links in body,
// bottom category/tag rows with smart-suggestion badge, auto-save hint.

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:suicun/core/database/providers.dart';
import 'package:suicun/features/records/domain/record_model.dart';
import 'package:suicun/features/records/presentation/edit_record_notifier.dart';
import 'package:suicun/features/records/presentation/records_notifier.dart';
import 'package:suicun/features/tags/domain/tag_model.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';
import 'package:suicun/services/auto_category_service.dart';

class EditRecordPage extends ConsumerStatefulWidget {
  const EditRecordPage({super.key, this.recordId});

  final String? recordId;

  @override
  ConsumerState<EditRecordPage> createState() => _EditRecordPageState();
}

class _EditRecordPageState extends ConsumerState<EditRecordPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late final FocusNode _bodyFocusNode;
  bool _initialized = false;

  /// Body shows rich text when not editing; tap to edit.
  late bool _bodyEditing;

  /// Smart-suggestion wiring.
  Timer? _suggestTimer;
  bool _userPickedCategory = false;
  bool _smartSuggested = false;

  bool get _isNew => widget.recordId == null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _bodyController = TextEditingController();
    _bodyFocusNode = FocusNode();
    _bodyEditing = _isNew;
    _bodyFocusNode.addListener(() {
      // On the edit page, losing focus collapses back to rich text.
      // On the new page the body stays editable (matches the mockup).
      if (!_bodyFocusNode.hasFocus && _bodyEditing && !_isNew && mounted) {
        setState(() => _bodyEditing = false);
      }
    });
  }

  @override
  void dispose() {
    _suggestTimer?.cancel();
    _titleController.dispose();
    _bodyController.dispose();
    _bodyFocusNode.dispose();
    super.dispose();
  }

  void _onChanged() {
    ref.read(editRecordProvider(widget.recordId).notifier).onInputChanged(
          _titleController.text,
          _bodyController.text,
        );
    _scheduleSuggest();
  }

  void _scheduleSuggest() {
    _suggestTimer?.cancel();
    _suggestTimer = Timer(const Duration(milliseconds: 1200), () {
      _maybeSuggest();
    });
  }

  Future<void> _maybeSuggest() async {
    if (_userPickedCategory || !mounted) return;
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty && body.isEmpty) return;
    try {
      final suggestion = await ref
          .read(autoCategoryServiceProvider)
          .suggestCategory(title: title, body: body);
      if (!mounted || suggestion == null) return;
      final currentId =
          ref.read(editRecordProvider(widget.recordId)).record?.categoryId;
      if (currentId == suggestion.categoryId) return;
      await ref
          .read(editRecordProvider(widget.recordId).notifier)
          .setCategory(suggestion.categoryId);
      if (mounted) setState(() => _smartSuggested = true);
    } catch (_) {
      // Suggestion is best-effort; never break editing.
    }
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
    if (selected == null || !mounted) return;
    final categoryId = selected == '__none__' ? null : selected;
    await ref
        .read(editRecordProvider(widget.recordId).notifier)
        .setCategory(categoryId);
    // Learn from the manual correction.
    if (categoryId != null) {
      try {
        await ref.read(autoCategoryServiceProvider).learnFromCorrection(
              title: _titleController.text,
              body: _bodyController.text,
              categoryId: categoryId,
            );
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _userPickedCategory = true;
        _smartSuggested = false;
      });
    }
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

  Future<void> _removeTag(AppLocalizations l10n, RecordDetail record, String tagId) async {
    final remaining =
        record.tags.map((t) => t.id).where((id) => id != tagId).toList();
    await ref
        .read(editRecordProvider(widget.recordId).notifier)
        .setTags(remaining);
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final state = ref.watch(editRecordProvider(widget.recordId));

    if (!_initialized && state.record != null) {
      _titleController.text = state.record!.title;
      _bodyController.text = state.record!.body;
      _initialized = true;
    }

    final record = state.record;
    final isEmptyInput =
        _titleController.text.isEmpty && _bodyController.text.isEmpty;
    // New page that has never been saved shows the page title;
    // otherwise the app bar shows the live save status.
    final showPageTitle = _isNew && record == null && isEmptyInput;

    return PopScope(
      onPopInvokedWithResult: (_, __) async {
        await ref.read(editRecordProvider(widget.recordId).notifier).flush();
      },
      child: Scaffold(
        appBar: AppBar(
          title: showPageTitle
              ? Text(
                  l10n.newInfo,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                )
              : _SaveStatusTitle(saveState: state.saveState),
          actions: [
            IconButton(
              icon: Icon(
                record?.isFavorite == true ? Icons.star : Icons.star_border,
                color: record?.isFavorite == true ? Colors.amber : null,
              ),
              tooltip: record?.isFavorite == true
                  ? l10n.unfavorite
                  : l10n.favorite,
              onPressed: () {
                ref
                    .read(editRecordProvider(widget.recordId).notifier)
                    .toggleFavorite();
              },
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
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isNew && isEmptyInput)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 8),
                          child: Text(
                            l10n.notYetInput,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      TextField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          hintText: l10n.titleHint,
                          hintStyle: TextStyle(
                            color: colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.6),
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => _onChanged(),
                      ),
                      const SizedBox(height: 8),
                      _buildBodyArea(l10n, theme, colorScheme),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              _buildCategoryRow(l10n, theme, colorScheme, record),
              const Divider(height: 1, indent: 20, endIndent: 20),
              _buildTagRow(l10n, theme, colorScheme, record),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.autoSaveHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Body: rich text with tappable links when idle, TextField when editing.
  Widget _buildBodyArea(
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final text = _bodyController.text;
    if (_bodyEditing) {
      return TextField(
        controller: _bodyController,
        focusNode: _bodyFocusNode,
        autofocus: _isNew,
        decoration: InputDecoration(
          hintText: l10n.bodyHint,
          hintStyle: TextStyle(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: EdgeInsets.zero,
        ),
        style: theme.textTheme.bodyLarge,
        keyboardType: TextInputType.multiline,
        maxLines: null,
        onChanged: (_) => _onChanged(),
      );
    }

    if (text.isEmpty) {
      return GestureDetector(
        onTap: () => setState(() {
          _bodyEditing = true;
          _bodyFocusNode.requestFocus();
        }),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            l10n.bodyHint,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => setState(() {
        _bodyEditing = true;
        _bodyFocusNode.requestFocus();
      }),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text.rich(
          TextSpan(
            children: _buildBodySpans(text, l10n, theme, colorScheme),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  static final _linkRegExp = RegExp(r'https?://[^\s]+');

  List<InlineSpan> _buildBodySpans(
    String text,
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in _linkRegExp.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      var url = match.group(0)!;
      // Trim trailing CJK/ASCII punctuation accidentally captured.
      url = url.replaceAll(RegExp(r'[。，、；：？！,.!?;:)\]]+$'), '');
      spans.add(
        TextSpan(
          text: url,
          style: TextStyle(
            color: colorScheme.primary,
            decoration: TextDecoration.underline,
            decorationColor: colorScheme.primary,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.linkCopied)),
                );
              }
            },
        ),
      );
      cursor = match.start + url.length;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return spans;
  }

  Widget _buildCategoryRow(
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme colorScheme,
    RecordDetail? record,
  ) {
    final category = record?.category;
    return InkWell(
      onTap: () => _pickCategory(l10n, record),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              Icon(Icons.folder_outlined,
                  color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Text(l10n.category, style: theme.textTheme.titleMedium),
              const Spacer(),
              if (_smartSuggested)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    l10n.smartRecommend,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimary,
                      fontSize: 11,
                    ),
                  ),
                ),
              if (category != null) ...[
                _ColorDot(color: _parseColor(category.color)),
                const SizedBox(width: 6),
                Text(category.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    )),
              ] else
                Text(
                  l10n.uncategorized,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right,
                  color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTagRow(
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme colorScheme,
    RecordDetail? record,
  ) {
    final tags = record?.tags ?? const <TagModel>[];
    return InkWell(
      onTap: () => _pickTags(l10n, record),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              Icon(Icons.label_outlined,
                  color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Text(l10n.tags, style: theme.textTheme.titleMedium),
              const SizedBox(width: 12),
              Expanded(
                child: tags.isEmpty
                    ? Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: () => _pickTags(l10n, record),
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(l10n.addTags),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 40),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12),
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            for (final t in tags)
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 6),
                                child: _TagChip(
                                  label: t.name,
                                  onRemove: () =>
                                      _removeTag(l10n, record!, t.id),
                                ),
                              ),
                            Padding(
                              padding:
                                  const EdgeInsets.only(left: 6),
                              child: _DashedAddButton(
                                onTap: () => _pickTags(l10n, record),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right,
                  color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// App bar title showing the live auto-save status.
class _SaveStatusTitle extends StatelessWidget {
  const _SaveStatusTitle({required this.saveState});

  final SaveState saveState;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    switch (saveState) {
      case SaveState.saved:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: colorScheme.primary, size: 18),
            const SizedBox(width: 4),
            Text(
              l10n.saved,
              style: TextStyle(
                color: colorScheme.primary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      case SaveState.saving:
        return Text(
          l10n.saving,
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
        );
      case SaveState.error:
        return Text(
          l10n.saveFailed,
          style: TextStyle(
            color: colorScheme.error,
            fontSize: 14,
          ),
        );
    }
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 4, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          GestureDetector(
            onTap: onRemove,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.close, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedAddButton extends StatelessWidget {
  const _DashedAddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: CustomPaint(
        painter: _DashedRectPainter(color: colorScheme.outline),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(Icons.add,
              size: 18, color: colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// Dashed rounded-rectangle border painter (no extra dependencies).
class _DashedRectPainter extends CustomPainter {
  _DashedRectPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const dash = 4.0;
    const gap = 3.0;
    const radius = 8.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromLTWH(0.6, 0.6, size.width - 1.2, size.height - 1.2);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics().first;
    final total = metrics.length;
    var dist = 0.0;
    final dashed = Path();
    while (dist < total) {
      final end = (dist + dash).clamp(0.0, total);
      dashed.addPath(metrics.extractPath(dist, end), Offset.zero);
      dist += dash + gap;
    }
    canvas.drawPath(dashed, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) =>
      oldDelegate.color != color;
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
