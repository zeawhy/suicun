// lib/features/categories/domain/category_model.dart
// Immutable domain model for a category.

/// Immutable domain representation of a Category.
class CategoryModel {
  const CategoryModel({
    required this.id,
    required this.name,
    required this.color,
    this.deletedAt,
  });

  final String id;

  /// Display name of the category.
  final String name;

  /// Hex color string, e.g. "#4866D5".
  final String color;

  /// Non-null when the category has been soft-deleted.
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  CategoryModel copyWith({
    String? id,
    String? name,
    String? color,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          color == other.color &&
          deletedAt == other.deletedAt;

  @override
  int get hashCode => Object.hash(id, name, color, deletedAt);

  @override
  String toString() =>
      'CategoryModel(id: $id, name: $name, color: $color, deletedAt: $deletedAt)';
}
