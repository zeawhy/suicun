import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';
import 'package:suicun/features/tags/presentation/tags_notifier.dart';

class TagsPage extends ConsumerWidget {
  const TagsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tagsState = ref.watch(tagsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tags)),
      body: tagsState.when(
        data: (tags) {
          if (tags.isEmpty) {
            return const Center(child: Text('No tags'));
          }
          return ListView.builder(
            itemCount: tags.length,
            itemBuilder: (context, index) {
              final tag = tags[index];
              return ListTile(
                title: Text(tag.name),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    ref.read(tagsProvider.notifier).deleteTag(tag.id);
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
          ref.read(tagsProvider.notifier).addTag('New Tag ${DateTime.now().second}');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
