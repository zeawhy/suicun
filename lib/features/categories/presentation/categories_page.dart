import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';
import 'package:suicun/features/categories/presentation/categories_notifier.dart';

class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final categoriesState = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.categories)),
      body: categoriesState.when(
        data: (categories) {
          if (categories.isEmpty) {
            return const Center(child: Text('No categories'));
          }
          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              return ListTile(
                title: Text(cat.name),
                leading: CircleAvatar(backgroundColor: Color(int.parse(cat.color, radix: 16) | 0xFF000000)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    ref.read(categoriesProvider.notifier).deleteCategory(cat.id);
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Add dummy category for now
          ref.read(categoriesProvider.notifier).addCategory('New Category ${DateTime.now().second}', 'FF0000');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
