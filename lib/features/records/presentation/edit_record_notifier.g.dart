// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'edit_record_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(EditRecordNotifier)
final editRecordProvider = EditRecordNotifierFamily._();

final class EditRecordNotifierProvider
    extends $NotifierProvider<EditRecordNotifier, EditRecordState> {
  EditRecordNotifierProvider._(
      {required EditRecordNotifierFamily super.from,
      required String? super.argument})
      : super(
          retry: null,
          name: r'editRecordProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$editRecordNotifierHash();

  @override
  String toString() {
    return r'editRecordProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  EditRecordNotifier create() => EditRecordNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EditRecordState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EditRecordState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is EditRecordNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$editRecordNotifierHash() =>
    r'ff3535ba35618ffacd45d926cae9d81f0401e16e';

final class EditRecordNotifierFamily extends $Family
    with
        $ClassFamilyOverride<EditRecordNotifier, EditRecordState,
            EditRecordState, EditRecordState, String?> {
  EditRecordNotifierFamily._()
      : super(
          retry: null,
          name: r'editRecordProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  EditRecordNotifierProvider call(
    String? recordId,
  ) =>
      EditRecordNotifierProvider._(argument: recordId, from: this);

  @override
  String toString() => r'editRecordProvider';
}

abstract class _$EditRecordNotifier extends $Notifier<EditRecordState> {
  late final _$args = ref.$arg as String?;
  String? get recordId => _$args;

  EditRecordState build(
    String? recordId,
  );
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<EditRecordState, EditRecordState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<EditRecordState, EditRecordState>,
        EditRecordState,
        Object?,
        Object?>;
    return element.handleCreate(
        ref,
        () => build(
              _$args,
            ));
  }
}
