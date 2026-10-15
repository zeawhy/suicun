// lib/shared/theme/app_theme.dart
// Defines the Material 3 theme for Suicun (随存).

import 'package:flutter/material.dart';

/// Provides the [ThemeData] for light and dark modes.
///
/// The dark theme is designed independently rather than being a mechanical
/// inversion of the light theme.
class AppTheme {
  AppTheme._();

  // ─── C1 Design Constants ──────────────────────────────────────────────────
  static const Color backgroundLight = Color(0xFFF7F9FC);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color primaryBlue = Color(0xFF3265E5);
  static const Color textMain = Color(0xFF202938);
  static const Color textSecondary = Color(0xFF657084);
  static const Color dividerColor = Color(0xFFE5EAF2);

  static const Color successColor = Color(0xFF2D8263);
  static const Color warningColor = Color(0xFFA76A12);
  static const Color dangerColor = Color(0xFFC43D48);

  /// Unified category color mapping across all pages:
  /// 学习紫色 #805AD5, 工作蓝色 #3265E5, 待办红色 #D65C65, 灵感黄色 #D49A25, 生活绿色 #3C9567
  static const Map<String, Color> categoryColorMap = {
    '学习': Color(0xFF805AD5),
    '工作': Color(0xFF3265E5),
    '待办': Color(0xFFD65C65),
    '灵感': Color(0xFFD49A25),
    '生活': Color(0xFF3C9567),
  };

  /// Fallback category color parser that respects the unified category colors.
  static Color getCategoryColor(String? name, [String? hex]) {
    return SuiVaultColors.light.colorForCategory(name, hex);
  }

  // ─── Shared text theme ────────────────────────────────────────────────────

  static TextTheme _buildTextTheme(TextTheme base, {required Color textColor, required Color secondaryTextColor}) {
    return base.copyWith(
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: textColor,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: textColor,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 16,
        height: 1.45,
        color: textColor,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14,
        height: 1.4,
        color: secondaryTextColor,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 12,
        height: 1.35,
        color: secondaryTextColor,
      ),
    );
  }

  // ─── Light theme ──────────────────────────────────────────────────────────

  static ThemeData lightTheme() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: primaryBlue,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFE9F0FD),
      onPrimaryContainer: Color(0xFF1A3882),
      secondary: textSecondary,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFEFF2F7),
      onSecondaryContainer: Color(0xFF2C374A),
      error: dangerColor,
      onError: Colors.white,
      errorContainer: Color(0xFFFDE8E9),
      onErrorContainer: Color(0xFF7A1C24),
      surface: backgroundLight,
      surfaceDim: Color(0xFFEEF2F6),
      surfaceBright: Color(0xFFFFFFFF),
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFF7F9FC),
      surfaceContainer: Color(0xFFF0F4F9),
      surfaceContainerHigh: Color(0xFFE9EEF5),
      surfaceContainerHighest: Color(0xFFE2E8F0),
      onSurface: textMain,
      onSurfaceVariant: textSecondary,
      outline: dividerColor,
      outlineVariant: dividerColor,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundLight,
      textTheme: _buildTextTheme(
        ThemeData.light().textTheme,
        textColor: textMain,
        secondaryTextColor: textSecondary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: textMain,
        titleTextStyle: TextStyle(
          color: textMain,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: dividerColor),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle: const TextStyle(
          color: textMain,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        dragHandleColor: dividerColor,
      ),
      dividerTheme: const DividerThemeData(
        color: dividerColor,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardLight,
        hintStyle: const TextStyle(
          color: textSecondary,
          fontSize: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: dangerColor),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: const BorderSide(color: dividerColor),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 2,
        focusElevation: 3,
        hoverElevation: 3,
        highlightElevation: 4,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      extensions: const [
        SuiVaultColors.light,
      ],
    );
  }

  // ─── Dark theme ───────────────────────────────────────────────────────────

  static ThemeData darkTheme() {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF5B8DEF),
      onPrimary: Colors.white,
      primaryContainer: Color(0xFF1E3A78),
      onPrimaryContainer: Color(0xFFD6E3FC),
      secondary: Color(0xFF9BA5B4),
      onSecondary: Color(0xFF1E2028),
      secondaryContainer: Color(0xFF242A36),
      onSecondaryContainer: Color(0xFFE0E5EE),
      error: Color(0xFFF07178),
      onError: Color(0xFF441216),
      errorContainer: Color(0xFF5A1E24),
      onErrorContainer: Color(0xFFFFD9DC),
      surface: Color(0xFF12161E),
      surfaceDim: Color(0xFF0D1016),
      surfaceBright: Color(0xFF1E2430),
      surfaceContainerLowest: Color(0xFF161B24),
      surfaceContainerLow: Color(0xFF1A202B),
      surfaceContainer: Color(0xFF1F2633),
      surfaceContainerHigh: Color(0xFF262E3D),
      surfaceContainerHighest: Color(0xFF2D3647),
      onSurface: Color(0xFFE5EAF2),
      onSurfaceVariant: Color(0xFF96A0B2),
      outline: Color(0xFF333D4F),
      outlineVariant: Color(0xFF2A3342),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF12161E),
      textTheme: _buildTextTheme(
        ThemeData.dark().textTheme,
        textColor: const Color(0xFFE5EAF2),
        secondaryTextColor: const Color(0xFF96A0B2),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: Color(0xFFE5EAF2),
        titleTextStyle: TextStyle(
          color: Color(0xFFE5EAF2),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF161B24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF2A3342)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF1F2422),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle: const TextStyle(
          color: Color(0xFFE9EDEB),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF1F2422),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        dragHandleColor: Color(0xFF2E3431),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF2E3431),
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1F2422),
        hintStyle: const TextStyle(
          color: Color(0xFF9AA3A0),
          fontSize: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2E3431)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2E3431)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF5B8DEF), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF07178)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF5B8DEF),
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: const BorderSide(color: Color(0xFF2A3342)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF5B8DEF),
        foregroundColor: Colors.white,
        elevation: 2,
        focusElevation: 3,
        hoverElevation: 3,
        highlightElevation: 4,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      extensions: const [
        SuiVaultColors.dark,
      ],
    );
  }
}

