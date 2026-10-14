// lib/features/records/presentation/template_sheet.dart
// Modal bottom sheet for picking a note template before creating a record.

import 'package:flutter/material.dart';
import 'package:suicun/features/records/presentation/note_template.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';

/// Shows the template picker modal bottom sheet in C1 style.
/// Returns the selected template id (e.g. 'blank', 'password') or null if cancelled.
Future<String?> showTemplateSheet(BuildContext context) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final l10n = AppLocalizations.of(context);

  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: colorScheme.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  l10n.templateSheetTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              for (final template in NoteTemplate.all)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      template.icon,
                      size: 22,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  title: Text(
                    template.getTitle(l10n),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    template.getDescription(l10n),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  onTap: () => Navigator.of(sheetContext).pop(template.id),
                ),
            ],
          ),
        ),
      );
    },
  );
}
