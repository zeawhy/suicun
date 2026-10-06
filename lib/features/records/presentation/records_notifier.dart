// lib/features/records/presentation/records_notifier.dart
// Riverpod state management for the records list page.

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:suicun/core/database/providers.dart';
import 'package:suicun/features/records/domain/record_model.dart';

import 'package:suicun/features/records/presentation/home_sort_provider.dart';

part 'records_notifier.g.dart';

/// The current search/filter state driving the home list.
class RecordsFilter {
  const RecordsFilter({
    this.query = '',
    this.categoryId,
    this.favoritesOnly = false,
  });

  final String query;
  final String? categoryId;
  final bool favoritesOnly;

  RecordsFilter copyWith({
    String? query,
    String? categoryId,
    bool? favoritesOnly,
    bool clearCategory = false,
  }) {
    return RecordsFilter(
      query: query ?? this.query,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
    );
  }
}

@riverpod
class RecordsFilterNotifier extends _$RecordsFilterNotifier {
  @override
  RecordsFilter build() => const RecordsFilter();

  void setQuery(String q) => state = state.copyWith(query: q);
  void setCategory(String? id) =>
      state = state.copyWith(categoryId: id, clearCategory: id == null);
  void setFavoritesOnly(bool v) => state = state.copyWith(favoritesOnly: v);
  void clearFilter() => state = const RecordsFilter();
}

@riverpod
Future<List<RecordDetail>> recordsList(Ref ref) async {
  final filter = ref.watch(recordsFilterProvider);
  final sortMode =
      ref.watch(homeSortModeProvider).value ?? RecordSortMode.byUpdatedAt;
  final repo = ref.watch(recordRepositoryProvider);
  final records = await repo.searchRecords(
    query: filter.query,
    categoryId: filter.categoryId,
    favoritesOnly: filter.favoritesOnly ? true : null,
    includeDeleted: false,
  );

  String displayTitle(RecordDetail r) {
    if (r.title.isNotEmpty) return r.title;
    for (final line in r.body.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '';
  }

  // In-memory sort based on active sort mode, using id ascending as tie-breaker.
  // Note: For Chinese / non-ASCII titles, string comparison is done by Unicode code point
  // rather than Pinyin collation, keeping comparison uniform and predictable.
  final sorted = List<RecordDetail>.from(records);
  sorted.sort((a, b) {
    final cmp = switch (sortMode) {
      RecordSortMode.byUpdatedAt => b.updatedAt.compareTo(a.updatedAt),
      RecordSortMode.byCreatedAt => b.createdAt.compareTo(a.createdAt),
      RecordSortMode.byTitle =>
        displayTitle(a).toLowerCase().compareTo(displayTitle(b).toLowerCase()),
    };
    if (cmp != 0) return cmp;
    return a.id.compareTo(b.id);
  });

  return sorted;
}

@riverpod
Future<List<RecordDetail>> trashList(Ref ref) async {
  final repo = ref.watch(recordRepositoryProvider);
  return repo.searchRecords(includeDeleted: true);
}