/// Theme extension defining semantic status colors and unified category palettes
/// for SuiVault, supporting smooth transitions and dark mode adaptation.
@immutable
class SuiVaultColors extends ThemeExtension<SuiVaultColors> {
  const SuiVaultColors({
    required this.success,
    required this.warning,
    required this.danger,
    required this.categoryPalette,
  });

  final Color success;
  final Color warning;
  final Color danger;
  final Map<String, Color> categoryPalette;

  static const SuiVaultColors light = SuiVaultColors(
    success: Color(0xFF2D8263),
    warning: Color(0xFFA76A12),
    danger: Color(0xFFC43D48),
    categoryPalette: {
      '学习': Color(0xFF805AD5),
      '工作': Color(0xFF3265E5),
      '待办': Color(0xFFD65C65),
      '灵感': Color(0xFFD49A25),
      '生活': Color(0xFF3C9567),
    },
  );

  static const SuiVaultColors dark = SuiVaultColors(
    success: Color(0xFF56C29B),
    warning: Color(0xFFF0B45B),
    danger: Color(0xFFF2747E),
    categoryPalette: {
      '学习': Color(0xFFB794F4),
      '工作': Color(0xFF7FA3F7),
      '待办': Color(0xFFF6878F),
      '灵感': Color(0xFFF6C863),
      '生活': Color(0xFF68D391),
    },
  );

  Color colorForCategory(String? name, [String? hex]) {
    if (name != null && categoryPalette.containsKey(name.trim())) {
      return categoryPalette[name.trim()]!;
    }
    if (hex != null && hex.isNotEmpty) {
      final clean = hex.toUpperCase().replaceAll('#', '');
      if (clean.length == 6) {
        final parsed = int.tryParse('FF$clean', radix: 16);
        if (parsed != null) return Color(parsed);
      } else {
        final parsed = int.tryParse(clean, radix: 16);
        if (parsed != null) return Color(parsed);
      }
    }
    return categoryPalette['工作'] ?? const Color(0xFF3265E5);
  }

  @override
  SuiVaultColors copyWith({
    Color? success,
    Color? warning,
    Color? danger,
    Map<String, Color>? categoryPalette,
  }) {
    return SuiVaultColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      categoryPalette: categoryPalette ?? this.categoryPalette,
    );
  }

  @override
  SuiVaultColors lerp(ThemeExtension<SuiVaultColors>? other, double t) {
    if (other is! SuiVaultColors) {
      return this;
    }
    return SuiVaultColors(
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      categoryPalette: t < 0.5 ? categoryPalette : other.categoryPalette,
    );
  }
}

extension SuiVaultThemeDataX on ThemeData {
  SuiVaultColors get suiColors =>
      extension<SuiVaultColors>() ??
      (brightness == Brightness.dark
          ? SuiVaultColors.dark
          : SuiVaultColors.light);
}

extension SuiVaultBuildContextX on BuildContext {
  SuiVaultColors get suiColors => Theme.of(this).suiColors;
}
