// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_sort_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(HomeSortMode)
final homeSortModeProvider = HomeSortModeProvider._();

final class HomeSortModeProvider
    extends $AsyncNotifierProvider<HomeSortMode, RecordSortMode> {
  HomeSortModeProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'homeSortModeProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$homeSortModeHash();

  @$internal
  @override
  HomeSortMode create() => HomeSortMode();
}

String _$homeSortModeHash() => r'f578b3d5309c4b651322f8412ea97bb612ec3537';

abstract class _$HomeSortMode extends $AsyncNotifier<RecordSortMode> {
  FutureOr<RecordSortMode> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<RecordSortMode>, RecordSortMode>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<RecordSortMode>, RecordSortMode>,
        AsyncValue<RecordSortMode>,
        Object?,
        Object?>;
    return element.handleCreate(ref, build);
  }
}
