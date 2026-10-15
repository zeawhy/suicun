// lib/shared/theme/theme_providers.dart
// Riverpod providers for theme mode management.

import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

export 'app_theme.dart'
    show SuiVaultColors, SuiVaultBuildContextX, SuiVaultThemeDataX;

part 'theme_providers.g.dart';

/// The three modes a user can choose for the app's appearance.
enum AppThemeMode { light, dark, system }

/// Notifier that holds and exposes the user-selected [AppThemeMode].
///
/// Defaults to [AppThemeMode.system] so the OS preference is respected on
/// first launch.
@riverpod
class ThemeModeNotifier extends _$ThemeModeNotifier {
  @override
  AppThemeMode build() => AppThemeMode.system;

  /// Updates the current theme mode.
  void setMode(AppThemeMode mode) => state = mode;
}

/// Derived provider that maps [AppThemeMode] to Flutter's [ThemeMode].
///
/// Consume this when passing a value to [MaterialApp.themeMode].
@riverpod
ThemeMode resolvedThemeMode(Ref ref) {
  final mode = ref.watch(themeModeProvider);
  return switch (mode) {
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
    AppThemeMode.system => ThemeMode.system,
  };
}
