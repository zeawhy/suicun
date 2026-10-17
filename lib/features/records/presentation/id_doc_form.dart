// lib/features/records/presentation/id_doc_form.dart
// Round 4 §3: ID document edit form.

import 'dart:async';
import 'dart:io';

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:suicun/features/records/domain/id_doc_data.dart';
import 'package:suicun/features/records/presentation/id_doc_types.dart';
import 'package:suicun/features/records/presentation/template_views/id_photo_storage.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';

class IdDocForm extends StatefulWidget {
  const IdDocForm({
    super.key,
    this.initialData,
    required this.recordId,
    required this.onSave,
    this.categoryRow,
    this.tagRow,
  });

  final IdDocData? initialData;
  final String recordId;
  final Future<void> Function(IdDocData data) onSave;
  final Widget? categoryRow;
  final Widget? tagRow;

  @override
  State<IdDocForm> createState() => _IdDocFormState();
}

class _IdDocFormState extends State<IdDocForm> {
  late IdDocType _selectedType;
  late final TextEditingController _nameController;
  late final TextEditingController _numberController;
  late final TextEditingController _noteController;

  bool _obscureNumber = true;
  String? _issuingCountryCode;
  DateTime? _issueDate;
  DateTime? _expiryDate;
  bool _noExpiry = false;

  File? _photoFrontFile;
  File? _photoBackFile;
  String? _photoFrontRel;
  String? _photoBackRel;

  List<IdDocType> _orderedTypes = [];
  bool _isSaving = false;

  /// §1.6.1: True debounce — 600ms Timer restarted on every change.
  Timer? _saveTimer;

  /// Set when a change arrives while [_performSave] is running; triggers
  /// one more save after the current one finishes.
  bool _pendingSave = false;

