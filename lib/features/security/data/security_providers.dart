// lib/features/security/data/security_providers.dart
// Riverpod providers for stage B security (app lock).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:suicun/features/security/data/app_lock_service.dart';

/// App lock service (PIN / biometric settings + verification).
final appLockServiceProvider = Provider<AppLockService>((ref) {
  return AppLockService();
});

/// Whether the app content is currently locked behind the app lock screen.
/// Starts locked; the gate unlocks it when the lock is disabled or the
/// user authenticates.
class AppLockController extends Notifier<bool> {
  @override
  bool build() => true;

  void lock() {
    state = true;
  }

  void unlock() {
    state = false;
  }
}

final appLockControllerProvider =
    NotifierProvider<AppLockController, bool>(AppLockController.new);

/// Whether app lock is currently enabled in settings.
final appLockEnabledProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(appLockServiceProvider);
  return service.isEnabled();
});
