// lib/features/security/presentation/app_lock_gate.dart
// Stage B: gates the whole app behind the app lock (spec §9).
//
// Behavior:
// - On startup, if the app lock is disabled, content shows immediately.
// - If enabled, a lock screen is shown until the user authenticates
//   (PIN and/or biometric, per settings).
// - When the app goes to background, the pause time is recorded; on
//   return, the app re-locks when the configured timeout has elapsed.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:suicun/features/security/data/security_providers.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';

/// Wraps the app; shows [child] only when unlocked.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  DateTime? _pausedAt;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialCheck();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initialCheck() async {
    final service = ref.read(appLockServiceProvider);
    final enabled = await service.isEnabled();
    if (!mounted) return;
    if (!enabled) {
      ref.read(appLockControllerProvider.notifier).unlock();
    }
    setState(() => _checking = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      _relockIfTimedOut();
    }
  }

  Future<void> _relockIfTimedOut() async {
    final service = ref.read(appLockServiceProvider);
    if (!await service.isEnabled()) return;
    if (ref.read(appLockControllerProvider)) return; // already locked
    final pausedAt = _pausedAt;
    if (pausedAt == null) {
      // No pause recorded (e.g. first resume); lock to be safe.
      ref.read(appLockControllerProvider.notifier).lock();
      return;
    }
    final timeout = await service.getTimeout();
    if (DateTime.now().difference(pausedAt).inSeconds >= timeout.seconds) {
      if (mounted) ref.read(appLockControllerProvider.notifier).lock();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    final locked = ref.watch(appLockControllerProvider);
    if (!locked) return widget.child;
    return MaterialApp(
      home: _LockScreen(
        onUnlocked: () =>
            ref.read(appLockControllerProvider.notifier).unlock(),
      ),
    );
  }
}

/// Lock screen: PIN pad and/or biometric button, per configuration.
class _LockScreen extends ConsumerStatefulWidget {
  const _LockScreen({required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  ConsumerState<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<_LockScreen> {
  String _pin = '';
  String? _error;
  bool _biometricAvailable = false;
  bool _checkingBiometric = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final service = ref.read(appLockServiceProvider);
    final bioEnabled = await service.isBiometricEnabled();
    final canAuth = bioEnabled && await service.deviceSupportsAuth();
    if (!mounted) return;
    setState(() {
      _biometricAvailable = canAuth;
      _checkingBiometric = false;
    });
    if (canAuth) {
      // Offer biometric immediately; user can fall back to PIN.
      _tryBiometric();
    }
  }

  Future<void> _tryBiometric() async {
    final service = ref.read(appLockServiceProvider);
    final l10n = AppLocalizations.of(context);
    final ok = await service.authenticateBiometric(
      reason: l10n.unlockApp,
    );
    if (ok && mounted) widget.onUnlocked();
  }

  Future<void> _onDigit(String d) async {
    if (_pin.length >= 12) return;
    setState(() {
      _pin += d;
      _error = null;
    });
  }

  Future<void> _onConfirm() async {
    if (_pin.length < 4) {
      setState(() => _error = AppLocalizations.of(context).pinTooShort);
      return;
    }
    final service = ref.read(appLockServiceProvider);
    final ok = await service.verifyPin(_pin);
    if (!mounted) return;
    if (ok) {
      widget.onUnlocked();
    } else {
      final lockout = await service.lockoutRemaining();
      setState(() {
        _error = lockout > Duration.zero
            ? AppLocalizations.of(context)
                .lockoutTryLater(lockout.inSeconds + 1)
            : AppLocalizations.of(context).wrongPin;
        _pin = '';
      });
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Icon(Icons.lock_outline,
                  size: 48, color: colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                l10n.appLocked,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // PIN dots (filled = entered digits).
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                children: [
                  for (var i = 0; i < _pin.length.clamp(0, 12); i++)
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.primary,
                      ),
                    ),
                  if (_pin.isEmpty)
                    Text(
                      l10n.enterPin,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              SizedBox(
                height: 28,
                child: _error == null
                    ? null
                    : Text(_error!,
                        style: TextStyle(
                            color: colorScheme.error, fontSize: 13)),
              ),
              if (!_checkingBiometric && _biometricAvailable)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: IconButton.filledTonal(
                    onPressed: _tryBiometric,
                    icon: const Icon(Icons.fingerprint, size: 32),
                    tooltip: l10n.useBiometric,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(64, 64),
                    ),
                  ),
                ),
              // Numeric pad.
              for (final row in [
                ['1', '2', '3'],
                ['4', '5', '6'],
                ['7', '8', '9'],
                ['ok', '0', 'back'],
              ])
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final key in row)
                      SizedBox(
                        width: 88,
                        height: 64,
                        child: key == 'back'
                            ? IconButton(
                                onPressed: _onBackspace,
                                icon:
                                    const Icon(Icons.backspace_outlined),
                              )
                            : key == 'ok'
                                ? IconButton.filled(
                                    onPressed: _onConfirm,
                                    icon: const Icon(Icons.check),
                                  )
                                : TextButton(
                                    onPressed: () => _onDigit(key),
                                    child: Text(
                                      key,
                                      style: theme
                                          .textTheme.headlineMedium,
                                    ),
                                  ),
                      ),
                  ],
                ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
