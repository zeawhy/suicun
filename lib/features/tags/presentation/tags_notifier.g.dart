// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tags_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TagsNotifier)
final tagsProvider = TagsNotifierProvider._();

final class TagsNotifierProvider
    extends $AsyncNotifierProvider<TagsNotifier, List<TagModel>> {
  TagsNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'tagsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$tagsNotifierHash();

  @$internal
  @override
  TagsNotifier create() => TagsNotifier();
}

String _$tagsNotifierHash() => r'445cd32e3a870b8fb81f7e2e6e0e7b1d0e09370f';

abstract class _$TagsNotifier extends $AsyncNotifier<List<TagModel>> {
  FutureOr<List<TagModel>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<TagModel>>, List<TagModel>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<List<TagModel>>, List<TagModel>>,
        AsyncValue<List<TagModel>>,
        Object?,
        Object?>;
    return element.handleCreate(ref, build);
  }
}
