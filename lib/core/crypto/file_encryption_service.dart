// lib/core/crypto/file_encryption_service.dart
// Encrypts ID photos at rest (spec §2.3).
//
// Design mirrors DatabaseEncryptionService:
// - A random 256-bit file key is generated once and stored in the platform
//   secure storage (Android Keystore). Key: `suicun.crypto.fileKey.v1`.
// - AES-256-GCM via package:cryptography. File format:
//   `4-byte magic "SVF1" + 12-byte nonce + ciphertext + 16-byte MAC`
//   (nonce/ciphertext/MAC as produced by `SecretBox.concatenation()`).
// - Corrupt key entries are NEVER overwritten (fail closed), same rule as
//   the database key — overwriting would orphan existing encrypted photos.

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'package:suicun/core/crypto/key_value_store.dart';

/// Secure-storage key for the random photo-encryption key (base64, 32 bytes).
const String kFileKeyStoreKey = 'suicun.crypto.fileKey.v1';

/// 4-byte magic header identifying encrypted photo files.
const List<int> kEncryptedPhotoMagic = [0x53, 0x56, 0x46, 0x31]; // "SVF1"

/// Thrown when photo encryption/decryption fails.
class FileEncryptionError implements Exception {
  FileEncryptionError(this.message, [this.cause]);
  final String message;
  final Object? cause;

  @override
  String toString() =>
      'FileEncryptionError: $message${cause == null ? '' : ' (caused by $cause)'}';
}

class FileEncryptionService {
  FileEncryptionService({KeyValueStore? store, Random? random})
      : _store = store ?? SecureStorageKeyValueStore(),
        _random = random ?? Random.secure();

  final KeyValueStore _store;
  final Random _random;

  static final _aesGcm = AesGcm.with256bits();

  /// Returns the photo-encryption key, generating and persisting a fresh
  /// random 256-bit key on first use. Corrupt entries fail closed (never
  /// overwritten), mirroring DatabaseEncryptionService.ensureKey.
  Future<Uint8List> ensureKey() async {
    final stored = await _store.read(kFileKeyStoreKey);
    if (stored != null && stored.isNotEmpty) {
      Uint8List? bytes;
      try {
        bytes = base64Decode(stored);
      } catch (_) {
        bytes = null;
      }
      if (bytes != null && bytes.length == 32) return bytes;
      throw FileEncryptionError(
          'stored photo key is corrupt; refusing to overwrite it');
    }
    final fresh = Uint8List(32);
    for (var i = 0; i < fresh.length; i++) {
      fresh[i] = _random.nextInt(256);
    }
    await _store.write(kFileKeyStoreKey, base64Encode(fresh));
    return fresh;
  }

  /// Deletes the stored photo key. After this, encrypted photos cannot be
  /// decrypted (used only for "erase all data" / recovery flows).
  Future<void> deleteKey() => _store.delete(kFileKeyStoreKey);

  Uint8List _nonce() {
    final b = Uint8List(12);
    for (var i = 0; i < b.length; i++) {
      b[i] = _random.nextInt(256);
    }
    return b;
  }

  /// Encrypts [plain] and writes `magic + nonce + ciphertext + MAC` to [target].
  /// (The nonce is part of `SecretBox.concatenation()`.)
  Future<void> writeEncrypted(File target, Uint8List plain) async {
    final key = await ensureKey();
    final nonce = _nonce();
    final box = await _aesGcm.encrypt(
      plain,
      secretKey: SecretKey(key),
      nonce: nonce,
    );
    // SecretBox.concatenation() = nonce + ciphertext + 16-byte MAC.
    final out = BytesBuilder()
      ..add(kEncryptedPhotoMagic)
      ..add(box.concatenation());
    await target.writeAsBytes(out.toBytes(), flush: true);
  }

  /// Reads an encrypted photo file and returns the decrypted bytes.
  /// Throws [FileEncryptionError] on bad magic, truncation, or MAC failure
  /// (tampering / wrong key).
  Future<Uint8List> readDecrypted(File source) async {
    final bytes = await source.readAsBytes();
    // Minimum: 4 magic + 12 nonce + 16 MAC (+ ≥0 ciphertext).
    if (bytes.length < 32) {
      throw FileEncryptionError('encrypted photo is truncated');
    }
    for (var i = 0; i < 4; i++) {
      if (bytes[i] != kEncryptedPhotoMagic[i]) {
        throw FileEncryptionError('not an encrypted photo (bad magic)');
      }
    }
    final nonceAndCipher = bytes.sublist(4);
    final key = await ensureKey();
    try {
      final box = SecretBox.fromConcatenation(
        nonceAndCipher,
        nonceLength: 12,
        macLength: 16,
      );
      final clear = await _aesGcm.decrypt(box, secretKey: SecretKey(key));
      return Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError catch (e) {
      throw FileEncryptionError('photo authentication failed (tampered?)', e);
    } catch (e) {
      throw FileEncryptionError('photo decryption failed', e);
    }
  }
}
