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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suicun/core/database/providers.dart';
import 'package:suicun/features/categories/domain/category_model.dart';
import 'package:suicun/features/categories/presentation/categories_notifier.dart';
import 'package:suicun/features/records/domain/record_model.dart';
import 'package:suicun/features/records/presentation/home_sort_provider.dart';
import 'package:suicun/features/records/presentation/records_notifier.dart';
import 'package:suicun/features/categories/presentation/category_display_name.dart';
import 'package:suicun/features/records/data/quick_access_storage.dart';
import 'package:suicun/features/records/presentation/quick_access_panel.dart';
import 'package:suicun/features/settings/data/privacy_prefs.dart';
import 'package:suicun/features/settings/presentation/settings_page.dart';
import 'package:suicun/features/sync/sync_contract.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:suicun/features/records/presentation/clipboard_sniffer.dart';
import 'package:suicun/shared/theme/app_theme.dart';
import 'package:suicun/shared/widgets/record_card.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

/// Returns the localized action label for a sniffed clipboard type.
/// (UI layer resolves via l10n; clipboard_sniffer.dart stays pure.)
String _sniffActionLabel(SniffedType type, AppLocalizations l10n) {
  switch (type) {
    case SniffedType.idDocument:
      return l10n.sniffSaveId;
    case SniffedType.address:
      return l10n.sniffSaveAddress;
    case SniffedType.link:
      return l10n.sniffSaveAccount;
  }
}

/// Returns the localized label for a speed-dial template item by id.
String _speedDialLabel(String id, AppLocalizations l10n) {
  switch (id) {
    case 'blank':
      return l10n.speedDialBlank;
    case 'id_document':
      return l10n.speedDialId;
    case 'password':
      return l10n.speedDialPassword;
    case 'address':
      return l10n.speedDialAddress;
    default:
      return id;
  }
}

