// lib/features/records/domain/record_model.dart
// Immutable domain models for records.

import 'package:suicun/features/categories/domain/category_model.dart';
import 'package:suicun/features/tags/domain/tag_model.dart';

/// Immutable domain representation of a Record (without joined details).
class RecordModel {
  const RecordModel({
    required this.id,
    required this.title,
    required this.body,
    required this.isFavorite,
    required this.createdAt,
    required this.updatedAt,
    this.categoryId,
    this.deletedAt,
  });

  final String id;
  final String title;
  final String body;
  final String? categoryId;
  final bool isFavorite;

  /// Always UTC.
  final DateTime createdAt;

  /// Always UTC.
  final DateTime updatedAt;

  /// Non-null when the record has been soft-deleted. Always UTC when set.
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  RecordModel copyWith({
    String? id,
    String? title,
    String? body,
    String? categoryId,
    bool? isFavorite,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearCategoryId = false,
    bool clearDeletedAt = false,
  }) {
    return RecordModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecordModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          body == other.body &&
          categoryId == other.categoryId &&
          isFavorite == other.isFavorite &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          deletedAt == other.deletedAt;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        body,
        categoryId,
        isFavorite,
        createdAt,
        updatedAt,
        deletedAt,
      );

  @override
  String toString() => 'RecordModel(id: $id, title: $title, '
      'isFavorite: $isFavorite, updatedAt: $updatedAt)';
}

/// [RecordModel] extended with its joined [CategoryModel] and [TagModel] list.
class RecordDetail {
  const RecordDetail({
    required this.record,
    required this.tags,
    this.category,
  });

  final RecordModel record;
  final CategoryModel? category;
  final List<TagModel> tags;

  // ── Convenience forwarders ────────────────────────────────────────────────

  String get id => record.id;
  String get title => record.title;
  String get body => record.body;
  String? get categoryId => record.categoryId;
  bool get isFavorite => record.isFavorite;
  DateTime get createdAt => record.createdAt;
  DateTime get updatedAt => record.updatedAt;
  DateTime? get deletedAt => record.deletedAt;
  bool get isDeleted => record.isDeleted;

  RecordDetail copyWith({
    RecordModel? record,
    CategoryModel? category,
    List<TagModel>? tags,
    bool clearCategory = false,
  }) {
    return RecordDetail(
      record: record ?? this.record,
      category: clearCategory ? null : (category ?? this.category),
      tags: tags ?? this.tags,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecordDetail &&
          runtimeType == other.runtimeType &&
          record == other.record &&
          category == other.category &&
          _tagListEquals(tags, other.tags);

  bool _tagListEquals(List<TagModel> a, List<TagModel> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(record, category, Object.hashAll(tags));

  @override
  String toString() => 'RecordDetail(id: ${record.id}, '
      'title: ${record.title}, tags: ${tags.length})';
}
