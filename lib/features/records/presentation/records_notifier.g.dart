// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'records_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(RecordsFilterNotifier)
final recordsFilterProvider = RecordsFilterNotifierProvider._();

final class RecordsFilterNotifierProvider
    extends $NotifierProvider<RecordsFilterNotifier, RecordsFilter> {
  RecordsFilterNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'recordsFilterProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$recordsFilterNotifierHash();

  @$internal
  @override
  RecordsFilterNotifier create() => RecordsFilterNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RecordsFilter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RecordsFilter>(value),
    );
  }
}

String _$recordsFilterNotifierHash() =>
    r'2e30ec8e4788f6bc858686f7d3abd86d98e2c89a';

abstract class _$RecordsFilterNotifier extends $Notifier<RecordsFilter> {
  RecordsFilter build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<RecordsFilter, RecordsFilter>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<RecordsFilter, RecordsFilter>,
        RecordsFilter,
        Object?,
        Object?>;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(recordsList)
final recordsListProvider = RecordsListProvider._();

final class RecordsListProvider extends $FunctionalProvider<
        AsyncValue<List<RecordDetail>>,
        List<RecordDetail>,
        FutureOr<List<RecordDetail>>>
    with
        $FutureModifier<List<RecordDetail>>,
        $FutureProvider<List<RecordDetail>> {
  RecordsListProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'recordsListProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$recordsListHash();

  @$internal
  @override
  $FutureProviderElement<List<RecordDetail>> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<RecordDetail>> create(Ref ref) {
    return recordsList(ref);
  }
}

String _$recordsListHash() => r'8a2a338e0fa77a24ff01d35bcea6c8fb0a1e291e';

@ProviderFor(trashList)
final trashListProvider = TrashListProvider._();

final class TrashListProvider extends $FunctionalProvider<
        AsyncValue<List<RecordDetail>>,
        List<RecordDetail>,
        FutureOr<List<RecordDetail>>>
    with
        $FutureModifier<List<RecordDetail>>,
        $FutureProvider<List<RecordDetail>> {
  TrashListProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'trashListProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$trashListHash();

  @$internal
  @override
  $FutureProviderElement<List<RecordDetail>> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<RecordDetail>> create(Ref ref) {
    return trashList(ref);
  }
}

String _$trashListHash() => r'1f63421bfd8a625d3f4e8dd82d97e60aed9bba40';
