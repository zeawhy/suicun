import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:suicun/core/database/providers.dart';
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final recordsAsync = ref.watch(recordsListProvider);
    final filter = ref.watch(recordsFilterProvider);

    return Scaffold(
      appBar: _isMultiSelect
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitMultiSelect,
              ),
              title: Text(l10n.selectedCount(_selectedIds.length)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    // TODO: handle batch delete
                    _exitMultiSelect();
                  },
                ),
              ],
            )
          : AppBar(
              title: Text(l10n.appName),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => context.push('/settings'),
                ),
              ],
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (v) => ref.read(recordsFilterProvider.notifier).setQuery(v),
              decoration: InputDecoration(
                hintText: l10n.searchHint,
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                FilterChip(
                  label: Text(l10n.all),
                  selected: filter.categoryId == null && !filter.favoritesOnly,
                  onSelected: (_) => ref.read(recordsFilterProvider.notifier).clearFilter(),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(l10n.favorites),
                  selected: filter.favoritesOnly,
                  onSelected: (v) => ref.read(recordsFilterProvider.notifier).setFavoritesOnly(v),
                ),
                // TODO: Load real categories
              ],
            ),
          ),
          Expanded(
            child: recordsAsync.when(
              data: (records) {
                if (records.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(l10n.recordsEmpty, style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text(l10n.recordsEmptyHint),
                      ],
                    ),
                  );
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
                        isSelected: _selectedIds.contains(r.id),
                        isMultiSelectMode: _isMultiSelect,
                        untitledLabel: l10n.untitledRecord,
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
                        onFavoriteToggle: () async {
                          await ref
                              .read(recordRepositoryProvider)
                              .updateRecord(r.id, isFavorite: !r.isFavorite);
                          ref.invalidate(recordsListProvider);
                        },
                      ),
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
              child: const Icon(Icons.add),
            ),
    );
  }
}
