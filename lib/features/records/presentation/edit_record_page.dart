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
import 'package:suicun/features/categories/presentation/category_display_name.dart';
import 'package:suicun/features/records/domain/record_model.dart';
import 'package:suicun/features/records/presentation/checklist_line.dart';
import 'package:suicun/features/records/presentation/edit_record_notifier.dart';
import 'package:suicun/features/records/presentation/markdown_line.dart';
import 'package:suicun/features/records/presentation/note_template.dart';
import 'package:suicun/features/records/presentation/records_notifier.dart';
import 'package:suicun/features/records/presentation/secret_line.dart';
import 'package:suicun/features/records/presentation/template_views/blank_template_view.dart';
import 'package:suicun/features/records/presentation/template_views/contact_template_view.dart';
import 'package:suicun/features/records/presentation/template_views/id_document_template_view.dart';
import 'package:suicun/features/records/presentation/template_views/idea_template_view.dart';
import 'package:suicun/features/records/presentation/template_views/password_template_view.dart';
import 'package:suicun/features/records/presentation/template_views/template_detector.dart';
import 'package:suicun/features/records/presentation/template_views/todo_template_view.dart';
import 'package:suicun/features/tags/domain/tag_model.dart';
import 'package:suicun/features/records/presentation/template_sheet.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';
import 'package:suicun/services/auto_category_service.dart';
import 'package:suicun/shared/theme/app_theme.dart';

class EditRecordPage extends ConsumerStatefulWidget {
  const EditRecordPage({
    super.key,
    this.recordId,
    this.templateId,
    this.autofocus = false,
    this.initialText,
  });

  final String? recordId;
  final String? templateId;
  final bool autofocus;
  final String? initialText;

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

