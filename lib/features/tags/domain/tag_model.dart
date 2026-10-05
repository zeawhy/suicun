// lib/features/tags/domain/tag_model.dart
// Immutable domain model for a tag.

/// Immutable domain representation of a Tag.
class TagModel {
  const TagModel({
    required this.id,
    required this.name,
    this.deletedAt,
  });

  final String id;

  /// Display name of the tag.
  final String name;

  /// Non-null when the tag has been soft-deleted.
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  TagModel copyWith({
    String? id,
    String? name,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return TagModel(
      id: id ?? this.id,
      name: name ?? this.name,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TagModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          deletedAt == other.deletedAt;

  @override
  int get hashCode => Object.hash(id, name, deletedAt);

  @override
  String toString() =>
      'TagModel(id: $id, name: $name, deletedAt: $deletedAt)';
}
