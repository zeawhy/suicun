// lib/shared/theme/app_theme.dart
// Defines the Material 3 theme for Suicun (随存).

import 'package:flutter/material.dart';

/// Provides the [ThemeData] for light and dark modes.
///
/// The dark theme is designed independently rather than being a mechanical
/// inversion of the light theme.
class AppTheme {
  AppTheme._();

  // ─── Shared text theme ────────────────────────────────────────────────────

  static TextTheme _buildTextTheme(TextTheme base) {
    return base.copyWith(
      bodyLarge: base.bodyLarge?.copyWith(fontSize: 16),
      titleLarge: base.titleLarge?.copyWith(fontSize: 20),
      headlineMedium: base.headlineMedium?.copyWith(fontSize: 24),
    );
  }

  // ─── Light theme ──────────────────────────────────────────────────────────

  static ThemeData lightTheme() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF4866D5),
      onPrimary: Colors.white,
      secondary: Color(0xFF687180),
      onSecondary: Colors.white,
      error: Color(0xFFB3261E),
      onError: Colors.white,
      surface: Color(0xFFF7F8FA),
      onSurface: Color(0xFF20242C),
      onSurfaceVariant: Color(0xFF687180),
      outline: Color(0xFFD0D5DD),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF7F8FA),
      textTheme: _buildTextTheme(ThemeData.light().textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: Color(0xFF20242C),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFFFFFFFF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFFFFFF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF4866D5), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  // ─── Dark theme ───────────────────────────────────────────────────────────

  static ThemeData darkTheme() {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF7B97FF),
      onPrimary: Color(0xFF0B1460),
      secondary: Color(0xFF9BA5B4),
      onSecondary: Color(0xFF1E2028),
      error: Color(0xFFCF6679),
      onError: Color(0xFF1E2028),
      surface: Color(0xFF1E2028),
      onSurface: Color(0xFFE3E5EC),
      onSurfaceVariant: Color(0xFF9BA5B4),
      outline: Color(0xFF3A3F4B),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF121318),
      textTheme: _buildTextTheme(ThemeData.dark().textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: Color(0xFFE3E5EC),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF1E2028),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2A2D38),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF3A3F4B)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF3A3F4B)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF7B97FF), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
