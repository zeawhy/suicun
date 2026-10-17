// lib/features/records/presentation/id_presentation_page.dart

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suicun/features/records/domain/record_model.dart';
import 'package:suicun/features/records/domain/id_doc_codec.dart';
import 'package:suicun/features/records/presentation/template_views/id_photo_storage.dart';
import 'package:suicun/features/settings/data/privacy_prefs.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';
import 'package:suicun/shared/utils/display_title.dart';
import 'package:suicun/shared/utils/mask_doc_number.dart';
import 'package:suicun/shared/utils/secure_flag.dart';

class _IdPhotoItem {
  const _IdPhotoItem({
    required this.isFront,
    required this.bytes,
  });

  final bool isFront;
  final Uint8List bytes;
}

/// Fullscreen presentation mode for ID/Photo records.
///
/// Features:
/// - Black fullscreen background.
/// - Adjustable screen brightness with smooth ramp transition, controlled via SharedPreferences or manual toggle.
/// - PageView to switch between front and back photos with dots indicator.
/// - Top bar displaying "[Document Name] · 正面/背面" and close button.
/// - Disables screenshotting on Android using FLAG_SECURE (on iOS, best-effort documented).
/// - 5 bottom quick actions: Rotate (Landscape/Portrait), Brightness, Show/Hide Number, Copy Number, Zoom (InteractiveViewer).
class IdPresentationPage extends StatefulWidget {
  const IdPresentationPage({
    super.key,
    required this.record,
  });

  final RecordDetail record;

  static Future<void> show(BuildContext context, RecordDetail record) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => IdPresentationPage(record: record),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<IdPresentationPage> createState() => _IdPresentationPageState();
}

