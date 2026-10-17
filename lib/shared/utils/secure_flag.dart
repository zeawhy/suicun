// lib/shared/utils/secure_flag.dart

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suicun/features/settings/data/privacy_prefs.dart';

/// Helper for toggling Android FLAG_SECURE (blocks screenshots/screen recording)
/// on pages that display sensitive ID document information.
///
/// Respects the user setting [PrivacyPrefsKeys.allowIdScreenshots]:
/// when the user explicitly allows screenshots, FLAG_SECURE is not applied.
class SecureFlag {
  SecureFlag._();

  static const _channel = MethodChannel('com.suivault.app/secure');

  /// Enables FLAG_SECURE unless the user has allowed screenshots in settings.
  static Future<void> enableIfNeeded() async {
    if (!Platform.isAndroid) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final allowed =
          prefs.getBool(PrivacyPrefsKeys.allowIdScreenshots) ?? false;
      if (allowed) return;
      await _channel.invokeMethod('enableSecure');
    } catch (_) {}
  }

  /// Disables FLAG_SECURE (call when leaving the protected page).
  static Future<void> disable() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('disableSecure');
    } catch (_) {}
  }
}
