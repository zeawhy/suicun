// lib/features/settings/data/privacy_prefs.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suicun/features/records/data/quick_access_storage.dart';

class PrivacyPrefsKeys {
  PrivacyPrefsKeys._();

  static const String clipboardSniffEnabled = 'clipboard_sniff_enabled';
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