class _IdPresentationPageState extends State<IdPresentationPage>
    with WidgetsBindingObserver {
  // Native FLAG_SECURE toggle via SecureFlag helper
  // (com.suivault.app/secure). Replaces the unmaintained
  // flutter_windowmanager plugin, which breaks the release build on AGP 9+.

  final PageController _pageController = PageController();
  final List<TransformationController> _transformControllers = [];

  double? _previousBrightness;
  bool _isHighBrightness = false;
  bool _isRestoring = false;
  bool _isExiting = false;
  bool _canPopNow = false;

  bool _isLandscape = false;
  bool _obscureNumber = false;
  final bool _showNumberBar = true;
  bool _largeTextMode = false;

  bool _loading = true;
  final List<_IdPhotoItem> _photoItems = [];
  String? _docNumber;
  String? _docName;
  // Round 6 §6: true when a photo path was recorded but the file is missing
  // on this device (e.g. synced from another device).
  bool _photoMissing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initEnvironment();
    _loadData();
  }

  Future<void> _rampBrightness(double from, double to) async {
    const steps = 10;
    for (var i = 1; i <= steps; i++) {
      try {
        await ScreenBrightness()
            .setApplicationScreenBrightness(from + (to - from) * i / steps);
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 30));
    }
  }

  Future<void> _initEnvironment() async {
    try {
      _previousBrightness = await ScreenBrightness().application;
    } catch (_) {
      _previousBrightness = null;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final autoBright =
          prefs.getBool(PrivacyPrefsKeys.presentAutoBrightness) ?? false;
      if (autoBright) {
        final current = _previousBrightness ?? 0.5;
        await _rampBrightness(current, 1.0);
        if (mounted) {
          setState(() {
            _isHighBrightness = true;
          });
        }
      }
    } catch (_) {}

    // Disable screenshots (FLAG_SECURE on Android), unless user allowed in settings.
    await SecureFlag.enableIfNeeded();
  }

  Future<void> _toggleBrightness() async {
    try {
      final current = await ScreenBrightness().application;
      if (_isHighBrightness) {
        final target = _previousBrightness ?? current;
        await _rampBrightness(current, target);
        await ScreenBrightness().resetApplicationScreenBrightness();
        if (mounted) {
          setState(() {
            _isHighBrightness = false;
          });
        }
      } else {
        _previousBrightness ??= current;
        await _rampBrightness(current, 1.0);
        if (mounted) {
          setState(() {
            _isHighBrightness = true;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isHighBrightness = !_isHighBrightness;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_isHighBrightness) {
        try {
          if (_previousBrightness != null) {
            ScreenBrightness()
                .setApplicationScreenBrightness(_previousBrightness!);
          } else {
            ScreenBrightness().resetApplicationScreenBrightness();
          }
        } catch (_) {}
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_isHighBrightness) {
        try {
          ScreenBrightness().setApplicationScreenBrightness(1.0);
        } catch (_) {}
      }
    }
  }

  Future<void> _restoreEnvironment() async {
    if (_isRestoring) return;
    _isRestoring = true;

    // Restore brightness
    try {
      if (_isHighBrightness && _previousBrightness != null) {
        final current = await ScreenBrightness()
            .application
            .timeout(const Duration(milliseconds: 200));
        if (mounted) {
          await _rampBrightness(current, _previousBrightness!);
        }
      }
      await ScreenBrightness()
          .resetApplicationScreenBrightness()
          .timeout(const Duration(milliseconds: 200));
    } catch (_) {}

    // Restore FLAG_SECURE
    await SecureFlag.disable();

    // Restore orientation
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    } catch (_) {}
  }

  Future<void> _handleExit() async {
    if (_isExiting) return;
    _isExiting = true;
    await _restoreEnvironment();
    if (mounted) {
      _canPopNow = true;
      Navigator.of(context).pop();
    }
  }

  Future<void> _loadData() async {
    // Round 6 §6: decode via the new codec (structured JSON or legacy body).
    final idData = decodeIdDocBody(widget.record.body);
    _docNumber = idData?.number;
    _docName = idData?.name;

    final frontPath = idData?.photoFront;
    final backPath = idData?.photoBack;

    if (frontPath != null && frontPath.isNotEmpty) {
      final frontBytes = await loadIdPhotoBytes(frontPath);
      if (frontBytes != null) {
        _photoItems.add(_IdPhotoItem(isFront: true, bytes: frontBytes));
        _transformControllers.add(TransformationController());
      } else {
        _photoMissing = true;
      }
    }

    if (backPath != null && backPath.isNotEmpty) {
      final backBytes = await loadIdPhotoBytes(backPath);
      if (backBytes != null) {
        _photoItems.add(_IdPhotoItem(isFront: false, bytes: backBytes));
        _transformControllers.add(TransformationController());
      } else {
        _photoMissing = true;
      }
    }

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!_isRestoring) {
      _restoreEnvironment();
    }
    _pageController.dispose();
    for (final c in _transformControllers) {
      c.dispose();
    }
    super.dispose();
  }

  int _currentPage = 0;

  void _toggleOrientation() async {
    _isLandscape = !_isLandscape;
    setState(() {});
    try {
      if (_isLandscape) {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
      }
    } catch (_) {}
  }

  void _toggleNumberVisibility() {
    setState(() {
      _obscureNumber = !_obscureNumber;
    });
  }

  Future<void> _copyNumber() async {
    final num = _docNumber?.trim() ?? '';
    if (num.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context).noIdNumberRecorded)),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: num));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(AppLocalizations.of(context).idNumberCopiedMsg)),
    );
  }

  void _toggleZoom() {
    if (_photoItems.isNotEmpty && _currentPage < _transformControllers.length) {
      final controller = _transformControllers[_currentPage];
      final currentScale = controller.value.getMaxScaleOnAxis();
      if (currentScale > 1.05) {
        controller.value = Matrix4.identity();
      } else {
        controller.value = Matrix4.diagonal3Values(2.0, 2.0, 1.0);
      }
    } else {
      setState(() {
        _largeTextMode = !_largeTextMode;
      });
    }
  }

  String _formatNumber(String raw) {
    // Round 6 §6: use the global maskDocNumber, consistent with the card.
    if (!_obscureNumber) return raw;
    return maskDocNumber(raw);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = displayTitleFor(
      widget.record,
      untitled: l10n.untitledRecord,
      defaultDocType: l10n.templateIdDocument,
      context: context,
    );
    final sideText = _photoItems.isEmpty
        ? ''
        : (_photoItems[_currentPage].isFront
            ? l10n.frontSide
            : l10n.backSide);
    final headerTitle = sideText.isNotEmpty ? '$title · $sideText' : title;

    return PopScope(
      canPop: _canPopNow,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleExit();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: SafeArea(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragEnd: (details) {
                final isZoomed = _transformControllers.isNotEmpty &&
                    _currentPage < _transformControllers.length &&
                    _transformControllers[_currentPage].value.getMaxScaleOnAxis() > 1.05;
                if (!isZoomed && (details.primaryVelocity ?? 0) > 300) {
                  _handleExit();
                }
              },
              child: Column(
                children: [
                  // ── Top Header ──────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 26),
                          tooltip: l10n.closeAction,
                          onPressed: _handleExit,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            headerTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Center PageView (Photos) ────────────────────────────────
                  Expanded(
                    child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          )
                        : _photoItems.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.badge_outlined,
                                        size: 72,
                                        color: Colors.white38,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _docName ?? title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _largeTextMode = !_largeTextMode;
                                          });
                                        },
                                          child: Text(
                                          // Round 6 §6: a recorded-but-missing photo shows
                                          // "photo not on this device"; noPhotoOrNumber
                                          // only when neither photo nor number exists.
                                          _docNumber != null && _docNumber!.isNotEmpty
                                              ? _formatNumber(_docNumber!)
                                              : (_photoMissing
                                                  ? l10n.photoNotOnDevice
                                                  : l10n.noPhotoOrNumber),
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: _largeTextMode ? 24 : 16,
                                            fontWeight: _largeTextMode
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            letterSpacing: _largeTextMode ? 2.0 : 1.2,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures()
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : PageView.builder(
                                controller: _pageController,
                                itemCount: _photoItems.length,
                                onPageChanged: (idx) {
                                  setState(() {
                                    _currentPage = idx;
                                  });
                                },
                                itemBuilder: (context, index) {
                                  final item = _photoItems[index];
                                  return GestureDetector(
                                    onDoubleTap: () {
                                      final controller = _transformControllers[index];
                                      final currentScale = controller.value.getMaxScaleOnAxis();
                                      if (currentScale > 1.05) {
                                        controller.value = Matrix4.identity();
                                      } else {
                                        controller.value = Matrix4.diagonal3Values(2.5, 2.5, 1.0);
                                      }
                                    },
                                    child: InteractiveViewer(
                                      transformationController:
                                          _transformControllers[index],
                                      minScale: 1.0,
                                      maxScale: 5.0,
                                      child: Center(
                                        child: Image.memory(
                                          item.bytes,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),

                  // ── Dots Indicator ──────────────────────────────────────────
                  if (_photoItems.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _photoItems.length,
                          (i) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentPage == i
                                  ? Colors.white
                                  : Colors.white24,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // ── Number Display Bar ──────────────────────────────────────
                  if (_docNumber != null && _docNumber!.isNotEmpty && _showNumberBar)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _largeTextMode = !_largeTextMode;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        padding: EdgeInsets.symmetric(
                          horizontal: _largeTextMode ? 22 : 16,
                          vertical: _largeTextMode ? 12 : 8,
                        ),
                        decoration: BoxDecoration(
                          color: _largeTextMode ? Colors.white24 : Colors.white12,
                          borderRadius:
                              BorderRadius.circular(_largeTextMode ? 16 : 20),
                          border: _largeTextMode
                              ? Border.all(color: Colors.white70, width: 1.5)
                              : null,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _formatNumber(_docNumber!),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: _largeTextMode ? 24 : 15,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: _largeTextMode ? 2.0 : 1.1,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _toggleNumberVisibility,
                                child: Icon(
                                  _obscureNumber
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: _largeTextMode ? 22 : 18,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                _largeTextMode
                                    ? Icons.zoom_out_map_rounded
                                    : Icons.zoom_in_rounded,
                                size: _largeTextMode ? 20 : 16,
                                color: Colors.white60,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // ── Bottom 5 Action Buttons ─────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.white12, width: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _ActionButton(
                          icon: Icons.screen_rotation_outlined,
                          label: l10n.landscapeAction,
                          onTap: _toggleOrientation,
                        ),
                        _ActionButton(
                          icon: _isHighBrightness
                              ? Icons.brightness_high
                              : Icons.brightness_high_outlined,
                          label: l10n.presentBrightness,
                          onTap: _toggleBrightness,
                        ),
                        _ActionButton(
                          icon: _obscureNumber
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          label: _obscureNumber
                              ? l10n.showNumberAction
                              : l10n.hideNumberAction,
                          onTap: _toggleNumberVisibility,
                        ),
                        _ActionButton(
                          icon: Icons.copy_rounded,
                          label: l10n.copyNumberAction,
                          onTap: _copyNumber,
                        ),
                        _ActionButton(
                          icon: Icons.zoom_in_rounded,
                          label: l10n.zoomInAction,
                          onTap: _toggleZoom,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
