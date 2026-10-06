// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
      'color', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('#4866D5'));
  static const VerificationMeta _keywordsMeta =
      const VerificationMeta('keywords');
  @override
  late final GeneratedColumn<String> keywords = GeneratedColumn<String>(
      'keywords', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [id, name, color, keywords, deletedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(Insertable<Category> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
          _colorMeta, color.isAcceptableOrUnknown(data['color']!, _colorMeta));
    }
    if (data.containsKey('keywords')) {
      context.handle(_keywordsMeta,
          keywords.isAcceptableOrUnknown(data['keywords']!, _keywordsMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      color: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}color'])!,
      keywords: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}keywords']),
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class Category extends DataClass implements Insertable<Category> {
  final String id;
  final String name;
  final String color;
  final String? keywords;
  final DateTime? deletedAt;
  const Category(
      {required this.id,
      required this.name,
      required this.color,
      this.keywords,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['color'] = Variable<String>(color);
    if (!nullToAbsent || keywords != null) {
      map['keywords'] = Variable<String>(keywords);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      name: Value(name),
      color: Value(color),
      keywords: keywords == null && nullToAbsent
          ? const Value.absent()
          : Value(keywords),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Category.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<String>(json['color']),
      keywords: serializer.fromJson<String?>(json['keywords']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<String>(color),
      'keywords': serializer.toJson<String?>(keywords),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Category copyWith(
          {String? id,
          String? name,
          String? color,
          Value<String?> keywords = const Value.absent(),
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      Category(
        id: id ?? this.id,
        name: name ?? this.name,
        color: color ?? this.color,
        keywords: keywords.present ? keywords.value : this.keywords,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      keywords: data.keywords.present ? data.keywords.value : this.keywords,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('keywords: $keywords, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, color, keywords, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.id == this.id &&
          other.name == this.name &&
          other.color == this.color &&
          other.keywords == this.keywords &&
          other.deletedAt == this.deletedAt);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> color;
  final Value<String?> keywords;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.keywords = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required String id,
    required String name,
    this.color = const Value.absent(),
    this.keywords = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name);
  static Insertable<Category> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? color,
    Expression<String>? keywords,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (keywords != null) 'keywords': keywords,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? color,
      Value<String?>? keywords,
      Value<DateTime?>? deletedAt,
      Value<int>? rowid}) {
    return CategoriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      keywords: keywords ?? this.keywords,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (keywords.present) {
      map['keywords'] = Variable<String>(keywords.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('keywords: $keywords, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecordsTable extends Records with TableInfo<$RecordsTable, Record> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
      'body', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _categoryIdMeta =
      const VerificationMeta('categoryId');
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
      'category_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES categories (id)'));
  static const VerificationMeta _isFavoriteMeta =
      const VerificationMeta('isFavorite');
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
      'is_favorite', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_favorite" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _localSeqMeta =
      const VerificationMeta('localSeq');
  @override
  late final GeneratedColumn<int> localSeq = GeneratedColumn<int>(
      'local_seq', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        title,
        body,
        categoryId,
        isFavorite,
        createdAt,
        updatedAt,
        deletedAt,
        localSeq
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'records';
  @override
  VerificationContext validateIntegrity(Insertable<Record> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    }
    if (data.containsKey('body')) {
      context.handle(
          _bodyMeta, body.isAcceptableOrUnknown(data['body']!, _bodyMeta));
    }
    if (data.containsKey('category_id')) {
      context.handle(
          _categoryIdMeta,
          categoryId.isAcceptableOrUnknown(
              data['category_id']!, _categoryIdMeta));
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
          _isFavoriteMeta,
          isFavorite.isAcceptableOrUnknown(
              data['is_favorite']!, _isFavoriteMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    if (data.containsKey('local_seq')) {
      context.handle(_localSeqMeta,
          localSeq.isAcceptableOrUnknown(data['local_seq']!, _localSeqMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Record map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Record(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      body: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}body'])!,
      categoryId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category_id']),
      isFavorite: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_favorite'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
      localSeq: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}local_seq']),
    );
  }

  @override
  $RecordsTable createAlias(String alias) {
    return $RecordsTable(attachedDatabase, alias);
  }
}

class Record extends DataClass implements Insertable<Record> {
  final String id;
  final String title;
  final String body;
  final String? categoryId;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int? localSeq;
  const Record(
      {required this.id,
      required this.title,
      required this.body,
      this.categoryId,
      required this.isFavorite,
      required this.createdAt,
      required this.updatedAt,
      this.deletedAt,
      this.localSeq});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    map['is_favorite'] = Variable<bool>(isFavorite);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || localSeq != null) {
      map['local_seq'] = Variable<int>(localSeq);
    }
    return map;
  }

  RecordsCompanion toCompanion(bool nullToAbsent) {
    return RecordsCompanion(
      id: Value(id),
      title: Value(title),
      body: Value(body),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      isFavorite: Value(isFavorite),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      localSeq: localSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(localSeq),
    );
  }

  factory Record.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Record(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String>(json['body']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      localSeq: serializer.fromJson<int?>(json['localSeq']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
      'categoryId': serializer.toJson<String?>(categoryId),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'localSeq': serializer.toJson<int?>(localSeq),
    };
  }

  Record copyWith(
          {String? id,
          String? title,
          String? body,
          Value<String?> categoryId = const Value.absent(),
          bool? isFavorite,
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<DateTime?> deletedAt = const Value.absent(),
          Value<int?> localSeq = const Value.absent()}) =>
      Record(
        id: id ?? this.id,
        title: title ?? this.title,
        body: body ?? this.body,
        categoryId: categoryId.present ? categoryId.value : this.categoryId,
        isFavorite: isFavorite ?? this.isFavorite,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
        localSeq: localSeq.present ? localSeq.value : this.localSeq,
      );
  Record copyWithCompanion(RecordsCompanion data) {
    return Record(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      categoryId:
          data.categoryId.present ? data.categoryId.value : this.categoryId,
      isFavorite:
          data.isFavorite.present ? data.isFavorite.value : this.isFavorite,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      localSeq: data.localSeq.present ? data.localSeq.value : this.localSeq,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Record(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('categoryId: $categoryId, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('localSeq: $localSeq')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, body, categoryId, isFavorite,
      createdAt, updatedAt, deletedAt, localSeq);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Record &&
          other.id == this.id &&
          other.title == this.title &&
          other.body == this.body &&
          other.categoryId == this.categoryId &&
          other.isFavorite == this.isFavorite &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.localSeq == this.localSeq);
}

class RecordsCompanion extends UpdateCompanion<Record> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> body;
  final Value<String?> categoryId;
  final Value<bool> isFavorite;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int?> localSeq;
  final Value<int> rowid;
  const RecordsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.localSeq = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecordsCompanion.insert({
    required String id,
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.isFavorite = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.localSeq = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<Record> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? body,
    Expression<String>? categoryId,
    Expression<bool>? isFavorite,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? localSeq,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (categoryId != null) 'category_id': categoryId,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (localSeq != null) 'local_seq': localSeq,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecordsCompanion copyWith(
      {Value<String>? id,
      Value<String>? title,
      Value<String>? body,
      Value<String?>? categoryId,
      Value<bool>? isFavorite,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? deletedAt,
      Value<int?>? localSeq,
      Value<int>? rowid}) {
    return RecordsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      categoryId: categoryId ?? this.categoryId,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      localSeq: localSeq ?? this.localSeq,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (localSeq.present) {
      map['local_seq'] = Variable<int>(localSeq.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecordsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('categoryId: $categoryId, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('localSeq: $localSeq, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TagsTable extends Tags with TableInfo<$TagsTable, Tag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [id, name, deletedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags';
  @override
  VerificationContext validateIntegrity(Insertable<Tag> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Tag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Tag(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $TagsTable createAlias(String alias) {
    return $TagsTable(attachedDatabase, alias);
  }
}

class Tag extends DataClass implements Insertable<Tag> {
  final String id;
  final String name;
  final DateTime? deletedAt;
  const Tag({required this.id, required this.name, this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  TagsCompanion toCompanion(bool nullToAbsent) {
    return TagsCompanion(
      id: Value(id),
      name: Value(name),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Tag.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Tag(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Tag copyWith(
          {String? id,
          String? name,
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      Tag(
        id: id ?? this.id,
        name: name ?? this.name,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  Tag copyWithCompanion(TagsCompanion data) {
    return Tag(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Tag(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Tag &&
          other.id == this.id &&
          other.name == this.name &&
          other.deletedAt == this.deletedAt);
}

class TagsCompanion extends UpdateCompanion<Tag> {
  final Value<String> id;
  final Value<String> name;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const TagsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TagsCompanion.insert({
    required String id,
    required String name,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name);
  static Insertable<Tag> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TagsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<DateTime?>? deletedAt,
      Value<int>? rowid}) {
    return TagsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecordTagsTable extends RecordTags
    with TableInfo<$RecordTagsTable, RecordTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecordTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _recordIdMeta =
      const VerificationMeta('recordId');
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
      'record_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES records (id)'));
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId = GeneratedColumn<String>(
      'tag_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES tags (id)'));
  @override
  List<GeneratedColumn> get $columns => [recordId, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'record_tags';
  @override
  VerificationContext validateIntegrity(Insertable<RecordTag> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('record_id')) {
      context.handle(_recordIdMeta,
          recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta));
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
          _tagIdMeta, tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta));
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {recordId, tagId};
  @override
  RecordTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecordTag(
      recordId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}record_id'])!,
      tagId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tag_id'])!,
    );
  }

  @override
  $RecordTagsTable createAlias(String alias) {
    return $RecordTagsTable(attachedDatabase, alias);
  }
}

class RecordTag extends DataClass implements Insertable<RecordTag> {
  final String recordId;
  final String tagId;
  const RecordTag({required this.recordId, required this.tagId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['record_id'] = Variable<String>(recordId);
    map['tag_id'] = Variable<String>(tagId);
    return map;
  }

  RecordTagsCompanion toCompanion(bool nullToAbsent) {
    return RecordTagsCompanion(
      recordId: Value(recordId),
      tagId: Value(tagId),
    );
  }

  factory RecordTag.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecordTag(
      recordId: serializer.fromJson<String>(json['recordId']),
      tagId: serializer.fromJson<String>(json['tagId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'recordId': serializer.toJson<String>(recordId),
      'tagId': serializer.toJson<String>(tagId),
    };
  }

  RecordTag copyWith({String? recordId, String? tagId}) => RecordTag(
        recordId: recordId ?? this.recordId,
        tagId: tagId ?? this.tagId,
      );
  RecordTag copyWithCompanion(RecordTagsCompanion data) {
    return RecordTag(
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecordTag(')
          ..write('recordId: $recordId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(recordId, tagId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecordTag &&
          other.recordId == this.recordId &&
          other.tagId == this.tagId);
}

class RecordTagsCompanion extends UpdateCompanion<RecordTag> {
  final Value<String> recordId;
  final Value<String> tagId;
  final Value<int> rowid;
  const RecordTagsCompanion({
    this.recordId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecordTagsCompanion.insert({
    required String recordId,
    required String tagId,
    this.rowid = const Value.absent(),
  })  : recordId = Value(recordId),
        tagId = Value(tagId);
  static Insertable<RecordTag> custom({
    Expression<String>? recordId,
    Expression<String>? tagId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (recordId != null) 'record_id': recordId,
      if (tagId != null) 'tag_id': tagId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecordTagsCompanion copyWith(
      {Value<String>? recordId, Value<String>? tagId, Value<int>? rowid}) {
    return RecordTagsCompanion(
      recordId: recordId ?? this.recordId,
      tagId: tagId ?? this.tagId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<String>(tagId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecordTagsCompanion(')
          ..write('recordId: $recordId, ')
          ..write('tagId: $tagId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RevisionsTable extends Revisions
    with TableInfo<$RevisionsTable, Revision> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RevisionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _revisionIdMeta =
      const VerificationMeta('revisionId');
  @override
  late final GeneratedColumn<String> revisionId = GeneratedColumn<String>(
      'revision_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _entityTypeMeta =
      const VerificationMeta('entityType');
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
      'entity_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _entityIdMeta =
      const VerificationMeta('entityId');
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
      'entity_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _parentsJsonMeta =
      const VerificationMeta('parentsJson');
  @override
  late final GeneratedColumn<String> parentsJson = GeneratedColumn<String>(
      'parents_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _payloadJsonMeta =
      const VerificationMeta('payloadJson');
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
      'payload_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _receivedAtMeta =
      const VerificationMeta('receivedAt');
  @override
  late final GeneratedColumn<DateTime> receivedAt = GeneratedColumn<DateTime>(
      'received_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _isLocalMeta =
      const VerificationMeta('isLocal');
  @override
  late final GeneratedColumn<bool> isLocal = GeneratedColumn<bool>(
      'is_local', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_local" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        revisionId,
        entityType,
        entityId,
        parentsJson,
        payloadJson,
        createdAt,
        receivedAt,
        isLocal
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'revisions';
  @override
  VerificationContext validateIntegrity(Insertable<Revision> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('revision_id')) {
      context.handle(
          _revisionIdMeta,
          revisionId.isAcceptableOrUnknown(
              data['revision_id']!, _revisionIdMeta));
    } else if (isInserting) {
      context.missing(_revisionIdMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
          _entityTypeMeta,
          entityType.isAcceptableOrUnknown(
              data['entity_type']!, _entityTypeMeta));
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(_entityIdMeta,
          entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta));
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('parents_json')) {
      context.handle(
          _parentsJsonMeta,
          parentsJson.isAcceptableOrUnknown(
              data['parents_json']!, _parentsJsonMeta));
    }
    if (data.containsKey('payload_json')) {
      context.handle(
          _payloadJsonMeta,
          payloadJson.isAcceptableOrUnknown(
              data['payload_json']!, _payloadJsonMeta));
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('received_at')) {
      context.handle(
          _receivedAtMeta,
          receivedAt.isAcceptableOrUnknown(
              data['received_at']!, _receivedAtMeta));
    } else if (isInserting) {
      context.missing(_receivedAtMeta);
    }
    if (data.containsKey('is_local')) {
      context.handle(_isLocalMeta,
          isLocal.isAcceptableOrUnknown(data['is_local']!, _isLocalMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {revisionId};
  @override
  Revision map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Revision(
      revisionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}revision_id'])!,
      entityType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_type'])!,
      entityId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_id'])!,
      parentsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}parents_json'])!,
      payloadJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload_json'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      receivedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}received_at'])!,
      isLocal: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_local'])!,
    );
  }

  @override
  $RevisionsTable createAlias(String alias) {
    return $RevisionsTable(attachedDatabase, alias);
  }
}

class Revision extends DataClass implements Insertable<Revision> {
  final String revisionId;
  final String entityType;
  final String entityId;
  final String parentsJson;
  final String payloadJson;
  final DateTime createdAt;
  final DateTime receivedAt;
  final bool isLocal;
  const Revision(
      {required this.revisionId,
      required this.entityType,
      required this.entityId,
      required this.parentsJson,
      required this.payloadJson,
      required this.createdAt,
      required this.receivedAt,
      required this.isLocal});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['revision_id'] = Variable<String>(revisionId);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['parents_json'] = Variable<String>(parentsJson);
    map['payload_json'] = Variable<String>(payloadJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['received_at'] = Variable<DateTime>(receivedAt);
    map['is_local'] = Variable<bool>(isLocal);
    return map;
  }

  RevisionsCompanion toCompanion(bool nullToAbsent) {
    return RevisionsCompanion(
      revisionId: Value(revisionId),
      entityType: Value(entityType),
      entityId: Value(entityId),
      parentsJson: Value(parentsJson),
      payloadJson: Value(payloadJson),
      createdAt: Value(createdAt),
      receivedAt: Value(receivedAt),
      isLocal: Value(isLocal),
    );
  }

  factory Revision.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Revision(
      revisionId: serializer.fromJson<String>(json['revisionId']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      parentsJson: serializer.fromJson<String>(json['parentsJson']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      receivedAt: serializer.fromJson<DateTime>(json['receivedAt']),
      isLocal: serializer.fromJson<bool>(json['isLocal']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'revisionId': serializer.toJson<String>(revisionId),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'parentsJson': serializer.toJson<String>(parentsJson),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'receivedAt': serializer.toJson<DateTime>(receivedAt),
      'isLocal': serializer.toJson<bool>(isLocal),
    };
  }

  Revision copyWith(
          {String? revisionId,
          String? entityType,
          String? entityId,
          String? parentsJson,
          String? payloadJson,
          DateTime? createdAt,
          DateTime? receivedAt,
          bool? isLocal}) =>
      Revision(
        revisionId: revisionId ?? this.revisionId,
        entityType: entityType ?? this.entityType,
        entityId: entityId ?? this.entityId,
        parentsJson: parentsJson ?? this.parentsJson,
        payloadJson: payloadJson ?? this.payloadJson,
        createdAt: createdAt ?? this.createdAt,
        receivedAt: receivedAt ?? this.receivedAt,
        isLocal: isLocal ?? this.isLocal,
      );
  Revision copyWithCompanion(RevisionsCompanion data) {
    return Revision(
      revisionId:
          data.revisionId.present ? data.revisionId.value : this.revisionId,
      entityType:
          data.entityType.present ? data.entityType.value : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      parentsJson:
          data.parentsJson.present ? data.parentsJson.value : this.parentsJson,
      payloadJson:
          data.payloadJson.present ? data.payloadJson.value : this.payloadJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      receivedAt:
          data.receivedAt.present ? data.receivedAt.value : this.receivedAt,
      isLocal: data.isLocal.present ? data.isLocal.value : this.isLocal,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Revision(')
          ..write('revisionId: $revisionId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('parentsJson: $parentsJson, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('isLocal: $isLocal')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(revisionId, entityType, entityId, parentsJson,
      payloadJson, createdAt, receivedAt, isLocal);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Revision &&
          other.revisionId == this.revisionId &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.parentsJson == this.parentsJson &&
          other.payloadJson == this.payloadJson &&
          other.createdAt == this.createdAt &&
          other.receivedAt == this.receivedAt &&
          other.isLocal == this.isLocal);
}

class RevisionsCompanion extends UpdateCompanion<Revision> {
  final Value<String> revisionId;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> parentsJson;
  final Value<String> payloadJson;
  final Value<DateTime> createdAt;
  final Value<DateTime> receivedAt;
  final Value<bool> isLocal;
  final Value<int> rowid;
  const RevisionsCompanion({
    this.revisionId = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.parentsJson = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.isLocal = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RevisionsCompanion.insert({
    required String revisionId,
    required String entityType,
    required String entityId,
    this.parentsJson = const Value.absent(),
    required String payloadJson,
    required DateTime createdAt,
    required DateTime receivedAt,
    this.isLocal = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : revisionId = Value(revisionId),
        entityType = Value(entityType),
        entityId = Value(entityId),
        payloadJson = Value(payloadJson),
        createdAt = Value(createdAt),
        receivedAt = Value(receivedAt);
  static Insertable<Revision> custom({
    Expression<String>? revisionId,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? parentsJson,
    Expression<String>? payloadJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? receivedAt,
    Expression<bool>? isLocal,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (revisionId != null) 'revision_id': revisionId,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (parentsJson != null) 'parents_json': parentsJson,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (createdAt != null) 'created_at': createdAt,
      if (receivedAt != null) 'received_at': receivedAt,
      if (isLocal != null) 'is_local': isLocal,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RevisionsCompanion copyWith(
      {Value<String>? revisionId,
      Value<String>? entityType,
      Value<String>? entityId,
      Value<String>? parentsJson,
      Value<String>? payloadJson,
      Value<DateTime>? createdAt,
      Value<DateTime>? receivedAt,
      Value<bool>? isLocal,
      Value<int>? rowid}) {
    return RevisionsCompanion(
      revisionId: revisionId ?? this.revisionId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      parentsJson: parentsJson ?? this.parentsJson,
      payloadJson: payloadJson ?? this.payloadJson,
      createdAt: createdAt ?? this.createdAt,
      receivedAt: receivedAt ?? this.receivedAt,
      isLocal: isLocal ?? this.isLocal,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (revisionId.present) {
      map['revision_id'] = Variable<String>(revisionId.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (parentsJson.present) {
      map['parents_json'] = Variable<String>(parentsJson.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (receivedAt.present) {
      map['received_at'] = Variable<DateTime>(receivedAt.value);
    }
    if (isLocal.present) {
      map['is_local'] = Variable<bool>(isLocal.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RevisionsCompanion(')
          ..write('revisionId: $revisionId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('parentsJson: $parentsJson, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('isLocal: $isLocal, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _operationIdMeta =
      const VerificationMeta('operationId');
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
      'operation_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _revisionIdMeta =
      const VerificationMeta('revisionId');
  @override
  late final GeneratedColumn<String> revisionId = GeneratedColumn<String>(
      'revision_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  static const VerificationMeta _attemptCountMeta =
      const VerificationMeta('attemptCount');
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
      'attempt_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _nextRetryAtMeta =
      const VerificationMeta('nextRetryAt');
  @override
  late final GeneratedColumn<DateTime> nextRetryAt = GeneratedColumn<DateTime>(
      'next_retry_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _lastErrorMeta =
      const VerificationMeta('lastError');
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
      'last_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        operationId,
        revisionId,
        status,
        attemptCount,
        nextRetryAt,
        createdAt,
        lastError
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(Insertable<OutboxData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('operation_id')) {
      context.handle(
          _operationIdMeta,
          operationId.isAcceptableOrUnknown(
              data['operation_id']!, _operationIdMeta));
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('revision_id')) {
      context.handle(
          _revisionIdMeta,
          revisionId.isAcceptableOrUnknown(
              data['revision_id']!, _revisionIdMeta));
    } else if (isInserting) {
      context.missing(_revisionIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
          _attemptCountMeta,
          attemptCount.isAcceptableOrUnknown(
              data['attempt_count']!, _attemptCountMeta));
    }
    if (data.containsKey('next_retry_at')) {
      context.handle(
          _nextRetryAtMeta,
          nextRetryAt.isAcceptableOrUnknown(
              data['next_retry_at']!, _nextRetryAtMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('last_error')) {
      context.handle(_lastErrorMeta,
          lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {operationId};
  @override
  OutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxData(
      operationId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}operation_id'])!,
      revisionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}revision_id'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      attemptCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}attempt_count'])!,
      nextRetryAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}next_retry_at']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      lastError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_error']),
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }
}

class OutboxData extends DataClass implements Insertable<OutboxData> {
  final String operationId;
  final String revisionId;
  final String status;
  final int attemptCount;
  final DateTime? nextRetryAt;
  final DateTime createdAt;
  final String? lastError;
  const OutboxData(
      {required this.operationId,
      required this.revisionId,
      required this.status,
      required this.attemptCount,
      this.nextRetryAt,
      required this.createdAt,
      this.lastError});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['operation_id'] = Variable<String>(operationId);
    map['revision_id'] = Variable<String>(revisionId);
    map['status'] = Variable<String>(status);
    map['attempt_count'] = Variable<int>(attemptCount);
    if (!nullToAbsent || nextRetryAt != null) {
      map['next_retry_at'] = Variable<DateTime>(nextRetryAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      operationId: Value(operationId),
      revisionId: Value(revisionId),
      status: Value(status),
      attemptCount: Value(attemptCount),
      nextRetryAt: nextRetryAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextRetryAt),
      createdAt: Value(createdAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory OutboxData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxData(
      operationId: serializer.fromJson<String>(json['operationId']),
      revisionId: serializer.fromJson<String>(json['revisionId']),
      status: serializer.fromJson<String>(json['status']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      nextRetryAt: serializer.fromJson<DateTime?>(json['nextRetryAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'operationId': serializer.toJson<String>(operationId),
      'revisionId': serializer.toJson<String>(revisionId),
      'status': serializer.toJson<String>(status),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'nextRetryAt': serializer.toJson<DateTime?>(nextRetryAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  OutboxData copyWith(
          {String? operationId,
          String? revisionId,
          String? status,
          int? attemptCount,
          Value<DateTime?> nextRetryAt = const Value.absent(),
          DateTime? createdAt,
          Value<String?> lastError = const Value.absent()}) =>
      OutboxData(
        operationId: operationId ?? this.operationId,
        revisionId: revisionId ?? this.revisionId,
        status: status ?? this.status,
        attemptCount: attemptCount ?? this.attemptCount,
        nextRetryAt: nextRetryAt.present ? nextRetryAt.value : this.nextRetryAt,
        createdAt: createdAt ?? this.createdAt,
        lastError: lastError.present ? lastError.value : this.lastError,
      );
  OutboxData copyWithCompanion(OutboxCompanion data) {
    return OutboxData(
      operationId:
          data.operationId.present ? data.operationId.value : this.operationId,
      revisionId:
          data.revisionId.present ? data.revisionId.value : this.revisionId,
      status: data.status.present ? data.status.value : this.status,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      nextRetryAt:
          data.nextRetryAt.present ? data.nextRetryAt.value : this.nextRetryAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxData(')
          ..write('operationId: $operationId, ')
          ..write('revisionId: $revisionId, ')
          ..write('status: $status, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(operationId, revisionId, status, attemptCount,
      nextRetryAt, createdAt, lastError);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxData &&
          other.operationId == this.operationId &&
          other.revisionId == this.revisionId &&
          other.status == this.status &&
          other.attemptCount == this.attemptCount &&
          other.nextRetryAt == this.nextRetryAt &&
          other.createdAt == this.createdAt &&
          other.lastError == this.lastError);
}

class OutboxCompanion extends UpdateCompanion<OutboxData> {
  final Value<String> operationId;
  final Value<String> revisionId;
  final Value<String> status;
  final Value<int> attemptCount;
  final Value<DateTime?> nextRetryAt;
  final Value<DateTime> createdAt;
  final Value<String?> lastError;
  final Value<int> rowid;
  const OutboxCompanion({
    this.operationId = const Value.absent(),
    this.revisionId = const Value.absent(),
    this.status = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxCompanion.insert({
    required String operationId,
    required String revisionId,
    this.status = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    required DateTime createdAt,
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : operationId = Value(operationId),
        revisionId = Value(revisionId),
        createdAt = Value(createdAt);
  static Insertable<OutboxData> custom({
    Expression<String>? operationId,
    Expression<String>? revisionId,
    Expression<String>? status,
    Expression<int>? attemptCount,
    Expression<DateTime>? nextRetryAt,
    Expression<DateTime>? createdAt,
    Expression<String>? lastError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (operationId != null) 'operation_id': operationId,
      if (revisionId != null) 'revision_id': revisionId,
      if (status != null) 'status': status,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (nextRetryAt != null) 'next_retry_at': nextRetryAt,
      if (createdAt != null) 'created_at': createdAt,
      if (lastError != null) 'last_error': lastError,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxCompanion copyWith(
      {Value<String>? operationId,
      Value<String>? revisionId,
      Value<String>? status,
      Value<int>? attemptCount,
      Value<DateTime?>? nextRetryAt,
      Value<DateTime>? createdAt,
      Value<String?>? lastError,
      Value<int>? rowid}) {
    return OutboxCompanion(
      operationId: operationId ?? this.operationId,
      revisionId: revisionId ?? this.revisionId,
      status: status ?? this.status,
      attemptCount: attemptCount ?? this.attemptCount,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      createdAt: createdAt ?? this.createdAt,
      lastError: lastError ?? this.lastError,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (revisionId.present) {
      map['revision_id'] = Variable<String>(revisionId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (nextRetryAt.present) {
      map['next_retry_at'] = Variable<DateTime>(nextRetryAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('operationId: $operationId, ')
          ..write('revisionId: $revisionId, ')
          ..write('status: $status, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastError: $lastError, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RemoteReceiptsTable extends RemoteReceipts
    with TableInfo<$RemoteReceiptsTable, RemoteReceipt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RemoteReceiptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _revisionIdMeta =
      const VerificationMeta('revisionId');
  @override
  late final GeneratedColumn<String> revisionId = GeneratedColumn<String>(
      'revision_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _remotePathMeta =
      const VerificationMeta('remotePath');
  @override
  late final GeneratedColumn<String> remotePath = GeneratedColumn<String>(
      'remote_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _etagMeta = const VerificationMeta('etag');
  @override
  late final GeneratedColumn<String> etag = GeneratedColumn<String>(
      'etag', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _observedAtMeta =
      const VerificationMeta('observedAt');
  @override
  late final GeneratedColumn<DateTime> observedAt = GeneratedColumn<DateTime>(
      'observed_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [revisionId, remotePath, etag, observedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'remote_receipts';
  @override
  VerificationContext validateIntegrity(Insertable<RemoteReceipt> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('revision_id')) {
      context.handle(
          _revisionIdMeta,
          revisionId.isAcceptableOrUnknown(
              data['revision_id']!, _revisionIdMeta));
    } else if (isInserting) {
      context.missing(_revisionIdMeta);
    }
    if (data.containsKey('remote_path')) {
      context.handle(
          _remotePathMeta,
          remotePath.isAcceptableOrUnknown(
              data['remote_path']!, _remotePathMeta));
    } else if (isInserting) {
      context.missing(_remotePathMeta);
    }
    if (data.containsKey('etag')) {
      context.handle(
          _etagMeta, etag.isAcceptableOrUnknown(data['etag']!, _etagMeta));
    }
    if (data.containsKey('observed_at')) {
      context.handle(
          _observedAtMeta,
          observedAt.isAcceptableOrUnknown(
              data['observed_at']!, _observedAtMeta));
    } else if (isInserting) {
      context.missing(_observedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {revisionId};
  @override
  RemoteReceipt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RemoteReceipt(
      revisionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}revision_id'])!,
      remotePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}remote_path'])!,
      etag: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}etag']),
      observedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}observed_at'])!,
    );
  }

  @override
  $RemoteReceiptsTable createAlias(String alias) {
    return $RemoteReceiptsTable(attachedDatabase, alias);
  }
}

class RemoteReceipt extends DataClass implements Insertable<RemoteReceipt> {
  final String revisionId;
  final String remotePath;
  final String? etag;
  final DateTime observedAt;
  const RemoteReceipt(
      {required this.revisionId,
      required this.remotePath,
      this.etag,
      required this.observedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['revision_id'] = Variable<String>(revisionId);
    map['remote_path'] = Variable<String>(remotePath);
    if (!nullToAbsent || etag != null) {
      map['etag'] = Variable<String>(etag);
    }
    map['observed_at'] = Variable<DateTime>(observedAt);
    return map;
  }

  RemoteReceiptsCompanion toCompanion(bool nullToAbsent) {
    return RemoteReceiptsCompanion(
      revisionId: Value(revisionId),
      remotePath: Value(remotePath),
      etag: etag == null && nullToAbsent ? const Value.absent() : Value(etag),
      observedAt: Value(observedAt),
    );
  }

  factory RemoteReceipt.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RemoteReceipt(
      revisionId: serializer.fromJson<String>(json['revisionId']),
      remotePath: serializer.fromJson<String>(json['remotePath']),
      etag: serializer.fromJson<String?>(json['etag']),
      observedAt: serializer.fromJson<DateTime>(json['observedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'revisionId': serializer.toJson<String>(revisionId),
      'remotePath': serializer.toJson<String>(remotePath),
      'etag': serializer.toJson<String?>(etag),
      'observedAt': serializer.toJson<DateTime>(observedAt),
    };
  }

  RemoteReceipt copyWith(
          {String? revisionId,
          String? remotePath,
          Value<String?> etag = const Value.absent(),
          DateTime? observedAt}) =>
      RemoteReceipt(
        revisionId: revisionId ?? this.revisionId,
        remotePath: remotePath ?? this.remotePath,
        etag: etag.present ? etag.value : this.etag,
        observedAt: observedAt ?? this.observedAt,
      );
  RemoteReceipt copyWithCompanion(RemoteReceiptsCompanion data) {
    return RemoteReceipt(
      revisionId:
          data.revisionId.present ? data.revisionId.value : this.revisionId,
      remotePath:
          data.remotePath.present ? data.remotePath.value : this.remotePath,
      etag: data.etag.present ? data.etag.value : this.etag,
      observedAt:
          data.observedAt.present ? data.observedAt.value : this.observedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RemoteReceipt(')
          ..write('revisionId: $revisionId, ')
          ..write('remotePath: $remotePath, ')
          ..write('etag: $etag, ')
          ..write('observedAt: $observedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(revisionId, remotePath, etag, observedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RemoteReceipt &&
          other.revisionId == this.revisionId &&
          other.remotePath == this.remotePath &&
          other.etag == this.etag &&
          other.observedAt == this.observedAt);
}

class RemoteReceiptsCompanion extends UpdateCompanion<RemoteReceipt> {
  final Value<String> revisionId;
  final Value<String> remotePath;
  final Value<String?> etag;
  final Value<DateTime> observedAt;
  final Value<int> rowid;
  const RemoteReceiptsCompanion({
    this.revisionId = const Value.absent(),
    this.remotePath = const Value.absent(),
    this.etag = const Value.absent(),
    this.observedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RemoteReceiptsCompanion.insert({
    required String revisionId,
    required String remotePath,
    this.etag = const Value.absent(),
    required DateTime observedAt,
    this.rowid = const Value.absent(),
  })  : revisionId = Value(revisionId),
        remotePath = Value(remotePath),
        observedAt = Value(observedAt);
  static Insertable<RemoteReceipt> custom({
    Expression<String>? revisionId,
    Expression<String>? remotePath,
    Expression<String>? etag,
    Expression<DateTime>? observedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (revisionId != null) 'revision_id': revisionId,
      if (remotePath != null) 'remote_path': remotePath,
      if (etag != null) 'etag': etag,
      if (observedAt != null) 'observed_at': observedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RemoteReceiptsCompanion copyWith(
      {Value<String>? revisionId,
      Value<String>? remotePath,
      Value<String?>? etag,
      Value<DateTime>? observedAt,
      Value<int>? rowid}) {
    return RemoteReceiptsCompanion(
      revisionId: revisionId ?? this.revisionId,
      remotePath: remotePath ?? this.remotePath,
      etag: etag ?? this.etag,
      observedAt: observedAt ?? this.observedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (revisionId.present) {
      map['revision_id'] = Variable<String>(revisionId.value);
    }
    if (remotePath.present) {
      map['remote_path'] = Variable<String>(remotePath.value);
    }
    if (etag.present) {
      map['etag'] = Variable<String>(etag.value);
    }
    if (observedAt.present) {
      map['observed_at'] = Variable<DateTime>(observedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RemoteReceiptsCompanion(')
          ..write('revisionId: $revisionId, ')
          ..write('remotePath: $remotePath, ')
          ..write('etag: $etag, ')
          ..write('observedAt: $observedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncStateTable extends SyncState
    with TableInfo<$SyncStateTable, SyncStateData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _vaultIdMeta =
      const VerificationMeta('vaultId');
  @override
  late final GeneratedColumn<String> vaultId = GeneratedColumn<String>(
      'vault_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _deviceIdMeta =
      const VerificationMeta('deviceId');
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
      'device_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _protocolVersionMeta =
      const VerificationMeta('protocolVersion');
  @override
  late final GeneratedColumn<int> protocolVersion = GeneratedColumn<int>(
      'protocol_version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _lastSuccessAtMeta =
      const VerificationMeta('lastSuccessAt');
  @override
  late final GeneratedColumn<DateTime> lastSuccessAt =
      GeneratedColumn<DateTime>('last_success_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _enabledMeta =
      const VerificationMeta('enabled');
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
      'enabled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("enabled" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _lastErrorMeta =
      const VerificationMeta('lastError');
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
      'last_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [vaultId, deviceId, protocolVersion, lastSuccessAt, enabled, lastError];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state';
  @override
  VerificationContext validateIntegrity(Insertable<SyncStateData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('vault_id')) {
      context.handle(_vaultIdMeta,
          vaultId.isAcceptableOrUnknown(data['vault_id']!, _vaultIdMeta));
    } else if (isInserting) {
      context.missing(_vaultIdMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(_deviceIdMeta,
          deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta));
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('protocol_version')) {
      context.handle(
          _protocolVersionMeta,
          protocolVersion.isAcceptableOrUnknown(
              data['protocol_version']!, _protocolVersionMeta));
    }
    if (data.containsKey('last_success_at')) {
      context.handle(
          _lastSuccessAtMeta,
          lastSuccessAt.isAcceptableOrUnknown(
              data['last_success_at']!, _lastSuccessAtMeta));
    }
    if (data.containsKey('enabled')) {
      context.handle(_enabledMeta,
          enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta));
    }
    if (data.containsKey('last_error')) {
      context.handle(_lastErrorMeta,
          lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {vaultId};
  @override
  SyncStateData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateData(
      vaultId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}vault_id'])!,
      deviceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_id'])!,
      protocolVersion: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}protocol_version'])!,
      lastSuccessAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_success_at']),
      enabled: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}enabled'])!,
      lastError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_error']),
    );
  }

  @override
  $SyncStateTable createAlias(String alias) {
    return $SyncStateTable(attachedDatabase, alias);
  }
}

class SyncStateData extends DataClass implements Insertable<SyncStateData> {
  final String vaultId;
  final String deviceId;
  final int protocolVersion;
  final DateTime? lastSuccessAt;
  final bool enabled;
  final String? lastError;
  const SyncStateData(
      {required this.vaultId,
      required this.deviceId,
      required this.protocolVersion,
      this.lastSuccessAt,
      required this.enabled,
      this.lastError});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['vault_id'] = Variable<String>(vaultId);
    map['device_id'] = Variable<String>(deviceId);
    map['protocol_version'] = Variable<int>(protocolVersion);
    if (!nullToAbsent || lastSuccessAt != null) {
      map['last_success_at'] = Variable<DateTime>(lastSuccessAt);
    }
    map['enabled'] = Variable<bool>(enabled);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  SyncStateCompanion toCompanion(bool nullToAbsent) {
    return SyncStateCompanion(
      vaultId: Value(vaultId),
      deviceId: Value(deviceId),
      protocolVersion: Value(protocolVersion),
      lastSuccessAt: lastSuccessAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSuccessAt),
      enabled: Value(enabled),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory SyncStateData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateData(
      vaultId: serializer.fromJson<String>(json['vaultId']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      protocolVersion: serializer.fromJson<int>(json['protocolVersion']),
      lastSuccessAt: serializer.fromJson<DateTime?>(json['lastSuccessAt']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'vaultId': serializer.toJson<String>(vaultId),
      'deviceId': serializer.toJson<String>(deviceId),
      'protocolVersion': serializer.toJson<int>(protocolVersion),
      'lastSuccessAt': serializer.toJson<DateTime?>(lastSuccessAt),
      'enabled': serializer.toJson<bool>(enabled),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  SyncStateData copyWith(
          {String? vaultId,
          String? deviceId,
          int? protocolVersion,
          Value<DateTime?> lastSuccessAt = const Value.absent(),
          bool? enabled,
          Value<String?> lastError = const Value.absent()}) =>
      SyncStateData(
        vaultId: vaultId ?? this.vaultId,
        deviceId: deviceId ?? this.deviceId,
        protocolVersion: protocolVersion ?? this.protocolVersion,
        lastSuccessAt:
            lastSuccessAt.present ? lastSuccessAt.value : this.lastSuccessAt,
        enabled: enabled ?? this.enabled,
        lastError: lastError.present ? lastError.value : this.lastError,
      );
  SyncStateData copyWithCompanion(SyncStateCompanion data) {
    return SyncStateData(
      vaultId: data.vaultId.present ? data.vaultId.value : this.vaultId,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      protocolVersion: data.protocolVersion.present
          ? data.protocolVersion.value
          : this.protocolVersion,
      lastSuccessAt: data.lastSuccessAt.present
          ? data.lastSuccessAt.value
          : this.lastSuccessAt,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateData(')
          ..write('vaultId: $vaultId, ')
          ..write('deviceId: $deviceId, ')
          ..write('protocolVersion: $protocolVersion, ')
          ..write('lastSuccessAt: $lastSuccessAt, ')
          ..write('enabled: $enabled, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      vaultId, deviceId, protocolVersion, lastSuccessAt, enabled, lastError);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateData &&
          other.vaultId == this.vaultId &&
          other.deviceId == this.deviceId &&
          other.protocolVersion == this.protocolVersion &&
          other.lastSuccessAt == this.lastSuccessAt &&
          other.enabled == this.enabled &&
          other.lastError == this.lastError);
}

class SyncStateCompanion extends UpdateCompanion<SyncStateData> {
  final Value<String> vaultId;
  final Value<String> deviceId;
  final Value<int> protocolVersion;
  final Value<DateTime?> lastSuccessAt;
  final Value<bool> enabled;
  final Value<String?> lastError;
  final Value<int> rowid;
  const SyncStateCompanion({
    this.vaultId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.protocolVersion = const Value.absent(),
    this.lastSuccessAt = const Value.absent(),
    this.enabled = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStateCompanion.insert({
    required String vaultId,
    required String deviceId,
    this.protocolVersion = const Value.absent(),
    this.lastSuccessAt = const Value.absent(),
    this.enabled = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : vaultId = Value(vaultId),
        deviceId = Value(deviceId);
  static Insertable<SyncStateData> custom({
    Expression<String>? vaultId,
    Expression<String>? deviceId,
    Expression<int>? protocolVersion,
    Expression<DateTime>? lastSuccessAt,
    Expression<bool>? enabled,
    Expression<String>? lastError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (vaultId != null) 'vault_id': vaultId,
      if (deviceId != null) 'device_id': deviceId,
      if (protocolVersion != null) 'protocol_version': protocolVersion,
      if (lastSuccessAt != null) 'last_success_at': lastSuccessAt,
      if (enabled != null) 'enabled': enabled,
      if (lastError != null) 'last_error': lastError,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStateCompanion copyWith(
      {Value<String>? vaultId,
      Value<String>? deviceId,
      Value<int>? protocolVersion,
      Value<DateTime?>? lastSuccessAt,
      Value<bool>? enabled,
      Value<String?>? lastError,
      Value<int>? rowid}) {
    return SyncStateCompanion(
      vaultId: vaultId ?? this.vaultId,
      deviceId: deviceId ?? this.deviceId,
      protocolVersion: protocolVersion ?? this.protocolVersion,
      lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
      enabled: enabled ?? this.enabled,
      lastError: lastError ?? this.lastError,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (vaultId.present) {
      map['vault_id'] = Variable<String>(vaultId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (protocolVersion.present) {
      map['protocol_version'] = Variable<int>(protocolVersion.value);
    }
    if (lastSuccessAt.present) {
      map['last_success_at'] = Variable<DateTime>(lastSuccessAt.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateCompanion(')
          ..write('vaultId: $vaultId, ')
          ..write('deviceId: $deviceId, ')
          ..write('protocolVersion: $protocolVersion, ')
          ..write('lastSuccessAt: $lastSuccessAt, ')
          ..write('enabled: $enabled, ')
          ..write('lastError: $lastError, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConflictsTable extends Conflicts
    with TableInfo<$ConflictsTable, Conflict> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConflictsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _entityIdMeta =
      const VerificationMeta('entityId');
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
      'entity_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _entityTypeMeta =
      const VerificationMeta('entityType');
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
      'entity_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _headRevisionIdsJsonMeta =
      const VerificationMeta('headRevisionIdsJson');
  @override
  late final GeneratedColumn<String> headRevisionIdsJson =
      GeneratedColumn<String>('head_revision_ids_json', aliasedName, false,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          defaultValue: const Constant('[]'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _resolutionRevisionIdMeta =
      const VerificationMeta('resolutionRevisionId');
  @override
  late final GeneratedColumn<String> resolutionRevisionId =
      GeneratedColumn<String>('resolution_revision_id', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _resolvedAtMeta =
      const VerificationMeta('resolvedAt');
  @override
  late final GeneratedColumn<DateTime> resolvedAt = GeneratedColumn<DateTime>(
      'resolved_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        entityId,
        entityType,
        headRevisionIdsJson,
        createdAt,
        resolutionRevisionId,
        resolvedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conflicts';
  @override
  VerificationContext validateIntegrity(Insertable<Conflict> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(_entityIdMeta,
          entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta));
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
          _entityTypeMeta,
          entityType.isAcceptableOrUnknown(
              data['entity_type']!, _entityTypeMeta));
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('head_revision_ids_json')) {
      context.handle(
          _headRevisionIdsJsonMeta,
          headRevisionIdsJson.isAcceptableOrUnknown(
              data['head_revision_ids_json']!, _headRevisionIdsJsonMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('resolution_revision_id')) {
      context.handle(
          _resolutionRevisionIdMeta,
          resolutionRevisionId.isAcceptableOrUnknown(
              data['resolution_revision_id']!, _resolutionRevisionIdMeta));
    }
    if (data.containsKey('resolved_at')) {
      context.handle(
          _resolvedAtMeta,
          resolvedAt.isAcceptableOrUnknown(
              data['resolved_at']!, _resolvedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Conflict map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Conflict(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      entityId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_id'])!,
      entityType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_type'])!,
      headRevisionIdsJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}head_revision_ids_json'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      resolutionRevisionId: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}resolution_revision_id']),
      resolvedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}resolved_at']),
    );
  }

  @override
  $ConflictsTable createAlias(String alias) {
    return $ConflictsTable(attachedDatabase, alias);
  }
}

class Conflict extends DataClass implements Insertable<Conflict> {
  final String id;
  final String entityId;
  final String entityType;
  final String headRevisionIdsJson;
  final DateTime createdAt;
  final String? resolutionRevisionId;
  final DateTime? resolvedAt;
  const Conflict(
      {required this.id,
      required this.entityId,
      required this.entityType,
      required this.headRevisionIdsJson,
      required this.createdAt,
      this.resolutionRevisionId,
      this.resolvedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['entity_id'] = Variable<String>(entityId);
    map['entity_type'] = Variable<String>(entityType);
    map['head_revision_ids_json'] = Variable<String>(headRevisionIdsJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || resolutionRevisionId != null) {
      map['resolution_revision_id'] = Variable<String>(resolutionRevisionId);
    }
    if (!nullToAbsent || resolvedAt != null) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt);
    }
    return map;
  }

  ConflictsCompanion toCompanion(bool nullToAbsent) {
    return ConflictsCompanion(
      id: Value(id),
      entityId: Value(entityId),
      entityType: Value(entityType),
      headRevisionIdsJson: Value(headRevisionIdsJson),
      createdAt: Value(createdAt),
      resolutionRevisionId: resolutionRevisionId == null && nullToAbsent
          ? const Value.absent()
          : Value(resolutionRevisionId),
      resolvedAt: resolvedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedAt),
    );
  }

  factory Conflict.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Conflict(
      id: serializer.fromJson<String>(json['id']),
      entityId: serializer.fromJson<String>(json['entityId']),
      entityType: serializer.fromJson<String>(json['entityType']),
      headRevisionIdsJson:
          serializer.fromJson<String>(json['headRevisionIdsJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      resolutionRevisionId:
          serializer.fromJson<String?>(json['resolutionRevisionId']),
      resolvedAt: serializer.fromJson<DateTime?>(json['resolvedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'entityId': serializer.toJson<String>(entityId),
      'entityType': serializer.toJson<String>(entityType),
      'headRevisionIdsJson': serializer.toJson<String>(headRevisionIdsJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'resolutionRevisionId': serializer.toJson<String?>(resolutionRevisionId),
      'resolvedAt': serializer.toJson<DateTime?>(resolvedAt),
    };
  }

  Conflict copyWith(
          {String? id,
          String? entityId,
          String? entityType,
          String? headRevisionIdsJson,
          DateTime? createdAt,
          Value<String?> resolutionRevisionId = const Value.absent(),
          Value<DateTime?> resolvedAt = const Value.absent()}) =>
      Conflict(
        id: id ?? this.id,
        entityId: entityId ?? this.entityId,
        entityType: entityType ?? this.entityType,
        headRevisionIdsJson: headRevisionIdsJson ?? this.headRevisionIdsJson,
        createdAt: createdAt ?? this.createdAt,
        resolutionRevisionId: resolutionRevisionId.present
            ? resolutionRevisionId.value
            : this.resolutionRevisionId,
        resolvedAt: resolvedAt.present ? resolvedAt.value : this.resolvedAt,
      );
  Conflict copyWithCompanion(ConflictsCompanion data) {
    return Conflict(
      id: data.id.present ? data.id.value : this.id,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      entityType:
          data.entityType.present ? data.entityType.value : this.entityType,
      headRevisionIdsJson: data.headRevisionIdsJson.present
          ? data.headRevisionIdsJson.value
          : this.headRevisionIdsJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      resolutionRevisionId: data.resolutionRevisionId.present
          ? data.resolutionRevisionId.value
          : this.resolutionRevisionId,
      resolvedAt:
          data.resolvedAt.present ? data.resolvedAt.value : this.resolvedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Conflict(')
          ..write('id: $id, ')
          ..write('entityId: $entityId, ')
          ..write('entityType: $entityType, ')
          ..write('headRevisionIdsJson: $headRevisionIdsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('resolutionRevisionId: $resolutionRevisionId, ')
          ..write('resolvedAt: $resolvedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, entityId, entityType, headRevisionIdsJson,
      createdAt, resolutionRevisionId, resolvedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Conflict &&
          other.id == this.id &&
          other.entityId == this.entityId &&
          other.entityType == this.entityType &&
          other.headRevisionIdsJson == this.headRevisionIdsJson &&
          other.createdAt == this.createdAt &&
          other.resolutionRevisionId == this.resolutionRevisionId &&
          other.resolvedAt == this.resolvedAt);
}

class ConflictsCompanion extends UpdateCompanion<Conflict> {
  final Value<String> id;
  final Value<String> entityId;
  final Value<String> entityType;
  final Value<String> headRevisionIdsJson;
  final Value<DateTime> createdAt;
  final Value<String?> resolutionRevisionId;
  final Value<DateTime?> resolvedAt;
  final Value<int> rowid;
  const ConflictsCompanion({
    this.id = const Value.absent(),
    this.entityId = const Value.absent(),
    this.entityType = const Value.absent(),
    this.headRevisionIdsJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.resolutionRevisionId = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConflictsCompanion.insert({
    required String id,
    required String entityId,
    required String entityType,
    this.headRevisionIdsJson = const Value.absent(),
    required DateTime createdAt,
    this.resolutionRevisionId = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        entityId = Value(entityId),
        entityType = Value(entityType),
        createdAt = Value(createdAt);
  static Insertable<Conflict> custom({
    Expression<String>? id,
    Expression<String>? entityId,
    Expression<String>? entityType,
    Expression<String>? headRevisionIdsJson,
    Expression<DateTime>? createdAt,
    Expression<String>? resolutionRevisionId,
    Expression<DateTime>? resolvedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityId != null) 'entity_id': entityId,
      if (entityType != null) 'entity_type': entityType,
      if (headRevisionIdsJson != null)
        'head_revision_ids_json': headRevisionIdsJson,
      if (createdAt != null) 'created_at': createdAt,
      if (resolutionRevisionId != null)
        'resolution_revision_id': resolutionRevisionId,
      if (resolvedAt != null) 'resolved_at': resolvedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConflictsCompanion copyWith(
      {Value<String>? id,
      Value<String>? entityId,
      Value<String>? entityType,
      Value<String>? headRevisionIdsJson,
      Value<DateTime>? createdAt,
      Value<String?>? resolutionRevisionId,
      Value<DateTime?>? resolvedAt,
      Value<int>? rowid}) {
    return ConflictsCompanion(
      id: id ?? this.id,
      entityId: entityId ?? this.entityId,
      entityType: entityType ?? this.entityType,
      headRevisionIdsJson: headRevisionIdsJson ?? this.headRevisionIdsJson,
      createdAt: createdAt ?? this.createdAt,
      resolutionRevisionId: resolutionRevisionId ?? this.resolutionRevisionId,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (headRevisionIdsJson.present) {
      map['head_revision_ids_json'] =
          Variable<String>(headRevisionIdsJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (resolutionRevisionId.present) {
      map['resolution_revision_id'] =
          Variable<String>(resolutionRevisionId.value);
    }
    if (resolvedAt.present) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConflictsCompanion(')
          ..write('id: $id, ')
          ..write('entityId: $entityId, ')
          ..write('entityType: $entityType, ')
          ..write('headRevisionIdsJson: $headRevisionIdsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('resolutionRevisionId: $resolutionRevisionId, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncSkippedTable extends SyncSkipped
    with TableInfo<$SyncSkippedTable, SyncSkippedData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncSkippedTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _revisionIdMeta =
      const VerificationMeta('revisionId');
  @override
  late final GeneratedColumn<String> revisionId = GeneratedColumn<String>(
      'revision_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
      'reason', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _skippedAtMeta =
      const VerificationMeta('skippedAt');
  @override
  late final GeneratedColumn<DateTime> skippedAt = GeneratedColumn<DateTime>(
      'skipped_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [revisionId, reason, skippedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_skipped';
  @override
  VerificationContext validateIntegrity(Insertable<SyncSkippedData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('revision_id')) {
      context.handle(
          _revisionIdMeta,
          revisionId.isAcceptableOrUnknown(
              data['revision_id']!, _revisionIdMeta));
    } else if (isInserting) {
      context.missing(_revisionIdMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(_reasonMeta,
          reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta));
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('skipped_at')) {
      context.handle(_skippedAtMeta,
          skippedAt.isAcceptableOrUnknown(data['skipped_at']!, _skippedAtMeta));
    } else if (isInserting) {
      context.missing(_skippedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {revisionId};
  @override
  SyncSkippedData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncSkippedData(
      revisionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}revision_id'])!,
      reason: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reason'])!,
      skippedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}skipped_at'])!,
    );
  }

  @override
  $SyncSkippedTable createAlias(String alias) {
    return $SyncSkippedTable(attachedDatabase, alias);
  }
}

class SyncSkippedData extends DataClass implements Insertable<SyncSkippedData> {
  final String revisionId;
  final String reason;
  final DateTime skippedAt;
  const SyncSkippedData(
      {required this.revisionId,
      required this.reason,
      required this.skippedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['revision_id'] = Variable<String>(revisionId);
    map['reason'] = Variable<String>(reason);
    map['skipped_at'] = Variable<DateTime>(skippedAt);
    return map;
  }

  SyncSkippedCompanion toCompanion(bool nullToAbsent) {
    return SyncSkippedCompanion(
      revisionId: Value(revisionId),
      reason: Value(reason),
      skippedAt: Value(skippedAt),
    );
  }

  factory SyncSkippedData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncSkippedData(
      revisionId: serializer.fromJson<String>(json['revisionId']),
      reason: serializer.fromJson<String>(json['reason']),
      skippedAt: serializer.fromJson<DateTime>(json['skippedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'revisionId': serializer.toJson<String>(revisionId),
      'reason': serializer.toJson<String>(reason),
      'skippedAt': serializer.toJson<DateTime>(skippedAt),
    };
  }

  SyncSkippedData copyWith(
          {String? revisionId, String? reason, DateTime? skippedAt}) =>
      SyncSkippedData(
        revisionId: revisionId ?? this.revisionId,
        reason: reason ?? this.reason,
        skippedAt: skippedAt ?? this.skippedAt,
      );
  SyncSkippedData copyWithCompanion(SyncSkippedCompanion data) {
    return SyncSkippedData(
      revisionId:
          data.revisionId.present ? data.revisionId.value : this.revisionId,
      reason: data.reason.present ? data.reason.value : this.reason,
      skippedAt: data.skippedAt.present ? data.skippedAt.value : this.skippedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncSkippedData(')
          ..write('revisionId: $revisionId, ')
          ..write('reason: $reason, ')
          ..write('skippedAt: $skippedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(revisionId, reason, skippedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncSkippedData &&
          other.revisionId == this.revisionId &&
          other.reason == this.reason &&
          other.skippedAt == this.skippedAt);
}

class SyncSkippedCompanion extends UpdateCompanion<SyncSkippedData> {
  final Value<String> revisionId;
  final Value<String> reason;
  final Value<DateTime> skippedAt;
  final Value<int> rowid;
  const SyncSkippedCompanion({
    this.revisionId = const Value.absent(),
    this.reason = const Value.absent(),
    this.skippedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncSkippedCompanion.insert({
    required String revisionId,
    required String reason,
    required DateTime skippedAt,
    this.rowid = const Value.absent(),
  })  : revisionId = Value(revisionId),
        reason = Value(reason),
        skippedAt = Value(skippedAt);
  static Insertable<SyncSkippedData> custom({
    Expression<String>? revisionId,
    Expression<String>? reason,
    Expression<DateTime>? skippedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (revisionId != null) 'revision_id': revisionId,
      if (reason != null) 'reason': reason,
      if (skippedAt != null) 'skipped_at': skippedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncSkippedCompanion copyWith(
      {Value<String>? revisionId,
      Value<String>? reason,
      Value<DateTime>? skippedAt,
      Value<int>? rowid}) {
    return SyncSkippedCompanion(
      revisionId: revisionId ?? this.revisionId,
      reason: reason ?? this.reason,
      skippedAt: skippedAt ?? this.skippedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (revisionId.present) {
      map['revision_id'] = Variable<String>(revisionId.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (skippedAt.present) {
      map['skipped_at'] = Variable<DateTime>(skippedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncSkippedCompanion(')
          ..write('revisionId: $revisionId, ')
          ..write('reason: $reason, ')
          ..write('skippedAt: $skippedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $RecordsTable records = $RecordsTable(this);
  late final $TagsTable tags = $TagsTable(this);
  late final $RecordTagsTable recordTags = $RecordTagsTable(this);
  late final $RevisionsTable revisions = $RevisionsTable(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $RemoteReceiptsTable remoteReceipts = $RemoteReceiptsTable(this);
  late final $SyncStateTable syncState = $SyncStateTable(this);
  late final $ConflictsTable conflicts = $ConflictsTable(this);
  late final $SyncSkippedTable syncSkipped = $SyncSkippedTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        categories,
        records,
        tags,
        recordTags,
        revisions,
        outbox,
        remoteReceipts,
        syncState,
        conflicts,
        syncSkipped
      ];
}

typedef $$CategoriesTableCreateCompanionBuilder = CategoriesCompanion Function({
  required String id,
  required String name,
  Value<String> color,
  Value<String?> keywords,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$CategoriesTableUpdateCompanionBuilder = CategoriesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> color,
  Value<String?> keywords,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

final class $$CategoriesTableReferences
    extends BaseReferences<_$AppDatabase, $CategoriesTable, Category> {
  $$CategoriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$RecordsTable, List<Record>> _recordsRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.records,
          aliasName: 'categories__id__records__category_id');

  $$RecordsTableProcessedTableManager get recordsRefs {
    final manager = $$RecordsTableTableManager($_db, $_db.records)
        .filter((f) => f.categoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_recordsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$CategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get keywords => $composableBuilder(
      column: $table.keywords, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> recordsRefs(
      Expression<bool> Function($$RecordsTableFilterComposer f) f) {
    final $$RecordsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.records,
        getReferencedColumn: (t) => t.categoryId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RecordsTableFilterComposer(
              $db: $db,
              $table: $db.records,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get keywords => $composableBuilder(
      column: $table.keywords, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get keywords =>
      $composableBuilder(column: $table.keywords, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  Expression<T> recordsRefs<T extends Object>(
      Expression<T> Function($$RecordsTableAnnotationComposer a) f) {
    final $$RecordsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.records,
        getReferencedColumn: (t) => t.categoryId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RecordsTableAnnotationComposer(
              $db: $db,
              $table: $db.records,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$CategoriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CategoriesTable,
    Category,
    $$CategoriesTableFilterComposer,
    $$CategoriesTableOrderingComposer,
    $$CategoriesTableAnnotationComposer,
    $$CategoriesTableCreateCompanionBuilder,
    $$CategoriesTableUpdateCompanionBuilder,
    (Category, $$CategoriesTableReferences),
    Category,
    PrefetchHooks Function({bool recordsRefs})> {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> color = const Value.absent(),
            Value<String?> keywords = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CategoriesCompanion(
            id: id,
            name: name,
            color: color,
            keywords: keywords,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<String> color = const Value.absent(),
            Value<String?> keywords = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CategoriesCompanion.insert(
            id: id,
            name: name,
            color: color,
            keywords: keywords,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$CategoriesTable, Category>(table),
                    $$CategoriesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({recordsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (recordsRefs) db.records],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (recordsRefs)
                    await $_getPrefetchedData<Category, $CategoriesTable,
                            Record>(
                        currentTable: table,
                        referencedTable:
                            $$CategoriesTableReferences._recordsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$CategoriesTableReferences(db, table, p0)
                                .recordsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.categoryId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$CategoriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CategoriesTable,
    Category,
    $$CategoriesTableFilterComposer,
    $$CategoriesTableOrderingComposer,
    $$CategoriesTableAnnotationComposer,
    $$CategoriesTableCreateCompanionBuilder,
    $$CategoriesTableUpdateCompanionBuilder,
    (Category, $$CategoriesTableReferences),
    Category,
    PrefetchHooks Function({bool recordsRefs})>;
typedef $$RecordsTableCreateCompanionBuilder = RecordsCompanion Function({
  required String id,
  Value<String> title,
  Value<String> body,
  Value<String?> categoryId,
  Value<bool> isFavorite,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<int?> localSeq,
  Value<int> rowid,
});
typedef $$RecordsTableUpdateCompanionBuilder = RecordsCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<String> body,
  Value<String?> categoryId,
  Value<bool> isFavorite,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int?> localSeq,
  Value<int> rowid,
});

final class $$RecordsTableReferences
    extends BaseReferences<_$AppDatabase, $RecordsTable, Record> {
  $$RecordsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) =>
      db.categories.createAlias('records__category_id__categories__id');

  $$CategoriesTableProcessedTableManager? get categoryId {
    final $_column = $_itemColumn<String>('category_id');
    if ($_column == null) return null;
    final manager = $$CategoriesTableTableManager($_db, $_db.categories)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$RecordTagsTable, List<RecordTag>>
      _recordTagsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.recordTags,
              aliasName: 'records__id__record_tags__record_id');

  $$RecordTagsTableProcessedTableManager get recordTagsRefs {
    final manager = $$RecordTagsTableTableManager($_db, $_db.recordTags)
        .filter((f) => f.recordId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_recordTagsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$RecordsTableFilterComposer
    extends Composer<_$AppDatabase, $RecordsTable> {
  $$RecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get localSeq => $composableBuilder(
      column: $table.localSeq, builder: (column) => ColumnFilters(column));

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.categoryId,
        referencedTable: $db.categories,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CategoriesTableFilterComposer(
              $db: $db,
              $table: $db.categories,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> recordTagsRefs(
      Expression<bool> Function($$RecordTagsTableFilterComposer f) f) {
    final $$RecordTagsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.recordTags,
        getReferencedColumn: (t) => t.recordId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RecordTagsTableFilterComposer(
              $db: $db,
              $table: $db.recordTags,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$RecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $RecordsTable> {
  $$RecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get localSeq => $composableBuilder(
      column: $table.localSeq, builder: (column) => ColumnOrderings(column));

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.categoryId,
        referencedTable: $db.categories,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CategoriesTableOrderingComposer(
              $db: $db,
              $table: $db.categories,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$RecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecordsTable> {
  $$RecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get localSeq =>
      $composableBuilder(column: $table.localSeq, builder: (column) => column);

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.categoryId,
        referencedTable: $db.categories,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CategoriesTableAnnotationComposer(
              $db: $db,
              $table: $db.categories,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> recordTagsRefs<T extends Object>(
      Expression<T> Function($$RecordTagsTableAnnotationComposer a) f) {
    final $$RecordTagsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.recordTags,
        getReferencedColumn: (t) => t.recordId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RecordTagsTableAnnotationComposer(
              $db: $db,
              $table: $db.recordTags,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$RecordsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RecordsTable,
    Record,
    $$RecordsTableFilterComposer,
    $$RecordsTableOrderingComposer,
    $$RecordsTableAnnotationComposer,
    $$RecordsTableCreateCompanionBuilder,
    $$RecordsTableUpdateCompanionBuilder,
    (Record, $$RecordsTableReferences),
    Record,
    PrefetchHooks Function({bool categoryId, bool recordTagsRefs})> {
  $$RecordsTableTableManager(_$AppDatabase db, $RecordsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> body = const Value.absent(),
            Value<String?> categoryId = const Value.absent(),
            Value<bool> isFavorite = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int?> localSeq = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RecordsCompanion(
            id: id,
            title: title,
            body: body,
            categoryId: categoryId,
            isFavorite: isFavorite,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            localSeq: localSeq,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String> title = const Value.absent(),
            Value<String> body = const Value.absent(),
            Value<String?> categoryId = const Value.absent(),
            Value<bool> isFavorite = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int?> localSeq = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RecordsCompanion.insert(
            id: id,
            title: title,
            body: body,
            categoryId: categoryId,
            isFavorite: isFavorite,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            localSeq: localSeq,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$RecordsTable, Record>(table),
                    $$RecordsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {categoryId = false, recordTagsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (recordTagsRefs) db.recordTags],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (categoryId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.categoryId,
                    referencedTable:
                        $$RecordsTableReferences._categoryIdTable(db),
                    referencedColumn:
                        $$RecordsTableReferences._categoryIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (recordTagsRefs)
                    await $_getPrefetchedData<Record, $RecordsTable, RecordTag>(
                        currentTable: table,
                        referencedTable:
                            $$RecordsTableReferences._recordTagsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$RecordsTableReferences(db, table, p0)
                                .recordTagsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.recordId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$RecordsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $RecordsTable,
    Record,
    $$RecordsTableFilterComposer,
    $$RecordsTableOrderingComposer,
    $$RecordsTableAnnotationComposer,
    $$RecordsTableCreateCompanionBuilder,
    $$RecordsTableUpdateCompanionBuilder,
    (Record, $$RecordsTableReferences),
    Record,
    PrefetchHooks Function({bool categoryId, bool recordTagsRefs})>;
typedef $$TagsTableCreateCompanionBuilder = TagsCompanion Function({
  required String id,
  required String name,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$TagsTableUpdateCompanionBuilder = TagsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

final class $$TagsTableReferences
    extends BaseReferences<_$AppDatabase, $TagsTable, Tag> {
  $$TagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$RecordTagsTable, List<RecordTag>>
      _recordTagsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.recordTags,
              aliasName: 'tags__id__record_tags__tag_id');

  $$RecordTagsTableProcessedTableManager get recordTagsRefs {
    final manager = $$RecordTagsTableTableManager($_db, $_db.recordTags)
        .filter((f) => f.tagId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_recordTagsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$TagsTableFilterComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> recordTagsRefs(
      Expression<bool> Function($$RecordTagsTableFilterComposer f) f) {
    final $$RecordTagsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.recordTags,
        getReferencedColumn: (t) => t.tagId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RecordTagsTableFilterComposer(
              $db: $db,
              $table: $db.recordTags,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$TagsTableOrderingComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
}

class $$TagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  Expression<T> recordTagsRefs<T extends Object>(
      Expression<T> Function($$RecordTagsTableAnnotationComposer a) f) {
    final $$RecordTagsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.recordTags,
        getReferencedColumn: (t) => t.tagId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RecordTagsTableAnnotationComposer(
              $db: $db,
              $table: $db.recordTags,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$TagsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TagsTable,
    Tag,
    $$TagsTableFilterComposer,
    $$TagsTableOrderingComposer,
    $$TagsTableAnnotationComposer,
    $$TagsTableCreateCompanionBuilder,
    $$TagsTableUpdateCompanionBuilder,
    (Tag, $$TagsTableReferences),
    Tag,
    PrefetchHooks Function({bool recordTagsRefs})> {
  $$TagsTableTableManager(_$AppDatabase db, $TagsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TagsCompanion(
            id: id,
            name: name,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TagsCompanion.insert(
            id: id,
            name: name,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$TagsTable, Tag>(table),
                    $$TagsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({recordTagsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (recordTagsRefs) db.recordTags],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (recordTagsRefs)
                    await $_getPrefetchedData<Tag, $TagsTable, RecordTag>(
                        currentTable: table,
                        referencedTable:
                            $$TagsTableReferences._recordTagsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$TagsTableReferences(db, table, p0).recordTagsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.tagId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$TagsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TagsTable,
    Tag,
    $$TagsTableFilterComposer,
    $$TagsTableOrderingComposer,
    $$TagsTableAnnotationComposer,
    $$TagsTableCreateCompanionBuilder,
    $$TagsTableUpdateCompanionBuilder,
    (Tag, $$TagsTableReferences),
    Tag,
    PrefetchHooks Function({bool recordTagsRefs})>;
typedef $$RecordTagsTableCreateCompanionBuilder = RecordTagsCompanion Function({
  required String recordId,
  required String tagId,
  Value<int> rowid,
});
typedef $$RecordTagsTableUpdateCompanionBuilder = RecordTagsCompanion Function({
  Value<String> recordId,
  Value<String> tagId,
  Value<int> rowid,
});

final class $$RecordTagsTableReferences
    extends BaseReferences<_$AppDatabase, $RecordTagsTable, RecordTag> {
  $$RecordTagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RecordsTable _recordIdTable(_$AppDatabase db) =>
      db.records.createAlias('record_tags__record_id__records__id');

  $$RecordsTableProcessedTableManager get recordId {
    final $_column = $_itemColumn<String>('record_id')!;

    final manager = $$RecordsTableTableManager($_db, $_db.records)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_recordIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $TagsTable _tagIdTable(_$AppDatabase db) =>
      db.tags.createAlias('record_tags__tag_id__tags__id');

  $$TagsTableProcessedTableManager get tagId {
    final $_column = $_itemColumn<String>('tag_id')!;

    final manager = $$TagsTableTableManager($_db, $_db.tags)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tagIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$RecordTagsTableFilterComposer
    extends Composer<_$AppDatabase, $RecordTagsTable> {
  $$RecordTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$RecordsTableFilterComposer get recordId {
    final $$RecordsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.recordId,
        referencedTable: $db.records,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RecordsTableFilterComposer(
              $db: $db,
              $table: $db.records,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$TagsTableFilterComposer get tagId {
    final $$TagsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.tagId,
        referencedTable: $db.tags,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TagsTableFilterComposer(
              $db: $db,
              $table: $db.tags,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$RecordTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $RecordTagsTable> {
  $$RecordTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$RecordsTableOrderingComposer get recordId {
    final $$RecordsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.recordId,
        referencedTable: $db.records,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RecordsTableOrderingComposer(
              $db: $db,
              $table: $db.records,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$TagsTableOrderingComposer get tagId {
    final $$TagsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.tagId,
        referencedTable: $db.tags,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TagsTableOrderingComposer(
              $db: $db,
              $table: $db.tags,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$RecordTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecordTagsTable> {
  $$RecordTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$RecordsTableAnnotationComposer get recordId {
    final $$RecordsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.recordId,
        referencedTable: $db.records,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RecordsTableAnnotationComposer(
              $db: $db,
              $table: $db.records,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$TagsTableAnnotationComposer get tagId {
    final $$TagsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.tagId,
        referencedTable: $db.tags,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TagsTableAnnotationComposer(
              $db: $db,
              $table: $db.tags,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$RecordTagsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RecordTagsTable,
    RecordTag,
    $$RecordTagsTableFilterComposer,
    $$RecordTagsTableOrderingComposer,
    $$RecordTagsTableAnnotationComposer,
    $$RecordTagsTableCreateCompanionBuilder,
    $$RecordTagsTableUpdateCompanionBuilder,
    (RecordTag, $$RecordTagsTableReferences),
    RecordTag,
    PrefetchHooks Function({bool recordId, bool tagId})> {
  $$RecordTagsTableTableManager(_$AppDatabase db, $RecordTagsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecordTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecordTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecordTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> recordId = const Value.absent(),
            Value<String> tagId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RecordTagsCompanion(
            recordId: recordId,
            tagId: tagId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String recordId,
            required String tagId,
            Value<int> rowid = const Value.absent(),
          }) =>
              RecordTagsCompanion.insert(
            recordId: recordId,
            tagId: tagId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$RecordTagsTable, RecordTag>(table),
                    $$RecordTagsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({recordId = false, tagId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (recordId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.recordId,
                    referencedTable:
                        $$RecordTagsTableReferences._recordIdTable(db),
                    referencedColumn:
                        $$RecordTagsTableReferences._recordIdTable(db).id,
                  ) as T;
                }
                if (tagId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.tagId,
                    referencedTable:
                        $$RecordTagsTableReferences._tagIdTable(db),
                    referencedColumn:
                        $$RecordTagsTableReferences._tagIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$RecordTagsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $RecordTagsTable,
    RecordTag,
    $$RecordTagsTableFilterComposer,
    $$RecordTagsTableOrderingComposer,
    $$RecordTagsTableAnnotationComposer,
    $$RecordTagsTableCreateCompanionBuilder,
    $$RecordTagsTableUpdateCompanionBuilder,
    (RecordTag, $$RecordTagsTableReferences),
    RecordTag,
    PrefetchHooks Function({bool recordId, bool tagId})>;
typedef $$RevisionsTableCreateCompanionBuilder = RevisionsCompanion Function({
  required String revisionId,
  required String entityType,
  required String entityId,
  Value<String> parentsJson,
  required String payloadJson,
  required DateTime createdAt,
  required DateTime receivedAt,
  Value<bool> isLocal,
  Value<int> rowid,
});
typedef $$RevisionsTableUpdateCompanionBuilder = RevisionsCompanion Function({
  Value<String> revisionId,
  Value<String> entityType,
  Value<String> entityId,
  Value<String> parentsJson,
  Value<String> payloadJson,
  Value<DateTime> createdAt,
  Value<DateTime> receivedAt,
  Value<bool> isLocal,
  Value<int> rowid,
});

class $$RevisionsTableFilterComposer
    extends Composer<_$AppDatabase, $RevisionsTable> {
  $$RevisionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get revisionId => $composableBuilder(
      column: $table.revisionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get parentsJson => $composableBuilder(
      column: $table.parentsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get receivedAt => $composableBuilder(
      column: $table.receivedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isLocal => $composableBuilder(
      column: $table.isLocal, builder: (column) => ColumnFilters(column));
}

class $$RevisionsTableOrderingComposer
    extends Composer<_$AppDatabase, $RevisionsTable> {
  $$RevisionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get revisionId => $composableBuilder(
      column: $table.revisionId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get parentsJson => $composableBuilder(
      column: $table.parentsJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get receivedAt => $composableBuilder(
      column: $table.receivedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isLocal => $composableBuilder(
      column: $table.isLocal, builder: (column) => ColumnOrderings(column));
}

class $$RevisionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RevisionsTable> {
  $$RevisionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get revisionId => $composableBuilder(
      column: $table.revisionId, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get parentsJson => $composableBuilder(
      column: $table.parentsJson, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get receivedAt => $composableBuilder(
      column: $table.receivedAt, builder: (column) => column);

  GeneratedColumn<bool> get isLocal =>
      $composableBuilder(column: $table.isLocal, builder: (column) => column);
}

class $$RevisionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RevisionsTable,
    Revision,
    $$RevisionsTableFilterComposer,
    $$RevisionsTableOrderingComposer,
    $$RevisionsTableAnnotationComposer,
    $$RevisionsTableCreateCompanionBuilder,
    $$RevisionsTableUpdateCompanionBuilder,
    (Revision, BaseReferences<_$AppDatabase, $RevisionsTable, Revision>),
    Revision,
    PrefetchHooks Function()> {
  $$RevisionsTableTableManager(_$AppDatabase db, $RevisionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RevisionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RevisionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RevisionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> revisionId = const Value.absent(),
            Value<String> entityType = const Value.absent(),
            Value<String> entityId = const Value.absent(),
            Value<String> parentsJson = const Value.absent(),
            Value<String> payloadJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> receivedAt = const Value.absent(),
            Value<bool> isLocal = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RevisionsCompanion(
            revisionId: revisionId,
            entityType: entityType,
            entityId: entityId,
            parentsJson: parentsJson,
            payloadJson: payloadJson,
            createdAt: createdAt,
            receivedAt: receivedAt,
            isLocal: isLocal,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String revisionId,
            required String entityType,
            required String entityId,
            Value<String> parentsJson = const Value.absent(),
            required String payloadJson,
            required DateTime createdAt,
            required DateTime receivedAt,
            Value<bool> isLocal = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RevisionsCompanion.insert(
            revisionId: revisionId,
            entityType: entityType,
            entityId: entityId,
            parentsJson: parentsJson,
            payloadJson: payloadJson,
            createdAt: createdAt,
            receivedAt: receivedAt,
            isLocal: isLocal,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$RevisionsTable, Revision>(table),
                    BaseReferences<_$AppDatabase, $RevisionsTable, Revision>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$RevisionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $RevisionsTable,
    Revision,
    $$RevisionsTableFilterComposer,
    $$RevisionsTableOrderingComposer,
    $$RevisionsTableAnnotationComposer,
    $$RevisionsTableCreateCompanionBuilder,
    $$RevisionsTableUpdateCompanionBuilder,
    (Revision, BaseReferences<_$AppDatabase, $RevisionsTable, Revision>),
    Revision,
    PrefetchHooks Function()>;
typedef $$OutboxTableCreateCompanionBuilder = OutboxCompanion Function({
  required String operationId,
  required String revisionId,
  Value<String> status,
  Value<int> attemptCount,
  Value<DateTime?> nextRetryAt,
  required DateTime createdAt,
  Value<String?> lastError,
  Value<int> rowid,
});
typedef $$OutboxTableUpdateCompanionBuilder = OutboxCompanion Function({
  Value<String> operationId,
  Value<String> revisionId,
  Value<String> status,
  Value<int> attemptCount,
  Value<DateTime?> nextRetryAt,
  Value<DateTime> createdAt,
  Value<String?> lastError,
  Value<int> rowid,
});

class $$OutboxTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get operationId => $composableBuilder(
      column: $table.operationId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get revisionId => $composableBuilder(
      column: $table.revisionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attemptCount => $composableBuilder(
      column: $table.attemptCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get nextRetryAt => $composableBuilder(
      column: $table.nextRetryAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnFilters(column));
}

class $$OutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get operationId => $composableBuilder(
      column: $table.operationId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get revisionId => $composableBuilder(
      column: $table.revisionId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attemptCount => $composableBuilder(
      column: $table.attemptCount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get nextRetryAt => $composableBuilder(
      column: $table.nextRetryAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnOrderings(column));
}

class $$OutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get operationId => $composableBuilder(
      column: $table.operationId, builder: (column) => column);

  GeneratedColumn<String> get revisionId => $composableBuilder(
      column: $table.revisionId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attemptCount => $composableBuilder(
      column: $table.attemptCount, builder: (column) => column);

  GeneratedColumn<DateTime> get nextRetryAt => $composableBuilder(
      column: $table.nextRetryAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$OutboxTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OutboxTable,
    OutboxData,
    $$OutboxTableFilterComposer,
    $$OutboxTableOrderingComposer,
    $$OutboxTableAnnotationComposer,
    $$OutboxTableCreateCompanionBuilder,
    $$OutboxTableUpdateCompanionBuilder,
    (OutboxData, BaseReferences<_$AppDatabase, $OutboxTable, OutboxData>),
    OutboxData,
    PrefetchHooks Function()> {
  $$OutboxTableTableManager(_$AppDatabase db, $OutboxTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> operationId = const Value.absent(),
            Value<String> revisionId = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> attemptCount = const Value.absent(),
            Value<DateTime?> nextRetryAt = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OutboxCompanion(
            operationId: operationId,
            revisionId: revisionId,
            status: status,
            attemptCount: attemptCount,
            nextRetryAt: nextRetryAt,
            createdAt: createdAt,
            lastError: lastError,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String operationId,
            required String revisionId,
            Value<String> status = const Value.absent(),
            Value<int> attemptCount = const Value.absent(),
            Value<DateTime?> nextRetryAt = const Value.absent(),
            required DateTime createdAt,
            Value<String?> lastError = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OutboxCompanion.insert(
            operationId: operationId,
            revisionId: revisionId,
            status: status,
            attemptCount: attemptCount,
            nextRetryAt: nextRetryAt,
            createdAt: createdAt,
            lastError: lastError,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$OutboxTable, OutboxData>(table),
                    BaseReferences<_$AppDatabase, $OutboxTable, OutboxData>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$OutboxTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $OutboxTable,
    OutboxData,
    $$OutboxTableFilterComposer,
    $$OutboxTableOrderingComposer,
    $$OutboxTableAnnotationComposer,
    $$OutboxTableCreateCompanionBuilder,
    $$OutboxTableUpdateCompanionBuilder,
    (OutboxData, BaseReferences<_$AppDatabase, $OutboxTable, OutboxData>),
    OutboxData,
    PrefetchHooks Function()>;
typedef $$RemoteReceiptsTableCreateCompanionBuilder = RemoteReceiptsCompanion
    Function({
  required String revisionId,
  required String remotePath,
  Value<String?> etag,
  required DateTime observedAt,
  Value<int> rowid,
});
typedef $$RemoteReceiptsTableUpdateCompanionBuilder = RemoteReceiptsCompanion
    Function({
  Value<String> revisionId,
  Value<String> remotePath,
  Value<String?> etag,
  Value<DateTime> observedAt,
  Value<int> rowid,
});

class $$RemoteReceiptsTableFilterComposer
    extends Composer<_$AppDatabase, $RemoteReceiptsTable> {
  $$RemoteReceiptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get revisionId => $composableBuilder(
      column: $table.revisionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get remotePath => $composableBuilder(
      column: $table.remotePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get etag => $composableBuilder(
      column: $table.etag, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get observedAt => $composableBuilder(
      column: $table.observedAt, builder: (column) => ColumnFilters(column));
}

class $$RemoteReceiptsTableOrderingComposer
    extends Composer<_$AppDatabase, $RemoteReceiptsTable> {
  $$RemoteReceiptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get revisionId => $composableBuilder(
      column: $table.revisionId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get remotePath => $composableBuilder(
      column: $table.remotePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get etag => $composableBuilder(
      column: $table.etag, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get observedAt => $composableBuilder(
      column: $table.observedAt, builder: (column) => ColumnOrderings(column));
}

class $$RemoteReceiptsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RemoteReceiptsTable> {
  $$RemoteReceiptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get revisionId => $composableBuilder(
      column: $table.revisionId, builder: (column) => column);

  GeneratedColumn<String> get remotePath => $composableBuilder(
      column: $table.remotePath, builder: (column) => column);

  GeneratedColumn<String> get etag =>
      $composableBuilder(column: $table.etag, builder: (column) => column);

  GeneratedColumn<DateTime> get observedAt => $composableBuilder(
      column: $table.observedAt, builder: (column) => column);
}

class $$RemoteReceiptsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RemoteReceiptsTable,
    RemoteReceipt,
    $$RemoteReceiptsTableFilterComposer,
    $$RemoteReceiptsTableOrderingComposer,
    $$RemoteReceiptsTableAnnotationComposer,
    $$RemoteReceiptsTableCreateCompanionBuilder,
    $$RemoteReceiptsTableUpdateCompanionBuilder,
    (
      RemoteReceipt,
      BaseReferences<_$AppDatabase, $RemoteReceiptsTable, RemoteReceipt>
    ),
    RemoteReceipt,
    PrefetchHooks Function()> {
  $$RemoteReceiptsTableTableManager(
      _$AppDatabase db, $RemoteReceiptsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RemoteReceiptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RemoteReceiptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RemoteReceiptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> revisionId = const Value.absent(),
            Value<String> remotePath = const Value.absent(),
            Value<String?> etag = const Value.absent(),
            Value<DateTime> observedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RemoteReceiptsCompanion(
            revisionId: revisionId,
            remotePath: remotePath,
            etag: etag,
            observedAt: observedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String revisionId,
            required String remotePath,
            Value<String?> etag = const Value.absent(),
            required DateTime observedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              RemoteReceiptsCompanion.insert(
            revisionId: revisionId,
            remotePath: remotePath,
            etag: etag,
            observedAt: observedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$RemoteReceiptsTable, RemoteReceipt>(table),
                    BaseReferences<_$AppDatabase, $RemoteReceiptsTable,
                        RemoteReceipt>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$RemoteReceiptsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $RemoteReceiptsTable,
    RemoteReceipt,
    $$RemoteReceiptsTableFilterComposer,
    $$RemoteReceiptsTableOrderingComposer,
    $$RemoteReceiptsTableAnnotationComposer,
    $$RemoteReceiptsTableCreateCompanionBuilder,
    $$RemoteReceiptsTableUpdateCompanionBuilder,
    (
      RemoteReceipt,
      BaseReferences<_$AppDatabase, $RemoteReceiptsTable, RemoteReceipt>
    ),
    RemoteReceipt,
    PrefetchHooks Function()>;
typedef $$SyncStateTableCreateCompanionBuilder = SyncStateCompanion Function({
  required String vaultId,
  required String deviceId,
  Value<int> protocolVersion,
  Value<DateTime?> lastSuccessAt,
  Value<bool> enabled,
  Value<String?> lastError,
  Value<int> rowid,
});
typedef $$SyncStateTableUpdateCompanionBuilder = SyncStateCompanion Function({
  Value<String> vaultId,
  Value<String> deviceId,
  Value<int> protocolVersion,
  Value<DateTime?> lastSuccessAt,
  Value<bool> enabled,
  Value<String?> lastError,
  Value<int> rowid,
});

class $$SyncStateTableFilterComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get vaultId => $composableBuilder(
      column: $table.vaultId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get protocolVersion => $composableBuilder(
      column: $table.protocolVersion,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastSuccessAt => $composableBuilder(
      column: $table.lastSuccessAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get enabled => $composableBuilder(
      column: $table.enabled, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnFilters(column));
}

class $$SyncStateTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get vaultId => $composableBuilder(
      column: $table.vaultId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get protocolVersion => $composableBuilder(
      column: $table.protocolVersion,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastSuccessAt => $composableBuilder(
      column: $table.lastSuccessAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get enabled => $composableBuilder(
      column: $table.enabled, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnOrderings(column));
}

class $$SyncStateTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get vaultId =>
      $composableBuilder(column: $table.vaultId, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get protocolVersion => $composableBuilder(
      column: $table.protocolVersion, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSuccessAt => $composableBuilder(
      column: $table.lastSuccessAt, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$SyncStateTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncStateTable,
    SyncStateData,
    $$SyncStateTableFilterComposer,
    $$SyncStateTableOrderingComposer,
    $$SyncStateTableAnnotationComposer,
    $$SyncStateTableCreateCompanionBuilder,
    $$SyncStateTableUpdateCompanionBuilder,
    (
      SyncStateData,
      BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateData>
    ),
    SyncStateData,
    PrefetchHooks Function()> {
  $$SyncStateTableTableManager(_$AppDatabase db, $SyncStateTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> vaultId = const Value.absent(),
            Value<String> deviceId = const Value.absent(),
            Value<int> protocolVersion = const Value.absent(),
            Value<DateTime?> lastSuccessAt = const Value.absent(),
            Value<bool> enabled = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncStateCompanion(
            vaultId: vaultId,
            deviceId: deviceId,
            protocolVersion: protocolVersion,
            lastSuccessAt: lastSuccessAt,
            enabled: enabled,
            lastError: lastError,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String vaultId,
            required String deviceId,
            Value<int> protocolVersion = const Value.absent(),
            Value<DateTime?> lastSuccessAt = const Value.absent(),
            Value<bool> enabled = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncStateCompanion.insert(
            vaultId: vaultId,
            deviceId: deviceId,
            protocolVersion: protocolVersion,
            lastSuccessAt: lastSuccessAt,
            enabled: enabled,
            lastError: lastError,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$SyncStateTable, SyncStateData>(table),
                    BaseReferences<_$AppDatabase, $SyncStateTable,
                        SyncStateData>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncStateTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncStateTable,
    SyncStateData,
    $$SyncStateTableFilterComposer,
    $$SyncStateTableOrderingComposer,
    $$SyncStateTableAnnotationComposer,
    $$SyncStateTableCreateCompanionBuilder,
    $$SyncStateTableUpdateCompanionBuilder,
    (
      SyncStateData,
      BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateData>
    ),
    SyncStateData,
    PrefetchHooks Function()>;
typedef $$ConflictsTableCreateCompanionBuilder = ConflictsCompanion Function({
  required String id,
  required String entityId,
  required String entityType,
  Value<String> headRevisionIdsJson,
  required DateTime createdAt,
  Value<String?> resolutionRevisionId,
  Value<DateTime?> resolvedAt,
  Value<int> rowid,
});
typedef $$ConflictsTableUpdateCompanionBuilder = ConflictsCompanion Function({
  Value<String> id,
  Value<String> entityId,
  Value<String> entityType,
  Value<String> headRevisionIdsJson,
  Value<DateTime> createdAt,
  Value<String?> resolutionRevisionId,
  Value<DateTime?> resolvedAt,
  Value<int> rowid,
});

class $$ConflictsTableFilterComposer
    extends Composer<_$AppDatabase, $ConflictsTable> {
  $$ConflictsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get headRevisionIdsJson => $composableBuilder(
      column: $table.headRevisionIdsJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get resolutionRevisionId => $composableBuilder(
      column: $table.resolutionRevisionId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get resolvedAt => $composableBuilder(
      column: $table.resolvedAt, builder: (column) => ColumnFilters(column));
}

class $$ConflictsTableOrderingComposer
    extends Composer<_$AppDatabase, $ConflictsTable> {
  $$ConflictsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get headRevisionIdsJson => $composableBuilder(
      column: $table.headRevisionIdsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get resolutionRevisionId => $composableBuilder(
      column: $table.resolutionRevisionId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get resolvedAt => $composableBuilder(
      column: $table.resolvedAt, builder: (column) => ColumnOrderings(column));
}

class $$ConflictsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConflictsTable> {
  $$ConflictsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => column);

  GeneratedColumn<String> get headRevisionIdsJson => $composableBuilder(
      column: $table.headRevisionIdsJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get resolutionRevisionId => $composableBuilder(
      column: $table.resolutionRevisionId, builder: (column) => column);

  GeneratedColumn<DateTime> get resolvedAt => $composableBuilder(
      column: $table.resolvedAt, builder: (column) => column);
}

class $$ConflictsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ConflictsTable,
    Conflict,
    $$ConflictsTableFilterComposer,
    $$ConflictsTableOrderingComposer,
    $$ConflictsTableAnnotationComposer,
    $$ConflictsTableCreateCompanionBuilder,
    $$ConflictsTableUpdateCompanionBuilder,
    (Conflict, BaseReferences<_$AppDatabase, $ConflictsTable, Conflict>),
    Conflict,
    PrefetchHooks Function()> {
  $$ConflictsTableTableManager(_$AppDatabase db, $ConflictsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConflictsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConflictsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConflictsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> entityId = const Value.absent(),
            Value<String> entityType = const Value.absent(),
            Value<String> headRevisionIdsJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String?> resolutionRevisionId = const Value.absent(),
            Value<DateTime?> resolvedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ConflictsCompanion(
            id: id,
            entityId: entityId,
            entityType: entityType,
            headRevisionIdsJson: headRevisionIdsJson,
            createdAt: createdAt,
            resolutionRevisionId: resolutionRevisionId,
            resolvedAt: resolvedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String entityId,
            required String entityType,
            Value<String> headRevisionIdsJson = const Value.absent(),
            required DateTime createdAt,
            Value<String?> resolutionRevisionId = const Value.absent(),
            Value<DateTime?> resolvedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ConflictsCompanion.insert(
            id: id,
            entityId: entityId,
            entityType: entityType,
            headRevisionIdsJson: headRevisionIdsJson,
            createdAt: createdAt,
            resolutionRevisionId: resolutionRevisionId,
            resolvedAt: resolvedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$ConflictsTable, Conflict>(table),
                    BaseReferences<_$AppDatabase, $ConflictsTable, Conflict>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ConflictsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ConflictsTable,
    Conflict,
    $$ConflictsTableFilterComposer,
    $$ConflictsTableOrderingComposer,
    $$ConflictsTableAnnotationComposer,
    $$ConflictsTableCreateCompanionBuilder,
    $$ConflictsTableUpdateCompanionBuilder,
    (Conflict, BaseReferences<_$AppDatabase, $ConflictsTable, Conflict>),
    Conflict,
    PrefetchHooks Function()>;
typedef $$SyncSkippedTableCreateCompanionBuilder = SyncSkippedCompanion
    Function({
  required String revisionId,
  required String reason,
  required DateTime skippedAt,
  Value<int> rowid,
});
typedef $$SyncSkippedTableUpdateCompanionBuilder = SyncSkippedCompanion
    Function({
  Value<String> revisionId,
  Value<String> reason,
  Value<DateTime> skippedAt,
  Value<int> rowid,
});

class $$SyncSkippedTableFilterComposer
    extends Composer<_$AppDatabase, $SyncSkippedTable> {
  $$SyncSkippedTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get revisionId => $composableBuilder(
      column: $table.revisionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reason => $composableBuilder(
      column: $table.reason, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get skippedAt => $composableBuilder(
      column: $table.skippedAt, builder: (column) => ColumnFilters(column));
}

class $$SyncSkippedTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncSkippedTable> {
  $$SyncSkippedTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get revisionId => $composableBuilder(
      column: $table.revisionId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reason => $composableBuilder(
      column: $table.reason, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get skippedAt => $composableBuilder(
      column: $table.skippedAt, builder: (column) => ColumnOrderings(column));
}

class $$SyncSkippedTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncSkippedTable> {
  $$SyncSkippedTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get revisionId => $composableBuilder(
      column: $table.revisionId, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<DateTime> get skippedAt =>
      $composableBuilder(column: $table.skippedAt, builder: (column) => column);
}

class $$SyncSkippedTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncSkippedTable,
    SyncSkippedData,
    $$SyncSkippedTableFilterComposer,
    $$SyncSkippedTableOrderingComposer,
    $$SyncSkippedTableAnnotationComposer,
    $$SyncSkippedTableCreateCompanionBuilder,
    $$SyncSkippedTableUpdateCompanionBuilder,
    (
      SyncSkippedData,
      BaseReferences<_$AppDatabase, $SyncSkippedTable, SyncSkippedData>
    ),
    SyncSkippedData,
    PrefetchHooks Function()> {
  $$SyncSkippedTableTableManager(_$AppDatabase db, $SyncSkippedTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncSkippedTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncSkippedTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncSkippedTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> revisionId = const Value.absent(),
            Value<String> reason = const Value.absent(),
            Value<DateTime> skippedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncSkippedCompanion(
            revisionId: revisionId,
            reason: reason,
            skippedAt: skippedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String revisionId,
            required String reason,
            required DateTime skippedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncSkippedCompanion.insert(
            revisionId: revisionId,
            reason: reason,
            skippedAt: skippedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$SyncSkippedTable, SyncSkippedData>(table),
                    BaseReferences<_$AppDatabase, $SyncSkippedTable,
                        SyncSkippedData>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncSkippedTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncSkippedTable,
    SyncSkippedData,
    $$SyncSkippedTableFilterComposer,
    $$SyncSkippedTableOrderingComposer,
    $$SyncSkippedTableAnnotationComposer,
    $$SyncSkippedTableCreateCompanionBuilder,
    $$SyncSkippedTableUpdateCompanionBuilder,
    (
      SyncSkippedData,
      BaseReferences<_$AppDatabase, $SyncSkippedTable, SyncSkippedData>
    ),
    SyncSkippedData,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$RecordsTableTableManager get records =>
      $$RecordsTableTableManager(_db, _db.records);
  $$TagsTableTableManager get tags => $$TagsTableTableManager(_db, _db.tags);
  $$RecordTagsTableTableManager get recordTags =>
      $$RecordTagsTableTableManager(_db, _db.recordTags);
  $$RevisionsTableTableManager get revisions =>
      $$RevisionsTableTableManager(_db, _db.revisions);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$RemoteReceiptsTableTableManager get remoteReceipts =>
      $$RemoteReceiptsTableTableManager(_db, _db.remoteReceipts);
  $$SyncStateTableTableManager get syncState =>
      $$SyncStateTableTableManager(_db, _db.syncState);
  $$ConflictsTableTableManager get conflicts =>
      $$ConflictsTableTableManager(_db, _db.conflicts);
  $$SyncSkippedTableTableManager get syncSkipped =>
      $$SyncSkippedTableTableManager(_db, _db.syncSkipped);
}
