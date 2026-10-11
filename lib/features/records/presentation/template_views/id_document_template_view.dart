// lib/features/records/presentation/template_views/id_document_template_view.dart
// Reading & editing view for ID document template notes.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suicun/features/records/domain/record_model.dart';
import 'package:suicun/features/records/presentation/template_views/id_photo_storage.dart';
import 'package:suicun/features/records/presentation/template_views/template_detector.dart';
import 'package:suicun/features/records/presentation/template_views/template_header_card.dart';
import 'package:suicun/features/records/presentation/template_views/updated_at_text.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';

enum IdDocTypeKey {
  idCard,
  driverLicense,
  vehicleLicense,
  passport,
  hmtPermit,
  socialCard,
  propertyCert,
  other,
}

const Map<IdDocTypeKey, String> _kDocTypeChineseLabels = {
  IdDocTypeKey.idCard: '身份证',
  IdDocTypeKey.driverLicense: '驾驶证',
  IdDocTypeKey.vehicleLicense: '行驶证',
  IdDocTypeKey.passport: '护照',
  IdDocTypeKey.hmtPermit: '港澳通行证',
  IdDocTypeKey.socialCard: '社保卡',
  IdDocTypeKey.propertyCert: '房产证',
  IdDocTypeKey.other: '其他',
};

const Map<IdDocTypeKey, String> _kDocTypeEnglishLabels = {
  IdDocTypeKey.idCard: 'ID Card',
  IdDocTypeKey.driverLicense: 'Driver License',
  IdDocTypeKey.vehicleLicense: 'Vehicle License',
  IdDocTypeKey.passport: 'Passport',
  IdDocTypeKey.hmtPermit: 'Exit-Entry Permit (HK/Macau)',
  IdDocTypeKey.socialCard: 'Social Security Card',
  IdDocTypeKey.propertyCert: 'Property Certificate',
  IdDocTypeKey.other: 'Other',
};

IdDocTypeKey _parseDocTypeKey(String? docType) {
  if (docType == null || docType.trim().isEmpty) {
    return IdDocTypeKey.idCard;
  }
  final dt = docType.trim();
  final lower = dt.toLowerCase();
  if (dt == '身份证' || lower == 'id card') return IdDocTypeKey.idCard;
  if (dt == '驾驶证' || lower == 'driver license') return IdDocTypeKey.driverLicense;
  if (dt == '行驶证' || lower == 'vehicle license') return IdDocTypeKey.vehicleLicense;
  if (dt == '护照' || lower == 'passport') return IdDocTypeKey.passport;
  if (dt == '港澳通行证' || lower.contains('exit-entry') || lower.contains('hmt')) {
    return IdDocTypeKey.hmtPermit;
  }
  if (dt == '社保卡' || lower == 'social security card') return IdDocTypeKey.socialCard;
  if (dt == '房产证' || lower == 'property certificate') return IdDocTypeKey.propertyCert;
  return IdDocTypeKey.other;
}

