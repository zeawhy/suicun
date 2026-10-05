// lib/features/trash/presentation/trash_page.dart
// Recycle bin: restore soft-deleted records or delete them permanently.
// Restyled to the shared visual language; logic unchanged.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suicun/core/database/providers.dart';
import 'package:suicun/features/records/domain/record_model.dart';
import 'package:suicun/features/records/presentation/records_notifier.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';
import 'package:suicun/shared/widgets/record_list_tile.dart';

class TrashPage extends ConsumerWidget {
  const TrashPage({super.key});

  Future<void> _confirmEmptyTrash(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    List<RecordDetail> records,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.permanentDelete),
        content: Text(l10n.permanentDeleteConfirm),
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
    if (confirmed != true) return;
    final repo = ref.read(recordRepositoryProvider);
    for (final r in records) {
      await repo.permanentDeleteRecord(r.id);
    }
    ref.invalidate(trashListProvider);
  }

  Future<void> _showRecordActions(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    RecordDetail record,
  ) async {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(
          record.title.isNotEmpty ? record.title : l10n.untitledRecord,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('restore'),
            child: ListTile(
              leading: const Icon(Icons.restore_outlined),
              title: Text(l10n.restore),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('delete'),
            child: ListTile(
              leading: const Icon(Icons.delete_forever_outlined),
              title: Text(l10n.permanentDelete),
            ),
          ),
        ],
      ),
    );

    final repo = ref.read(recordRepositoryProvider);
    if (action == 'restore') {
      await repo.restoreRecord(record.id);
      ref.invalidate(trashListProvider);
      ref.invalidate(recordsListProvider);
    } else if (action == 'delete') {
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.permanentDelete),
          content: Text(l10n.permanentDeleteConfirm),
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
        await repo.permanentDeleteRecord(record.id);
        ref.invalidate(trashListProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final trashAsync = ref.watch(trashListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.trash),
        actions: [
          trashAsync.maybeWhen(
            data: (records) => records.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.delete_forever_outlined),
                    tooltip: l10n.permanentDelete,
                    onPressed: () =>
                        _confirmEmptyTrash(context, ref, l10n, records),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: trashAsync.when(
        data: (records) {
          if (records.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.delete_outline,
                      size: 64,
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.trashEmpty,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: records.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              indent: 76,
              endIndent: 16,
            ),
            itemBuilder: (context, index) {
              final r = records[index];
              return RecordListTile(
                record: r,
                isSelected: false,
                isMultiSelectMode: false,
                untitledLabel: l10n.untitledRecord,
                favoriteTooltip: l10n.favorite,
                unfavoriteTooltip: l10n.unfavorite,
                onTap: () => _showRecordActions(context, ref, l10n, r),
                onLongPress: () => _showRecordActions(context, ref, l10n, r),
                onFavoriteToggle: () {},
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text(e.toString())),
      ),
    );
  }
}
