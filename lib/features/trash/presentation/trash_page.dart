// lib/features/trash/presentation/trash_page.dart
// Recycle bin: restore soft-deleted records or delete them permanently.

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
              leading: const Icon(Icons.restore),
              title: Text(l10n.restore),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('delete'),
            child: ListTile(
              leading: const Icon(Icons.delete_forever),
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
    final trashAsync = ref.watch(trashListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.trash),
        actions: [
          trashAsync.maybeWhen(
            data: (records) => records.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.delete_forever),
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
            return Center(child: Text(l10n.trashEmpty));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: records.length,
            itemBuilder: (context, index) {
              final r = records[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: RecordListTile(
                  record: r,
                  isSelected: false,
                  isMultiSelectMode: false,
                  untitledLabel: l10n.untitledRecord,
                  onTap: () => _showRecordActions(context, ref, l10n, r),
                  onLongPress: () => _showRecordActions(context, ref, l10n, r),
                  onFavoriteToggle: () {},
                ),
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
