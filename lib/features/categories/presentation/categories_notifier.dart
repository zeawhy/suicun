import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:suicun/core/database/providers.dart';
import 'package:suicun/features/categories/domain/category_model.dart';

part 'categories_notifier.g.dart';

@riverpod
class CategoriesNotifier extends _$CategoriesNotifier {
  @override
  FutureOr<List<CategoryModel>> build() async {
    return ref.watch(categoryRepositoryProvider).getAllCategories();
  }

  Future<void> addCategory(String name, String color) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(categoryRepositoryProvider).createCategory(name, color);
      return ref.read(categoryRepositoryProvider).getAllCategories();
    });
  }

  Future<void> editCategory(String id, String name, String color) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(categoryRepositoryProvider).updateCategory(id, name: name, color: color);
      return ref.read(categoryRepositoryProvider).getAllCategories();
    });
  }

  Future<void> deleteCategory(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(categoryRepositoryProvider).deleteCategory(id);
      return ref.read(categoryRepositoryProvider).getAllCategories();
    });
  }
}
