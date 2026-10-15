// test/unit/theme_extension_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suicun/shared/theme/app_theme.dart';

void main() {
  group('SuiVaultColors ThemeExtension', () {
    test('light theme palette matches specification', () {
      const colors = SuiVaultColors.light;
      expect(colors.success, const Color(0xFF2D8263));
      expect(colors.warning, const Color(0xFFA76A12));
      expect(colors.danger, const Color(0xFFC43D48));

      expect(colors.categoryPalette['学习'], const Color(0xFF805AD5));
      expect(colors.categoryPalette['工作'], const Color(0xFF3265E5));
      expect(colors.categoryPalette['待办'], const Color(0xFFD65C65));
      expect(colors.categoryPalette['灵感'], const Color(0xFFD49A25));
      expect(colors.categoryPalette['生活'], const Color(0xFF3C9567));
    });

    test('dark theme palette matches specification', () {
      const colors = SuiVaultColors.dark;
      expect(colors.success, const Color(0xFF56C29B));
      expect(colors.warning, const Color(0xFFF0B45B));
      expect(colors.danger, const Color(0xFFF2747E));

      expect(colors.categoryPalette['学习'], const Color(0xFFB794F4));
      expect(colors.categoryPalette['工作'], const Color(0xFF7FA3F7));
      expect(colors.categoryPalette['待办'], const Color(0xFFF6878F));
      expect(colors.categoryPalette['灵感'], const Color(0xFFF6C863));
      expect(colors.categoryPalette['生活'], const Color(0xFF68D391));
    });

    test('colorForCategory resolves existing categories and falls back to 工作', () {
      const light = SuiVaultColors.light;
      expect(light.colorForCategory('学习'), const Color(0xFF805AD5));
      expect(light.colorForCategory('未知分类'), const Color(0xFF3265E5));
      expect(light.colorForCategory(null), const Color(0xFF3265E5));

      const dark = SuiVaultColors.dark;
      expect(dark.colorForCategory('学习'), const Color(0xFFB794F4));
      expect(dark.colorForCategory('未知分类'), const Color(0xFF7FA3F7));
      expect(dark.colorForCategory(null), const Color(0xFF7FA3F7));
    });

    test('copyWith updates specified fields', () {
      const original = SuiVaultColors.light;
      final updated = original.copyWith(success: const Color(0xFF00FF00));
      expect(updated.success, const Color(0xFF00FF00));
      expect(updated.warning, original.warning);
      expect(updated.danger, original.danger);
      expect(updated.categoryPalette, original.categoryPalette);
    });

    test('lerp blends colors correctly', () {
      const light = SuiVaultColors.light;
      const dark = SuiVaultColors.dark;
      final lerped = light.lerp(dark, 0.5);
      expect(lerped.success, Color.lerp(light.success, dark.success, 0.5));
      expect(lerped.categoryPalette, dark.categoryPalette);
    });

    test('ThemeData registers SuiVaultColors and unified corner radii', () {
      final lightTheme = AppTheme.lightTheme();
      final darkTheme = AppTheme.darkTheme();

      expect(lightTheme.extension<SuiVaultColors>(), isNotNull);
      expect(darkTheme.extension<SuiVaultColors>(), isNotNull);

      // Card: 14pt
      final lightCard = lightTheme.cardTheme.shape as RoundedRectangleBorder;
      final darkCard = darkTheme.cardTheme.shape as RoundedRectangleBorder;
      expect(lightCard.borderRadius, BorderRadius.circular(14));
      expect(darkCard.borderRadius, BorderRadius.circular(14));

      // Dialog: 16pt
      final lightDialog = lightTheme.dialogTheme.shape as RoundedRectangleBorder;
      final darkDialog = darkTheme.dialogTheme.shape as RoundedRectangleBorder;
      expect(lightDialog.borderRadius, BorderRadius.circular(16));
      expect(darkDialog.borderRadius, BorderRadius.circular(16));

      // BottomSheet: top 20pt
      final lightSheet = lightTheme.bottomSheetTheme.shape as RoundedRectangleBorder;
      final darkSheet = darkTheme.bottomSheetTheme.shape as RoundedRectangleBorder;
      expect(lightSheet.borderRadius, const BorderRadius.vertical(top: Radius.circular(20)));
      expect(darkSheet.borderRadius, const BorderRadius.vertical(top: Radius.circular(20)));

      // Inputs: 12pt
      final lightInput = lightTheme.inputDecorationTheme.border as OutlineInputBorder;
      final darkInput = darkTheme.inputDecorationTheme.border as OutlineInputBorder;
      expect(lightInput.borderRadius, BorderRadius.circular(12));
      expect(darkInput.borderRadius, BorderRadius.circular(12));

      // Buttons: 12pt
      final lightFilled = lightTheme.filledButtonTheme.style?.shape?.resolve({}) as RoundedRectangleBorder?;
      final darkFilled = darkTheme.filledButtonTheme.style?.shape?.resolve({}) as RoundedRectangleBorder?;
      expect(lightFilled?.borderRadius, BorderRadius.circular(12));
      expect(darkFilled?.borderRadius, BorderRadius.circular(12));
    });
  });
}
