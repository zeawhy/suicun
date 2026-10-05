// lib/features/categories/presentation/categories_page.dart
// Category management with per-category keyword editing for smart suggestions.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suicun/features/categories/domain/category_model.dart';
import 'package:suicun/features/categories/presentation/categories_notifier.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';
import 'package:suicun/services/auto_category_service.dart';

/// Preset colors offered when creating/editing a category.
const List<Color> _presetColors = [
  Color(0xFF4866D5),
  Color(0xFF7C5CD6),
  Color(0xFF2FA36B),
  Color(0xFFE39A2D),
  Color(0xFFE15D5D),
  Color(0xFF4AA3DF),
];

class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    CategoryModel cat,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteCategory),
        content: Text(l10n.deleteCategoryConfirm),
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
      await ref.read(categoriesProvider.notifier).deleteCategory(cat.id);
    }
  }

  Future<void> _editCategoryDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n, {
    CategoryModel? existing,
  }) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    Color selectedColor = existing != null
        ? _parseColor(existing.color)
        : _presetColors.first;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
              existing == null ? l10n.addCategory : l10n.editCategory),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                autofocus: existing == null,
                decoration: InputDecoration(
                  labelText: l10n.categoryName,
                  filled: true,
                ),
              ),
              const SizedBox(height: 16),
              Text(l10n.categoryColor,
                  style: Theme.of(ctx).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                children: [
                  for (final c in _presetColors)
                    GestureDetector(
                      onTap: () =>
                          setDialogState(() => selectedColor = c),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: selectedColor == c
                              ? Border.all(
                                  color: Theme.of(ctx).colorScheme.primary,
                                  width: 3,
                                )
                              : null,
                        ),
                        child: selectedColor == c
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 20)
                            : null,
                      ),
                    ),
                ],
              ),
            ],
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
      ),
    );
    final name = nameController.text.trim();
    nameController.dispose();
    if (confirmed != true || name.isEmpty) return;
    final hex =
        '#${selectedColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
    final notifier = ref.read(categoriesProvider.notifier);
    if (existing == null) {
      await notifier.addCategory(name, hex);
    } else {
      await notifier.editCategory(existing.id, name, hex);
    }
  }

  Future<void> _editKeywordsSheet(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    CategoryModel cat,
  ) async {
    final service = ref.read(autoCategoryServiceProvider);
    final initial = await service.getKeywords(cat.id);
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _KeywordsSheet(
        category: cat,
        initialKeywords: initial,
        onSave: (keywords) => service.setKeywords(cat.id, keywords),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final categoriesState = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.categories)),
      body: categoriesState.when(
        data: (categories) {
          if (categories.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.folder_outlined,
                      size: 64,
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.categoriesEmpty,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              indent: 72,
              endIndent: 16,
            ),
            itemBuilder: (context, index) {
              final cat = categories[index];
              final color = _parseColor(cat.color);
              return ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.folder_outlined, color: color),
                ),
                title: Text(cat.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: _KeywordCountLabel(categoryId: cat.id),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.key_outlined),
                      tooltip: l10n.keywords,
                      onPressed: () =>
                          _editKeywordsSheet(context, ref, l10n, cat),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: l10n.editCategory,
                      onPressed: () => _editCategoryDialog(
                          context, ref, l10n,
                          existing: cat),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: l10n.deleteCategory,
                      onPressed: () =>
                          _confirmDelete(context, ref, l10n, cat),
                    ),
                  ],
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text(e.toString())),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editCategoryDialog(context, ref, l10n),
        tooltip: l10n.addCategory,
        shape: const CircleBorder(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Subtitle showing how many smart-suggestion keywords a category has.
class _KeywordCountLabel extends ConsumerWidget {
  const _KeywordCountLabel({required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final keywordsAsync =
        ref.watch(_categoryKeywordsProvider(categoryId));
    return keywordsAsync.maybeWhen(
      data: (kws) => Text(
        '${l10n.keywords} · ${kws.length}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

final _categoryKeywordsProvider =
    FutureProvider.family<List<String>, String>((ref, categoryId) {
  return ref.watch(autoCategoryServiceProvider).getKeywords(categoryId);
});

/// Bottom sheet for viewing/adding/removing a category's keywords.
class _KeywordsSheet extends StatefulWidget {
  const _KeywordsSheet({
    required this.category,
    required this.initialKeywords,
    required this.onSave,
  });

  final CategoryModel category;
  final List<String> initialKeywords;
  final Future<void> Function(List<String>) onSave;

  @override
  State<_KeywordsSheet> createState() => _KeywordsSheetState();
}

class _KeywordsSheetState extends State<_KeywordsSheet> {
  late List<String> _keywords;
  final _inputController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _keywords = List.of(widget.initialKeywords);
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _addKeyword() {
    final kw = _inputController.text.trim();
    if (kw.isEmpty || _keywords.contains(kw)) return;
    setState(() {
      _keywords.add(kw);
      _inputController.clear();
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.onSave(_keywords);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.category.name} · ${l10n.keywords}',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_keywords.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  l10n.keywordsEmpty,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final kw in _keywords)
                    InputChip(
                      label: Text(kw),
                      onDeleted: () =>
                          setState(() => _keywords.remove(kw)),
                    ),
                ],
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    decoration: InputDecoration(
                      hintText: l10n.keywordHint,
                      isDense: true,
                      filled: true,
                    ),
                    onSubmitted: (_) => _addKeyword(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.add),
                  tooltip: l10n.addKeyword,
                  onPressed: _addKeyword,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.save),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _parseColor(String hexStr) {
  hexStr = hexStr.toUpperCase().replaceAll('#', '');
  if (hexStr.length == 6) hexStr = 'FF$hexStr';
  return Color(int.tryParse(hexStr, radix: 16) ?? 0xFF4866D5);
}
