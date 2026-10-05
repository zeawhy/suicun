// lib/core/crypto/backup_crypto.dart
// Stage B: self-contained encrypted backup container (spec §12).
//
// The container does NOT depend on the device secure storage, so it can be
// restored on a new device with only the backup password:
//   {
//     "format": "suicun-encrypted-backup", "version": 1,
//     "kdf": {"algorithm": "argon2id", "version": 19,
//             "memory_kb": 65536, "iterations": 3, "parallelism": 1,
//             "salt_b64": "<16 random bytes>"},
//     "nonce_b64": "<12 random bytes>",
//     "ciphertext_b64": "<AES-256-GCM of the plaintext backup JSON>"
//   }
//
// Argon2id parameters follow RFC 9106's first recommendation
// (m=64 MiB, t=3, p=1 — parallelism 1 keeps weak phones usable).
// The password is never stored; a wrong password fails GCM
// authentication and is reported as such (never as "corrupt file").

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class BackupCryptoError implements Exception {
  BackupCryptoError(this.message);
  final String message;
  @override
  String toString() => 'BackupCryptoError: $message';
}

/// KDF parameters written into every container (also used for decryption).
class BackupKdfParams {
  const BackupKdfParams({
    this.memoryKb = 65536,
    this.iterations = 3,
    this.parallelism = 1,
  });

  final int memoryKb;
  final int iterations;
  final int parallelism;

  Map<String, Object?> toJson(String saltB64) => {
        'algorithm': 'argon2id',
        'version': 19,
        'memory_kb': memoryKb,
        'iterations': iterations,
        'parallelism': parallelism,
        'salt_b64': saltB64,
      };

  static BackupKdfParams fromJson(Map<String, Object?> json) {
    if (json['algorithm'] != 'argon2id') {
      throw BackupCryptoError(
          'unsupported KDF: ${json['algorithm']} (expected argon2id)');
    }
    int asInt(Object? v, String name, int max) {
      if (v is int && v > 0 && v <= max) return v;
      throw BackupCryptoError('invalid KDF parameter: $name');
    }

    // Upper bounds: the container is untrusted input; unbounded values
    // would let a crafted file exhaust memory/CPU (up to 1 TiB of RAM).
    return BackupKdfParams(
      memoryKb: asInt(json['memory_kb'], 'memory_kb', 1 << 18), // 256 MiB
      iterations: asInt(json['iterations'], 'iterations', 16),
      parallelism: asInt(json['parallelism'], 'parallelism', 16),
    );

  }
}

class BackupCrypto {
  BackupCrypto({Random? random}) : _random = random ?? Random.secure();

  final Random _random;
  static final _aesGcm = AesGcm.with256bits();

  Uint8List _nonce(int length) {
    final b = Uint8List(length);
    for (var i = 0; i < length; i++) {
      b[i] = _random.nextInt(256);
    }
    return b;
  }

  Future<SecretKey> _deriveKey(
    String password,
    Uint8List salt,
    BackupKdfParams params,
  ) {
    final argon2 = Argon2id(
      parallelism: params.parallelism,
      memory: params.memoryKb,
      iterations: params.iterations,
      hashLength: 32,
    );
    return argon2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }

  /// Encrypts [plaintextJson] (the full backup JSON string) with [password].
  /// Returns the container as a JSON string, ready to write to a file.
  Future<String> encryptContainer(
    String plaintextJson,
    String password, {
    BackupKdfParams params = const BackupKdfParams(),
  }) async {
    if (password.isEmpty) {
      throw BackupCryptoError('backup password must not be empty');
    }
    final salt = _nonce(16);
    final nonce = _nonce(12);
    final key = await _deriveKey(password, salt, params);
    final box = await _aesGcm.encrypt(
      utf8.encode(plaintextJson),
      secretKey: key,
      nonce: nonce,
    );
    final container = {
      'format': 'suicun-encrypted-backup',
      'version': 1,
      'kdf': params.toJson(base64Encode(salt)),
      'nonce_b64': base64Encode(nonce),
      'ciphertext_b64': base64Encode(box.concatenation()),
    };
    return const JsonEncoder.withIndent('  ').convert(container);
  }

  /// Decrypts a container produced by [encryptContainer].
  /// Throws [BackupCryptoError] on wrong password (GCM auth failure),
  /// unsupported format, or malformed container.
  Future<String> decryptContainer(String containerJson, String password) async {
    if (password.isEmpty) {
      throw BackupCryptoError('backup password must not be empty');
    }
    late Map<String, dynamic> container;
    try {
      final decoded = jsonDecode(containerJson);
      if (decoded is! Map<String, dynamic>) {
        throw BackupCryptoError('not a JSON object');
      }
      container = decoded;
    } catch (e) {
      if (e is BackupCryptoError) rethrow;
      throw BackupCryptoError('container is not valid JSON');
    }

    if (container['format'] != 'suicun-encrypted-backup') {
      throw BackupCryptoError('not a 随存 encrypted backup container');
    }
    if (container['version'] != 1) {
      throw BackupCryptoError(
          'unsupported container version: ${container['version']}');
    }

    final kdfJson = container['kdf'];
    if (kdfJson is! Map<String, dynamic>) {
      throw BackupCryptoError('container is missing KDF parameters');
    }
    final params = BackupKdfParams.fromJson(kdfJson);
    final saltB64 = kdfJson['salt_b64'];
    final nonceB64 = container['nonce_b64'];
    final ctB64 = container['ciphertext_b64'];
    if (saltB64 is! String || nonceB64 is! String || ctB64 is! String) {
      throw BackupCryptoError('container is missing cryptographic fields');
    }

    late Uint8List salt, nonce, concatenation;
    try {
      salt = base64Decode(saltB64);
      nonce = base64Decode(nonceB64);
      concatenation = base64Decode(ctB64);
    } catch (_) {
      throw BackupCryptoError('container has malformed base64 fields');
    }
    if (salt.length != 16 || nonce.length != 12 || concatenation.isEmpty) {
      throw BackupCryptoError('container has invalid field lengths');
    }

    final key = await _deriveKey(password, salt, params);
    final List<int> clear;
    try {
      // concatenation() layout: nonce (12) + cipherText + mac (16).
      final box = SecretBox.fromConcatenation(
        concatenation,
        nonceLength: 12,
        macLength: 16,
      );
      clear = await _aesGcm.decrypt(box, secretKey: key);
    } on SecretBoxAuthenticationError {
      throw BackupCryptoError(
          'wrong password or tampered backup (authentication failed)');
    } catch (e) {
      throw BackupCryptoError('decryption failed: $e');
    }
    // Decryption succeeded: a decoding failure now means corrupted
    // plaintext, not a wrong password — report it distinctly.
    try {
      return utf8.decode(clear);
    } on FormatException {
      throw BackupCryptoError(
          'decrypted backup is not valid UTF-8 (data corrupted)');
    }
  }
}
