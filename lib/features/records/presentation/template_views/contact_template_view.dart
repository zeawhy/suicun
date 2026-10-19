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

class ContactTemplateView extends StatefulWidget {
  const ContactTemplateView({
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

  final ContactTemplateData data;
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
  State<ContactTemplateView> createState() => _ContactTemplateViewState();
}

class _ContactTemplateViewState extends State<ContactTemplateView> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.data.name ?? '');
    _phoneController = TextEditingController(text: widget.data.phone ?? '');
    _emailController = TextEditingController(text: widget.data.email ?? '');
    _addressController = TextEditingController(text: widget.data.address ?? '');
    _notesController = TextEditingController(text: widget.data.notes ?? '');
  }

  @override
  void didUpdateWidget(ContactTemplateView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isEditing) {
      if (widget.data.name != null &&
          widget.data.name != _nameController.text) {
        _nameController.text = widget.data.name!;
      }
      if (widget.data.phone != null &&
          widget.data.phone != _phoneController.text) {
        _phoneController.text = widget.data.phone!;
      }
      if (widget.data.email != null &&
          widget.data.email != _emailController.text) {
        _emailController.text = widget.data.email!;
      }
      if (widget.data.address != null &&
          widget.data.address != _addressController.text) {
        _addressController.text = widget.data.address!;
      }
      if (widget.data.notes != null &&
          widget.data.notes != _notesController.text) {
        _notesController.text = widget.data.notes!;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _syncBody() {
    final raw = widget.rawBody ?? '';
    final isEnglish = raw.contains('Name') ||
        raw.contains('name') ||
        raw.contains('Phone:') ||
        raw.contains('Email:');
    String body;
    if (isEnglish) {
      body = 'Name: ${_nameController.text}\n'
          'Phone: ${_phoneController.text}\n'
          'Email: ${_emailController.text}\n'
          'Address: ${_addressController.text}\n'
          'Notes: ${_notesController.text}';
    } else {
      body = '姓名：${_nameController.text}\n'
          '电话：${_phoneController.text}\n'
          '邮箱：${_emailController.text}\n'
          '地址：${_addressController.text}\n'
          '备注：${_notesController.text}';
    }
    // Round 9: preserve user-added custom lines verbatim so editing through
    // the template UI never drops them.
    final extra = widget.data.extraLines;
    if (extra.isNotEmpty) {
      body = '$body\n${extra.join('\n')}';
    }
    widget.onBodyChanged?.call(body);
  }

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

    final name = widget.data.name;
    final phone = widget.data.phone;
    final email = widget.data.email;
    final address = widget.data.address;
    final notes = widget.data.notes;

    final hasName = name != null && name.trim().isNotEmpty;
    final fallbackTitle = widget.record?.title.isNotEmpty == true
        ? widget.record!.title
        : l10n.untitledRecord;
    final headerTitle = hasName ? name.trim() : fallbackTitle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Header card (Icons.person_outline + name/title + pencil edit button)
        TemplateHeaderCard(
          title: headerTitle,
          icon: Icons.person_outline,
          onEdit: widget.onEdit,
          titleController: widget.titleController,
          onTitleChanged: widget.onTitleChanged,
        ),
        const SizedBox(height: 16),

        // 2. Contact fields card
        _buildContactFieldsCard(
          context,
          showNameField: widget.isEditing || !hasName,
          name: name,
          phone: phone,
          email: email,
          address: address,
          theme: theme,
          colorScheme: colorScheme,
          l10n: l10n,
        ),

        // 3. Notes card (independent, hidden if empty when reading)
        if (widget.isEditing || (notes != null && notes.trim().isNotEmpty)) ...[
          const SizedBox(height: 16),
          _buildNotesCard(context, notes?.trim() ?? '', theme, colorScheme, l10n),
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

    // Name field
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
              if (widget.isEditing)
                TextField(
                  key: const Key('contact_name_field'),
                  controller: _nameController,
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
                  if (widget.isEditing)
                    TextField(
                      key: const Key('contact_phone_field'),
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
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
                  else if (hasPhone)
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
            if (!widget.isEditing && hasPhone)
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
                  if (widget.isEditing)
                    TextField(
                      key: const Key('contact_email_field'),
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
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
                  else if (hasEmail)
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
            if (!widget.isEditing && hasEmail)
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
                  if (widget.isEditing)
                    TextField(
                      key: const Key('contact_address_field'),
                      controller: _addressController,
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
                  else if (hasAddress)
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
            if (!widget.isEditing && hasAddress)
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
          if (widget.isEditing)
            TextField(
              key: const Key('contact_notes_field'),
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
