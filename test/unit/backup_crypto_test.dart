// test/unit/backup_crypto_test.dart
// Stage B tests for the self-contained encrypted backup container.
// Uses the REAL Argon2id + AES-256-GCM (package:cryptography), with
// reduced KDF cost in tests for speed. Production defaults are stronger
// (see BackupKdfParams defaults).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:suicun/core/crypto/backup_crypto.dart';

const _testParams = BackupKdfParams(
  memoryKb: 8192,
  iterations: 1,
  parallelism: 1,
);

void main() {
  group('BackupCrypto', () {
    test('encrypt/decrypt round-trips', () async {
      const plaintext = '{"records":[{"title":"秘密","body":"hello 世界"}]}';
      final container = await BackupCrypto()
          .encryptContainer(plaintext, 'correct horse', params: _testParams);

      final decoded = jsonDecode(container) as Map<String, dynamic>;
      expect(decoded['format'], 'suicun-encrypted-backup');
      expect(decoded['version'], 1);
      final kdf = decoded['kdf'] as Map<String, dynamic>;
      expect(kdf['algorithm'], 'argon2id');
      expect(kdf['memory_kb'], 8192);

      final back = await BackupCrypto().decryptContainer(
        container,
        'correct horse',
      );
      expect(back, plaintext);
    });

    test('wrong password fails authentication (not silent garbage)', () async {
      final container = await BackupCrypto().encryptContainer(
        '{"a":1}',
        'right-password',
        params: _testParams,
      );
      expect(
        () => BackupCrypto().decryptContainer(container, 'wrong-password'),
        throwsA(
          isA<BackupCryptoError>().having(
            (e) => e.message,
            'message',
            contains('authentication failed'),
          ),
        ),
      );
    });

    test('tampered ciphertext is rejected', () async {
      final container = await BackupCrypto().encryptContainer(
        '{"a":1}',
        'password123',
        params: _testParams,
      );
      final decoded = jsonDecode(container) as Map<String, dynamic>;
      final ct = base64Decode(decoded['ciphertext_b64'] as String);
      ct[20] ^= 0xff; // flip a byte in the ciphertext region
      decoded['ciphertext_b64'] = base64Encode(ct);
      expect(
        () => BackupCrypto()
            .decryptContainer(jsonEncode(decoded), 'password123'),
        throwsA(isA<BackupCryptoError>()),
      );
    });

    test('two encryptions of the same input differ (random salt+nonce)',
        () async {
      final a = await BackupCrypto().encryptContainer(
        '{"a":1}',
        'password123',
        params: _testParams,
      );
      final b = await BackupCrypto().encryptContainer(
        '{"a":1}',
        'password123',
        params: _testParams,
      );
      expect(a, isNot(b));
    });

    test('malformed containers are rejected with clear errors', () async {
      const good = 'password123';
      // Not JSON.
      expect(
        () => BackupCrypto().decryptContainer('not json', good),
        throwsA(isA<BackupCryptoError>()),
      );
      // Wrong format marker.
      expect(
        () => BackupCrypto().decryptContainer(
            '{"format":"other","version":1}', good),
        throwsA(isA<BackupCryptoError>()),
      );
      // Unsupported version.
      expect(
        () => BackupCrypto().decryptContainer(
            '{"format":"suicun-encrypted-backup","version":99}', good),
        throwsA(isA<BackupCryptoError>()),
      );
      // Empty password.
      expect(
        () => BackupCrypto().encryptContainer('{}', '', params: _testParams),
        throwsA(isA<BackupCryptoError>()),
      );
    });

    test('KDF params round-trip', () {
      const params = BackupKdfParams(
          memoryKb: 32768, iterations: 2, parallelism: 1);
      final json = params.toJson('c2FsdA==');
      final back = BackupKdfParams.fromJson(json);
      expect(back.memoryKb, 32768);
      expect(back.iterations, 2);
      expect(back.parallelism, 1);
    });
  });
}