class IdDocumentTemplateView extends StatefulWidget {
  const IdDocumentTemplateView({
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

  final IdDocumentTemplateData data;
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
  State<IdDocumentTemplateView> createState() => _IdDocumentTemplateViewState();
}

class _IdDocumentTemplateViewState extends State<IdDocumentTemplateView> {
  bool _obscureNumber = true;
  late IdDocTypeKey _selectedDocTypeKey;
  late final TextEditingController _customDocTypeController;
  late final TextEditingController _nameController;
  late final TextEditingController _numberController;
  late final TextEditingController _validUntilController;
  late final TextEditingController _notesController;

  String? _photoFrontRel;
  String? _photoBackRel;

  @override
  void initState() {
    super.initState();
    _selectedDocTypeKey = _parseDocTypeKey(widget.data.docType);
    final isCustomOther = _selectedDocTypeKey == IdDocTypeKey.other;
    final customInitialText = isCustomOther &&
            widget.data.docType != null &&
            widget.data.docType != '其他' &&
            widget.data.docType?.toLowerCase() != 'other'
        ? widget.data.docType!
        : '';
    _customDocTypeController = TextEditingController(text: customInitialText);
    _nameController = TextEditingController(text: widget.data.name ?? '');
    _numberController =
        TextEditingController(text: widget.data.docNumber ?? '');
    _validUntilController =
        TextEditingController(text: widget.data.validUntil ?? '');
    _notesController = TextEditingController(text: widget.data.notes ?? '');
    _photoFrontRel = widget.data.photoFront;
    _photoBackRel = widget.data.photoBack;
  }

  @override
  void didUpdateWidget(IdDocumentTemplateView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isEditing) {
      if (widget.data.name != null &&
          widget.data.name != _nameController.text) {
        _nameController.text = widget.data.name!;
      }
      if (widget.data.docNumber != null &&
          widget.data.docNumber != _numberController.text) {
        _numberController.text = widget.data.docNumber!;
      }
      if (widget.data.validUntil != null &&
          widget.data.validUntil != _validUntilController.text) {
        _validUntilController.text = widget.data.validUntil!;
      }
      if (widget.data.notes != null &&
          widget.data.notes != _notesController.text) {
        _notesController.text = widget.data.notes!;
      }
      if (widget.data.photoFront != _photoFrontRel) {
        _photoFrontRel = widget.data.photoFront;
      }
      if (widget.data.photoBack != _photoBackRel) {
        _photoBackRel = widget.data.photoBack;
      }
      if (widget.data.docType != null) {
        final parsed = _parseDocTypeKey(widget.data.docType);
        if (parsed != _selectedDocTypeKey) {
          _selectedDocTypeKey = parsed;
          if (parsed == IdDocTypeKey.other) {
            final dt = widget.data.docType!;
            if (dt != '其他' && dt.toLowerCase() != 'other') {
              _customDocTypeController.text = dt;
            }
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _customDocTypeController.dispose();
    _nameController.dispose();
    _numberController.dispose();
    _validUntilController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _syncBody() {
    final raw = widget.rawBody ?? '';
    final isEnglish = raw.contains('Document type') ||
        raw.contains('document type') ||
        raw.contains('Document number') ||
        raw.contains('document number') ||
        raw.contains('Valid until') ||
        raw.contains('ID photo front');

    final String type;
    if (_selectedDocTypeKey == IdDocTypeKey.other) {
      final customText = _customDocTypeController.text.trim();
      if (customText.isNotEmpty) {
        type = customText;
      } else {
        type = isEnglish ? 'Other' : '其他';
      }
    } else {
      type = isEnglish
          ? _kDocTypeEnglishLabels[_selectedDocTypeKey]!
          : _kDocTypeChineseLabels[_selectedDocTypeKey]!;
    }

    final name = _nameController.text;
    final number = _numberController.text;
    final valid = _validUntilController.text;
    final frontRel = _photoFrontRel ?? '';
    final backRel = _photoBackRel ?? '';
    final notes = _notesController.text;

    final String body;
    if (isEnglish) {
      body = 'Document type: $type\n'
          'Name: $name\n'
          'Document number: $number\n'
          'Valid until: $valid\n'
          'ID photo front: $frontRel\n'
          'ID photo back: $backRel\n'
          'Notes: $notes';
    } else {
      body = '证件类型：$type\n'
          '姓名：$name\n'
          '证件号码：$number\n'
          '有效期至：$valid\n'
          '证件照片正面：$frontRel\n'
          '证件照片反面：$backRel\n'
          '备注：$notes';
    }
    widget.onBodyChanged?.call(body);
  }

  void _toggleNumberVisibility() {
    setState(() {
      _obscureNumber = !_obscureNumber;
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

  Future<void> _pickPhoto({
    required bool isFront,
    required ImageSource source,
  }) async {
    if (source == ImageSource.camera) {
      final prefs = await SharedPreferences.getInstance();
      final shown = prefs.getBool('id_camera_rationale_shown') ?? false;
      if (!shown) {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context);
        final agreed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.cameraRationaleTitle),
            content: Text(l10n.cameraRationaleMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(l10n.confirm),
              ),
            ],
          ),
        );
        if (agreed != true) return;
        await prefs.setBool('id_camera_rationale_shown', true);
      }
    }

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source);
      if (picked == null) return;

      final recordId = widget.record?.id ?? 'new';
      final relPath = await saveIdPhoto(
        picked,
        recordId: recordId,
        isFront: isFront,
      );
      if (relPath != null && mounted) {
        setState(() {
          if (isFront) {
            _photoFrontRel = relPath;
          } else {
            _photoBackRel = relPath;
          }
        });
        _syncBody();
      }
    } catch (_) {
      // Ignore pick failure or canceled
    }
  }

  void _viewPhoto(BuildContext context, File file) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(l10n.viewPhoto),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.file(file),
            ),
          ),
        ),
      ),
    );
  }

  String _getDocTypeDisplay(AppLocalizations l10n, IdDocTypeKey key) {
    switch (key) {
      case IdDocTypeKey.idCard:
        return l10n.docTypeIdCard;
      case IdDocTypeKey.driverLicense:
        return l10n.docTypeDriverLicense;
      case IdDocTypeKey.vehicleLicense:
        return l10n.docTypeVehicleLicense;
      case IdDocTypeKey.passport:
        return l10n.docTypePassport;
      case IdDocTypeKey.hmtPermit:
        return l10n.docTypeHmtPermit;
      case IdDocTypeKey.socialCard:
        return l10n.docTypeSocialCard;
      case IdDocTypeKey.propertyCert:
        return l10n.docTypePropertyCert;
      case IdDocTypeKey.other:
        return l10n.docTypeOther;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final docType = widget.data.docType;
    final name = widget.data.name;
    final docNumber = widget.data.docNumber;
    final validUntil = widget.data.validUntil;
    final notes = widget.data.notes;

    final title = widget.record?.title.isNotEmpty == true
        ? widget.record!.title
        : l10n.untitledRecord;

    final hasFront = _photoFrontRel != null && _photoFrontRel!.isNotEmpty;
    final hasBack = _photoBackRel != null && _photoBackRel!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Header card
        TemplateHeaderCard(
          title: title,
          icon: Icons.badge_outlined,
          onEdit: widget.onEdit,
          titleController: widget.titleController,
          onTitleChanged: widget.onTitleChanged,
        ),
        const SizedBox(height: 16),

        // 2. Field card (Surface container, rounded 16)
        _buildFieldsCard(
          context,
          docType: docType,
          name: name,
          docNumber: docNumber,
          validUntil: validUntil,
          theme: theme,
          colorScheme: colorScheme,
          l10n: l10n,
        ),

        // 3. Photo card (front & back)
        if (widget.isEditing || hasFront || hasBack) ...[
          const SizedBox(height: 16),
          _buildPhotosCard(
            context,
            theme: theme,
            colorScheme: colorScheme,
            l10n: l10n,
          ),
        ],

        // 4. Notes card (independent, hidden if empty when reading)
        if (widget.isEditing || (notes != null && notes.isNotEmpty)) ...[
          const SizedBox(height: 16),
          _buildNotesCard(context, notes ?? '', theme, colorScheme, l10n),
        ],

        const SizedBox(height: 16),

        // 5. Category & Tag rows container
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

        // 6. Updated at relative time or auto-save hint
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
    BuildContext context, {
    required String? docType,
    required String? name,
    required String? docNumber,
    required String? validUntil,
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
          // Field 1: Document Type
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.fieldDocType,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                if (widget.isEditing) ...[
                  DropdownButtonFormField<IdDocTypeKey>(
                    key: const Key('id_doc_type_dropdown'),
                    initialValue: _selectedDocTypeKey,
                    isDense: true,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      filled: false,
                    ),
                    items: IdDocTypeKey.values.map((key) {
                      return DropdownMenuItem(
                        value: key,
                        child: Text(_getDocTypeDisplay(l10n, key)),
                      );
                    }).toList(),
                    onChanged: (newKey) {
                      if (newKey != null) {
                        setState(() {
                          _selectedDocTypeKey = newKey;
                        });
                        _syncBody();
                      }
                    },
                  ),
                  if (_selectedDocTypeKey == IdDocTypeKey.other) ...[
                    const SizedBox(height: 6),
                    TextField(
                      key: const Key('id_doc_type_custom_field'),
                      controller: _customDocTypeController,
                      decoration: InputDecoration(
                        hintText: l10n.docTypeCustomHint,
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
                    ),
                  ],
                ] else if (docType != null && docType.isNotEmpty)
                  SelectableText(
                    docType,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  )
                else
                  Text(
                    l10n.notFilled,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
          divider,

          // Field 2: Name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.fieldDocName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                if (widget.isEditing)
                  TextField(
                    key: const Key('id_doc_name_field'),
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
                else if (name != null && name.isNotEmpty)
                  SelectableText(
                    name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  )
                else
                  Text(
                    l10n.notFilled,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
          divider,

          // Field 3: Document Number (Masked by default)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.fieldDocNumber,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (widget.isEditing)
                        TextField(
                          key: const Key('id_doc_number_field'),
                          controller: _numberController,
                          obscureText: _obscureNumber,
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
                      else if (docNumber != null && docNumber.isNotEmpty)
                        _obscureNumber
                            ? Text(
                                '••••••',
                                key: const Key('id_doc_number_masked_text'),
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  letterSpacing: 2.0,
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : SelectableText(
                                docNumber,
                                key: const Key('id_doc_number_visible_text'),
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: colorScheme.onSurface,
                                ),
                              )
                      else
                        Text(
                          l10n.notFilled,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.5),
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.isEditing)
                  IconButton(
                    key: const Key('id_doc_number_toggle_obscure'),
                    icon: Icon(
                      _obscureNumber
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                    tooltip: _obscureNumber
                        ? l10n.showPassword
                        : l10n.hidePassword,
                    color: colorScheme.onSurfaceVariant,
                    onPressed: _toggleNumberVisibility,
                  )
                else if (docNumber != null && docNumber.isNotEmpty) ...[
                  IconButton(
                    key: const Key('id_doc_number_toggle_obscure'),
                    icon: Icon(
                      _obscureNumber
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                    tooltip: _obscureNumber
                        ? l10n.showPassword
                        : l10n.hidePassword,
                    color: colorScheme.onSurfaceVariant,
                    onPressed: _toggleNumberVisibility,
                  ),
                  IconButton(
                    key: const Key('id_doc_number_copy_button'),
                    icon: const Icon(Icons.copy_rounded, size: 20),
                    tooltip: l10n.copy,
                    color: colorScheme.onSurfaceVariant,
                    onPressed: () =>
                        _copyText(context, docNumber, l10n.copied),
                  ),
                ],
              ],
            ),
          ),
          divider,

          // Field 4: Valid Until
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.fieldValidUntil,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                if (widget.isEditing)
                  TextField(
                    key: const Key('id_doc_valid_until_field'),
                    controller: _validUntilController,
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
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => _syncBody(),
                  )
                else if (validUntil != null && validUntil.isNotEmpty)
                  SelectableText(
                    validUntil,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  )
                else
                  Text(
                    l10n.notFilled,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosCard(
    BuildContext context, {
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
          // Front photo section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.fieldPhotoFront,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                _buildPhotoSlot(
                  context,
                  isFront: true,
                  relPath: _photoFrontRel,
                  theme: theme,
                  colorScheme: colorScheme,
                  l10n: l10n,
                ),
              ],
            ),
          ),
          divider,
          // Back photo section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.fieldPhotoBack,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                _buildPhotoSlot(
                  context,
                  isFront: false,
                  relPath: _photoBackRel,
                  theme: theme,
                  colorScheme: colorScheme,
                  l10n: l10n,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSlot(
    BuildContext context, {
    required bool isFront,
    required String? relPath,
    required ThemeData theme,
    required ColorScheme colorScheme,
    required AppLocalizations l10n,
  }) {
    final hasPhoto = relPath != null && relPath.isNotEmpty;

    if (hasPhoto) {
      return FutureBuilder<File?>(
        future: resolveIdPhoto(relPath),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }

          final file = snapshot.data;
          if (file != null) {
            return GestureDetector(
              onTap: () => _viewPhoto(context, file),
              child: Stack(
                children: [
                  Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.outlineVariant
                            .withValues(alpha: 0.5),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.file(
                      file,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: colorScheme.outline,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.zoom_in,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  if (widget.isEditing)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            setState(() {
                              if (isFront) {
                                _photoFrontRel = null;
                              } else {
                                _photoBackRel = null;
                              }
                            });
                            _syncBody();
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }

          // File does not exist on disk
          return Container(
            height: 80,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image_outlined, color: colorScheme.outline),
                const SizedBox(width: 8),
                Text(
                  l10n.notFilled,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
                if (widget.isEditing) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () {
                      setState(() {
                        if (isFront) {
                          _photoFrontRel = null;
                        } else {
                          _photoBackRel = null;
                        }
                      });
                      _syncBody();
                    },
                  ),
                ],
              ],
            ),
          );
        },
      );
    }

    // No photo
    if (widget.isEditing) {
      return Container(
        height: 110,
        width: double.infinity,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 26,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  key: Key(isFront
                      ? 'id_photo_front_camera_button'
                      : 'id_photo_back_camera_button'),
                  onPressed: () => _pickPhoto(
                    isFront: isFront,
                    source: ImageSource.camera,
                  ),
                  icon: const Icon(Icons.camera_alt_outlined, size: 16),
                  label: Text(l10n.takePhoto),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  key: Key(isFront
                      ? 'id_photo_front_gallery_button'
                      : 'id_photo_back_gallery_button'),
                  onPressed: () => _pickPhoto(
                    isFront: isFront,
                    source: ImageSource.gallery,
                  ),
                  icon: const Icon(Icons.photo_library_outlined, size: 16),
                  label: Text(l10n.chooseFromGallery),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Text(
      l10n.notFilled,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
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
              key: const Key('id_doc_notes_field'),
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
