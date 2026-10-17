// lib/features/records/presentation/template_views/id_card_view.dart
// ID card view: a bank-card-style rendering of an ID document record,
// shown in the reading state of [IdDocumentTemplateView] (spec Phase 2).
//
// Interactions: tap to flip (if a back photo exists), eye toggle for the
// document number, long-press to copy the raw number, tap a photo to
// reveal it (auto re-blurs after 10s), ⋯ menu for share/save photo.

import 'dart:async';
import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suicun/features/records/domain/id_doc_data.dart';
import 'package:suicun/features/records/domain/id_doc_expiry.dart';
import 'package:suicun/features/records/presentation/id_doc_types.dart';
import 'package:suicun/features/records/presentation/template_views/id_expiry_pill.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';
import 'package:suicun/shared/utils/mask_doc_number.dart';

class IdCardView extends StatefulWidget {
  const IdCardView({
    super.key,
    required this.docType,
    required this.docTypeLabel,
    this.name,
    this.docNumber,
    this.validUntil,
    this.frontPhoto,
    this.backPhoto,
    this.frontPhotoMissing = false,
    this.backPhotoMissing = false,
    this.issuingCountry,
    this.expiryDate,
    this.noExpiry = false,
    required this.onPresent,
    required this.onSharePhoto,
  });

  /// Parsed document type key (drives gradient + icon).
  final IdDocType docType;

  /// Localized document type name (custom "other" names shown as-is).
  final String docTypeLabel;
  final String? name;
  final String? docNumber;
  final String? validUntil;

  /// Resolved photo files (null when the record has no photo on that side).
  final Uint8List? frontPhoto;
  final Uint8List? backPhoto;

  /// True when a photo path is set but the file is missing on this device
  /// (e.g. synced from another device). Shows a placeholder instead.
  final bool frontPhotoMissing;
  final bool backPhotoMissing;

  /// ISO 3166-1 alpha-2 country code (e.g. 'US'). Shown top-right when set.
  final String? issuingCountry;

  /// Expiry date for the §5 status pill. When null and [noExpiry] is false,
  /// no pill is shown.
  final DateTime? expiryDate;

  /// True when the document is marked as long-term valid.
  final bool noExpiry;

  /// Called when the "present document" button is tapped.
  final VoidCallback onPresent;

  /// Reused share/save logic from the template view.
  final Future<void> Function(BuildContext context, Uint8List bytes) onSharePhoto;

  @override
  State<IdCardView> createState() => _IdCardViewState();
}

