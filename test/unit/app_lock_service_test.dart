// test/unit/app_lock_service_test.dart
// Stage B tests for the app lock service (PIN + settings).
// Biometric prompts need a real device and are not unit-tested.

import 'package:flutter_test/flutter_test.dart';

import 'package:suicun/core/crypto/key_value_store.dart';
import 'package:suicun/features/security/data/app_lock_service.dart';

void main() {
  late MemoryKeyValueStore store;
  late AppLockService service;

  setUp(() {
    store = MemoryKeyValueStore();
    service = AppLockService(store: store);
  });

  group('settings', () {
    test('enabled defaults to false', () async {
      expect(await service.isEnabled(), isFalse);
    });

    test('enable/disable round-trips', () async {
      await service.setEnabled(true);
      expect(await service.isEnabled(), isTrue);
      await service.setEnabled(false);
      expect(await service.isEnabled(), isFalse);
    });

    test('timeout defaults to one minute and round-trips', () async {
      expect(await service.getTimeout(), LockTimeout.oneMinute);
      await service.setTimeout(LockTimeout.fiveMinutes);
      expect(await service.getTimeout(), LockTimeout.fiveMinutes);
      await service.setTimeout(LockTimeout.immediately);
      expect(await service.getTimeout(), LockTimeout.immediately);
    });

    test('biometric flag round-trips', () async {
      expect(await service.isBiometricEnabled(), isFalse);
      await service.setBiometricEnabled(true);
      expect(await service.isBiometricEnabled(), isTrue);
    });

    test('canUnlock is false with nothing configured', () async {
      expect(await service.canUnlock(), isFalse);
    });

    test('canUnlock is true after setting a PIN', () async {
      await service.setPin('1234');
      expect(await service.canUnlock(), isTrue);
    });
  });

  group('PIN', () {
    test('rejects PINs shorter than 4 digits', () async {
      expect(await service.setPin('123'), isFalse);
      expect(await service.hasPin(), isFalse);
    });

    test('set + verify round-trips', () async {
      expect(await service.setPin('4826'), isTrue);
      expect(await service.hasPin(), isTrue);
      expect(await service.verifyPin('4826'), isTrue);
      expect(await service.verifyPin('4827'), isFalse);
      expect(await service.verifyPin(''), isFalse);
    });

    test('PIN is stored hashed (argon2id), not plaintext', () async {
      await service.setPin('4826');
      final stored = await store.read('suicun.applock.pinHash.v2');
      expect(stored, isNotNull);
      expect(stored, isNot(contains('4826')));
      expect(stored, startsWith('argon2id\$'));
    });

    test('clearPin removes verification', () async {
      await service.setPin('4826');
      await service.clearPin();
      expect(await service.hasPin(), isFalse);
      expect(await service.verifyPin('4826'), isFalse);
    });

    test('changing PIN invalidates the old one', () async {
      await service.setPin('1111');
      await service.setPin('2222');
      expect(await service.verifyPin('1111'), isFalse);
      expect(await service.verifyPin('2222'), isTrue);
    });

    test('5 consecutive failures trigger a lockout', () async {
      await service.setPin('4826');
      for (var i = 0; i < 5; i++) {
        expect(await service.verifyPin('0000'), isFalse);
      }
      expect(await service.lockoutRemaining() > Duration.zero, isTrue);
      // Even the correct PIN is rejected while locked out.
      expect(await service.verifyPin('4826'), isFalse);
    });

    test('successful verify resets the failure counter', () async {
      await service.setPin('4826');
      for (var i = 0; i < 4; i++) {
        await service.verifyPin('0000');
      }
      expect(await service.verifyPin('4826'), isTrue);
      expect(await service.lockoutRemaining(), Duration.zero);
      // Counter was reset: 4 more failures do not lock out.
      for (var i = 0; i < 4; i++) {
        await service.verifyPin('0000');
      }
      expect(await service.lockoutRemaining(), Duration.zero);
    });
  });
}
