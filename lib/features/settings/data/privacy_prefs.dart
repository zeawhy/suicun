// lib/features/settings/data/privacy_prefs.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suicun/features/records/data/quick_access_storage.dart';

class PrivacyPrefsKeys {
  PrivacyPrefsKeys._();

  static const String clipboardSniffEnabled = 'clipboard_sniff_enabled';
  static const String onboardingClipboardAsked = 'onboarding_clipboard_asked';
  static const String presentAutoBrightness = 'present_auto_brightness';
}

class ClipboardSniffEnabledNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    return prefs.getBool(PrivacyPrefsKeys.clipboardSniffEnabled) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool(PrivacyPrefsKeys.clipboardSniffEnabled, enabled);
    state = AsyncData(enabled);
  }
}

final clipboardSniffEnabledProvider =
    AsyncNotifierProvider<ClipboardSniffEnabledNotifier, bool>(
  ClipboardSniffEnabledNotifier.new,
);

class PresentAutoBrightnessNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    return prefs.getBool(PrivacyPrefsKeys.presentAutoBrightness) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool(PrivacyPrefsKeys.presentAutoBrightness, enabled);
    state = AsyncData(enabled);
  }
}

final presentAutoBrightnessProvider =
    AsyncNotifierProvider<PresentAutoBrightnessNotifier, bool>(
  PresentAutoBrightnessNotifier.new,
);
