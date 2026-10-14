// lib/features/records/presentation/id_presentation_page.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:suicun/features/records/domain/record_model.dart';
import 'package:suicun/features/records/presentation/template_views/id_photo_storage.dart';
import 'package:suicun/features/records/presentation/template_views/template_detector.dart';

class _IdPhotoItem {
  const _IdPhotoItem({
    required this.isFront,
    required this.file,
  });

  final bool isFront;
  final File file;
}

/// Fullscreen presentation mode for ID/Photo records.
///
/// Features:
/// - Black fullscreen background.
/// - Increases screen brightness to maximum on entry, restores previous brightness on exit.
/// - PageView to switch between front and back photos with dots indicator.
/// - Top bar displaying "[Document Name] · 正面/背面" and close button.
/// - Disables screenshotting on Android using FLAG_SECURE (on iOS, best-effort documented).
/// - 4 bottom quick actions: Rotate (Landscape/Portrait), Show/Hide Number, Copy Number, Zoom (InteractiveViewer).
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

class _IdPresentationPageState extends State<IdPresentationPage> {
  // Native FLAG_SECURE toggle via MainActivity MethodChannel
  // (com.suivault.app/secure). Replaces the unmaintained
  // flutter_windowmanager plugin, which breaks the release build on AGP 9+.
  static const _secureChannel = MethodChannel('com.suivault.app/secure');

  final PageController _pageController = PageController();
  final List<TransformationController> _transformControllers = [];

  double? _previousBrightness;
  bool _isLandscape = false;
  bool _obscureNumber = false;
  final bool _showNumberBar = true;

  bool _loading = true;
  final List<_IdPhotoItem> _photoItems = [];
  String? _docNumber;
  String? _docName;

  @override
  void initState() {
    super.initState();
    _initEnvironment();
    _loadData();
  }

  Future<void> _initEnvironment() async {
    // 1. Maximize brightness
    try {
      _previousBrightness = await ScreenBrightness().application;
      await ScreenBrightness().setApplicationScreenBrightness(1.0);
    } catch (_) {
      // Ignored on unsupported platforms / test fakes
    }

    // 2. Disable screenshots (FLAG_SECURE on Android)
    // Platform differences:
    // Android: WindowManager.LayoutParams.FLAG_SECURE provides OS-level prevention
    // of screen capture, screen recording, and task switcher thumbnail leaking.
    // iOS: The iOS public SDK does not provide an equivalent system-wide toggle for FLAG_SECURE.
    // In production apps, developers typically hide sensitive content upon UIScreenCapturedNotification
    // or wrap views in secure text layer tricks. Here we apply FLAG_SECURE on Android.
    if (Platform.isAndroid) {
      try {
        await _secureChannel.invokeMethod('enableSecure');
      } catch (_) {}
    }
  }

  Future<void> _restoreEnvironment() async {
    // Restore brightness
    try {
      if (_previousBrightness != null) {
        await ScreenBrightness().setApplicationScreenBrightness(_previousBrightness!);
      } else {
        await ScreenBrightness().resetApplicationScreenBrightness();
      }
    } catch (_) {}

    // Restore FLAG_SECURE
    if (Platform.isAndroid) {
      try {
        await _secureChannel.invokeMethod('disableSecure');
      } catch (_) {}
    }

    // Restore orientation
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    } catch (_) {}
  }

  Future<void> _loadData() async {
    final idData = parseIdDocumentTemplate(widget.record.body);
    _docNumber = idData?.docNumber;
    _docName = idData?.name;

    final frontPath = idData?.photoFront;
    final backPath = idData?.photoBack;

    if (frontPath != null && frontPath.isNotEmpty) {
      final frontFile = await resolveIdPhoto(frontPath);
      if (frontFile != null && await frontFile.exists()) {
        _photoItems.add(_IdPhotoItem(isFront: true, file: frontFile));
        _transformControllers.add(TransformationController());
      }
    }

    if (backPath != null && backPath.isNotEmpty) {
      final backFile = await resolveIdPhoto(backPath);
      if (backFile != null && await backFile.exists()) {
        _photoItems.add(_IdPhotoItem(isFront: false, file: backFile));
        _transformControllers.add(TransformationController());
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
    _restoreEnvironment();
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
        const SnackBar(content: Text('未记录证件号码')),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: num));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('证件号码已复制到剪贴板')),
    );
  }

  void _toggleZoom() {
    if (_transformControllers.isEmpty || _currentPage >= _transformControllers.length) {
      return;
    }
    final controller = _transformControllers[_currentPage];
    final currentScale = controller.value.getMaxScaleOnAxis();
    if (currentScale > 1.05) {
      controller.value = Matrix4.identity();
    } else {
      controller.value = Matrix4.diagonal3Values(2.0, 2.0, 1.0);
    }
  }

  String _formatNumber(String raw) {
    if (!_obscureNumber) return raw;
    if (raw.length <= 6) return '******';
    final start = raw.substring(0, 4);
    final end = raw.substring(raw.length - 4);
    return '$start${'*' * (raw.length - 8).clamp(2, 8)}$end';
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.record.title.isNotEmpty ? widget.record.title : '证件出示';
    final sideText = _photoItems.isEmpty
        ? ''
        : (_photoItems[_currentPage].isFront ? '正面' : '背面');
    final headerTitle = sideText.isNotEmpty ? '$title · $sideText' : title;

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          child: Column(
            children: [
              // ── Top Header ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 26),
                      tooltip: '关闭',
                      onPressed: () => Navigator.of(context).pop(),
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
                                  Text(
                                    _docNumber != null && _docNumber!.isNotEmpty
                                        ? _formatNumber(_docNumber!)
                                        : '暂无证件照片与号码',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16,
                                      letterSpacing: 1.2,
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
                              return InteractiveViewer(
                                transformationController:
                                    _transformControllers[index],
                                minScale: 1.0,
                                maxScale: 5.0,
                                child: Center(
                                  child: Image.file(
                                    item.file,
                                    fit: BoxFit.contain,
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
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatNumber(_docNumber!),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _toggleNumberVisibility,
                        child: Icon(
                          _obscureNumber
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Bottom 4 Action Buttons ─────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      label: '横屏',
                      onTap: _toggleOrientation,
                    ),
                    _ActionButton(
                      icon: _obscureNumber
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      label: _obscureNumber ? '显示号码' : '隐藏号码',
                      onTap: _toggleNumberVisibility,
                    ),
                    _ActionButton(
                      icon: Icons.copy_rounded,
                      label: '复制号码',
                      onTap: _copyNumber,
                    ),
                    _ActionButton(
                      icon: Icons.zoom_in_rounded,
                      label: '放大',
                      onTap: _toggleZoom,
                    ),
                  ],
                ),
              ),
            ],
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
