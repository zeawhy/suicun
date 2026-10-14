// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appDatabase)
final appDatabaseProvider = AppDatabaseProvider._();

final class AppDatabaseProvider
    extends $FunctionalProvider<AppDatabase, AppDatabase, AppDatabase>
    with $Provider<AppDatabase> {
  AppDatabaseProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'appDatabaseProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$appDatabaseHash();

  @$internal
  @override
  $ProviderElement<AppDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDatabase create(Ref ref) {
    return appDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDatabase>(value),
    );
  }
}

String _$appDatabaseHash() => r'06fdfb977c5a19f41b5a6fc7066db99dfba4499c';

@ProviderFor(syncEnqueuer)
final syncEnqueuerProvider = SyncEnqueuerProvider._();

final class SyncEnqueuerProvider
    extends $FunctionalProvider<SyncEnqueuer, SyncEnqueuer, SyncEnqueuer>
    with $Provider<SyncEnqueuer> {
  SyncEnqueuerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'syncEnqueuerProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$syncEnqueuerHash();

  @$internal
  @override
  $ProviderElement<SyncEnqueuer> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SyncEnqueuer create(Ref ref) {
    return syncEnqueuer(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncEnqueuer value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncEnqueuer>(value),
    );
  }
}

String _$syncEnqueuerHash() => r'4d30344fbb6ccf7e0b31d795987e2716e331b535';

@ProviderFor(recordRepository)
final recordRepositoryProvider = RecordRepositoryProvider._();

final class RecordRepositoryProvider extends $FunctionalProvider<
    RecordRepository,
    RecordRepository,
    RecordRepository> with $Provider<RecordRepository> {
  RecordRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'recordRepositoryProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$recordRepositoryHash();

  @$internal
  @override
  $ProviderElement<RecordRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RecordRepository create(Ref ref) {
    return recordRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RecordRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RecordRepository>(value),
    );
  }
}

String _$recordRepositoryHash() => r'd2d2a0683b20b4d011c5b88aa4029249b3c4e9e4';

@ProviderFor(categoryRepository)
final categoryRepositoryProvider = CategoryRepositoryProvider._();

final class CategoryRepositoryProvider extends $FunctionalProvider<
    CategoryRepository,
    CategoryRepository,
    CategoryRepository> with $Provider<CategoryRepository> {
  CategoryRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'categoryRepositoryProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$categoryRepositoryHash();

  @$internal
  @override
  $ProviderElement<CategoryRepository> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CategoryRepository create(Ref ref) {
    return categoryRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CategoryRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CategoryRepository>(value),
    );
  }
}

String _$categoryRepositoryHash() =>
    r'c6769185144a92bb153da17a1eef8764bc0e4eb2';

@ProviderFor(tagRepository)
final tagRepositoryProvider = TagRepositoryProvider._();

final class TagRepositoryProvider
    extends $FunctionalProvider<TagRepository, TagRepository, TagRepository>
    with $Provider<TagRepository> {
  TagRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'tagRepositoryProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$tagRepositoryHash();

  @$internal
  @override
  $ProviderElement<TagRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TagRepository create(Ref ref) {
    return tagRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TagRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TagRepository>(value),
    );
  }
}

String _$tagRepositoryHash() => r'094cdf1d33dbdf9e0ee883cc8cf0a63a52bd4e99';
