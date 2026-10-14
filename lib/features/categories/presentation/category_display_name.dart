// lib/features/categories/presentation/category_display_name.dart
//
// Display-name resolution for categories.
//
// The five built-in categories are seeded with Chinese stored names
// (see CategoryRepository.defaultCategories) so that seeding stays
// idempotent and user data is never touched. At render time, those
// built-in names are mapped to localized strings so the UI follows the
// system locale. User-created categories fall through unchanged.

import 'package:flutter/widgets.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';

/// Localized display name for a category.
///
/// [storedName] is the name persisted in the database. Built-in names
/// ('工作', '学习', '生活', '灵感', '待办') resolve to the current locale;
/// anything else is returned as-is.
String categoryDisplayName(BuildContext context, String storedName) {
  final l10n = AppLocalizations.of(context);
  return switch (storedName.trim()) {
    '工作' => l10n.defaultCategoryWork,
    '学习' => l10n.defaultCategoryStudy,
    '生活' => l10n.defaultCategoryLife,
    '灵感' => l10n.defaultCategoryIdeas,
    '待办' => l10n.defaultCategoryTodo,
    _ => storedName,
  };
}
