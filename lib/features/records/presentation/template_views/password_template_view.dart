// lib/features/records/presentation/template_views/password_template_view.dart
// Reading view for password template notes.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:suicun/features/records/domain/record_model.dart';
import 'package:suicun/features/records/presentation/template_views/template_detector.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';

class PasswordTemplateView extends StatefulWidget {
  const PasswordTemplateView({
    super.key,
    required this.data,
    required this.record,
    required this.onEdit,
    required this.categoryRow,
    required this.tagRow,
    this.suggestionRow,
  });

  final PasswordTemplateData data;
  final RecordDetail? record;
  final VoidCallback onEdit;
  final Widget categoryRow;
  final Widget tagRow;
  final Widget? suggestionRow;

  @override
  State<PasswordTemplateView> createState() => _PasswordTemplateViewState();
}

class _PasswordTemplateViewState extends State<PasswordTemplateView> {
  bool _obscurePassword = true;

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  Future<void> _copyText(
    BuildContext context,
    String? text,
    String successMessage,
  ) async {
    final value = text ?? '';
    if (value.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(successMessage),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _formatUpdatedAt(DateTime dateTime, BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final isZh = locale.toLowerCase().startsWith('zh');

    final local = dateTime.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final diffDays = today.difference(day).inDays;

    final hm = DateFormat.Hm(locale).format(local);

    String timeStr;
    if (diffDays <= 0) {
      timeStr = '${l10n.today} $hm';
    } else if (diffDays == 1) {
      timeStr = '${l10n.yesterday} $hm';
    } else if (local.year == now.year) {
      if (isZh) {
        timeStr = '${local.month}月${local.day}日 $hm';
      } else {
        final mmmd = DateFormat.MMMd(locale).format(local);
        timeStr = '$mmmd, $hm';
      }
    } else {
      if (isZh) {
        timeStr = '${local.year}年${local.month}月${local.day}日';
      } else {
        timeStr = DateFormat('yyyy-MM-dd HH:mm').format(local);
      }
    }

    return l10n.updatedAt(timeStr);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final website = widget.data.website;
    final username = widget.data.username;
    final password = widget.data.password;
    final notes = widget.data.notes;

    final title = widget.record?.title.isNotEmpty == true
        ? widget.record!.title
        : l10n.untitledRecord;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Header card
        _buildHeaderCard(context, title, theme, colorScheme, l10n),
        const SizedBox(height: 16),

        // 2. Field card (Surface container, rounded 16)
        _buildFieldsCard(context, website, username, password, theme, colorScheme, l10n),

        // 3. Notes card (independent, hidden if empty)
        if (notes != null && notes.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildNotesCard(context, notes, theme, colorScheme, l10n),
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
              widget.categoryRow,
              if (widget.suggestionRow != null) widget.suggestionRow!,
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              widget.tagRow,
            ],
          ),
        ),

        // 5. Updated at relative time
        if (widget.record != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Center(
              child: Text(
                _formatUpdatedAt(widget.record!.updatedAt, context),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHeaderCard(
    BuildContext context,
    String title,
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Rounded square key icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.vpn_key_rounded,
              color: colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          // Title
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Edit button
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.editInfo,
            color: colorScheme.onSurfaceVariant,
            onPressed: widget.onEdit,
          ),
        ],
      ),
    );
  }

  Widget _buildFieldsCard(
    BuildContext context,
    String? website,
    String? username,
    String? password,
    ThemeData theme,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    final divider = Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
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
          // Field 1: Website / App
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.fieldWebsite,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                if (website != null && website.isNotEmpty)
                  SelectableText(
                    website,
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
          divider,

          // Field 2: Username / Email
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.fieldUsername,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (username != null && username.isNotEmpty)
                        SelectableText(
                          username,
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
                if (username != null && username.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 20),
                    tooltip: l10n.copy,
                    color: colorScheme.onSurfaceVariant,
                    onPressed: () => _copyText(context, username, l10n.copied),
                  ),
              ],
            ),
          ),
          divider,

          // Field 3: Password
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.fieldPassword,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (password != null && password.isNotEmpty)
                        _obscurePassword
                            ? Text(
                                '••••••',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  letterSpacing: 2.0,
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : SelectableText(
                                password,
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
                if (password != null && password.isNotEmpty) ...[
                  IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                    tooltip: _obscurePassword
                        ? l10n.showPassword
                        : l10n.hidePassword,
                    color: colorScheme.onSurfaceVariant,
                    onPressed: _togglePasswordVisibility,
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 20),
                    tooltip: l10n.copy,
                    color: colorScheme.onSurfaceVariant,
                    onPressed: () =>
                        _copyText(context, password, l10n.passwordCopied),
                  ),
                ],
              ],
            ),
          ),
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
