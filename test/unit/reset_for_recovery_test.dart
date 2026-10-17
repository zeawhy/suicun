// test/unit/reset_for_recovery_test.dart
// Unit tests for DatabaseEncryptionService.resetForRecovery (§2.6).

import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:suicun/core/crypto/database_encryption_service.dart';
import 'package:suicun/core/crypto/key_value_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('resetForRecovery', () {
    late Directory tempDir;
    late MemoryKeyValueStore store;
    late DatabaseEncryptionService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('recovery_test');
      store = MemoryKeyValueStore();
      service = DatabaseEncryptionService(
        store: store,
        random: Random(42),
      );
      // Seed keys as if the app had run before.
      await store.write('suicun.crypto.dbKey.v1', 'aGVsbG8=');
      await store.write('suicun.crypto.fileKey.v1', 'd29ybGQ=');
    });

    tearDown(() async {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    });

    test('renames db files, deletes photos and keys', () async {
      final dbFile = File('${tempDir.path}/suicun.db');
      await dbFile.writeAsString('fake-db');
      await File('${tempDir.path}/suicun.db-wal').writeAsString('wal');
      final photosDir = Directory('${tempDir.path}/id_photos');
      await photosDir.create();
      await File('${photosDir.path}/a.jpg').writeAsString('photo');

      await service.resetForRecovery(
        dbFileOverride: dbFile,
        photosDirOverride: photosDir,
      );

      // DB renamed.
      expect(await dbFile.exists(), isFalse);
      expect(
          await File('${tempDir.path}/suicun.db.unreadable').exists(), isTrue);
      expect(
          await File('${tempDir.path}/suicun.db.unreadable-wal').exists(),
          isTrue);
      // Photos deleted.
      expect(await photosDir.exists(), isFalse);
      // Keys deleted.
      expect(await store.read('suicun.crypto.dbKey.v1'), isNull);
      expect(await store.read('suicun.crypto.fileKey.v1'), isNull);
    });

    test('keeps only the most recent .unreadable set', () async {
      final dbFile = File('${tempDir.path}/suicun.db');
      await dbFile.writeAsString('new-db');
      // Pre-existing unreadable backup.
      await File('${tempDir.path}/suicun.db.unreadable')
          .writeAsString('old-db');

      await service.resetForRecovery(
        dbFileOverride: dbFile,
        photosDirOverride: Directory('${tempDir.path}/id_photos'),
      );

      final content =
          await File('${tempDir.path}/suicun.db.unreadable').readAsString();
      expect(content, 'new-db');
    });

    test('tolerates missing files', () async {
      final dbFile = File('${tempDir.path}/suicun.db');
      // Nothing exists; should not throw.
      await service.resetForRecovery(
        dbFileOverride: dbFile,
        photosDirOverride: Directory('${tempDir.path}/id_photos'),
      );
      expect(await store.read('suicun.crypto.dbKey.v1'), isNull);
    });
  });
}
