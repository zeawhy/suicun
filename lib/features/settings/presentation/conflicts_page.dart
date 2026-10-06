// lib/features/settings/presentation/conflicts_page.dart
// Sync conflicts resolution page for 随存 (Stage C).
//
// Honesty rules:
// - Never pretend "conflicts resolved" or invent conflict data.
// - All data strictly comes from conflictsProvider.
// - All resolutions go through syncActions.resolveConflict.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suicun/features/sync/sync_contract.dart';
import 'package:suicun/features/sync/sync_errors.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';
import 'package:suicun/shared/utils/date_formatter.dart';

class ConflictsPage extends ConsumerStatefulWidget {
  const ConflictsPage({super.key});

  @override
  ConsumerState<ConflictsPage> createState() => _ConflictsPageState();
}

class _ConflictsPageState extends ConsumerState<ConflictsPage> {
  final Set<String> _resolvingIds = {};

  String _entityTypeLabel(AppLocalizations l10n, String entityType) {
    return switch (entityType.toLowerCase()) {
      'record' => l10n.conflictTypeRecord,
      'category' => l10n.conflictTypeCategory,
      'tag' => l10n.conflictTypeTag,
      _ => entityType,
    };
  }

  Future<void> _handleResolve(
    String conflictId,
    ConflictChoice choice, {
    String? mergedTitle,
    String? mergedBody,
  }) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _resolvingIds.add(conflictId));
    try {
      final actions = ref.read(syncActionsProvider);
      await actions.resolveConflict(
        conflictId,
        choice,
        mergedTitle: mergedTitle,
        mergedBody: mergedBody,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.resolveSuccess)),
      );
    } catch (e) {
      if (!mounted) return;
      final isEn = Localizations.localeOf(context).languageCode == 'en';
      final msg = e is SyncError ? e.message(english: isEn) : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _resolvingIds.remove(conflictId));
      }
    }
  }

  Future<void> _showManualMergeDialog(ConflictInfo conflict) async {
    final l10n = AppLocalizations.of(context);
    final titleController = TextEditingController(text: conflict.localTitle);
    final bodyController = TextEditingController(text: conflict.localBody);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.mergeDialogTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: l10n.mergeTitleHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bodyController,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: l10n.mergeBodyHint,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
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

    if (confirmed == true && mounted) {
      await _handleResolve(
        conflict.id,
        ConflictChoice.manualMerge,
        mergedTitle: titleController.text,
        mergedBody: bodyController.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final conflictsAsync = ref.watch(conflictsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.conflictsTitle),
      ),
      body: conflictsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorCard(context, l10n),
        data: (conflicts) {
          if (conflicts.isEmpty) {
            return _buildEmptyState(context, l10n);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: conflicts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              return _buildConflictCard(context, l10n, conflicts[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.sync_problem_outlined,
                  size: 48,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.syncStatusUnavailable,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.syncStatusUnavailableDesc,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green.shade700,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.conflictsEmpty,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConflictCard(
    BuildContext context,
    AppLocalizations l10n,
    ConflictInfo conflict,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final locale = Localizations.localeOf(context).languageCode;
    final isResolving = _resolvingIds.contains(conflict.id);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top chip
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  label: Text(_entityTypeLabel(l10n, conflict.entityType)),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                if (isResolving)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.resolving,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Two-column comparison
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Local version
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.localVersion,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          conflict.localTitle.isEmpty
                              ? l10n.untitledRecord
                              : conflict.localTitle,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (conflict.localBody.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            conflict.localBody,
                            style: theme.textTheme.bodySmall,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          l10n.updatedAt(DateFormatter.formatFull(
                              conflict.localUpdatedAt, locale)),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Remote version
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.remoteVersion,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          conflict.remoteTitle.isEmpty
                              ? l10n.untitledRecord
                              : conflict.remoteTitle,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (conflict.remoteBody.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            conflict.remoteBody,
                            style: theme.textTheme.bodySmall,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          l10n.updatedAt(DateFormatter.formatFull(
                              conflict.remoteUpdatedAt, locale)),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Actions
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: isResolving
                      ? null
                      : () => _handleResolve(
                          conflict.id, ConflictChoice.keepLocal),
                  child: Text(l10n.keepLocal),
                ),
                OutlinedButton(
                  onPressed: isResolving
                      ? null
                      : () => _handleResolve(
                          conflict.id, ConflictChoice.keepRemote),
                  child: Text(l10n.keepRemote),
                ),
                OutlinedButton(
                  onPressed: isResolving
                      ? null
                      : () => _handleResolve(
                          conflict.id, ConflictChoice.keepBoth),
                  child: Text(l10n.keepBoth),
                ),
                FilledButton.tonal(
                  onPressed: isResolving
                      ? null
                      : () => _showManualMergeDialog(conflict),
                  child: Text(l10n.manualMerge),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Footer note
            Row(
              children: [
                Icon(
                  Icons.history_outlined,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.conflictHistoryNote,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