class _IdCardViewState extends State<IdCardView>
    with SingleTickerProviderStateMixin {
  static final _cjkRegex = RegExp(r'[\u3400-\u9FFF]');

  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;

  bool _showingBack = false;
  bool _showFullNumber = false;
  bool _frontRevealed = false;
  bool _backRevealed = false;
  bool _showHint = false;
  Timer? _frontRevealTimer;
  Timer? _backRevealTimer;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flipAnimation = CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOutCubic,
    );
    _loadHintCount();
  }

  @override
  void dispose() {
    _frontRevealTimer?.cancel();
    _backRevealTimer?.cancel();
    _flipController.dispose();
    super.dispose();
  }

  /// Shows the hint below the card only on the first 3 visits to an ID
  /// record detail page (SharedPreferences `id_card_hint_count`).
  Future<void> _loadHintCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = prefs.getInt('id_card_hint_count') ?? 0;
      await prefs.setInt('id_card_hint_count', count + 1);
      if (mounted) setState(() => _showHint = count < 3);
    } catch (_) {
      if (mounted) setState(() => _showHint = true);
    }
  }

  void _toggleFlip() {
    if (widget.backPhoto == null) return;
    final toBack = !_showingBack;
    if (MediaQuery.disableAnimationsOf(context)) {
      _flipController.value = toBack ? 1.0 : 0.0;
    } else if (toBack) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
    setState(() => _showingBack = toBack);
  }

  void _togglePhotoReveal(bool isFront) {
    setState(() {
      if (isFront) {
        _frontRevealTimer?.cancel();
        _frontRevealTimer = null;
        _frontRevealed = !_frontRevealed;
        if (_frontRevealed) {
          _frontRevealTimer = Timer(const Duration(seconds: 10), () {
            if (mounted) setState(() => _frontRevealed = false);
          });
        }
      } else {
        _backRevealTimer?.cancel();
        _backRevealTimer = null;
        _backRevealed = !_backRevealed;
        if (_backRevealed) {
          _backRevealTimer = Timer(const Duration(seconds: 10), () {
            if (mounted) setState(() => _backRevealed = false);
          });
        }
      }
    });
  }

  Future<void> _copyNumber() async {
    final raw = widget.docNumber?.trim() ?? '';
    if (raw.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    await HapticFeedback.mediumImpact();
    await Clipboard.setData(ClipboardData(text: raw));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.idNumberCopied),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  /// ⋯ menu: share photo / save to gallery. When both sides exist, the user
  /// picks a side first.
  Future<void> _showMoreMenu() async {
    final front = widget.frontPhoto;
    final back = widget.backPhoto;
    if (front == null && back == null) return;
    final l10n = AppLocalizations.of(context);

    Uint8List? target = front ?? back;
    if (front != null && back != null) {
      if (!mounted) return;
      target = await showModalBottomSheet<Uint8List>(
        context: context,
        builder: (sheetCtx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  l10n.choosePhotoSide,
                  style: Theme.of(sheetCtx).textTheme.titleSmall,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_outlined),
                title: Text(l10n.idCardFrontPhoto),
                onTap: () => Navigator.of(sheetCtx).pop(front),
              ),
              ListTile(
                leading: const Icon(Icons.photo_outlined),
                title: Text(l10n.idCardBackPhoto),
                onTap: () => Navigator.of(sheetCtx).pop(back),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
      if (target == null || !mounted) return;
    }

    final action = await showModalBottomSheet<int>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: Text(l10n.sharePhoto),
              onTap: () => Navigator.of(sheetCtx).pop(0),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    await widget.onSharePhoto(context, target!);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayName = widget.name?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label:
              '${widget.docTypeLabel}, ${displayName.isEmpty ? l10n.notFilled : displayName}',
          child: GestureDetector(
            key: const Key('id_card_gesture'),
            onTap: _toggleFlip,
            onLongPress: _copyNumber,
            child: AnimatedBuilder(
              animation: _flipAnimation,
              builder: (context, _) {
                final angle = _flipAnimation.value * pi;
                // The card is edge-on at 90°: swap sides exactly there so the
                // swap itself is invisible.
                final showFront = _flipAnimation.value < 0.5;
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(angle),
                  child: showFront
                      ? _buildCardShell(
                          context, _buildFrontChildren(context, l10n))
                      : Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..rotateY(pi),
                          child: _buildCardShell(
                              context, _buildBackChildren(context, l10n)),
                        ),
                );
              },
            ),
          ),
        ),
        if (_showHint) ...[
          const SizedBox(height: 10),
          Text(
            widget.backPhoto != null
                ? l10n.idCardHintFlip
                : l10n.idCardHintNoFlip,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('id_card_present_button'),
          onPressed: widget.onPresent,
          icon: const Icon(Icons.fullscreen),
          label: Text(l10n.idFullScreenView),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }

  /// Card shell: aspect ratio, gradient, decorative circles, shadow.
  /// No brand watermark.
  Widget _buildCardShell(BuildContext context, List<Widget> children) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gradientColors = kDocTypeGradients[widget.docType]!;

    return AspectRatio(
      aspectRatio: 85.6 / 54,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = constraints.maxWidth;
          return Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.4)
                      : gradientColors.last.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
              border: isDark
                  ? Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    )
                  : null,
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CardCirclesPainter(cardWidth: cardWidth),
                  ),
                ),
                ...children,
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildFrontChildren(
      BuildContext context, AppLocalizations l10n) {
    final name = widget.name?.trim() ?? '';
    final rawNumber = widget.docNumber?.trim() ?? '';
    final validUntil = widget.validUntil?.trim() ?? '';
    final hasFrontPhoto = widget.frontPhoto != null;
    final showFrontPhotoArea =
        hasFrontPhoto || widget.frontPhotoMissing;
    final hasBackPhoto = widget.backPhoto != null;
    final isCjk = _cjkRegex.hasMatch(name);

    return [
      // Top-left: type icon + localized type name.
      Positioned(
        left: 18,
        top: 16,
        right: 52,
        child: Row(
          children: [
            Icon(
              widget.docType.icon,
              size: 18,
              color: Colors.white.withValues(alpha: 0.95),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                widget.docTypeLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              ),
            ),
          ],
        ),
      ),
      // Top-right: country code + ⋯ menu.
      Positioned(
        right: 8,
        top: 8,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.issuingCountry?.trim().isNotEmpty ?? false)
              Container(
                margin: const EdgeInsets.only(right: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.issuingCountry!.trim().toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                ),
              ),
            IconButton(
              key: const Key('id_card_more_button'),
              icon: const Icon(Icons.more_horiz, size: 24),
              color: Colors.white.withValues(alpha: 0.8),
              tooltip: l10n.idCardMoreActions,
              onPressed: _showMoreMenu,
            ),
          ],
        ),
      ),
      // Left, 46 from top: name + valid-until subline.
      Positioned(
        left: 18,
        top: 46,
        right: hasFrontPhoto ? 100 : 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name.isEmpty ? l10n.notFilled : name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                // CJK names get wider tracking; never insert spaces.
                letterSpacing: name.isEmpty ? 0.5 : (isCjk ? 2 : 0.5),
                color: name.isEmpty
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.white,
              ),
            ),
            if (validUntil.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                l10n.idCardValidUntil(validUntil),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
      // Right, 46 from top: front photo (64×80), blurred by default.
      // If the photo file is missing on this device, show a placeholder.
      if (showFrontPhotoArea)
        Positioned(
          right: 18,
          top: 46,
          child: hasFrontPhoto
              ? _buildPhotoThumb(
                  bytes: widget.frontPhoto!,
                  revealed: _frontRevealed,
                  onTap: () => _togglePhotoReveal(true),
                  l10n: l10n,
                )
              : _buildMissingPhotoPlaceholder(l10n),
        ),
      // Bottom-left: document number + eye toggle + expiry pill.
      if (rawNumber.isNotEmpty)
        Positioned(
          left: 18,
          bottom: 16,
          right: 56,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Semantics(
                      // Screen readers only ever hear the masked value.
                      label: maskDocNumber(rawNumber),
                      excludeSemantics: true,
                      child: Text(
                        _showFullNumber
                            ? formatDocNumber(rawNumber)
                            : maskDocNumber(rawNumber),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          letterSpacing: 1.5,
                          color: Colors.white,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    key: const Key('id_card_number_eye'),
                    icon: Icon(
                      _showFullNumber
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 16,
                    ),
                    color: Colors.white.withValues(alpha: 0.8),
                    tooltip: _showFullNumber
                        ? l10n.hidePassword
                        : l10n.showPassword,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () =>
                        setState(() => _showFullNumber = !_showFullNumber),
                  ),
                ],
              ),
              // Expiry status pill (§5), shown below the number when relevant.
              _buildExpiryPill(),
            ],
          ),
        ),
      // Bottom-right: flip hint (only a hint; tapping flips like the card).
      if (hasBackPhoto)
        Positioned(
          right: 18,
          bottom: 18,
          child: Icon(
            Icons.flip_rounded,
            size: 14,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
    ];
  }

  List<Widget> _buildBackChildren(
      BuildContext context, AppLocalizations l10n) {
    return [
      Positioned.fill(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: GestureDetector(
              onTap: () => _togglePhotoReveal(false),
              child: Semantics(
                button: true,
                label: l10n.idCardTapToReveal,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildPhotoImage(widget.backPhoto!, blurred: !_backRevealed),
                    if (!_backRevealed)
                      Container(
                        color: Colors.black.withValues(alpha: 0.25),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.visibility_off_outlined,
                                size: 20,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.idCardTapToReveal,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      Positioned(
        right: 18,
        bottom: 16,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.flip_rounded,
              size: 14,
              color: Colors.white.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 4),
            Text(
              l10n.idCardFlipBack,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  /// Builds the expiry status pill (§5) shown below the document number.
  /// Returns an empty widget when there's no expiry info or the doc is valid.
  Widget _buildExpiryPill() {
    final doc = IdDocData(
      type: 'other', // Type doesn't affect expiry calculation.
      expiryDate: widget.expiryDate,
      noExpiry: widget.noExpiry,
    );
    final status = expiryStatusOf(doc);
    if (status == IdDocExpiryStatus.valid) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: IdExpiryPill(status: status),
    );
  }

  Widget _buildPhotoThumb({
    required Uint8List bytes,
    required bool revealed,
    required VoidCallback onTap,
    required AppLocalizations l10n,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        button: true,
        label: l10n.idCardTapToReveal,
        child: Container(
          width: 64,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildPhotoImage(bytes, blurred: !revealed),
              if (!revealed)
                const Center(
                  child: Icon(
                    Icons.visibility_off_outlined,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMissingPhotoPlaceholder(AppLocalizations l10n) {
    return Container(
      width: 64,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 1.5,
        ),
        color: Colors.white.withValues(alpha: 0.08),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.image_not_supported_outlined,
            size: 20,
            color: Colors.white70,
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              l10n.photoNotOnThisDevice,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 9, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoImage(Uint8List bytes, {required bool blurred}) {
    final image = Image.memory(
      bytes,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: Colors.white.withValues(alpha: 0.1),
      ),
    );
    if (!blurred) return image;
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: image,
    );
  }
}

/// Decorative translucent circles (top-right + bottom-left). Deliberately
/// abstract — no official-document motifs.
class _CardCirclesPainter extends CustomPainter {
  const _CardCirclesPainter({required this.cardWidth});

  final double cardWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final topRight = Paint()
      ..color = Colors.white.withValues(alpha: 0.07);
    canvas.drawCircle(
      Offset(size.width + cardWidth * 0.08, -cardWidth * 0.08),
      cardWidth * 0.28,
      topRight,
    );
    final bottomLeft = Paint()
      ..color = Colors.white.withValues(alpha: 0.05);
    canvas.drawCircle(
      Offset(-cardWidth * 0.1, size.height + cardWidth * 0.1),
      cardWidth * 0.3,
      bottomLeft,
    );
  }

  @override
  bool shouldRepaint(covariant _CardCirclesPainter oldDelegate) =>
      oldDelegate.cardWidth != cardWidth;
}
