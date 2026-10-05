// lib/features/security/data/app_lock_service.dart
// Stage B: app lock (spec §9).
//
// - Unlock via app PIN and/or biometric / device credential (local_auth).
// - The PIN only gates UI access. It is NEVER used to derive the database
//   key (spec §9 forbids low-entropy PIN key derivation); the DB key stays
//   a random 256-bit value in the platform secure storage.
// - The PIN is stored as an Argon2id hash (salted, PHC-like format),
//   not plaintext. 5 consecutive failures trigger a 30s lockout.
// - Re-lock triggers: app start (when enabled) and return from background
//   after the configured timeout.

import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import 'package:suicun/core/crypto/key_value_store.dart';

/// Lock timeout options (seconds).
enum LockTimeout {
  immediately(0),
  oneMinute(60),
  fiveMinutes(300);

  const LockTimeout(this.seconds);
  final int seconds;
}

class AppLockService {
  AppLockService({
    KeyValueStore? store,
    LocalAuthentication? auth,
    Random? random,
  })  : _store = store ?? SecureStorageKeyValueStore(),
        _auth = auth ?? LocalAuthentication(),
        _random = random ?? Random.secure();

  final KeyValueStore _store;
  final LocalAuthentication _auth;
  final Random _random;

  static const _kEnabled = 'suicun.applock.enabled';
  // PHC-like format: argon2id$v=19$m=<kb>,t=<iter>,p=<par>$<salt_b64>$<hash_b64>
  static const _kPinHash = 'suicun.applock.pinHash.v2';
  static const _kBiometric = 'suicun.applock.biometric';
  static const _kTimeout = 'suicun.applock.timeoutSecs';
  static const _kFailCount = 'suicun.applock.failCount';
  static const _kLockoutUntil = 'suicun.applock.lockoutUntilMs';

  /// Argon2id cost for PIN hashing: fast enough for a lock screen
  /// (~0.1-0.3s), slow enough to make offline brute force of a 4-6 digit
  /// PIN expensive. (Plain SHA-256 would fall in milliseconds.)
  static const _pinMemoryKb = 16384;
  static const _pinIterations = 2;
  static const _pinParallelism = 1;

  static const _maxFailures = 5;
  static const _lockoutDuration = Duration(seconds: 30);

  Argon2id get _pinKdf => Argon2id(
        parallelism: _pinParallelism,
        memory: _pinMemoryKb,
        iterations: _pinIterations,
        hashLength: 32,
      );

  // ── Settings ─────────────────────────────────────────────────────────────

  Future<bool> isEnabled() async => await _store.read(_kEnabled) == '1';

  Future<void> setEnabled(bool enabled) async {
    await _store.write(_kEnabled, enabled ? '1' : '0');
  }

  Future<bool> hasPin() async => await _store.read(_kPinHash) != null;

  Future<bool> isBiometricEnabled() async =>
      await _store.read(_kBiometric) == '1';

  Future<void> setBiometricEnabled(bool enabled) async {
    await _store.write(_kBiometric, enabled ? '1' : '0');
  }

  Future<LockTimeout> getTimeout() async {
    final raw = await _store.read(_kTimeout);
    final secs = int.tryParse(raw ?? '');
    for (final t in LockTimeout.values) {
      if (t.seconds == secs) return t;
    }
    return LockTimeout.oneMinute;
  }

  Future<void> setTimeout(LockTimeout timeout) async {
    await _store.write(_kTimeout, timeout.seconds.toString());
  }

  /// True when at least one unlock method is configured.
  Future<bool> canUnlock() async =>
      await hasPin() || await isBiometricEnabled();

  // ── PIN ──────────────────────────────────────────────────────────────────

  /// Sets (or changes) the app PIN. Minimum 4 digits.
  /// The PIN is hashed with Argon2id (never stored plaintext, never SHA-256:
  /// a 4-6 digit PIN would fall to offline brute force in milliseconds).
  /// Returns false when the PIN is too short; never throws for input errors.
  Future<bool> setPin(String pin) async {
    final trimmed = pin.trim();
    if (trimmed.length < 4) return false;
    final salt = Uint8List(16);
    for (var i = 0; i < salt.length; i++) {
      salt[i] = _random.nextInt(256);
    }
    final hash = await _pinKdf.deriveKey(
      secretKey: SecretKey(utf8.encode(trimmed)),
      nonce: salt,
    );
    final hashBytes = await hash.extractBytes();
    await _store.write(
      _kPinHash,
      'argon2id\$v=19\$m=$_pinMemoryKb,t=$_pinIterations,p=$_pinParallelism'
      '\$${base64Encode(salt)}\$${base64Encode(hashBytes)}',
    );
    // Reset any lockout when the PIN changes.
    await _store.delete(_kFailCount);
    await _store.delete(_kLockoutUntil);
    return true;
  }

