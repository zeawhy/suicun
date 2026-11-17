// lib/features/records/presentation/template_views/blank_template_view.dart
// Reading view for blank template notes.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:suicun/features/records/domain/record_model.dart';
import 'package:suicun/features/records/presentation/template_views/template_header_card.dart';
import 'package:suicun/features/records/presentation/template_views/updated_at_text.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';

class BlankTemplateView extends StatelessWidget {
  const BlankTemplateView({
    super.key,
    required this.record,
    required this.bodySpans,
    required this.isEmptyBody,
    required this.onEdit,
    required this.onTapBody,
    required this.categoryRow,
    required this.tagRow,
    this.suggestionRow,
    this.bodyText,
  });

  final RecordDetail? record;
  final List<InlineSpan> bodySpans;
  final bool isEmptyBody;
  final VoidCallback onEdit;
  final VoidCallback onTapBody;
  final Widget categoryRow;
  final Widget tagRow;
  final Widget? suggestionRow;
  final String? bodyText;

  void _copyText(
    BuildContext context,
    String? text,
    String successMessage,
  ) {
    final value = text ?? '';
    if (value.isEmpty) return;
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(successMessage),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final title = record?.title.isNotEmpty == true
        ? record!.title
        : l10n.untitledRecord;
    final rawBodyText = bodyText ?? record?.body ?? '';
    final showCopyButton = !isEmptyBody && rawBodyText.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Header card
        TemplateHeaderCard(
          title: title,
          icon: Icons.edit_note_outlined,
          onEdit: onEdit,
        ),
        const SizedBox(height: 16),

        // 2. Content card
        GestureDetector(
          onTap: onTapBody,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: showCopyButton
                ? const EdgeInsets.fromLTRB(16, 8, 8, 16)
                : const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            child: isEmptyBody
                ? Text(
                    l10n.bodyHint,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
                      height: 1.5,
                    ),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: showCopyButton
                              ? const EdgeInsets.only(top: 8)
                              : EdgeInsets.zero,
                          child: Text.rich(
                            TextSpan(
                              children: bodySpans,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onSurface,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (showCopyButton) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 20),
                          tooltip: l10n.copy,
                          color: colorScheme.onSurfaceVariant,
                          onPressed: () => _copyText(
                            context,
                            rawBodyText,
                            l10n.copiedToClipboardMsg,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 16),

        // 3. Category & Tag rows container
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Column(
            children: [
              categoryRow,
              if (suggestionRow != null) suggestionRow!,
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              tagRow,
            ],
          ),
        ),

        // 4. Updated at relative time
        if (record != null)
          UpdatedAtText(dateTime: record!.updatedAt),
      ],
    );
  }
}