class _HomePageState extends ConsumerState<HomePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  late final AnimationController _speedDialController;
  Timer? _debounce;
  Timer? _clipboardTimer;
  SniffedClipboardData? _sniffedClipboardData;
  String? _lastHandledHash;
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

  bool get _isSpeedDialOpen =>
      _speedDialController.status == AnimationStatus.forward ||
      _speedDialController.status == AnimationStatus.completed;

  void _toggleSpeedDial() {
    if (_isSpeedDialOpen) {
      _closeSpeedDial();
    } else {
      _checkClipboardOnSpeedDial();
      _speedDialController.forward();
    }
    setState(() {});
  }

  void _closeSpeedDial() {
    if (_speedDialController.value > 0) {
      _speedDialController.reverse();
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _speedDialController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _loadLastHandledClipboardHash();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOnboardingClipboard();
    });
  }

  Future<void> _checkOnboardingClipboard() async {
    if (!mounted) return;
    try {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      final asked =
          prefs.getBool(PrivacyPrefsKeys.onboardingClipboardAsked) ?? false;
      if (!asked && mounted) {
        _showOnboardingClipboardSheet();
      }
    } catch (_) {}
  }

  Future<void> _showOnboardingClipboardSheet() async {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.content_paste_search_rounded,
                  size: 48,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.onboardingClipboardTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.onboardingClipboardBody,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          final prefs =
                              await ref.read(sharedPreferencesProvider.future);
                          await prefs.setBool(
                            PrivacyPrefsKeys.onboardingClipboardAsked,
                            true,
                          );
                        },
                        child: Text(l10n.onboardingClipboardNotNow),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          final prefs =
                              await ref.read(sharedPreferencesProvider.future);
                          await prefs.setBool(
                            PrivacyPrefsKeys.onboardingClipboardAsked,
                            true,
                          );
                          await ref
                              .read(clipboardSniffEnabledProvider.notifier)
                              .setEnabled(true);
                        },
                        child: Text(l10n.onboardingClipboardEnable),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.onboardingClipboardFooter,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      await prefs.setBool(PrivacyPrefsKeys.onboardingClipboardAsked, true);
    } catch (_) {}
  }

  Future<void> _loadLastHandledClipboardHash() async {
    try {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      _lastHandledHash = prefs.getString('clipboard_last_handled_hash');
    } catch (_) {}
  }

  Future<void> _markClipboardHandled(String text) async {
    final hash = text.hashCode.toString();
    _lastHandledHash = hash;
    try {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      await prefs.setString('clipboard_last_handled_hash', hash);
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {}

  Future<void> _checkClipboardOnSpeedDial() async {
    try {
      final enabled = await ref.read(clipboardSniffEnabledProvider.future);
      if (!enabled) {
        if (mounted && _sniffedClipboardData != null) {
          setState(() {
            _sniffedClipboardData = null;
          });
        }
        return;
      }
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isEmpty || text.hashCode.toString() == _lastHandledHash) {
        if (mounted && _sniffedClipboardData != null) {
          setState(() {
            _sniffedClipboardData = null;
          });
        }
        return;
      }
      final isEnglish =
          Localizations.localeOf(context).languageCode != 'zh';
      final sniffed = sniffClipboardText(text, isEnglish: isEnglish);
      if (mounted) {
        setState(() {
          _sniffedClipboardData = sniffed;
        });
      }
    } catch (_) {
      // Ignore clipboard access errors
    }
  }

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
    WidgetsBinding.instance.removeObserver(this);
    _clipboardTimer?.cancel();
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _scrollController.dispose();
    _speedDialController.dispose();
    super.dispose();
  }

  void _openSearch({required bool requestFocus}) {
    if (!mounted || _searchExpanded) return;
    final currentFilter = ref.read(recordsFilterProvider);
    _savedCategoryId = currentFilter.categoryId;
    _savedFavoritesOnly = currentFilter.favoritesOnly;
    _savedOffset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;
    final notifier = ref.read(recordsFilterProvider.notifier);
    notifier.setCategory(null);
    notifier.setFavoritesOnly(false);
    HapticFeedback.selectionClick();
    setState(() {
      _searchExpanded = true;
    });
    if (requestFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _searchFocus.requestFocus();
        }
      });
    }
  }

  void _onSearchBlankTap() {
    if (!_searchExpanded) return;
    if (_searchController.text.trim().isEmpty) {
      _cancelSearch(); // 没输入内容：直接退出搜索
    } else {
      _searchFocus.unfocus(); // 有内容：只收起键盘，保留结果
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

  Future<void> _toggleQuickAccess(RecordDetail r) async {
    final l10n = AppLocalizations.of(context);
    try {
      final res = await ref
          .read(quickAccessIdsProvider.notifier)
          .toggle(r.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res ? l10n.quickAccessAdded : l10n.quickAccessRemoved),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.quickAccessLimitReached),
          duration: const Duration(seconds: 2),
        ),
      );
    }
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
                    isQuick ? Icons.push_pin : Icons.push_pin_outlined,
                    color: isQuick
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(isQuick ? l10n.unsetQuickAccess : l10n.setQuickAccess),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _toggleQuickAccess(r);
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
                  title: Text(l10n.multiSelectActions),
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
    await ref.read(quickAccessIdsProvider.notifier).removeEverywhere(id);
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
                          color: Theme.of(ctx)
                              .suiColors
                              .colorForCategory(c.name, c.color),
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

    final isSearchOrFilterActive = filter.query.trim().isNotEmpty ||
        filter.categoryId != null ||
        filter.favoritesOnly;

    final records = recordsAsync.value ?? const [];

    final quickIds = ref.watch(quickAccessIdsProvider).value ?? const [];
    final recentOpenedIds =
        ref.watch(recentOpenedIdsProvider).value ?? const [];
    final swipeHintSeen =
        ref.watch(swipeHintSeenProvider).value ?? false;

    final recordMap = {for (final r in records) r.id: r};
    final quickRecords = quickIds
        .map((id) => recordMap[id])
        .whereType<RecordDetail>()
        .toList();
    final quickIdSet = quickRecords.map((r) => r.id).toSet();
    final recentRecords = recentOpenedIds
        .where((id) => !quickIdSet.contains(id))   // 已在常用里的不再重复显示
        .map((id) => recordMap[id])
        .whereType<RecordDetail>()
        .take(5)
        .toList();
    final showRecentBar = recentRecords.isNotEmpty && records.length > 3;

    if (!isSearchOrFilterActive && recordsAsync.hasValue) {
      final staleIds = quickIds.where((id) => !recordMap.containsKey(id)).toList();
      if (staleIds.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          for (final id in staleIds) {
            ref.read(quickAccessIdsProvider.notifier).removeEverywhere(id);
          }
        });
      }
    }

    final showQuickAndRecent =
        !_searchExpanded && !isSearchOrFilterActive && !_isMultiSelect;
    final showQuickAdd = !isSearchOrFilterActive &&
        !_searchExpanded &&
        !_isMultiSelect &&
        records.length < 3;

    final scaffoldContent = Scaffold(
      floatingActionButton: (_isMultiSelect || _searchExpanded)
          ? null
          : _buildSpeedDialFab(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _onSearchBlankTap,
          child: SlidableAutoCloseBehavior(
            child: NotificationListener<OverscrollNotification>(
              onNotification: (notification) {
                if (notification.overscroll < 0 &&
                    _scrollController.hasClients &&
                    _scrollController.offset <= 0 &&
                    !_searchExpanded) {
                  if (mounted) {
                    _openSearch(requestFocus: true);
                  }
                }
                return false;
              },
              child: CustomScrollView(
                controller: _scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _buildSliverAppBar(l10n, colorScheme),
                  // §2.7: one-time backup reminder banner.
                  const SliverToBoxAdapter(
                    child: _BackupReminderBanner(),
                  ),
                  if (showQuickAndRecent)
                    SliverToBoxAdapter(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          QuickAccessGrid(
                            records: quickRecords,
                            onRecordAction: (r) => executeQuickAction(
                              context: context,
                              record: r,
                              onOpenRecord: _openRecord,
                            ),
                            onLongPress: (r) => _showRecordActionSheet(r),
                          ),
                          if (showRecentBar)
                            RecentOpenedBar(
                              records: recentRecords,
                              onTap: (r) => executeQuickAction(
                                context: context,
                                record: r,
                                onOpenRecord: _openRecord,
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (!_isMultiSelect && !_searchExpanded)
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _CategoryFilterHeaderDelegate(
                        height: 46,
                        backgroundColor: colorScheme.surface,
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
                          orElse: () => const SizedBox(height: 46),
                        ),
                      ),
                    ),
                  if (_searchExpanded && filter.query.trim().isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _onSearchBlankTap,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search,
                                size: 32,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.searchPromptEmpty,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                else if (recordsAsync.isLoading && !recordsAsync.hasValue)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (recordsAsync.hasError && !recordsAsync.hasValue)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(recordsAsync.error.toString()),
                    ),
                  )
                else if (records.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(
                      filter: filter,
                      onClearFilter: () => ref
                          .read(recordsFilterProvider.notifier)
                          .clearFilter(),
                    ),
                  )
                else ...[
                  SliverToBoxAdapter(
                    child: Padding(
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
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, showQuickAdd ? 16 : 80),
                    sliver: SliverList.separated(
                      itemCount: records.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final r = records[index];
                        return RecordCard(
                          record: r,
                          searchQuery: filter.query.trim(),
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
                          isQuickAccess: quickIds.contains(r.id),
                          showQuickAccessMark:
                              !showQuickAndRecent && quickIds.contains(r.id),
                          onQuickAccessToggle: () => _toggleQuickAccess(r),
                          onAnySlideAction: () {
                            ref.read(swipeHintSeenProvider.notifier).markSeen();
                          },
                          showSwipeHint:
                              index == 0 && !swipeHintSeen && !_isMultiSelect,
                          onEdit: () => _openRecord(r),
                          onChangeCategory: () =>
                              _showChangeCategoryDialog(r),
                          onDelete: () => _deleteRecord(r.id),
                        );
                      },
                    ),
                  ),
                  if (showQuickAdd)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.quickAdd,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 12),
                            GridView.count(
                              crossAxisCount: 4,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              childAspectRatio: 0.9,
                              padding: EdgeInsets.zero,
                              children: [
                                for (final item in _getSpeedDialItems(
                                  context,
                                  theme.brightness == Brightness.dark,
                                ))
                                  InkWell(
                                    key: Key('quick_add_item_${item.id}'),
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => context.push(item.route),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: item.accentColor.withValues(
                                              alpha: theme.brightness ==
                                                      Brightness.dark
                                                  ? 0.2
                                                  : 0.12,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            item.icon,
                                            size: 20,
                                            color: item.accentColor,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _speedDialLabel(item.id, l10n),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: colorScheme.onSurface,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );

    final mainContent = Stack(
      children: [
        scaffoldContent,
        if (!_isMultiSelect) _buildSpeedDialOverlay(context),
      ],
    );

    return PopScope(
      canPop: !_settingsOpen &&
          !_isSpeedDialOpen &&
          !_searchExpanded &&
          !_isMultiSelect,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_isSpeedDialOpen) {
          _closeSpeedDial();
          return;
        }
        if (_settingsOpen) {
          _closeSettings();
          return;
        }
        if (_searchExpanded) {
          _cancelSearch();
          return;
        }
        if (_isMultiSelect) {
          _exitMultiSelect();
          return;
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

  Widget _buildSpeedDialFab(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FloatingActionButton(
      key: const Key('home_speed_dial_fab'),
      heroTag: 'speedDialMainFab',
      elevation: 2,
      shape: const CircleBorder(),
      tooltip: l10n.newRecord,
      onPressed: _toggleSpeedDial,
      child: AnimatedRotation(
        turns: _isSpeedDialOpen ? 0.125 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: const Icon(Icons.add, size: 24),
      ),
    );
  }

  Widget _buildSpeedDialOverlay(BuildContext context) {
    return AnimatedBuilder(
      animation: _speedDialController,
      builder: (context, child) {
        if (_speedDialController.value == 0) {
          return const SizedBox.shrink();
        }
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final items = _getSpeedDialItems(context, isDark);
        final bottomPadding = MediaQuery.paddingOf(context).bottom + 16;

        return Positioned.fill(
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _closeSpeedDial,
                  child: Container(
                    color: Colors.black.withValues(
                      alpha: 0.3 * _speedDialController.value,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 16,
                bottom: bottomPadding + 56 + 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (_sniffedClipboardData != null) ...[
                      _buildSniffedSpeedDialItem(
                        context,
                        data: _sniffedClipboardData!,
                        isDark: isDark,
                        colorScheme: theme.colorScheme,
                      ),
                      const SizedBox(height: 12),
                    ],
                    for (int i = 0; i < items.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      _buildSpeedDialItem(
                        context,
                        item: items[i],
                        index: i,
                        total: items.length,
                        isDark: isDark,
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                right: 16,
                bottom: bottomPadding,
                child: FloatingActionButton(
                  key: const Key('speedDialOverlayFab'),
                  heroTag: 'speedDialOverlayFab',
                  elevation: 2,
                  shape: const CircleBorder(),
                  tooltip: AppLocalizations.of(context).newRecord,
                  onPressed: _closeSpeedDial,
                  child: AnimatedRotation(
                    turns: _isSpeedDialOpen ? 0.125 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.add, size: 24),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<_SpeedDialItemData> _getSpeedDialItems(
      BuildContext context, bool isDark) {
    return [
      _SpeedDialItemData(
        id: 'blank',
        icon: Icons.edit_note_outlined,
        accentColor: isDark ? const Color(0xFFE6C875) : const Color(0xFF785700),
        route: '/edit?template=blank&autofocus=true',
      ),
      _SpeedDialItemData(
        id: 'id_document',
        icon: Icons.badge_outlined,
        accentColor: isDark ? const Color(0xFF90B8DE) : const Color(0xFF334155),
        route: '/edit?template=id_document&autofocus=true',
      ),
      _SpeedDialItemData(
        id: 'password',
        icon: Icons.lock_outline,
        accentColor: isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20),
        route: '/edit?template=password&autofocus=true',
      ),
      _SpeedDialItemData(
        id: 'address',
        icon: Icons.location_on_outlined,
        accentColor: isDark ? const Color(0xFFFFB74D) : const Color(0xFFC2410C),
        route: '/edit?template=address&autofocus=true',
      ),
    ];
  }

  Widget _buildSpeedDialItem(
    BuildContext context, {
    required _SpeedDialItemData item,
    required int index,
    required int total,
    required bool isDark,
  }) {
    final reverseIndex = total - 1 - index;
    final begin = (reverseIndex * 0.12).clamp(0.0, 0.6);
    final end = (begin + 0.4).clamp(0.0, 1.0);
    final scaleAnim = CurvedAnimation(
      parent: _speedDialController,
      curve: Interval(begin, end, curve: Curves.easeOutBack),
    );
    final fadeAnim = CurvedAnimation(
      parent: _speedDialController,
      curve: Interval(begin, end, curve: Curves.easeIn),
    );

    return ScaleTransition(
      scale: scaleAnim,
      alignment: Alignment.bottomRight,
      child: FadeTransition(
        opacity: fadeAnim,
        child: _TemplateChip(
          item: item,
          isDark: isDark,
          elevation: 3,
          shadowColor: Colors.black26,
          inkWellKey: Key('speed_dial_item_${item.id}'),
          onTap: () {
            _closeSpeedDial();
            context.push(item.route);
          },
        ),
      ),
    );
  }

  Widget _buildSniffedSpeedDialItem(
    BuildContext context, {
    required SniffedClipboardData data,
    required bool isDark,
    required ColorScheme colorScheme,
  }) {
    final l10n = AppLocalizations.of(context);
    final scaleAnim = CurvedAnimation(
      parent: _speedDialController,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack),
    );
    final fadeAnim = CurvedAnimation(
      parent: _speedDialController,
      curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
    );

    return ScaleTransition(
      scale: scaleAnim,
      alignment: Alignment.bottomRight,
      child: FadeTransition(
        opacity: fadeAnim,
        child: Material(
          key: const Key('clipboard_sniff_banner'),
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
          elevation: 3,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: colorScheme.primary.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () {
              final text = data.rawText;
              final templateId = data.templateId;
              final initialBody = data.initialBody;
              _markClipboardHandled(text);
              _closeSpeedDial();
              setState(() {
                _sniffedClipboardData = null;
              });
              context.push(
                '/edit?template=$templateId&autofocus=true',
                extra: initialBody,
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '📋',
                    style: TextStyle(fontSize: 15),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_sniffActionLabel(data.type, l10n)}：${data.previewText}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    key: const Key('clipboard_sniff_ignore_button'),
                    onTap: () {
                      _markClipboardHandled(data.rawText);
                      setState(() {
                        _sniffedClipboardData = null;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
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

  Widget _buildSliverAppBar(AppLocalizations l10n, ColorScheme colorScheme) {
    if (_isMultiSelect) {
      return SliverAppBar(
        floating: true,
        snap: true,
        pinned: false,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close),
              constraints:
                  const BoxConstraints(minWidth: 48, minHeight: 48),
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
              constraints:
                  const BoxConstraints(minWidth: 48, minHeight: 48),
              tooltip: l10n.batchDelete,
              onPressed: () async {
                final repo = ref.read(recordRepositoryProvider);
                final quickNotifier = ref.read(quickAccessIdsProvider.notifier);
                for (final id in _selectedIds) {
                  await repo.softDeleteRecord(id);
                  await quickNotifier.removeEverywhere(id);
                }
                ref.invalidate(recordsListProvider);
                ref.invalidate(trashListProvider);
                _exitMultiSelect();
              },
            ),
          ],
        ),
      );
    }

    if (_searchExpanded) {
      final recentSearches =
          ref.watch(recentSearchProvider).value ?? const [];
      return SliverAppBar(
        floating: true,
        snap: true,
        pinned: false,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        title: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                onChanged: _onSearchChanged,
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    ref.read(recentSearchProvider.notifier).addQuery(value);
                  }
                },
                decoration: InputDecoration(
                  hintText: l10n.searchHint,
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
        bottom: recentSearches.isNotEmpty
            ? PreferredSize(
                preferredSize: const Size.fromHeight(42),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: RecentSearchChips(
                    queries: recentSearches,
                    onSelectQuery: (q) {
                      _searchController.text = q;
                      ref.read(recordsFilterProvider.notifier).setQuery(q);
                      ref.read(recentSearchProvider.notifier).addQuery(q);
                    },
                    onClear: () =>
                        ref.read(recentSearchProvider.notifier).clear(),
                  ),
                ),
              )
            : null,
      );
    }

    return SliverAppBar(
      floating: true,
      snap: true,
      pinned: false,
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded),
        tooltip: l10n.settings,
        onPressed: _toggleSettings,
      ),
      titleSpacing: 4,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.appName,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 8),
          _SyncBadge(),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded, size: 22),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          tooltip: l10n.search,
          onPressed: () => _openSearch(requestFocus: true),
        ),
      ],
    );
  }
}

class _SpeedDialItemData {
  const _SpeedDialItemData({
    required this.id,
    required this.icon,
    required this.accentColor,
    required this.route,
  });

  final String id;
  final IconData icon;
  final Color accentColor;
  final String route;
}

class _TemplateChip extends StatelessWidget {
  const _TemplateChip({
    required this.item,
    required this.isDark,
    required this.onTap,
    this.elevation = 2,
    this.shadowColor,
    this.inkWellKey,
  });

  final _SpeedDialItemData item;
  final bool isDark;
  final VoidCallback onTap;
  final double elevation;
  final Color? shadowColor;
  final Key? inkWellKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: isDark ? const Color(0xFF242C36) : Colors.white,
      elevation: elevation,
      shadowColor: shadowColor ?? Colors.black26,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        key: inkWellKey,
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: item.accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  item.icon,
                  size: 16,
                  color: item.accentColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _speedDialLabel(item.id, l10n),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryFilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  _CategoryFilterHeaderDelegate({
    required this.height,
    required this.backgroundColor,
    required this.child,
  });

  final double height;
  final Color backgroundColor;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      height: height,
      color: backgroundColor,
      alignment: Alignment.centerLeft,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _CategoryFilterHeaderDelegate oldDelegate) {
    return oldDelegate.height != height ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.child != child;
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
      IconData? icon,
      required bool selected,
      required VoidCallback onTap,
    }) {
      final itemColor =
          selected ? colorScheme.primary : colorScheme.onSurfaceVariant;
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: itemColor),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: itemColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Colors.black, Colors.black, Colors.transparent],
              stops: [0.0, 0.92, 1.0],
            ).createShader(rect),
            blendMode: BlendMode.dstIn,
            child: SingleChildScrollView(
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
                    icon: Icons.star_rounded,
                    selected: filter.favoritesOnly,
                    onTap: onFavorites,
                  ),
                  for (final c in categories)
                    tabItem(
                      label: categoryDisplayName(context, c.name),
                      selected:
                          !filter.favoritesOnly && filter.categoryId == c.id,
                      onTap: () => onCategory(c.id),
                    ),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.tune_rounded, size: 20),
          tooltip: l10n.manageCategories,
          onPressed: () => context.push('/settings/categories'),
        ),
      ],
    );
  }
}

/// Tiny cloud badge shown in the top SliverAppBar next to the title.
class _SyncBadge extends ConsumerWidget {
  const _SyncBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final syncOverviewAsync = ref.watch(syncOverviewProvider);

    return syncOverviewAsync.when(
      loading: () => const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 1.5),
      ),
      error: (_, __) => _buildIconBadge(
        context: context,
        icon: Icons.cloud_off_outlined,
        color: Colors.orange,
        tooltip: l10n.syncStatusUnavailable,
        onTap: () => context.push('/settings/webdav'),
      ),
      data: (o) {
        if (o.syncing) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 11,
                  height: 11,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  l10n.syncStatusSyncing,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          );
        }

        if (o.lastSuccessAt != null) {
          const greenColor = Color(0xFF4CAF50);
          return _buildIconBadge(
            context: context,
            icon: Icons.cloud_done_outlined,
            color: greenColor,
            tooltip: l10n.synced,
            onTap: () {
              final formattedTime = DateFormat.yMMMd(locale)
                  .add_Hms()
                  .format(o.lastSuccessAt!.toLocal());
              showModalBottomSheet<void>(
                context: context,
                builder: (sheetContext) {
                  return SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: greenColor.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.cloud_done_outlined,
                                  color: greenColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.webdavSync,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      l10n.lastSyncTime(formattedTime),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: theme
                                            .colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.tonal(
                              onPressed: () {
                                Navigator.pop(sheetContext);
                                context.push('/settings/webdav');
                              },
                              child: Text(l10n.goToWebdavSettings),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        }

        if (o.enabled) {
          return _buildIconBadge(
            context: context,
            icon: Icons.cloud_queue_outlined,
            color: Colors.orange,
            tooltip: l10n.syncNever,
            onTap: () => context.push('/settings/webdav'),
          );
        }

        return _buildIconBadge(
          context: context,
          icon: Icons.cloud_off_outlined,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
          tooltip: l10n.syncStatusDisabled,
          onTap: () => context.push('/settings/webdav'),
        );
      },
    );
  }

  Widget _buildIconBadge({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(icon, size: 16, color: color),
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

/// §2.7: one-time banner reminding the user to enable encrypted backup or sync.
///
/// Shows when (first ID doc saved OR >=3 records) AND (never exported an
/// encrypted backup) AND (WebDAV sync not enabled) AND (not dismissed in
/// the last 30 days).
class _BackupReminderBanner extends ConsumerStatefulWidget {
  const _BackupReminderBanner();

  @override
  ConsumerState<_BackupReminderBanner> createState() =>
      _BackupReminderBannerState();
}

class _BackupReminderBannerState extends ConsumerState<_BackupReminderBanner> {
  bool _dismissed = false;

  Future<bool> _shouldShow(int recordCount, bool syncEnabled) async {
    if (_dismissed) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissedAt = prefs.getInt('backup_reminder_dismissed_at');
      if (dismissedAt != null &&
          DateTime.now().millisecondsSinceEpoch - dismissedAt <
              const Duration(days: 30).inMilliseconds) {
        return false;
      }
      if (prefs.getInt('last_encrypted_backup_at') != null) return false;
      if (syncEnabled) return false;
      final idDocSaved = prefs.getBool('id_doc_saved_once') ?? false;
      return idDocSaved || recordCount >= 3;
    } catch (_) {
      return false;
    }
  }

  Future<void> _dismiss() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('backup_reminder_dismissed_at',
          DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
    if (mounted) setState(() => _dismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final recordsAsync = ref.watch(recordsListProvider);
    final syncOverviewAsync = ref.watch(syncOverviewProvider);
    final recordCount = recordsAsync.value?.length ?? 0;
    final syncEnabled = syncOverviewAsync.value?.enabled ?? false;

    return FutureBuilder<bool>(
      future: _shouldShow(recordCount, syncEnabled),
      builder: (context, snapshot) {
        if (snapshot.data != true) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.backup_outlined,
                  color: colorScheme.onTertiaryContainer, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.backupReminderText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onTertiaryContainer,
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () => context.go('/settings/backup'),
                      child: Text(
                        l10n.setUp,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: _dismiss,
                tooltip: MaterialLocalizations.of(context).closeButtonLabel,
              ),
            ],
          ),
        );
      },
    );
  }
}