  /// True once the user manually picks a type (§1.6.4).
  bool _userSelectedType = false;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    _selectedType = IdDocTypeStorage.fromStorageKey(data?.type);
    _nameController = TextEditingController(text: data?.name ?? '');
    _numberController = TextEditingController(text: data?.number ?? '');
    _noteController = TextEditingController(text: data?.note ?? '');
    _issuingCountryCode = data?.issuingCountry;
    _issueDate = data?.issueDate;
    _expiryDate = data?.expiryDate;
    _noExpiry = data?.noExpiry ?? false;
    _photoFrontRel = data?.photoFront;
    _photoBackRel = data?.photoBack;
    _loadOrderedTypes();
    _resolvePhotos();
    _nameController.addListener(_onFieldChanged);
    _numberController.addListener(_onFieldChanged);
    _noteController.addListener(_onFieldChanged);
  }

  Future<void> _loadOrderedTypes() async {
    final countryCode =
        WidgetsBinding.instance.platformDispatcher.locale.countryCode;
    final ordered = await getOrderedDocTypes(countryCode);
    if (!mounted) return;
    setState(() => _orderedTypes = ordered);
    // §1.6.4: New form defaults to the first ordered type.
    if (widget.initialData == null &&
        !_userSelectedType &&
        ordered.isNotEmpty) {
      setState(() => _selectedType = ordered.first);
    }
  }

  Future<void> _resolvePhotos() async {
    final front = await resolveIdPhoto(_photoFrontRel ?? '');
    final back = await resolveIdPhoto(_photoBackRel ?? '');
    if (!mounted) return;
    setState(() {
      _photoFrontFile = front;
      _photoBackFile = back;
    });
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _nameController.dispose();
    _numberController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    // §1.6.1: Real debounce — cancel and restart the 600ms timer.
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), () {
      _save();
    });
  }

  /// Debounced save entry point. If a save is already running, just mark
  /// [_pendingSave] so one more save happens afterwards.
  Future<void> _save() async {
    if (_isSaving) {
      _pendingSave = true;
      return;
    }
    await _performSave();
    if (_pendingSave) {
      _pendingSave = false;
      await _performSave();
    }
  }

  /// The actual save work (no re-entrancy guard here).
  Future<void> _performSave() async {
    _isSaving = true;
    // Show the saving indicator.
    if (mounted) setState(() {});
    try {
      final data = IdDocData(
        type: _selectedType.storageKey,
        name: _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
        number: _numberController.text.trim().isEmpty
            ? null
            : _numberController.text.trim(),
        issuingCountry: _issuingCountryCode,
        issueDate: _issueDate,
        expiryDate: _noExpiry ? null : _expiryDate,
        noExpiry: _noExpiry,
        photoFront: _photoFrontRel,
        photoBack: _photoBackRel,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
      await widget.onSave(data);
      await recordRecentDocType(_selectedType);
    } finally {
      _isSaving = false;
      if (mounted) setState(() {});
    }
  }

  /// §1.6.1: Final save on page exit. Cancels the debounce timer, waits for
  /// any in-progress save, then performs one last save to capture the
  /// latest field values.
  Future<void> _finalSaveOnExit() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    // Wait for any in-progress save to finish.
    while (_isSaving) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    // One last save to capture the latest state.
    await _performSave();
    // In case a change snuck in during the final save.
    if (_pendingSave) {
      _pendingSave = false;
      await _performSave();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // §1.6.1: Intercept pop to perform a final save and wait for it.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _finalSaveOnExit();
        if (context.mounted) Navigator.of(context).pop(result);
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(_selectedType.localizedName(l10n)),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTypeSelector(context, l10n, theme),
          const SizedBox(height: 16),
          _buildNameField(l10n),
          const SizedBox(height: 16),
          _buildNumberField(l10n, theme),
          if (docTypeShowsIssuingCountry(_selectedType)) ...[
            const SizedBox(height: 16),
            _buildCountrySelector(context, l10n, theme),
          ],
          const SizedBox(height: 16),
          _buildDateRow(context, l10n, theme),
          const SizedBox(height: 16),
          _buildPhotoRow(context, l10n, theme, isFront: true),
          const SizedBox(height: 12),
          _buildPhotoRow(context, l10n, theme, isFront: false),
          const SizedBox(height: 16),
          _buildNoteField(l10n),
          if (widget.categoryRow != null) ...[
            const SizedBox(height: 16),
            widget.categoryRow!,
          ],
          if (widget.tagRow != null) ...[
            const SizedBox(height: 8),
            widget.tagRow!,
          ],
          const SizedBox(height: 32),
        ],
      ),
      ),
    );
  }

  Widget _buildTypeSelector(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.idFieldType,
            style: theme.textTheme.labelLarge
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _showTypePicker(context, l10n),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(_selectedType.icon, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(_selectedType.localizedName(l10n),
                        style: theme.textTheme.bodyLarge)),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showTypePicker(
      BuildContext context, AppLocalizations l10n) async {
    final selected = await showModalBottomSheet<IdDocType>(
      context: context,
      builder: (ctx) =>
          _TypePickerSheet(types: _orderedTypes, selected: _selectedType, l10n: l10n),
    );
    if (selected != null && selected != _selectedType) {
      setState(() {
        _selectedType = selected;
        _userSelectedType = true;
      });
      _onFieldChanged();
    }
  }

  Widget _buildNameField(AppLocalizations l10n) {
    return TextField(
      controller: _nameController,
      decoration: InputDecoration(
          labelText: l10n.idFieldName, border: const OutlineInputBorder()),
      textInputAction: TextInputAction.next,
    );
  }

  Widget _buildNumberField(AppLocalizations l10n, ThemeData theme) {
    // §1.6.2: No restrictions on the number — any characters allowed,
    // no validation hint.
    return TextField(
      controller: _numberController,
      obscureText: _obscureNumber,
      decoration: InputDecoration(
        labelText: l10n.idFieldNumber,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(_obscureNumber
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _obscureNumber = !_obscureNumber),
        ),
      ),
      keyboardType: TextInputType.visiblePassword,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: TextInputAction.next,
    );
  }

  Widget _buildCountrySelector(
      BuildContext context, AppLocalizations l10n, ThemeData theme) {
    String displayName = '';
    if (_issuingCountryCode != null) {
      try {
        // §1.6.3: Localized country name via CountryLocalizations.
        displayName =
            CountryLocalizations.of(context)?.countryName(
              countryCode: _issuingCountryCode!,
            ) ??
            Country.parse(_issuingCountryCode!).name;
      } catch (_) {}
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.idFieldIssuingCountry,
            style: theme.textTheme.labelLarge
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () {
            showCountryPicker(
              context: context,
              showPhoneCode: false,
              showSearch: true,
              countryListTheme: const CountryListThemeData(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20))),
              onSelect: (Country country) {
                setState(() => _issuingCountryCode = country.countryCode);
                _onFieldChanged();
              },
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.public_outlined),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(displayName.isEmpty ? '—' : displayName,
                        style: theme.textTheme.bodyLarge)),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateRow(
      BuildContext context, AppLocalizations l10n, ThemeData theme) {
    final locale = Localizations.localeOf(context).toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
                child: _buildDateField(
                    context: context,
                    theme: theme,
                    label: l10n.idFieldIssueDate,
                    date: _issueDate,
                    onPick: (d) {
                      setState(() => _issueDate = d);
                      _onFieldChanged();
                    },
                    onClear: () {
                      setState(() => _issueDate = null);
                      _onFieldChanged();
                    },
                    locale: locale)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildDateField(
                    context: context,
                    theme: theme,
                    label: l10n.idFieldExpiryDate,
                    date: _noExpiry ? null : _expiryDate,
                    enabled: !_noExpiry,
                    onPick: (d) {
                      setState(() => _expiryDate = d);
                      _onFieldChanged();
                    },
                    onClear: () {
                      setState(() => _expiryDate = null);
                      _onFieldChanged();
                    },
                    locale: locale)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Switch(
                value: _noExpiry,
                onChanged: (v) {
                  setState(() => _noExpiry = v);
                  _onFieldChanged();
                }),
            const SizedBox(width: 8),
            Text(l10n.idNoExpiry),
          ],
        ),
      ],
    );
  }

  Widget _buildDateField({
    required BuildContext context,
    required ThemeData theme,
    required String label,
    required DateTime? date,
    required ValueChanged<DateTime?> onPick,
    required VoidCallback onClear,
    required String locale,
    bool enabled = true,
  }) {
    final display = date == null ? '—' : DateFormat.yMMMd(locale).format(date);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.labelLarge
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        InkWell(
          onTap: enabled
              ? () async {
                  final picked = await showDatePicker(
                      context: context,
                      initialDate: date ?? DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime(2100));
                  if (picked != null) onPick(picked);
                }
              : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(
                  color: enabled
                      ? theme.colorScheme.outline
                      : theme.colorScheme.outline.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                    child: Text(display,
                        style: theme.textTheme.bodyLarge?.copyWith(
                            color: enabled
                                ? null
                                : theme.colorScheme.onSurface
                                    .withValues(alpha: 0.4)))),
                if (date != null && enabled)
                  InkWell(
                      onTap: onClear, child: const Icon(Icons.clear, size: 20))
                else
                  const Icon(Icons.calendar_today_outlined, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoRow(BuildContext context, AppLocalizations l10n,
      ThemeData theme, {required bool isFront}) {
    final file = isFront ? _photoFrontFile : _photoBackFile;
    final label = isFront ? l10n.idPhotoFront : l10n.idPhotoBack;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.labelLarge
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 96,
              height: 64,
              decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline),
                  borderRadius: BorderRadius.circular(8)),
              clipBehavior: Clip.antiAlias,
              child: file != null
                  ? Image.file(file, fit: BoxFit.cover)
                  : InkWell(
                      onTap: () => _pickPhoto(context, l10n, isFront: isFront),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_a_photo_outlined, size: 24),
                          const SizedBox(height: 4),
                          Text(l10n.idPhotoAdd,
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
            ),
            if (file != null) ...[
              const SizedBox(width: 12),
              TextButton.icon(
                  onPressed: () => _pickPhoto(context, l10n, isFront: isFront),
                  icon: const Icon(Icons.refresh_outlined, size: 18),
                  label: Text(l10n.idPhotoReplace)),
              TextButton.icon(
                  onPressed: () => _removePhoto(isFront),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(l10n.idPhotoRemove),
                  style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error)),
            ],
          ],
        ),
      ],
    );
  }

  Future<void> _pickPhoto(BuildContext context, AppLocalizations l10n,
      {required bool isFront}) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: Text(l10n.idPhotoTake),
                onTap: () => Navigator.pop(ctx, ImageSource.camera)),
            ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(l10n.idPhotoPick),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    // §1.7: Delete the old photo file when replacing.
    final oldRel = isFront ? _photoFrontRel : _photoBackRel;
    final rel = await saveIdPhoto(picked,
        recordId: widget.recordId, isFront: isFront);
    if (rel == null) return;
    if (oldRel != null && oldRel != rel) {
      await deleteIdPhotoFile(oldRel);
    }
    final file = await resolveIdPhoto(rel);
    if (!mounted) return;
    setState(() {
      if (isFront) {
        _photoFrontRel = rel;
        _photoFrontFile = file;
      } else {
        _photoBackRel = rel;
        _photoBackFile = file;
      }
    });
    _onFieldChanged();
  }

  Future<void> _removePhoto(bool isFront) async {
    // §1.7: Delete the photo file when removing.
    final oldRel = isFront ? _photoFrontRel : _photoBackRel;
    if (oldRel != null) {
      await deleteIdPhotoFile(oldRel);
    }
    if (!mounted) return;
    setState(() {
      if (isFront) {
        _photoFrontRel = null;
        _photoFrontFile = null;
      } else {
        _photoBackRel = null;
        _photoBackFile = null;
      }
    });
    _onFieldChanged();
  }

  Widget _buildNoteField(AppLocalizations l10n) {
    return TextField(
      controller: _noteController,
      decoration: InputDecoration(
          labelText: l10n.idFieldNote,
          border: const OutlineInputBorder(),
          alignLabelWithHint: true),
      maxLines: 4,
      minLines: 3,
      textInputAction: TextInputAction.newline,
    );
  }
}

