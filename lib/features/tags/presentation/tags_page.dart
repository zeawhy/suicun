// lib/features/tags/presentation/tags_page.dart
// Tag management: list, add, rename, delete. Restyled to shared visuals.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suicun/features/tags/domain/tag_model.dart';
import 'package:suicun/features/tags/presentation/tags_notifier.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';

class TagsPage extends ConsumerWidget {
  const TagsPage({super.key});

  Future<void> _addTagDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.addTag),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.tagName,
            filled: true,
          ),
          onSubmitted: (_) => Navigator.of(ctx).pop(true),
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
    final name = controller.text.trim();
    controller.dispose();
    if (confirmed != true || name.isEmpty) return;
    try {
      await ref.read(tagsProvider.notifier).addTag(name);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.duplicateName)),
        );
      }
    }
  }

  Future<void> _renameTagDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    TagModel tag,
  ) async {
    final controller = TextEditingController(text: tag.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.editTag),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.tagName,
            filled: true,
          ),
          onSubmitted: (_) => Navigator.of(ctx).pop(true),
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
    final name = controller.text.trim();
    controller.dispose();
    if (confirmed != true || name.isEmpty || name == tag.name) return;
    try {
      await ref.read(tagsProvider.notifier).renameTag(tag.id, name);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.duplicateName)),
        );
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    TagModel tag,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteTag),
        content: Text(l10n.deleteTagConfirm),
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
      await ref.read(tagsProvider.notifier).deleteTag(tag.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tagsState = ref.watch(tagsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tags)),
      body: tagsState.when(
        data: (tags) {
          if (tags.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.label_outlined,
                      size: 64,
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.tagsEmpty,
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
            itemCount: tags.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              indent: 72,
              endIndent: 16,
            ),
            itemBuilder: (context, index) {
              final tag = tags[index];
              return ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.tag_outlined,
                    color: theme.colorScheme.primary,
                  ),
                ),
                title: Text(tag.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: l10n.editTag,
                      onPressed: () =>
                          _renameTagDialog(context, ref, l10n, tag),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: l10n.deleteTag,
                      onPressed: () =>
                          _confirmDelete(context, ref, l10n, tag),
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
        onPressed: () => _addTagDialog(context, ref, l10n),
        tooltip: l10n.addTag,
        shape: const CircleBorder(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
