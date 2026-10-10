// lib/features/records/presentation/template_views/password_template_view.dart
// Reading view for password template notes.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:suicun/features/records/domain/record_model.dart';
import 'package:suicun/features/records/presentation/template_views/template_detector.dart';
import 'package:suicun/features/records/presentation/template_views/template_header_card.dart';
import 'package:suicun/features/records/presentation/template_views/updated_at_text.dart';
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
    this.isEditing = false,
    this.titleController,
    this.onTitleChanged,
    this.onBodyChanged,
    this.rawBody,
  });

  final PasswordTemplateData data;
  final RecordDetail? record;
  final VoidCallback onEdit;
  final Widget categoryRow;
  final Widget tagRow;
  final Widget? suggestionRow;
  final bool isEditing;
  final TextEditingController? titleController;
  final ValueChanged<String>? onTitleChanged;
  final ValueChanged<String>? onBodyChanged;
  final String? rawBody;

  @override
  State<PasswordTemplateView> createState() => _PasswordTemplateViewState();
}

class _PasswordTemplateViewState extends State<PasswordTemplateView> {
  bool _obscurePassword = true;
  late final TextEditingController _websiteController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _websiteController = TextEditingController(text: widget.data.website ?? '');
    _usernameController =
        TextEditingController(text: widget.data.username ?? '');
    _passwordController =
        TextEditingController(text: widget.data.password ?? '');
    _notesController = TextEditingController(text: widget.data.notes ?? '');
  }

  @override
  void didUpdateWidget(PasswordTemplateView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isEditing) {
      if (widget.data.website != null &&
          widget.data.website != _websiteController.text) {
        _websiteController.text = widget.data.website!;
      }
      if (widget.data.username != null &&
          widget.data.username != _usernameController.text) {
        _usernameController.text = widget.data.username!;
      }
      if (widget.data.password != null &&
          widget.data.password != _passwordController.text) {
        _passwordController.text = widget.data.password!;
      }
      if (widget.data.notes != null &&
          widget.data.notes != _notesController.text) {
        _notesController.text = widget.data.notes!;
      }
    }
  }

  @override
  void dispose() {
    _websiteController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _syncBody() {
    final raw = widget.rawBody ?? '';
    final isEnglish = raw.contains('Website') ||
        raw.contains('website') ||
        raw.contains('Password:') ||
        raw.contains('Username:');
    final String body;
    if (isEnglish) {
      body = 'Website/App: ${_websiteController.text}\n'
          'Username: ${_usernameController.text}\n'
          'Password: ${_passwordController.text}\n'
          'Notes: ${_notesController.text}';
    } else {
      body = '网站/应用：${_websiteController.text}\n'
          '用户名：${_usernameController.text}\n'
          '密码：${_passwordController.text}\n'
          '备注：${_notesController.text}';
    }
    widget.onBodyChanged?.call(body);
  }

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
        TemplateHeaderCard(
          title: title,
          icon: Icons.vpn_key_rounded,
          onEdit: widget.onEdit,
          titleController: widget.titleController,
          onTitleChanged: widget.onTitleChanged,
        ),
        const SizedBox(height: 16),

        // 2. Field card (Surface container, rounded 16)
        _buildFieldsCard(context, website, username, password, theme, colorScheme, l10n),

        // 3. Notes card (independent, hidden if empty when reading)
        if (widget.isEditing || (notes != null && notes.isNotEmpty)) ...[
          const SizedBox(height: 16),
          _buildNotesCard(context, notes ?? '', theme, colorScheme, l10n),
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

        // 5. Updated at relative time or auto-save hint
        if (widget.isEditing)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 14),
            child: Row(
              children: [
                Icon(
                  Icons.cloud_done_outlined,
                  size: 14,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.autoSaveHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (widget.record != null)
          UpdatedAtText(dateTime: widget.record!.updatedAt),
      ],
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
                if (widget.isEditing)
                  TextField(
                    key: const Key('password_website_field'),
                    controller: _websiteController,
                    decoration: InputDecoration(
                      hintText: l10n.notFilled,
                      hintStyle: TextStyle(
                        color: colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.5),
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => _syncBody(),
                  )
                else if (website != null && website.isNotEmpty)
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
                      if (widget.isEditing)
                        TextField(
                          key: const Key('password_username_field'),
                          controller: _usernameController,
                          decoration: InputDecoration(
                            hintText: l10n.notFilled,
                            hintStyle: TextStyle(
                              color: colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.5),
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => _syncBody(),
                        )
                      else if (username != null && username.isNotEmpty)
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
                if (!widget.isEditing && username != null && username.isNotEmpty)
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
                      if (widget.isEditing)
                        TextField(
                          key: const Key('password_password_field'),
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: l10n.notFilled,
                            hintStyle: TextStyle(
                              color: colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.5),
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => _syncBody(),
                        )
                      else if (password != null && password.isNotEmpty)
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
                if (widget.isEditing)
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
                  )
                else if (password != null && password.isNotEmpty) ...[
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
          if (widget.isEditing)
            TextField(
              key: const Key('password_notes_field'),
              controller: _notesController,
              minLines: 2,
              maxLines: null,
              decoration: InputDecoration(
                hintText: l10n.notFilled,
                hintStyle: TextStyle(
                  color: colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.5),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface,
                height: 1.5,
              ),
              onChanged: (_) => _syncBody(),
            )
          else
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
