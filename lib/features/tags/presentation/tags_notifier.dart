import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:suicun/core/database/providers.dart';
import 'package:suicun/features/tags/domain/tag_model.dart';

part 'tags_notifier.g.dart';

@riverpod
class TagsNotifier extends _$TagsNotifier {
  @override
  FutureOr<List<TagModel>> build() async {
    return ref.watch(tagRepositoryProvider).getAllTags();
  }

  Future<void> addTag(String name) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(tagRepositoryProvider).findOrCreateTag(name);
      return ref.read(tagRepositoryProvider).getAllTags();
    });
  }

  Future<void> renameTag(String id, String newName) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(tagRepositoryProvider).renameTag(id, newName);
      return ref.read(tagRepositoryProvider).getAllTags();
    });
  }

  Future<void> deleteTag(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(tagRepositoryProvider).deleteTag(id);
      return ref.read(tagRepositoryProvider).getAllTags();
    });
  }
}
