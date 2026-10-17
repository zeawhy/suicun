// test/unit/file_encryption_service_test.dart
// Unit tests for FileEncryptionService (spec §2.3).

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:suicun/core/crypto/file_encryption_service.dart';
import 'package:suicun/core/crypto/key_value_store.dart';

void main() {
  group('FileEncryptionService', () {
    late MemoryKeyValueStore store;
    late FileEncryptionService svc;

    setUp(() {
      store = MemoryKeyValueStore();
      svc = FileEncryptionService(store: store);
    });

    test('encrypt/decrypt roundtrip', () async {
      final plain = Uint8List.fromList(List.generate(256, (i) => i % 256));
      final file = File('${Directory.systemTemp.path}/test_enc_${DateTime.now().microsecondsSinceEpoch}.enc');

      await svc.writeEncrypted(file, plain);
      expect(await file.exists(), isTrue);

      // Verify file format: magic + nonce + ciphertext + MAC
      final raw = await file.readAsBytes();
      expect(raw.length, greaterThan(32));
      expect(raw.sublist(0, 4), [0x53, 0x56, 0x46, 0x31]); // "SVF1"

      final decrypted = await svc.readDecrypted(file);
      expect(decrypted, plain);

      await file.delete();
    });

    test('tampered ciphertext fails authentication', () async {
      final plain = Uint8List.fromList([1, 2, 3, 4, 5]);
      final file = File('${Directory.systemTemp.path}/test_tamper_${DateTime.now().microsecondsSinceEpoch}.enc');

      await svc.writeEncrypted(file, plain);

      // Flip a byte in the ciphertext region
      final raw = await file.readAsBytes();
      raw[20] ^= 0xFF;
      await file.writeAsBytes(raw);

      expect(
        () => svc.readDecrypted(file),
        throwsA(isA<FileEncryptionError>()),
      );

      await file.delete();
    });

    test('bad magic throws', () async {
      final file = File('${Directory.systemTemp.path}/test_magic_${DateTime.now().microsecondsSinceEpoch}.enc');
      await file.writeAsBytes(Uint8List.fromList(List.filled(40, 0)));

      expect(
        () => svc.readDecrypted(file),
        throwsA(isA<FileEncryptionError>()),
      );

      await file.delete();
    });

    test('truncated file throws', () async {
      final file = File('${Directory.systemTemp.path}/test_trunc_${DateTime.now().microsecondsSinceEpoch}.enc');
      await file.writeAsBytes(Uint8List.fromList([0x53, 0x56, 0x46])); // only 3 bytes

      expect(
        () => svc.readDecrypted(file),
        throwsA(isA<FileEncryptionError>()),
      );

      await file.delete();
    });

    test('corrupt key is not overwritten (fail closed)', () async {
      // Write a corrupt (wrong length) key
      await store.write(kFileKeyStoreKey, 'not-valid-base64!!!');

      expect(
        () => svc.ensureKey(),
        throwsA(isA<FileEncryptionError>()),
      );

      // Verify the corrupt value was NOT overwritten
      final stillThere = await store.read(kFileKeyStoreKey);
      expect(stillThere, 'not-valid-base64!!!');
    });

    test('corrupt key with wrong length is not overwritten', () async {
      // Valid base64 but wrong length (not 32 bytes)
      await store.write(kFileKeyStoreKey, 'aGVsbG8='); // "hello" = 5 bytes

      expect(
        () => svc.ensureKey(),
        throwsA(isA<FileEncryptionError>()),
      );

      final stillThere = await store.read(kFileKeyStoreKey);
      expect(stillThere, 'aGVsbG8=');
    });

    test('key is generated once and reused', () async {
      final key1 = await svc.ensureKey();
      expect(key1.length, 32);

      final key2 = await svc.ensureKey();
      expect(key2, key1);
    });

    test('different nonces produce different ciphertexts', () async {
      final plain = Uint8List.fromList([1, 2, 3, 4]);
      final file1 = File('${Directory.systemTemp.path}/test_nonce1_${DateTime.now().microsecondsSinceEpoch}.enc');
      final file2 = File('${Directory.systemTemp.path}/test_nonce2_${DateTime.now().microsecondsSinceEpoch}.enc');

      await svc.writeEncrypted(file1, plain);
      await svc.writeEncrypted(file2, plain);

      final raw1 = await file1.readAsBytes();
      final raw2 = await file2.readAsBytes();

      // Nonces should differ (bytes 4-16)
      expect(raw1.sublist(4, 16), isNot(equals(raw2.sublist(4, 16))));

      // But both decrypt to the same plaintext
      expect(await svc.readDecrypted(file1), plain);
      expect(await svc.readDecrypted(file2), plain);

      await file1.delete();
      await file2.delete();
    });
  });
}
