// lib/features/categories/data/category_repository.dart

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/core/database/tables.dart';
import 'package:suicun/core/errors/app_errors.dart';
import 'package:suicun/features/categories/domain/category_model.dart';

const _uuid = Uuid();

class CategoryRepository {
  CategoryRepository(this._db);

  final AppDatabase _db;

  static CategoryModel _toModel(Category c) => CategoryModel(
        id: c.id,
        name: c.name,
        color: c.color,
        deletedAt: c.deletedAt?.toUtc(),
      );

  /// All non-deleted categories ordered by name.
  Future<List<CategoryModel>> getAllCategories() async {
    try {
      final rows = await (_db.select(_db.categories)
            ..where((c) => c.deletedAt.isNull())
            ..orderBy([(c) => OrderingTerm(expression: c.name)]))
          .get();
      return rows.map(_toModel).toList();
    } catch (e) {
      throw DatabaseError('Failed to load categories', e);
    }
  }

  /// Creates a new category. Throws [ValidationError] if name already exists.
  Future<CategoryModel> createCategory(String name, String color) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw const ValidationError('Category name is empty');
    if (await nameExists(trimmed)) {
      throw const ValidationError('Category name already exists');
    }
    try {
      final id = _uuid.v4();
      await _db.into(_db.categories).insert(
            CategoriesCompanion.insert(
              id: id,
              name: trimmed,
              color: Value(color),
            ),
          );
      return _toModel(await (_db.select(_db.categories)
            ..where((c) => c.id.equals(id)))
          .getSingle());
    } catch (e) {
      throw DatabaseError('Failed to create category', e);
    }
  }

  /// Updates a category's name and/or color.
  Future<CategoryModel> updateCategory(
    String id, {
    String? name,
    String? color,
  }) async {
    if (name != null) {
      final trimmed = name.trim();
      if (trimmed.isEmpty) throw const ValidationError('Category name is empty');
      if (await nameExists(trimmed, excludeId: id)) {
        throw const ValidationError('Category name already exists');
      }
    }
    try {
      await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
        CategoriesCompanion(
          name: name != null ? Value(name.trim()) : const Value.absent(),
          color: color != null ? Value(color) : const Value.absent(),
        ),
      );
      return _toModel(await (_db.select(_db.categories)
            ..where((c) => c.id.equals(id)))
          .getSingle());
    } catch (e) {
      throw DatabaseError('Failed to update category $id', e);
    }
  }

  /// Soft-deletes a category and sets all its records' categoryId to null.
  Future<void> deleteCategory(String id) async {
    try {
      await _db.transaction(() async {
        // Nullify all records that belong to this category
        await (_db.update(_db.records)
              ..where((r) => r.categoryId.equals(id)))
            .write(const RecordsCompanion(categoryId: Value(null)));
        // Soft-delete the category
        await (_db.update(_db.categories)..where((c) => c.id.equals(id)))
            .write(
          CategoriesCompanion(deletedAt: Value(DateTime.now().toUtc())),
        );
      });
    } catch (e) {
      throw DatabaseError('Failed to delete category $id', e);
    }
  }

  /// Returns true if a non-deleted category with [name] exists (case-insensitive).
  Future<bool> nameExists(String name, {String? excludeId}) async {
    final lower = name.trim().toLowerCase();
    final cats = await getAllCategories();
    return cats.any((c) =>
        c.name.toLowerCase() == lower &&
        (excludeId == null || c.id != excludeId));
  }
}