  Future<void> clearPin() => _store.delete(_kPinHash);

  /// Remaining lockout time after too many failed attempts.
  Future<Duration> lockoutRemaining() async {
    final raw = await _store.read(_kLockoutUntil);
    final untilMs = int.tryParse(raw ?? '');
    if (untilMs == null) return Duration.zero;
    final remaining =
        DateTime.fromMillisecondsSinceEpoch(untilMs).difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Verifies a PIN against the stored Argon2id hash.
  /// Returns false while locked out, when no PIN is set, or on mismatch.
  /// Tracks failures: [_maxFailures] consecutive failures trigger a
  /// [_lockoutDuration] lockout.
  Future<void> _verifyQueue = Future<void>.value();

  Future<bool> verifyPin(String pin) {
    // Serialize attempts: concurrent calls would otherwise all read the same
    // fail counter and let an attacker try many PINs per counter increment.
    final result = _verifyQueue.then((_) => _verifyPinLocked(pin));
    _verifyQueue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<bool> _verifyPinLocked(String pin) async {
    if (await lockoutRemaining() > Duration.zero) return false;
    final stored = await _store.read(_kPinHash);
    if (stored == null) return false;
    final ok = await _verifyPinHash(pin.trim(), stored);
    if (ok) {
      await _store.delete(_kFailCount);
      await _store.delete(_kLockoutUntil);
      return true;
    }
    final fails = (int.tryParse(await _store.read(_kFailCount) ?? '') ?? 0) + 1;
    await _store.write(_kFailCount, fails.toString());
    if (fails >= _maxFailures) {
      // 30s for the first lockout, doubling every further batch of
      // failures (capped at 1h) to slow long-running brute force.
      final level = min((fails - _maxFailures) ~/ _maxFailures, 7);
      final duration = _lockoutDuration * (1 << level);
      final capped =
          duration > const Duration(hours: 1) ? const Duration(hours: 1) : duration;
      await _store.write(
        _kLockoutUntil,
        DateTime.now().add(capped).millisecondsSinceEpoch.toString(),
      );
    }
    return false;
  }


  /// Parses the PHC-like hash and compares with constant-time digest check.
  Future<bool> _verifyPinHash(String pin, String stored) async {
    try {
      // argon2id$v=19$m=<kb>,t=<iter>,p=<par>$<salt_b64>$<hash_b64>
      final parts = stored.split('\$');
      if (parts.length != 5 || parts[0] != 'argon2id') return false;
      final paramMatch =
          RegExp(r'^m=(\d+),t=(\d+),p=(\d+)$').firstMatch(parts[2]);
      if (paramMatch == null) return false;
      final kdf = Argon2id(
        memory: int.parse(paramMatch.group(1)!),
        iterations: int.parse(paramMatch.group(2)!),
        parallelism: int.parse(paramMatch.group(3)!),
        hashLength: 32,
      );
      final salt = base64Decode(parts[3]);
      final expected = base64Decode(parts[4]);
      final derived = await kdf.deriveKey(
        secretKey: SecretKey(utf8.encode(pin)),
        nonce: salt,
      );
      final actual = await derived.extractBytes();
      if (actual.length != expected.length) return false;
      var diff = 0;
      for (var i = 0; i < actual.length; i++) {
        diff |= actual[i] ^ expected[i];
      }
      return diff == 0;
    } catch (_) {
      return false;
    }
  }

  // ── Biometric / device credential ─────────────────────────────────────────

  /// Whether the device can do biometric or device-credential auth.
  Future<bool> deviceSupportsAuth() async {
    try {
      return await _auth.canCheckBiometrics ||
          await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  /// Prompts biometric / device credential. Returns true on success.
  /// Never throws; failures (no enrollment, user cancel) return false.
  Future<bool> authenticateBiometric({String reason = ''}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason.isEmpty ? '解锁随存' : reason,
        // biometricOnly: false allows device PIN/pattern/password fallback.
        biometricOnly: false,
      );
    } on PlatformException {
      return false;
    }
  }

  // ── Full reset (used by "erase all data") ──────────────────────────────────

  Future<void> clearAll() async {
    await Future.wait([
      _store.delete(_kEnabled),
      _store.delete(_kPinHash),
      _store.delete(_kBiometric),
      _store.delete(_kTimeout),
      _store.delete(_kFailCount),
      _store.delete(_kLockoutUntil),
    ]);
  }
}
