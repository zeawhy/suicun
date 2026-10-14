// lib/features/records/presentation/template_views/template_header_card.dart
// Shared header card for template reading views.

import 'package:flutter/material.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';

class TemplateHeaderCard extends StatelessWidget {
  const TemplateHeaderCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onEdit,
    this.titleController,
    this.onTitleChanged,
  });

  final String title;
  final IconData icon;
  final VoidCallback onEdit;
  final TextEditingController? titleController;
  final ValueChanged<String>? onTitleChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEditing = titleController != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Rounded square icon container
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          // Title
          Expanded(
            child: isEditing
                ? TextField(
                    key: const Key('template_title_field'),
                    controller: titleController,
                    decoration: InputDecoration(
                      hintText: l10n.titleHint,
                      hintStyle: TextStyle(
                        color: colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.6),
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                    textInputAction: TextInputAction.next,
                    onChanged: onTitleChanged,
                  )
                : Text(
                    title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
          if (!isEditing) ...[
            const SizedBox(width: 8),
            // Edit button
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.editInfo,
              color: colorScheme.onSurfaceVariant,
              onPressed: onEdit,
            ),
          ],
        ],
      ),
    );
  }
}
