// test/unit/database_encryption_service_test.dart
// Stage B tests for the database encryption service.
//
// Key lifecycle and header detection use a fake store / temp files.
// Migration and open tests use the REAL SQLCipher library (downloaded via
// the sqlite3 package's `source: sqlcipher` hook) — not mocks.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:suicun/core/crypto/database_encryption_service.dart';
import 'package:suicun/core/crypto/key_value_store.dart';
import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/features/categories/data/category_repository.dart';
import 'package:suicun/features/records/data/record_repository.dart';

void main() {
  late MemoryKeyValueStore store;
  late Directory tmp;

  setUp(() {
    store = MemoryKeyValueStore();
    tmp = Directory.systemTemp.createTempSync('dbenc_test_');
  });

  tearDown(() async {
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('key lifecycle', () {
    test('generates a 256-bit key on first use and persists it', () async {
      final service = DatabaseEncryptionService(store: store);
      final key1 = await service.ensureKey();
      expect(key1.length, 32);

      final stored = await store.read(kDatabaseKeyStoreKey);
      expect(stored, isNotNull);
      expect(base64Decode(stored!).length, 32);

      // Second call returns the same key (compare contents, not identity).
      final key2 = await service.ensureKey();
      expect(base64Encode(key2), base64Encode(key1));
    });

    test('keyLiteral produces the SQLCipher hex form', () {
      final bytes = Uint8List.fromList(List<int>.generate(32, (i) => i));
      final literal = DatabaseEncryptionService.keyLiteral(bytes);
      expect(literal, "x'000102030405060708090a0b0c0d0e0f"
          "101112131415161718191a1b1c1d1e1f'");
    });

    test('deleteKey removes the key; next ensureKey generates a fresh one',
        () async {
      final service = DatabaseEncryptionService(store: store);
      final key1 = await service.ensureKey();
      await service.deleteKey();
      final key2 = await service.ensureKey();
      expect(base64Encode(key2), isNot(base64Encode(key1)));
    });
  });

  group('isEncrypted', () {
    test('missing file counts as not encrypted', () async {
      expect(
        await DatabaseEncryptionService.isEncrypted(
            File('${tmp.path}/nope.db')),
        isFalse,
      );
    });

    test('plaintext header detected', () async {
      final f = File('${tmp.path}/plain.db');
      await f.writeAsBytes(
          'SQLite format 3\x00'.codeUnits + List.filled(100, 0));
      expect(await DatabaseEncryptionService.isEncrypted(f), isFalse);
    });

    test('random bytes detected as encrypted', () async {
      final f = File('${tmp.path}/enc.db');
      await f.writeAsBytes(List<int>.generate(100, (i) => (i * 7) & 0xff));
      expect(await DatabaseEncryptionService.isEncrypted(f), isTrue);
    });
  });

  group('migrateToEncrypted (real SQLCipher)', () {
    test('no-op when file is missing', () async {
      final service = DatabaseEncryptionService(store: store);
      final key = await service.ensureKey();
      await service.migrateToEncrypted(
          File('${tmp.path}/missing.db'), key);
      // No throw, no file created.
      expect(await File('${tmp.path}/missing.db').exists(), isFalse);
    });

    test('migrates plaintext to encrypted, data intact', () async {
      final service = DatabaseEncryptionService(store: store);
      final key = await service.ensureKey();
      final dbFile = File('${tmp.path}/suicun.db');

      // Build a plaintext database with user-like data.
      final plain = sqlite3.sqlite3.open(dbFile.path);
      plain.execute(
          'CREATE TABLE records (id TEXT PRIMARY KEY, body TEXT);');
      plain.execute(
          "INSERT INTO records VALUES ('r1', '秘密笔记内容 secret');");
      plain.close();
      expect(await DatabaseEncryptionService.isEncrypted(dbFile), isFalse);

      await service.migrateToEncrypted(dbFile, key);

      // Now encrypted.
      expect(await DatabaseEncryptionService.isEncrypted(dbFile), isTrue);
      // No plaintext sidecars left behind.
      for (final suffix in ['-wal', '-shm', '-journal', '.migrating']) {
        expect(await File('${dbFile.path}$suffix').exists(), isFalse);
      }

      // Data readable with the right key (raw SQLCipher read path).
      final literal = DatabaseEncryptionService.keyLiteral(key);
      final check = sqlite3.sqlite3.open(dbFile.path);
      try {
        check.execute('PRAGMA key = "$literal";');
        final rows = check.select('SELECT body FROM records;');
        expect(rows.first['body'], '秘密笔记内容 secret');
      } finally {
        check.close();
      }
    });

    test('openEncryptedDatabase fails fast on wrong key', () async {
      final service = DatabaseEncryptionService(store: store);
      final key = await service.ensureKey();
      final dbFile = File('${tmp.path}/suicun.db');

      final plain = sqlite3.sqlite3.open(dbFile.path);
      plain.execute('CREATE TABLE t (a TEXT);');
      plain.close();
      await service.migrateToEncrypted(dbFile, key);

      // Swap the stored key for a different one, then open.
      await store.delete(kDatabaseKeyStoreKey);
      final other = DatabaseEncryptionService(store: store);
      final wrongKey = await other.ensureKey();
      expect(base64Encode(wrongKey), isNot(base64Encode(key)));

      expect(
        () => other.openEncryptedDatabase(dbFileOverride: dbFile),
        throwsA(isA<DatabaseEncryptionError>()),
      );
    });
  });

  group('drift read path on encrypted database', () {
    test('writes and reads through the real AppDatabase', () async {
      final service = DatabaseEncryptionService(store: store);
      final dbFile = File('${tmp.path}/suicun.db');
      final executor =
          await service.openEncryptedDatabase(dbFileOverride: dbFile);
      final db = AppDatabase(executor);
      addTearDown(db.close);

      // Exercise the generated drift layer (not just raw SQL).
      final catRepo = CategoryRepository(db);
      final created = await catRepo.createCategory('工作', '#FF0000');
      expect(created.name, '工作');

      final recordRepo = RecordRepository(db);
      await recordRepo.createRecord(
        title: '标题',
        body: '正文秘密',
        categoryId: created.id,
      );
      final found = await recordRepo.searchRecords(query: '秘密');
      expect(found.length, 1);
      expect(found.first.title, '标题');

      // And the file on disk is encrypted.
      expect(await DatabaseEncryptionService.isEncrypted(dbFile), isTrue);
    });
  });
}
