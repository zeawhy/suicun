// lib/features/records/presentation/home_sort_provider.dart

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'home_sort_provider.g.dart';

enum RecordSortMode {
  byUpdatedAt('recentlyEdited'),
  byCreatedAt('recentlyCreated'),
  byTitle('titleAZ');

  const RecordSortMode(this.storageKey);

  final String storageKey;

  static const String prefsKey = 'home_sort_mode';

  static RecordSortMode fromStorage(String? value) {
    if (value == null) return RecordSortMode.byUpdatedAt;
    for (final mode in RecordSortMode.values) {
      if (mode.storageKey == value) return mode;
    }
    return RecordSortMode.byUpdatedAt;
  }
}

@riverpod
class HomeSortMode extends _$HomeSortMode {
  @override
  Future<RecordSortMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(RecordSortMode.prefsKey);
    return RecordSortMode.fromStorage(raw);
  }

  Future<void> setMode(RecordSortMode m) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(RecordSortMode.prefsKey, m.storageKey);
    state = AsyncData(m);
  }
}
