// lib/features/records/presentation/template_views/id_document_template_view.dart

// Read-only view for ID document template notes (Round 5 §1.4).
//
// Data source is [IdDocData] (structured). Editing is done exclusively via
// [IdDocForm]; this view has no editing mode, no TextFields, and never
// writes back to the body.


import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:suicun/features/records/domain/id_doc_data.dart';
import 'package:suicun/features/records/domain/record_model.dart';
import 'package:suicun/features/records/presentation/id_doc_types.dart';
import 'package:suicun/features/records/presentation/id_presentation_page.dart';
import 'package:suicun/features/records/presentation/template_views/id_card_view.dart';
import 'package:suicun/features/records/presentation/template_views/id_photo_storage.dart';
import 'package:suicun/features/records/presentation/template_views/template_header_card.dart';
import 'package:suicun/features/records/presentation/template_views/updated_at_text.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';
import 'package:suicun/shared/utils/display_title.dart';
import 'package:suicun/shared/utils/secure_flag.dart';

class IdDocumentTemplateView extends StatefulWidget {
  const IdDocumentTemplateView({
    super.key,
    required this.data,
    required this.record,
    required this.onEdit,
    required this.categoryRow,
    required this.tagRow,
    this.suggestionRow,
  });

  final IdDocData data;
  final RecordDetail? record;
  final VoidCallback onEdit;
  final Widget categoryRow;
  final Widget tagRow;
  final Widget? suggestionRow;

  @override
  State<IdDocumentTemplateView> createState() => _IdDocumentTemplateViewState();
}

class _IdDocumentTemplateViewState extends State<IdDocumentTemplateView> {
  bool _obscureNumber = true;

  /// Resolved photo bytes for the read-mode card view (null = no photo).
  Uint8List? _cardFrontBytes;
  Uint8List? _cardBackBytes;

  @override
  void initState() {
    super.initState();
    // Block screenshots on ID detail pages (unless user allowed in settings).
    SecureFlag.enableIfNeeded();
    _resolveCardPhotos();
  }

  /// Resolves the stored relative photo paths to bytes for [IdCardView].
  Future<void> _resolveCardPhotos() async {
    final front = await loadIdPhotoBytes(widget.data.photoFront ?? '');
    final back = await loadIdPhotoBytes(widget.data.photoBack ?? '');
    if (!mounted) return;
    setState(() {
      _cardFrontBytes = front;
      _cardBackBytes = back;
    });
  }

  @override
  void didUpdateWidget(IdDocumentTemplateView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data.photoFront != oldWidget.data.photoFront ||
        widget.data.photoBack != oldWidget.data.photoBack) {
      _resolveCardPhotos();
    }
  }

  @override
  void dispose() {
    // Restore screenshot ability when leaving the ID page.
    SecureFlag.disable();
    super.dispose();
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

  /// Shares the ID photo via the system share sheet.
  ///
  /// Decrypted bytes are written to a temporary file, shared, then deleted
  /// (spec §2.3: no plaintext photo files linger on disk).
  Future<void> _sharePhoto(BuildContext context, Uint8List bytes) async {
    final shareText = AppLocalizations.of(context).sharePhoto;
    File? tmp;
    try {
      final dir = await getTemporaryDirectory();
      tmp = File(
          '${dir.path}/id_photo_share_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tmp.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tmp.path)],
          text: shareText,
        ),
      );
    } catch (_) {
      // Ignore share cancellation/failure
    } finally {
      try {
        await tmp?.delete();
      } catch (_) {
        // Best effort
      }
    }
  }

  String _formatValidUntil(AppLocalizations l10n) {
    final data = widget.data;
    if (data.noExpiry) return l10n.idNoExpiry;
    final d = data.expiryDate;
    if (d == null) return l10n.notFilled;
    return DateFormat.yMMMd(Localizations.localeOf(context).languageCode)
        .format(d);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final data = widget.data;
    final type = IdDocTypeStorage.fromStorageKey(data.type);

    final title = widget.record != null
        ? displayTitleFor(widget.record!,
            untitled: l10n.untitledRecord,
            defaultDocType: l10n.templateIdDocument,
            context: context)
        : l10n.untitledRecord;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Header card
        TemplateHeaderCard(
          title: title,
          icon: type.icon,
          onEdit: widget.onEdit,
        ),
        const SizedBox(height: 16),

        // 2. ID card view
        IdCardView(
          docType: type,
          docTypeLabel: type.localizedName(l10n),
          name: data.name,
          docNumber: data.number,
          validUntil: _formatValidUntil(l10n),
          frontPhoto: _cardFrontBytes,
          backPhoto: _cardBackBytes,
          // §2.5: photo referenced but file missing on this device.
          frontPhotoMissing: (data.photoFront?.isNotEmpty ?? false) &&
              _cardFrontBytes == null,
          backPhotoMissing: (data.photoBack?.isNotEmpty ?? false) &&
              _cardBackBytes == null,
          issuingCountry: data.issuingCountry,
          expiryDate: data.expiryDate,
          noExpiry: data.noExpiry,
          onPresent: () {
            final rec = widget.record;
            if (rec != null) IdPresentationPage.show(context, rec);
          },
          onSharePhoto: _sharePhoto,
        ),
        const SizedBox(height: 16),

        // 3. Field card (read-only)
        _buildFieldsCard(context, theme, colorScheme, l10n),

        // 4. Notes card (hidden if empty)
        if (data.note != null && data.note!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildNotesCard(context, data.note!, theme, colorScheme, l10n),
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

        // 6. Updated at
        if (widget.record != null)
          UpdatedAtText(dateTime: widget.record!.updatedAt),
      ],
    );
  }

  Widget _buildFieldsCard(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    final data = widget.data;
    final divider = Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
    );

    Widget fieldValue(String? value) {
      if (value != null && value.isNotEmpty) {
        return SelectableText(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurface,
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
          // Name
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
                fieldValue(data.name),
              ],
            ),
          ),
          divider,

          // Document Number (masked by default)
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
                      if (data.number != null && data.number!.isNotEmpty)
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
                                data.number!,
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
                if (data.number != null && data.number!.isNotEmpty) ...[
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
                        _copyText(context, data.number, l10n.copied),
                  ),
                ],
              ],
            ),
          ),
          divider,

          // Valid Until
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
                Text(
                  _formatValidUntil(l10n),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
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