  /// Smart-suggestion wiring: up to two candidate categories are offered
  /// as tappable chips for the user to choose from (never auto-applied).
  Timer? _suggestTimer;
  bool _userPickedCategory = false;
  List<CategorySuggestion> _suggestions = const [];
  Map<String, String> _suggestionColors = const {};

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

    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _bodyEditing = true;
          });
          _bodyFocusNode.requestFocus();
        }
      });
    }
  }

  String _getCurrentTemplateTitle(AppLocalizations l10n) {
    final currentTemplate = NoteTemplate.byId(widget.templateId);
    if (currentTemplate != null) {
      return currentTemplate.getTitle(l10n);
    }
    final body = _bodyController.text;
    if (parsePasswordTemplate(body) != null) return l10n.templatePassword;
    if (parseIdeaTemplate(body) != null) return l10n.templateIdea;
    if (parseTodoTemplate(body) != null) return l10n.templateTodo;
    if (parseContactTemplate(body) != null) return l10n.templateContact;
    if (parseIdDocumentTemplate(body) != null) return l10n.templateIdDocument;
    return l10n.templateBlank;
  }

  void _switchTemplate(String templateId) {
    final locale = Localizations.localeOf(context).languageCode;
    final template = NoteTemplate.byId(templateId);
    if (template != null) {
      final templateBody = template.getBody(locale);
      if (_bodyController.text.trim().isEmpty) {
        _bodyController.text = templateBody;
      } else {
        _bodyController.text =
            '${_bodyController.text}\n\n$templateBody'.trim();
      }
      _onChanged();
      setState(() {
        _bodyEditing = true;
      });
      _bodyFocusNode.requestFocus();
    }
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
      final suggestions = await ref
          .read(autoCategoryServiceProvider)
          .suggestCategories(title: title, body: body, limit: 2);
      if (!mounted) return;
      final currentId =
          ref.read(editRecordProvider(widget.recordId)).record?.categoryId;
      final visible =
          suggestions.where((s) => s.categoryId != currentId).toList();
      Map<String, String> colors = const {};
      if (visible.isNotEmpty) {
        final cats =
            await ref.read(categoryRepositoryProvider).getAllCategories();
        colors = {for (final c in cats) c.id: c.color};
      }
      if (mounted) {
        setState(() {
          _suggestions = visible;
          _suggestionColors = colors;
        });
        if (visible.isNotEmpty) {
          final summary = visible
              .map((s) =>
                  '${s.categoryName}(confidence: ${s.confidence.toStringAsFixed(2)})')
              .join(', ');
          debugPrint('[auto_category] suggestions: $summary');
        }
      }
    } catch (e, st) {
      // Suggestion is best-effort; never break editing.
      debugPrint('[auto_category] suggestion failed: $e\n$st');
    }
  }

  /// Applies a tapped suggestion: sets the category, learns keywords from
  /// the current text, and dismisses the suggestion chips.
  Future<void> _applySuggestion(CategorySuggestion suggestion) async {
    await ref
        .read(editRecordProvider(widget.recordId).notifier)
        .setCategory(suggestion.categoryId);
    try {
      await ref.read(autoCategoryServiceProvider).learnFromCorrection(
            title: _titleController.text,
            body: _bodyController.text,
            categoryId: suggestion.categoryId,
          );
    } catch (_) {}
    if (mounted) {
      setState(() {
        _suggestions = const [];
        _suggestionColors = const {};
        _userPickedCategory = true;
      });
    }
  }

  /// Tappable suggestion chips ("智能推荐：工作 / 学习") shown under the
  /// category row. The user picks one; nothing is applied automatically.
  Widget _buildSuggestionRow(
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    if (_suggestions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_outlined,
              size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            l10n.smartRecommend,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in _suggestions)
                  InkWell(
                    onTap: () => _applySuggestion(s),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 40),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ColorDot(
                            color: Theme.of(context)
                                .suiColors
                                .colorForCategory(
                                  s.categoryName,
                                  _suggestionColors[s.categoryId],
                                ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            s.categoryName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
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
                  _ColorDot(
                    color: Theme.of(ctx)
                        .suiColors
                        .colorForCategory(c.name, c.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(categoryDisplayName(ctx, c.name))),
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
        _suggestions = const [];
        _suggestionColors = const {};
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
    final messenger = ScaffoldMessenger.of(context);
    context.pop();
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        persist: false,
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

    if (!_initialized) {
      if (state.record != null) {
        _titleController.text = state.record!.title;
        _bodyController.text = state.record!.body;
        _initialized = true;
      } else if (_isNew &&
          widget.initialText != null &&
          widget.initialText!.isNotEmpty) {
        _bodyController.text = widget.initialText!;
        _initialized = true;
      } else if (_isNew &&
          widget.templateId != null &&
          widget.templateId != 'blank') {
        final locale = Localizations.localeOf(context).languageCode;
        final template = NoteTemplate.byId(widget.templateId);
        if (template != null) {
          _bodyController.text = template.getBody(locale);
        }
        _initialized = true;
      }
    }

    final record = state.record;
    final isEmptyInput =
        _titleController.text.isEmpty && _bodyController.text.isEmpty;
    final showPageTitle = _isNew && record == null && isEmptyInput;
    final isPasswordTemplateRecord =
        parsePasswordTemplate(_bodyController.text) != null &&
            (_isNew || !_bodyEditing);
    final isIdeaTemplateRecord = !isPasswordTemplateRecord &&
        parseIdeaTemplate(_bodyController.text) != null &&
        (_isNew || !_bodyEditing);
    final isTodoTemplateRecord = !isPasswordTemplateRecord &&
        !isIdeaTemplateRecord &&
        parseTodoTemplate(_bodyController.text) != null &&
        (_isNew || !_bodyEditing);
    final isContactTemplateRecord = !isPasswordTemplateRecord &&
        !isIdeaTemplateRecord &&
        !isTodoTemplateRecord &&
        parseContactTemplate(_bodyController.text) != null &&
        (_isNew || !_bodyEditing);
    final isIdDocumentTemplateRecord = !isPasswordTemplateRecord &&
        !isIdeaTemplateRecord &&
        !isTodoTemplateRecord &&
        !isContactTemplateRecord &&
        parseIdDocumentTemplate(_bodyController.text) != null &&
        (_isNew || !_bodyEditing);
    final isBlankTemplateRecord = !_isNew &&
        !_bodyEditing &&
        !isPasswordTemplateRecord &&
        !isIdeaTemplateRecord &&
        !isTodoTemplateRecord &&
        !isContactTemplateRecord &&
        !isIdDocumentTemplateRecord;

    Widget appBarTitle;
    if (showPageTitle) {
      appBarTitle = Text(
        l10n.newInfo,
        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      );
    } else if (isPasswordTemplateRecord) {
      appBarTitle = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.recordTitlePassword,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          _SaveStatusTitle(
            saveState: state.saveState,
            fontSize: 12,
            iconSize: 14,
            onRetry: () => ref
                .read(editRecordProvider(widget.recordId).notifier)
                .onInputChanged(
                  _titleController.text,
                  _bodyController.text,
                ),
          ),
        ],
      );
    } else if (isIdeaTemplateRecord) {
      appBarTitle = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.recordTitleIdea,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          _SaveStatusTitle(
            saveState: state.saveState,
            fontSize: 12,
            iconSize: 14,
            onRetry: () => ref
                .read(editRecordProvider(widget.recordId).notifier)
                .onInputChanged(
                  _titleController.text,
                  _bodyController.text,
                ),
          ),
        ],
      );
    } else if (isTodoTemplateRecord) {
      appBarTitle = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.recordTitleTodo,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          _SaveStatusTitle(
            saveState: state.saveState,
            fontSize: 12,
            iconSize: 14,
            onRetry: () => ref
                .read(editRecordProvider(widget.recordId).notifier)
                .onInputChanged(
                  _titleController.text,
                  _bodyController.text,
                ),
          ),
        ],
      );
    } else if (isContactTemplateRecord) {
      appBarTitle = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.recordTitleContact,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          _SaveStatusTitle(
            saveState: state.saveState,
            fontSize: 12,
            iconSize: 14,
            onRetry: () => ref
                .read(editRecordProvider(widget.recordId).notifier)
                .onInputChanged(
                  _titleController.text,
                  _bodyController.text,
                ),
          ),
        ],
      );
    } else if (isIdDocumentTemplateRecord) {
      appBarTitle = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.recordTitleIdDocument,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          _SaveStatusTitle(
            saveState: state.saveState,
            fontSize: 12,
            iconSize: 14,
            onRetry: () => ref
                .read(editRecordProvider(widget.recordId).notifier)
                .onInputChanged(
                  _titleController.text,
                  _bodyController.text,
                ),
          ),
        ],
      );
    } else if (isBlankTemplateRecord) {
      appBarTitle = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.recordTitleNote,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          _SaveStatusTitle(
            saveState: state.saveState,
            fontSize: 12,
            iconSize: 14,
            onRetry: () => ref
                .read(editRecordProvider(widget.recordId).notifier)
                .onInputChanged(
                  _titleController.text,
                  _bodyController.text,
                ),
          ),
        ],
      );
    } else {
      appBarTitle = _SaveStatusTitle(
        saveState: state.saveState,
        onRetry: () => ref
            .read(editRecordProvider(widget.recordId).notifier)
            .onInputChanged(
              _titleController.text,
              _bodyController.text,
            ),
      );
    }

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return PopScope(
      onPopInvokedWithResult: (_, __) async {
        await ref.read(editRecordProvider(widget.recordId).notifier).flush();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: appBarTitle,
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
              icon: const Icon(Icons.more_horiz),
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
          child: isPasswordTemplateRecord
              ? SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                  child: PasswordTemplateView(
                    data: parsePasswordTemplate(_bodyController.text) ??
                        const PasswordTemplateData(),
                    record: record,
                    rawBody: _bodyController.text,
                    isEditing: _isNew,
                    titleController: _isNew ? _titleController : null,
                    onTitleChanged: _isNew ? (_) => _onChanged() : null,
                    onBodyChanged: (newBody) {
                      _bodyController.text = newBody;
                      _onChanged();
                    },
                    onEdit: () => setState(() {
                      _bodyEditing = true;
                      _bodyFocusNode.requestFocus();
                    }),
                    categoryRow: _buildCategoryRow(l10n, theme, colorScheme, record),
                    suggestionRow: _buildSuggestionRow(l10n, theme, colorScheme),
                    tagRow: _buildTagRow(l10n, theme, colorScheme, record),
                  ),
                )
              : isIdeaTemplateRecord
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                      child: IdeaTemplateView(
                        data: parseIdeaTemplate(_bodyController.text) ??
                            const IdeaTemplateData(),
                        record: record,
                        rawBody: _bodyController.text,
                        isEditing: _isNew,
                        titleController: _isNew ? _titleController : null,
                        onTitleChanged: _isNew ? (_) => _onChanged() : null,
                        onBodyChanged: (newBody) {
                          _bodyController.text = newBody;
                          _onChanged();
                        },
                        onEdit: () => setState(() {
                          _bodyEditing = true;
                          _bodyFocusNode.requestFocus();
                        }),
                        categoryRow: _buildCategoryRow(l10n, theme, colorScheme, record),
                        suggestionRow: _buildSuggestionRow(l10n, theme, colorScheme),
                        tagRow: _buildTagRow(l10n, theme, colorScheme, record),
                      ),
                    )
                  : isTodoTemplateRecord
                      ? SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                          child: TodoTemplateView(
                            data: parseTodoTemplate(_bodyController.text) ??
                                const TodoTemplateData(items: []),
                            record: record,
                            rawBody: _bodyController.text,
                            isEditing: _isNew,
                            titleController: _isNew ? _titleController : null,
                            onTitleChanged: _isNew ? (_) => _onChanged() : null,
                            onBodyChanged: (newBody) {
                              _bodyController.text = newBody;
                              _onChanged();
                            },
                            onEdit: () => setState(() {
                              _bodyEditing = true;
                              _bodyFocusNode.requestFocus();
                            }),
                            onToggle: _toggleChecklistLine,
                            categoryRow: _buildCategoryRow(l10n, theme, colorScheme, record),
                            suggestionRow: _buildSuggestionRow(l10n, theme, colorScheme),
                            tagRow: _buildTagRow(l10n, theme, colorScheme, record),
                          ),
                        )
                      : isContactTemplateRecord
                          ? SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                              child: ContactTemplateView(
                                data: parseContactTemplate(_bodyController.text) ??
                                    const ContactTemplateData(),
                                record: record,
                                rawBody: _bodyController.text,
                                isEditing: _isNew,
                                titleController: _isNew ? _titleController : null,
                                onTitleChanged: _isNew ? (_) => _onChanged() : null,
                                onBodyChanged: (newBody) {
                                  _bodyController.text = newBody;
                                  _onChanged();
                                },
                                onEdit: () => setState(() {
                                  _bodyEditing = true;
                                  _bodyFocusNode.requestFocus();
                                }),
                                categoryRow: _buildCategoryRow(l10n, theme, colorScheme, record),
                                suggestionRow: _buildSuggestionRow(l10n, theme, colorScheme),
                                tagRow: _buildTagRow(l10n, theme, colorScheme, record),
                              ),
                            )
                      : isIdDocumentTemplateRecord
                          ? SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                              child: IdDocumentTemplateView(
                                data: parseIdDocumentTemplate(_bodyController.text) ??
                                    const IdDocumentTemplateData(),
                                record: record,
                                rawBody: _bodyController.text,
                                isEditing: _isNew,
                                titleController: _isNew ? _titleController : null,
                                onTitleChanged: _isNew ? (_) => _onChanged() : null,
                                onBodyChanged: (newBody) {
                                  _bodyController.text = newBody;
                                  _onChanged();
                                },
                                onEdit: () => setState(() {
                                  _bodyEditing = true;
                                  _bodyFocusNode.requestFocus();
                                }),
                                categoryRow: _buildCategoryRow(l10n, theme, colorScheme, record),
                                suggestionRow: _buildSuggestionRow(l10n, theme, colorScheme),
                                tagRow: _buildTagRow(l10n, theme, colorScheme, record),
                              ),
                            )
                          : isBlankTemplateRecord
                              ? SingleChildScrollView(
                                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                                  child: BlankTemplateView(
                                    record: record,
                                    bodySpans: _buildBodySpans(_bodyController.text, l10n, theme, colorScheme),
                                    isEmptyBody: _bodyController.text.isEmpty,
                                    onEdit: () => setState(() {
                                      _bodyEditing = true;
                                      _bodyFocusNode.requestFocus();
                                    }),
                                    onTapBody: () => setState(() {
                                      _bodyEditing = true;
                                      _bodyFocusNode.requestFocus();
                                    }),
                                    categoryRow: _buildCategoryRow(l10n, theme, colorScheme, record),
                                    suggestionRow: _buildSuggestionRow(l10n, theme, colorScheme),
                                    tagRow: _buildTagRow(l10n, theme, colorScheme, record),
                                  ),
                                )
                              : Column(
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
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildCategoryRow(l10n, theme, colorScheme, record),
                          _buildSuggestionRow(l10n, theme, colorScheme),
                          Divider(
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                          _buildTagRow(l10n, theme, colorScheme, record),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
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
                                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
        bottomNavigationBar: AnimatedPadding(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SafeArea(
            top: false,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLowest,
                border: Border(
                  top: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // 模板切换胶囊
                  InkWell(
                    onTap: () async {
                      final selected = await showTemplateSheet(context);
                      if (selected != null && mounted) {
                        _switchTemplate(selected);
                      }
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            colorScheme.primaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.dashboard_customize_outlined,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getCurrentTemplateTitle(l10n),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // 快捷插入待办 checkbox
                  IconButton(
                    icon: const Icon(Icons.check_box_outlined, size: 20),
                    tooltip: l10n.formatCheckbox,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                    onPressed: () {
                      if (!_bodyEditing) {
                        setState(() => _bodyEditing = true);
                      }
                      _applyLineFormat(toggleCheckboxAt);
                    },
                  ),
                  const SizedBox(width: 6),
                  // 智能分类推荐 Chip
                  if (_suggestions.isNotEmpty)
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome_outlined,
                              size: 14,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            for (final s in _suggestions)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ActionChip(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  label: Text(
                                    s.categoryName,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  onPressed: () => _applySuggestion(s),
                                ),
                              ),
                          ],
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

  /// Body: rich text with tappable links when idle, TextField when editing.
  Widget _buildBodyArea(
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final text = _bodyController.text;
    if (_bodyEditing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFormatToolbar(l10n, theme, colorScheme),
          TextField(
            controller: _bodyController,
            focusNode: _bodyFocusNode,
            autofocus: _isNew,
            decoration: InputDecoration(
              hintText: l10n.bodyHint,
              hintStyle: TextStyle(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.zero,
            ),
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
            keyboardType: TextInputType.multiline,
            maxLines: null,
            onChanged: (_) => _onChanged(),
          ),
        ],
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
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
              height: 1.5,
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
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  /// Formatting toolbar shown above the body TextField while editing.
  /// Operates on plain-text markdown-ish markers; the read view renders them.
  Widget _buildFormatToolbar(
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FormatToolButton(
              icon: Icons.check_box_outlined,
              tooltip: l10n.formatCheckbox,
              onPressed: () => _applyLineFormat(toggleCheckboxAt),
            ),
            _FormatToolButton(
              icon: Icons.title,
              tooltip: l10n.formatHeading,
              onPressed: () => _applyLineFormat(toggleHeadingAt),
            ),
            _FormatToolButton(
              icon: Icons.format_bold,
              tooltip: l10n.formatBold,
              onPressed: _applyBoldFormat,
            ),
            _FormatToolButton(
              icon: Icons.format_list_bulleted,
              tooltip: l10n.formatBullet,
              onPressed: () => _applyLineFormat(toggleBulletAt),
            ),
          ],
        ),
      ),
    );
  }

  /// Applies a line-level format op at the current cursor position.
  void _applyLineFormat(FormatEditResult Function(String, int) op) {
    final selection = _bodyController.selection;
    final offset = selection.isValid
        ? selection.baseOffset
        : _bodyController.text.length;
    final result = op(_bodyController.text, offset);
    _bodyController.value = TextEditingValue(
      text: result.text,
      selection: TextSelection.collapsed(offset: result.cursorOffset),
    );
    _onChanged();
    if (!_bodyFocusNode.hasFocus) _bodyFocusNode.requestFocus();
  }

  /// Applies bold to the current selection, or inserts `****` with the
  /// cursor in the middle when nothing is selected.
  void _applyBoldFormat() {
    final selection = _bodyController.selection;
    final int start;
    final int end;
    if (selection.isValid) {
      start = selection.start;
      end = selection.end;
    } else {
      start = end = _bodyController.text.length;
    }
    final result = applyBold(_bodyController.text, start, end);
    _bodyController.value = TextEditingValue(
      text: result.text,
      selection: TextSelection.collapsed(offset: result.cursorOffset),
    );
    _onChanged();
    if (!_bodyFocusNode.hasFocus) _bodyFocusNode.requestFocus();
  }

  static final _linkRegExp = RegExp(r'https?://[^\s]+');

  List<InlineSpan> _buildBodySpans(
    String text,
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final secretLines = parseSecretLines(text);
    if (secretLines.isEmpty) return const [];

    final spans = <InlineSpan>[];
    for (var i = 0; i < secretLines.length; i++) {
      final line = secretLines[i];
      final isLastLine = i == secretLines.length - 1;

      if (line.isSecret) {
        final label = line.label ?? '';
        final secret = line.value ?? '';
        spans.add(
          TextSpan(
            text: '$label••••••',
            style: TextStyle(
              color: colorScheme.onSurface,
            ),
          ),
        );
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: secret));
                    if (mounted) {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.passwordCopied)),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      } else {
        final checklist = parseChecklistLine(line.rawLine);
        if (checklist.isChecklist) {
          _buildChecklistSpans(checklist, i, spans, l10n, theme, colorScheme);
        } else {
          final md = parseMarkdownLine(line.rawLine);
          if (md.isHeading) {
            _buildHeadingSpans(md, spans, l10n, theme, colorScheme);
          } else if (md.isBullet) {
            _buildBulletSpans(md, spans, l10n, colorScheme);
          } else {
            _buildLineSpansWithLinks(line.rawLine, spans, l10n, colorScheme);
          }
        }
      }

      if (!isLastLine) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return spans;
  }

  /// Toggles the checklist item at [lineIndex] and writes the change back
  /// through the normal auto-save chain.
  void _toggleChecklistLine(int lineIndex) {
    final newBody = toggleChecklistLineAt(_bodyController.text, lineIndex);
    if (newBody == _bodyController.text) return;
    _bodyController.text = newBody;
    _onChanged();
    if (mounted) setState(() {});
  }

  /// Renders one checklist line as a tappable checkbox + text row.
  void _buildChecklistSpans(
    ChecklistLine checklist,
    int lineIndex,
    List<InlineSpan> spans,
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final textSpans = <InlineSpan>[];
    _buildLineSpansWithLinks(
        checklist.content ?? '', textSpans, l10n, colorScheme);
    spans.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: checklist.checked,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (_) => _toggleChecklistLine(lineIndex),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text.rich(
                  TextSpan(
                    children: textSpans,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: checklist.checked
                          ? colorScheme.onSurfaceVariant
                          : colorScheme.onSurface,
                      height: 1.5,
                      decoration: checklist.checked
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Renders a `# ` heading line: larger bold text, links and bold inside.
  void _buildHeadingSpans(
    MarkdownLine md,
    List<InlineSpan> spans,
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final inner = <InlineSpan>[];
    _buildLineSpansWithLinks(md.content ?? '', inner, l10n, colorScheme);
    final baseSize = theme.textTheme.bodyLarge?.fontSize ?? 16.0;
    final extra = switch (md.headingLevel) {
      1 => 6.0,
      2 => 4.0,
      _ => 2.0,
    };
    spans.add(
      TextSpan(
        children: inner,
        style: TextStyle(
          fontSize: baseSize + extra,
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
          height: 1.5,
        ),
      ),
    );
  }

  /// Renders a `- ` bullet line: dot prefix, then links and bold inside.
  void _buildBulletSpans(
    MarkdownLine md,
    List<InlineSpan> spans,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    spans.add(
      TextSpan(
        text: '•  ',
        style: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    _buildLineSpansWithLinks(md.content ?? '', spans, l10n, colorScheme);
  }

  /// Emits spans for a plain segment, splitting `**bold**` parts.
  void _addBoldSpans(String segment, List<InlineSpan> spans) {
    for (final part in parseBoldSegments(segment)) {
      spans.add(
        TextSpan(
          text: part.text,
          style: part.bold
              ? const TextStyle(fontWeight: FontWeight.bold)
              : null,
        ),
      );
    }
  }

  void _buildLineSpansWithLinks(
    String lineText,
    List<InlineSpan> spans,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    var cursor = 0;
    for (final match in _linkRegExp.allMatches(lineText)) {
      if (match.start > cursor) {
        _addBoldSpans(lineText.substring(cursor, match.start), spans);
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
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.linkCopied)),
                );
              }
            },
        ),
      );
      cursor = match.start + url.length;
    }
    if (cursor < lineText.length) {
      _addBoldSpans(lineText.substring(cursor), spans);
    }
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
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              Icon(Icons.folder_outlined,
                  size: 20,
                  color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Text(
                l10n.category,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (category != null) ...[
                _ColorDot(
                  color: Theme.of(context)
                      .suiColors
                      .colorForCategory(
                        category.name,
                        category.color,
                      ),
                ),
                const SizedBox(width: 8),
                Text(categoryDisplayName(context, category.name),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
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
                  size: 20,
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
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              Icon(Icons.label_outlined,
                  size: 20,
                  color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Text(
                l10n.tags,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: tags.isEmpty
                    ? Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: () => _pickTags(l10n, record),
                          icon: const Icon(Icons.add, size: 16),
                          label: Text(l10n.addTags,
                              style: const TextStyle(fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 36),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
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
                  size: 20,
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
  const _SaveStatusTitle({
    required this.saveState,
    this.onRetry,
    this.fontSize = 14,
    this.iconSize = 18,
  });

  final SaveState saveState;
  final VoidCallback? onRetry;
  final double fontSize;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    switch (saveState) {
      case SaveState.saved:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: colorScheme.primary, size: iconSize),
            const SizedBox(width: 4),
            Text(
              l10n.saved,
              style: TextStyle(
                color: colorScheme.primary,
                fontSize: fontSize,
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
            fontSize: fontSize,
          ),
        );
      case SaveState.error:
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onRetry,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: colorScheme.error, size: iconSize),
                const SizedBox(width: 4),
                Text(
                  l10n.saveFailed,
                  style: TextStyle(
                    color: colorScheme.error,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
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

/// Single icon button in the formatting toolbar.
class _FormatToolButton extends StatelessWidget {
  const _FormatToolButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      color: colorScheme.onSurfaceVariant,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      onPressed: onPressed,
    );
  }
}
