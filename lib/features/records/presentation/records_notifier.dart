// lib/features/records/presentation/records_notifier.dart
// Riverpod state management for the records list page.

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:suicun/core/database/providers.dart';
import 'package:suicun/features/records/domain/record_model.dart';

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
  final repo = ref.watch(recordRepositoryProvider);
  return repo.searchRecords(
    query: filter.query,
    categoryId: filter.categoryId,
    favoritesOnly: filter.favoritesOnly ? true : null,
    includeDeleted: false,
  );
}

@riverpod
Future<List<RecordDetail>> trashList(Ref ref) async {
  final repo = ref.watch(recordRepositoryProvider);
  return repo.searchRecords(includeDeleted: true);
}
