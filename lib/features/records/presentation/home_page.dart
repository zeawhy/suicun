// lib/features/records/presentation/home_page.dart
// Home screen, restyled to match the design mockups:
// big title + settings gear, rounded search box, horizontal filter chips,
// record rows with colored icon blocks, gold stars, ⋮ menus, dividers, FAB.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:suicun/core/database/providers.dart';
import 'package:suicun/features/categories/domain/category_model.dart';
import 'package:suicun/features/categories/presentation/categories_notifier.dart';
import 'package:suicun/features/records/domain/record_model.dart';
import 'package:suicun/features/records/presentation/records_notifier.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';
import 'package:suicun/shared/widgets/record_list_tile.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _isMultiSelect = false;
  final Set<String> _selectedIds = {};

  void _toggleMultiSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isMultiSelect = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _exitMultiSelect() {
    setState(() {
      _isMultiSelect = false;
      _selectedIds.clear();
    });
  }

  Future<void> _deleteRecord(String id) async {
    await ref.read(recordRepositoryProvider).softDeleteRecord(id);
    ref.invalidate(recordsListProvider);
    ref.invalidate(trashListProvider);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.recordDeleted),
        action: SnackBarAction(
          label: l10n.undoDelete,
          onPressed: () async {
            await ref.read(recordRepositoryProvider).restoreRecord(id);
            ref.invalidate(recordsListProvider);
            ref.invalidate(trashListProvider);
          },
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(RecordDetail r) async {
    await ref
        .read(recordRepositoryProvider)
        .updateRecord(r.id, isFavorite: !r.isFavorite);
    ref.invalidate(recordsListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final recordsAsync = ref.watch(recordsListProvider);
    final filter = ref.watch(recordsFilterProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: _isMultiSelect
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                tooltip: l10n.cancel,
                onPressed: _exitMultiSelect,
              ),
              title: Text(l10n.selectedCount(_selectedIds.length)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: l10n.batchDelete,
                  onPressed: () async {
                    final repo = ref.read(recordRepositoryProvider);
                    for (final id in _selectedIds) {
                      await repo.softDeleteRecord(id);
                    }
                    ref.invalidate(recordsListProvider);
                    ref.invalidate(trashListProvider);
                    _exitMultiSelect();
                  },
                ),
              ],
            )
          : AppBar(
              title: Text(
                l10n.appName,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: l10n.settings,
                  onPressed: () => context.push('/settings'),
                ),
              ],
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              onChanged: (v) =>
                  ref.read(recordsFilterProvider.notifier).setQuery(v),
              decoration: InputDecoration(
                hintText: l10n.searchHint,
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                  size: 22,
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      BorderSide(color: colorScheme.primary, width: 1.5),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          categoriesAsync.maybeWhen(
            data: (categories) => _FilterChips(
              filter: filter,
              categories: categories,
              onAll: () =>
                  ref.read(recordsFilterProvider.notifier).clearFilter(),
              onFavorites: () => ref
                  .read(recordsFilterProvider.notifier)
                  .setFavoritesOnly(true),
              onCategory: (id) =>
                  ref.read(recordsFilterProvider.notifier).setCategory(id),
            ),
            orElse: () => const SizedBox(height: 40),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: recordsAsync.when(
              data: (records) {
                if (records.isEmpty) {
                  return _EmptyState(
                    filter: filter,
                    onClearFilter: () => ref
                        .read(recordsFilterProvider.notifier)
                        .clearFilter(),
                  );
                }
                return ListView.separated(
                  itemCount: records.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    indent: 78,
                    endIndent: 16,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                  itemBuilder: (context, index) {
                    final r = records[index];
                    return RecordListTile(
                      record: r,
                      isSelected: _selectedIds.contains(r.id),
                      isMultiSelectMode: _isMultiSelect,
                      untitledLabel: l10n.untitledRecord,
                      favoriteTooltip: l10n.favorite,
                      unfavoriteTooltip: l10n.unfavorite,
                      deleteLabel: l10n.delete,
                      onTap: () {
                        if (_isMultiSelect) {
                          _toggleMultiSelect(r.id);
                        } else {
                          context.push('/edit/${r.id}');
                        }
                      },
                      onLongPress: () {
                        if (!_isMultiSelect) {
                          setState(() {
                            _isMultiSelect = true;
                            _selectedIds.add(r.id);
                          });
                        }
                      },
                      onFavoriteToggle: () => _toggleFavorite(r),
                      onDelete: () => _deleteRecord(r.id),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text(e.toString())),
            ),
          ),
        ],
      ),
      floatingActionButton: _isMultiSelect
          ? null
          : FloatingActionButton(
              onPressed: () => context.push('/edit'),
              tooltip: l10n.newRecord,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.add, size: 28),
            ),
    );
  }
}

/// Horizontal filter chips: All / Favorites / categories.
class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.filter,
    required this.categories,
    required this.onAll,
    required this.onFavorites,
    required this.onCategory,
  });

  final RecordsFilter filter;
  final List<CategoryModel> categories;
  final VoidCallback onAll;
  final VoidCallback onFavorites;
  final void Function(String id) onCategory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final allSelected = filter.categoryId == null && !filter.favoritesOnly;

    Widget chip({
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          showCheckmark: false,
          labelStyle: TextStyle(
            color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
          selectedColor: colorScheme.primary,
          backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          side: BorderSide(
            color: selected
                ? Colors.transparent
                : colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          materialTapTargetSize: MaterialTapTargetSize.padded,
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          chip(label: l10n.all, selected: allSelected, onTap: onAll),
          chip(
            label: l10n.favorites,
            selected: filter.favoritesOnly,
            onTap: onFavorites,
          ),
          for (final c in categories)
            chip(
              label: c.name,
              selected: filter.categoryId == c.id,
              onTap: () => onCategory(c.id),
            ),
        ],
      ),
    );
  }
}

/// Three distinct empty states: no records / filter empty / search no result.
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.filter,
    required this.onClearFilter,
  });

  final RecordsFilter filter;
  final VoidCallback onClearFilter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final hasQuery = filter.query.trim().isNotEmpty;
    final hasFilter =
        filter.categoryId != null || filter.favoritesOnly;

    final String title;
    final String hint;
    final IconData icon;
    if (hasQuery) {
      title = l10n.searchEmpty;
      hint = l10n.searchEmptyHint;
      icon = Icons.search_off_rounded;
    } else if (hasFilter) {
      title = l10n.filterEmpty;
      hint = l10n.filterEmptyHint;
      icon = Icons.filter_alt_off_rounded;
    } else {
      title = l10n.recordsEmpty;
      hint = l10n.recordsEmptyHint;
      icon = Icons.auto_stories_outlined;
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 44,
                color: colorScheme.primary.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                hint,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (!hasQuery && hasFilter) ...[
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                onPressed: onClearFilter,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(l10n.clearFilter),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
