// lib/features/records/data/quick_access_storage.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keys used in SharedPreferences for quick-access redesign.
class QuickAccessKeys {
  QuickAccessKeys._();

  static const String quickAccessRecordIds = 'quick_access_record_ids';
  static const String recentOpenedRecordIds = 'recent_opened_record_ids';
  static const String recentSearchQueries = 'recent_search_queries';
}

/// Service managing local persistence for quick-access items, recent opened records,
/// and recent search queries via SharedPreferences.
class QuickAccessService {
  QuickAccessService(this._prefs);

  final SharedPreferences _prefs;

  // ─── 常用记录 (最多 6 个) ──────────────────────────────────────────────────

  static const int maxQuickAccessCount = 6;

  List<String> getQuickAccessIds() {
    return _prefs.getStringList(QuickAccessKeys.quickAccessRecordIds) ?? <String>[];
  }

  Future<bool> setQuickAccessIds(List<String> ids) async {
    final clamped = ids.take(maxQuickAccessCount).toList();
    return _prefs.setStringList(QuickAccessKeys.quickAccessRecordIds, clamped);
  }

  /// Adds [id] to quick access list. Returns true if added, false if already present
  /// or if limit reached.
  Future<bool> addToQuickAccess(String id) async {
    final current = getQuickAccessIds();
    if (current.contains(id)) return true;
    if (current.length >= maxQuickAccessCount) return false;
    current.add(id);
    await setQuickAccessIds(current);
    return true;
  }

  Future<void> removeFromQuickAccess(String id) async {
    final current = getQuickAccessIds();
    current.remove(id);
    await setQuickAccessIds(current);
  }

  Future<void> removeEverywhere(String id) async {
    await removeFromQuickAccess(id);
    final recent = getRecentOpenedIds()..remove(id);
    await _prefs.setStringList(QuickAccessKeys.recentOpenedRecordIds, recent);
  }

  Future<void> clearAll() async {
    await _prefs.remove(QuickAccessKeys.quickAccessRecordIds);
    await _prefs.remove(QuickAccessKeys.recentOpenedRecordIds);
    await _prefs.remove(QuickAccessKeys.recentSearchQueries);
  }

  Future<bool> toggleQuickAccess(String id) async {
    final current = getQuickAccessIds();
    if (current.contains(id)) {
      await removeFromQuickAccess(id);
      return false; // Now not quick access
    } else {
      if (current.length >= maxQuickAccessCount) {
        throw StateError('MAX_QUICK_ACCESS_REACHED');
      }
      current.add(id);
      await setQuickAccessIds(current);
      return true; // Now quick access
    }
  }

  bool isQuickAccess(String id) {
    return getQuickAccessIds().contains(id);
  }

  // ─── 最近打开记录 (最多 10 个保存，前 5 个展示) ──────────────────────────

  static const int maxRecentOpenedCount = 10;
  static const int displayRecentOpenedCount = 5;

  List<String> getRecentOpenedIds() {
    return _prefs.getStringList(QuickAccessKeys.recentOpenedRecordIds) ?? <String>[];
  }

  Future<void> recordOpened(String id) async {
    if (id.isEmpty) return;
    final current = getRecentOpenedIds();
    current.remove(id);
    current.insert(0, id);
    final clamped = current.take(maxRecentOpenedCount).toList();
    await _prefs.setStringList(QuickAccessKeys.recentOpenedRecordIds, clamped);
  }

  // ─── 最近搜索词 (最多 8 个) ──────────────────────────────────────────────

  static const int maxRecentSearchCount = 8;

  List<String> getRecentSearches() {
    return _prefs.getStringList(QuickAccessKeys.recentSearchQueries) ?? <String>[];
  }

  Future<void> addSearchQuery(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    final current = getRecentSearches();
    // Case-insensitive deduplication, keeping the user's latest query case
    current.removeWhere((q) => q.toLowerCase() == trimmed.toLowerCase());
    current.insert(0, trimmed);
    final clamped = current.take(maxRecentSearchCount).toList();
    await _prefs.setStringList(QuickAccessKeys.recentSearchQueries, clamped);
  }

  Future<void> clearRecentSearches() async {
    await _prefs.remove(QuickAccessKeys.recentSearchQueries);
  }
}

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});

class QuickAccessIdsNotifier extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    return QuickAccessService(prefs).getQuickAccessIds();
  }

  Future<bool> toggle(String id) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    final service = QuickAccessService(prefs);
    final res = await service.toggleQuickAccess(id);
    state = AsyncData(service.getQuickAccessIds());
    return res;
  }

  Future<bool> add(String id) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    final service = QuickAccessService(prefs);
    final res = await service.addToQuickAccess(id);
    state = AsyncData(service.getQuickAccessIds());
    return res;
  }

  Future<void> remove(String id) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    final service = QuickAccessService(prefs);
    await service.removeFromQuickAccess(id);
    state = AsyncData(service.getQuickAccessIds());
  }

  Future<void> removeEverywhere(String id) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    final service = QuickAccessService(prefs);
    await service.removeEverywhere(id);
    state = AsyncData(service.getQuickAccessIds());
    ref.invalidate(recentOpenedIdsProvider);
  }

  Future<void> clearAll() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    final service = QuickAccessService(prefs);
    await service.clearAll();
    state = const AsyncData([]);
    ref.invalidate(recentOpenedIdsProvider);
    ref.invalidate(recentSearchProvider);
  }
}

final quickAccessIdsProvider =
    AsyncNotifierProvider<QuickAccessIdsNotifier, List<String>>(
  QuickAccessIdsNotifier.new,
);

class RecentOpenedIdsNotifier extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    return QuickAccessService(prefs).getRecentOpenedIds();
  }

  Future<void> recordOpened(String id) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    final service = QuickAccessService(prefs);
    await service.recordOpened(id);
    state = AsyncData(service.getRecentOpenedIds());
  }
}

final recentOpenedIdsProvider =
    AsyncNotifierProvider<RecentOpenedIdsNotifier, List<String>>(
  RecentOpenedIdsNotifier.new,
);

class RecentSearchNotifier extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    return QuickAccessService(prefs).getRecentSearches();
  }

  Future<void> addQuery(String query) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    final service = QuickAccessService(prefs);
    await service.addSearchQuery(query);
    state = AsyncData(service.getRecentSearches());
  }

  Future<void> clear() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    final service = QuickAccessService(prefs);
    await service.clearRecentSearches();
    state = const AsyncData([]);
  }
}

final recentSearchProvider =
    AsyncNotifierProvider<RecentSearchNotifier, List<String>>(
  RecentSearchNotifier.new,
);