class _TypePickerSheet extends StatelessWidget {
  const _TypePickerSheet(
      {required this.types, required this.selected, required this.l10n});
  final List<IdDocType> types;
  final IdDocType selected;
  final AppLocalizations l10n;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCn = WidgetsBinding.instance.platformDispatcher.locale.countryCode
            ?.toUpperCase() ==
        'CN';
    List<IdDocType> mainList = types;
    List<IdDocType> chinaGroup = [];
    if (!isCn) {
      mainList = types.where((t) => !kChinaDocGroup.contains(t)).toList();
      chinaGroup = types.where((t) => kChinaDocGroup.contains(t)).toList();
    }
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
              padding: const EdgeInsets.all(16),
              child:
                  Text(l10n.idFieldType, style: theme.textTheme.titleLarge)),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                ...mainList.map((t) => _typeTile(context, t)),
                if (chinaGroup.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Text(l10n.idTypeGroupChina,
                        style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ),
                  ...chinaGroup.map((t) => _typeTile(context, t)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeTile(BuildContext context, IdDocType type) {
    final isSelected = type == selected;
    return ListTile(
      leading: Icon(type.icon),
      title: Text(type.localizedName(l10n)),
      trailing: isSelected
          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
          : null,
      selected: isSelected,
      onTap: () => Navigator.pop(context, type),
    );
  }
}
