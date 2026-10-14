// lib/features/records/presentation/home_page.dart
// Redesigned home page matching the modern jade green spec:
// header row, debounced search, custom category chips with fixed manage button,
// item count & persistent sort switcher, clean white cards, sticky bottom sync status + action.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:suicun/core/database/providers.dart';
import 'package:suicun/features/categories/domain/category_model.dart';
import 'package:suicun/features/categories/presentation/categories_notifier.dart';
import 'package:suicun/features/records/domain/record_model.dart';
import 'package:suicun/features/records/presentation/home_sort_provider.dart';
import 'package:suicun/features/records/presentation/records_notifier.dart';
import 'package:suicun/features/categories/presentation/category_display_name.dart';
import 'package:suicun/features/records/data/quick_access_storage.dart';
import 'package:suicun/features/records/presentation/quick_access_panel.dart';
import 'package:suicun/features/records/presentation/template_sheet.dart';
import 'package:suicun/features/settings/presentation/settings_page.dart';
import 'package:suicun/features/sync/sync_contract.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';
import 'package:suicun/shared/theme/app_theme.dart';
import 'package:suicun/shared/widgets/record_card.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  bool _searchExpanded = false;
  String? _savedCategoryId;
  bool _savedFavoritesOnly = false;
  double _savedOffset = 0.0;
  bool _isMultiSelect = false;
  final Set<String> _selectedIds = {};
  bool _settingsOpen = false;
  bool _settingsMounted = false;

  static const double _sidebarWidth = 320.0;
  static const Duration _sidebarAnimationDuration =
      Duration(milliseconds: 280);
  static const Curve _sidebarAnimationCurve = Curves.fastOutSlowIn;

  void _openSettings() {
    setState(() {
      _settingsMounted = true;
      _settingsOpen = true;
    });
  }

  void _closeSettings() {
    if (!_settingsOpen) return;
    setState(() {
      _settingsOpen = false;
    });
  }

  void _toggleSettings() {
    if (_settingsOpen) {
      _closeSettings();
    } else {
      _openSettings();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _openSearch({required bool requestFocus}) {
    if (!mounted || _searchExpanded) return;
    final currentFilter = ref.read(recordsFilterProvider);
    _savedCategoryId = currentFilter.categoryId;
    _savedFavoritesOnly = currentFilter.favoritesOnly;
    _savedOffset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;
    setState(() {
      _searchExpanded = true;
    });
    if (requestFocus) {
      _searchFocus.requestFocus();
    }
  }

  void _cancelSearch() {
    _debounce?.cancel();
    _searchController.clear();
    final notifier = ref.read(recordsFilterProvider.notifier);
    notifier.setQuery('');
    notifier.setCategory(_savedCategoryId);
    notifier.setFavoritesOnly(_savedFavoritesOnly);
    _searchFocus.unfocus();
    setState(() {
      _searchExpanded = false;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(
        _savedOffset.clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        ),
      );
    }
  }

  void _onSearchChanged(String value) {
    // Note on debounce and race condition prevention:
    // User input is debounced by 200ms to reduce database queries while typing.
    // recordsListProvider is a Riverpod FutureProvider; whenever recordsFilterProvider
    // emits a new query/filter, Riverpod triggers a new evaluation and exposes
    // only the latest AsyncValue. Any earlier, out-of-order query responses
    // that complete later are automatically dropped by Riverpod.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      ref.read(recordsFilterProvider.notifier).setQuery(value);
    });
    setState(() {});
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    ref.read(recordsFilterProvider.notifier).setQuery('');
    setState(() {});
  }

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

  void _openRecord(RecordDetail r) {
    ref.read(recentOpenedIdsProvider.notifier).recordOpened(r.id);
    context.push('/edit/${r.id}');
  }

  Future<void> _showRecordActionSheet(RecordDetail r) async {
    final quickIds = ref.read(quickAccessIdsProvider).value ?? [];
    final isQuick = quickIds.contains(r.id);
    final l10n = AppLocalizations.of(context);

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.title.isNotEmpty ? r.title : l10n.untitledRecord,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    isQuick ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: isQuick
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(isQuick ? '取消常用' : '设为常用'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    try {
                      final res = await ref
                          .read(quickAccessIdsProvider.notifier)
                          .toggle(r.id);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(res ? '已设为常用' : '已取消常用'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    } catch (_) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('常用最多只能添加 6 个'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(l10n.editInfo),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _openRecord(r);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.checklist_rounded),
                  title: const Text('多选操作'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    setState(() {
                      _isMultiSelect = true;
                      _selectedIds.add(r.id);
                    });
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    l10n.delete,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _deleteRecord(r.id);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteRecord(String id) async {
    await ref.read(recordRepositoryProvider).softDeleteRecord(id);
    ref.invalidate(recordsListProvider);
    ref.invalidate(trashListProvider);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        persist: false,
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
    try {
      await ref
          .read(recordRepositoryProvider)
          .updateRecord(r.id, isFavorite: !r.isFavorite);
      ref.invalidate(recordsListProvider);
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.favoriteFailed)),
      );
    }
  }

  Future<void> _showChangeCategoryDialog(RecordDetail r) async {
    final l10n = AppLocalizations.of(context);
    final categories = ref.read(categoriesProvider).value ?? [];
    final repo = ref.read(recordRepositoryProvider);

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return SimpleDialog(
          title: Text(l10n.changeCategory),
          children: [
            SimpleDialogOption(
              onPressed: () async {
                await repo.updateRecord(r.id, clearCategoryId: true);
                ref.invalidate(recordsListProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(l10n.uncategorized),
              ),
            ),
            for (final c in categories)
              SimpleDialogOption(
                onPressed: () async {
                  await repo.updateRecord(r.id, categoryId: c.id);
                  ref.invalidate(recordsListProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppTheme.getCategoryColor(c.name, c.color),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(categoryDisplayName(ctx, c.name)),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showSortSheet() {
    final l10n = AppLocalizations.of(context);
    final currentSortMode =
        ref.read(homeSortModeProvider).value ?? RecordSortMode.byUpdatedAt;

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text(
                    l10n.sortTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                RadioGroup<RecordSortMode>(
                  groupValue: currentSortMode,
                  onChanged: (m) async {
                    if (m != null) {
                      await ref.read(homeSortModeProvider.notifier).setMode(m);
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RadioListTile<RecordSortMode>(
                        title: Text(l10n.sortRecentlyEdited),
                        value: RecordSortMode.byUpdatedAt,
                      ),
                      RadioListTile<RecordSortMode>(
                        title: Text(l10n.sortRecentlyCreated),
                        value: RecordSortMode.byCreatedAt,
                      ),
                      RadioListTile<RecordSortMode>(
                        title: Text(l10n.sortTitleAZ),
                        value: RecordSortMode.byTitle,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final recordsAsync = ref.watch(recordsListProvider);
    final filter = ref.watch(recordsFilterProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final sortMode =
        ref.watch(homeSortModeProvider).value ?? RecordSortMode.byUpdatedAt;

    final sortTitleText = switch (sortMode) {
      RecordSortMode.byUpdatedAt => l10n.sortRecentlyEdited,
      RecordSortMode.byCreatedAt => l10n.sortRecentlyCreated,
      RecordSortMode.byTitle => l10n.sortTitleAZ,
    };

    final mainContent = Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // a) Top Row: Multi-select actions OR Category tabs + Search button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
              child: _isMultiSelect
                  ? Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close),
                          constraints: const BoxConstraints(
                              minWidth: 48, minHeight: 48),
                          tooltip: l10n.cancel,
                          onPressed: _exitMultiSelect,
                        ),
                        Text(
                          l10n.selectedCount(_selectedIds.length),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          constraints: const BoxConstraints(
                              minWidth: 48, minHeight: 48),
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
                  : Row(
                      children: [
                        Expanded(
                          child: categoriesAsync.maybeWhen(
                            data: (categories) => _CategoryFilterBar(
                              filter: filter,
                              categories: categories,
                              onAll: () {
                                final notifier =
                                    ref.read(recordsFilterProvider.notifier);
                                notifier.setCategory(null);
                                notifier.setFavoritesOnly(false);
                              },
                              onFavorites: () {
                                final notifier =
                                    ref.read(recordsFilterProvider.notifier);
                                notifier.setFavoritesOnly(true);
                                notifier.setCategory(null);
                              },
                              onCategory: (id) {
                                final notifier =
                                    ref.read(recordsFilterProvider.notifier);
                                notifier.setCategory(id);
                                notifier.setFavoritesOnly(false);
                              },
                            ),
                            orElse: () => const SizedBox(height: 38),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.search_rounded, size: 22),
                          constraints: const BoxConstraints(
                              minWidth: 48, minHeight: 48),
                          tooltip: l10n.search,
                          onPressed: () => _openSearch(requestFocus: true),
                        ),
                      ],
                    ),
            ),

            // b) Expanded search row (when search is expanded and not multi-selecting)
            if (_searchExpanded && !_isMultiSelect) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocus,
                        onChanged: _onSearchChanged,
                        onSubmitted: (value) {
                          if (value.trim().isNotEmpty) {
                            ref
                                .read(recentSearchProvider.notifier)
                                .addQuery(value);
                          }
                        },
                        decoration: InputDecoration(
                          hintText: '搜索，也可以输入拼音首字母',
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  constraints: const BoxConstraints(
                                      minWidth: 48, minHeight: 48),
                                  onPressed: _clearSearch,
                                )
                              : null,
                          filled: true,
                          fillColor: colorScheme.surfaceContainerLowest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: colorScheme.outlineVariant,
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: colorScheme.outlineVariant,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: colorScheme.primary,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _cancelSearch,
                      child: Text(l10n.cancel),
                    ),
                  ],
                ),
              ),
              ref.watch(recentSearchProvider).maybeWhen(
                    data: (searches) {
                      if (searches.isEmpty) return const SizedBox.shrink();
                      return RecentSearchChips(
                        queries: searches,
                        onSelectQuery: (q) {
                          _searchController.text = q;
                          ref.read(recordsFilterProvider.notifier).setQuery(q);
                          ref.read(recentSearchProvider.notifier).addQuery(q);
                        },
                        onClear: () =>
                            ref.read(recentSearchProvider.notifier).clear(),
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),
            ],

            // d & e) Record count + sort switcher & record list
            Expanded(
              child: recordsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(e.toString())),
                data: (records) {
                  final isSearchOrFilterActive =
                      filter.query.trim().isNotEmpty ||
                          filter.categoryId != null ||
                          filter.favoritesOnly;

                  if (records.isEmpty) {
                    return _EmptyState(
                      filter: filter,
                      onClearFilter: () => ref
                          .read(recordsFilterProvider.notifier)
                          .clearFilter(),
                    );
                  }

                  final quickIds =
                      ref.watch(quickAccessIdsProvider).value ?? const [];
                  final recentOpenedIds =
                      ref.watch(recentOpenedIdsProvider).value ?? const [];

                  final recordMap = {for (final r in records) r.id: r};
                  final quickRecords = quickIds
                      .map((id) => recordMap[id])
                      .whereType<RecordDetail>()
                      .toList();
                  final recentRecords = recentOpenedIds
                      .map((id) => recordMap[id])
                      .whereType<RecordDetail>()
                      .take(5)
                      .toList();

                  final showQuickAndRecent =
                      !isSearchOrFilterActive && !_isMultiSelect;

                  return NotificationListener<OverscrollNotification>(
                    onNotification: (notification) {
                      if (notification.overscroll < 0 &&
                          _scrollController.hasClients &&
                          _scrollController.offset <= 0 &&
                          !_searchExpanded) {
                        if (mounted) {
                          _openSearch(requestFocus: false);
                        }
                      }
                      return false;
                    },
                    child: SlidableAutoCloseBehavior(
                      child: ListView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
                        children: [
                          if (showQuickAndRecent) ...[
                            QuickAccessGrid(
                              records: quickRecords,
                              onRecordAction: (r) => executeQuickAction(
                                context: context,
                                record: r,
                                onOpenRecord: _openRecord,
                              ),
                              onLongPress: (r) => _showRecordActionSheet(r),
                            ),
                            RecentOpenedBar(
                              records: recentRecords,
                              onTap: (r) => executeQuickAction(
                                context: context,
                                record: r,
                                onOpenRecord: _openRecord,
                              ),
                            ),
                          ],
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                            child: Row(
                              children: [
                                Text(
                                  l10n.infoCount(records.length),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const Spacer(),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: _showSortSheet,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 10,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            sortTitleText,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: colorScheme.onSurface,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const Icon(
                                            Icons.arrow_drop_down,
                                            size: 18,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: [
                                for (final r in records)
                                  RecordCard(
                                    record: r,
                                    sortMode: sortMode,
                                    isSelected: _selectedIds.contains(r.id),
                                    isMultiSelectMode: _isMultiSelect,
                                    untitledLabel: l10n.untitledRecord,
                                    uncategorizedLabel: l10n.uncategorized,
                                    onTap: () {
                                      if (_isMultiSelect) {
                                        _toggleMultiSelect(r.id);
                                      } else {
                                        _openRecord(r);
                                      }
                                    },
                                    onLongPress: () {
                                      if (!_isMultiSelect) {
                                        _showRecordActionSheet(r);
                                      }
                                    },
                                    onFavoriteToggle: () => _toggleFavorite(r),
                                    onPinToggle: () => _toggleFavorite(r),
                                    onEdit: () => _openRecord(r),
                                    onChangeCategory: () =>
                                        _showChangeCategoryDialog(r),
                                    onDelete: () => _deleteRecord(r.id),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: !_isMultiSelect
          ? Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLowest,
                border: Border(
                  top: BorderSide(
                    color: colorScheme.outlineVariant,
                    width: 1,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: _toggleSettings,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.settings_outlined,
                                  size: 20,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  l10n.settings,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(child: _SyncStatus()),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: l10n.newRecord,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.add, size: 22),
                          label: Text(l10n.newInfo),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 52),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () async {
                            final templateId =
                                await showTemplateSheet(context);
                            if (templateId == null || !context.mounted) {
                              return;
                            }
                            if (templateId == 'blank') {
                              context.push('/edit');
                            } else {
                              context.push('/edit?template=$templateId');
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : null,
    );

    return PopScope(
      canPop: !_settingsOpen,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_settingsOpen) {
          _closeSettings();
        }
      },
      child: Material(
        color: colorScheme.surface,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedContainer(
                  duration: _sidebarAnimationDuration,
                  curve: _sidebarAnimationCurve,
                  width: _settingsOpen ? _sidebarWidth : 0.0,
                  onEnd: () {
                    if (!_settingsOpen && mounted) {
                      setState(() {
                        _settingsMounted = false;
                      });
                    }
                  },
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    border: _settingsOpen
                        ? Border(
                            right: BorderSide(
                              color: colorScheme.outlineVariant,
                              width: 1,
                            ),
                          )
                        : null,
                  ),
                  child: OverflowBox(
                    minWidth: _sidebarWidth,
                    maxWidth: _sidebarWidth,
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: _sidebarWidth,
                      child: _settingsMounted
                          ? Material(
                              color: colorScheme.surface,
                              child: SafeArea(
                                child: SettingsView(
                                  header: Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(4, 8, 4, 12),
                                    child: Row(
                                      children: [
                                        Text(
                                          l10n.settings,
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const Spacer(),
                                        IconButton(
                                          icon: const Icon(Icons.arrow_back),
                                          tooltip: l10n.cancel,
                                          onPressed: _closeSettings,
                                        ),
                                      ],
                                    ),
                                  ),
                                  onNavigate: _closeSettings,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
                Expanded(
                  child: AnimatedContainer(
                    duration: _sidebarAnimationDuration,
                    curve: _sidebarAnimationCurve,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _settingsOpen ? _closeSettings : null,
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.topLeft,
                          minWidth: 0,
                          maxWidth: constraints.maxWidth,
                          child: SizedBox(
                            width: constraints.maxWidth,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                IgnorePointer(
                                  ignoring: _settingsOpen,
                                  child: mainContent,
                                ),
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: AnimatedOpacity(
                                      opacity: _settingsOpen ? 1.0 : 0.0,
                                      duration: _sidebarAnimationDuration,
                                      curve: _sidebarAnimationCurve,
                                      child: const ColoredBox(
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Lightweight text category tabs: All, Favorites, followed by user categories.
class _CategoryFilterBar extends StatelessWidget {
  const _CategoryFilterBar({
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

    Widget tabItem({
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? colorScheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          tabItem(
            label: l10n.all,
            selected: allSelected,
            onTap: onAll,
          ),
          tabItem(
            label: l10n.favorites,
            selected: filter.favoritesOnly,
            onTap: onFavorites,
          ),
          for (final c in categories)
            tabItem(
              label: categoryDisplayName(context, c.name),
              selected: !filter.favoritesOnly && filter.categoryId == c.id,
              onTap: () => onCategory(c.id),
            ),
        ],
      ),
    );
  }
}

/// Sync status widget shown in the bottom bar.
class _SyncStatus extends ConsumerWidget {
  const _SyncStatus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final syncOverviewAsync = ref.watch(syncOverviewProvider);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.push('/settings/webdav'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: syncOverviewAsync.when(
            loading: () => const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ),
            error: (_, __) => Text(
              l10n.syncStatusUnavailable,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            data: (o) {
              final Widget icon;
              final String text;
              final Color textColor;

              if (o.syncing) {
                icon = Icon(
                  Icons.cloud_sync_outlined,
                  size: 20,
                  color: colorScheme.primary,
                );
                text = l10n.syncStatusSyncing;
                textColor = colorScheme.primary;
              } else if (o.lastSuccessAt != null) {
                icon = Icon(
                  Icons.cloud_done_outlined,
                  size: 20,
                  color: colorScheme.primary,
                );
                final hm =
                    DateFormat.Hm(locale).format(o.lastSuccessAt!.toLocal());
                text = '${l10n.synced} · $hm';
                textColor = colorScheme.onSurfaceVariant;
              } else if (o.enabled) {
                icon = Icon(
                  Icons.cloud_off_outlined,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                );
                text = l10n.syncNever;
                textColor = colorScheme.onSurfaceVariant;
              } else {
                icon = Icon(
                  Icons.cloud_off_outlined,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                );
                text = l10n.syncStatusDisabled;
                textColor = colorScheme.onSurfaceVariant;
              }

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon,
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: 13,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
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
    final hasFilter = filter.categoryId != null || filter.favoritesOnly;

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
