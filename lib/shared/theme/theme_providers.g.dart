// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Notifier that holds and exposes the user-selected [AppThemeMode].
///
/// Defaults to [AppThemeMode.system] so the OS preference is respected on
/// first launch.

@ProviderFor(ThemeModeNotifier)
final themeModeProvider = ThemeModeNotifierProvider._();

/// Notifier that holds and exposes the user-selected [AppThemeMode].
///
/// Defaults to [AppThemeMode.system] so the OS preference is respected on
/// first launch.
final class ThemeModeNotifierProvider
    extends $NotifierProvider<ThemeModeNotifier, AppThemeMode> {
  /// Notifier that holds and exposes the user-selected [AppThemeMode].
  ///
  /// Defaults to [AppThemeMode.system] so the OS preference is respected on
  /// first launch.
  ThemeModeNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'themeModeProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$themeModeNotifierHash();

  @$internal
  @override
  ThemeModeNotifier create() => ThemeModeNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppThemeMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppThemeMode>(value),
    );
  }
}

String _$themeModeNotifierHash() => r'f37afbec58841178f07c6bdbeaec0190f0dba42f';

/// Notifier that holds and exposes the user-selected [AppThemeMode].
///
/// Defaults to [AppThemeMode.system] so the OS preference is respected on
/// first launch.

abstract class _$ThemeModeNotifier extends $Notifier<AppThemeMode> {
  AppThemeMode build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AppThemeMode, AppThemeMode>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AppThemeMode, AppThemeMode>,
        AppThemeMode,
        Object?,
        Object?>;
    return element.handleCreate(ref, build);
  }
}

/// Derived provider that maps [AppThemeMode] to Flutter's [ThemeMode].
///
/// Consume this when passing a value to [MaterialApp.themeMode].

@ProviderFor(resolvedThemeMode)
final resolvedThemeModeProvider = ResolvedThemeModeProvider._();

/// Derived provider that maps [AppThemeMode] to Flutter's [ThemeMode].
///
/// Consume this when passing a value to [MaterialApp.themeMode].

final class ResolvedThemeModeProvider
    extends $FunctionalProvider<ThemeMode, ThemeMode, ThemeMode>
    with $Provider<ThemeMode> {
  /// Derived provider that maps [AppThemeMode] to Flutter's [ThemeMode].
  ///
  /// Consume this when passing a value to [MaterialApp.themeMode].
  ResolvedThemeModeProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'resolvedThemeModeProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$resolvedThemeModeHash();

  @$internal
  @override
  $ProviderElement<ThemeMode> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ThemeMode create(Ref ref) {
    return resolvedThemeMode(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThemeMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThemeMode>(value),
    );
  }
}

String _$resolvedThemeModeHash() => r'8d85b344d3d580680cccf4992fa3f052cbc16d43';
