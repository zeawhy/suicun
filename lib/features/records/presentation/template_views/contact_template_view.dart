// lib/features/records/presentation/template_views/contact_template_view.dart
// Reading view for contact template notes.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:suicun/features/records/domain/record_model.dart';
import 'package:suicun/features/records/presentation/template_views/template_detector.dart';
import 'package:suicun/features/records/presentation/template_views/template_header_card.dart';
import 'package:suicun/features/records/presentation/template_views/updated_at_text.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';

class ContactTemplateView extends StatelessWidget {
  const ContactTemplateView({
    super.key,
    required this.data,
    required this.record,
    required this.onEdit,
    required this.categoryRow,
    required this.tagRow,
    this.suggestionRow,
  });

  final ContactTemplateData data;
  final RecordDetail? record;
  final VoidCallback onEdit;
  final Widget categoryRow;
  final Widget tagRow;
  final Widget? suggestionRow;

  void _copyText(
    BuildContext context,
    String? text,
    String successMessage,
  ) {
    final value = text?.trim() ?? '';
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

  Future<void> _launchTel(BuildContext context, String? phone, AppLocalizations l10n) async {
    final trimmed = phone?.trim() ?? '';
    if (trimmed.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final uri = Uri(scheme: 'tel', path: trimmed);
      final launched = await launchUrl(uri);
      if (!launched) {
        Clipboard.setData(ClipboardData(text: trimmed));
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.copied),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      Clipboard.setData(ClipboardData(text: trimmed));
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.copied),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _launchEmail(BuildContext context, String? email, AppLocalizations l10n) async {
    final trimmed = email?.trim() ?? '';
    if (trimmed.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final uri = Uri(scheme: 'mailto', path: trimmed);
      final launched = await launchUrl(uri);
      if (!launched) {
        Clipboard.setData(ClipboardData(text: trimmed));
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.copied),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      Clipboard.setData(ClipboardData(text: trimmed));
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.copied),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final name = data.name;
    final phone = data.phone;
    final email = data.email;
    final address = data.address;
    final notes = data.notes;

    final hasName = name != null && name.trim().isNotEmpty;
    final fallbackTitle = record?.title.isNotEmpty == true
        ? record!.title
        : l10n.untitledRecord;
    final headerTitle = hasName ? name.trim() : fallbackTitle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Header card (Icons.person_outline + name/title + pencil edit button)
        TemplateHeaderCard(
          title: headerTitle,
          icon: Icons.person_outline,
          onEdit: onEdit,
        ),
        const SizedBox(height: 16),

        // 2. Contact fields card
        _buildContactFieldsCard(
          context,
          showNameField: !hasName,
          name: name,
          phone: phone,
          email: email,
          address: address,
          theme: theme,
          colorScheme: colorScheme,
          l10n: l10n,
        ),

        // 3. Notes card (independent, hidden if empty)
        if (notes != null && notes.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildNotesCard(context, notes.trim(), theme, colorScheme, l10n),
        ],

        const SizedBox(height: 16),

        // 4. Category & Tag rows container
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

        // 5. Updated at relative time
        if (record != null)
          UpdatedAtText(dateTime: record!.updatedAt),
      ],
    );
  }

  Widget _buildContactFieldsCard(
    BuildContext context, {
    required bool showNameField,
    required String? name,
    required String? phone,
    required String? email,
    required String? address,
    required ThemeData theme,
    required ColorScheme colorScheme,
    required AppLocalizations l10n,
  }) {
    final divider = Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
    );

    final fields = <Widget>[];

    // Optional Name field (if name is empty)
    if (showNameField) {
      fields.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.fieldName,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.notFilled,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Phone field
    final trimmedPhone = phone?.trim();
    final hasPhone = trimmedPhone != null && trimmedPhone.isNotEmpty;
    fields.add(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.fieldPhone,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (hasPhone)
                    SelectableText(
                      trimmedPhone,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    )
                  else
                    Text(
                      l10n.notFilled,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
                ],
              ),
            ),
            if (hasPhone)
              IconButton(
                icon: const Icon(Icons.phone_outlined, size: 20),
                tooltip: l10n.fieldPhone,
                color: colorScheme.primary,
                onPressed: () => _launchTel(context, trimmedPhone, l10n),
              ),
          ],
        ),
      ),
    );

    // Email field
    final trimmedEmail = email?.trim();
    final hasEmail = trimmedEmail != null && trimmedEmail.isNotEmpty;
    fields.add(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.fieldEmail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (hasEmail)
                    SelectableText(
                      trimmedEmail,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    )
                  else
                    Text(
                      l10n.notFilled,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
                ],
              ),
            ),
            if (hasEmail)
              IconButton(
                icon: const Icon(Icons.email_outlined, size: 20),
                tooltip: l10n.fieldEmail,
                color: colorScheme.primary,
                onPressed: () => _launchEmail(context, trimmedEmail, l10n),
              ),
          ],
        ),
      ),
    );

    // Address field (label on top, value below, copy button at row end)
    final trimmedAddress = address?.trim();
    final hasAddress = trimmedAddress != null && trimmedAddress.isNotEmpty;
    fields.add(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.fieldAddress,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (hasAddress)
                    SelectableText(
                      trimmedAddress,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    )
                  else
                    Text(
                      l10n.notFilled,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
                ],
              ),
            ),
            if (hasAddress)
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 20),
                tooltip: l10n.copy,
                color: colorScheme.onSurfaceVariant,
                onPressed: () => _copyText(context, trimmedAddress, l10n.copied),
              ),
          ],
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < fields.length; i++) ...[
            if (i > 0) divider,
            fields[i],
          ],
        ],
      ),
    );
  }

  Widget _buildNotesCard(
    BuildContext context,
    String notes,
    ThemeData theme,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.fieldNotes,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            notes,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurface,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
