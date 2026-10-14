// lib/core/crypto/database_encryption_service.dart
// Stage B: local database encryption (spec §9).
//
// Design:
// - A random 256-bit database key is generated once and stored in the
//   platform secure storage (Android Keystore). It is NEVER derived from
//   a user PIN (spec §9 forbids deriving the DB key from a low-entropy PIN).
// - The SQLite file is encrypted with SQLCipher (via package:sqlite3 3.x
//   `source: sqlcipher` native build). The key is applied with
//   `PRAGMA key = "x'<hex>'"` as the first statement on every connection.
// - Existing plaintext databases are migrated with `sqlcipher_export`
//   (ATTACH + export + atomic replace). The old file is deleted afterwards;
//   on flash storage, deleted blocks are not guaranteed to be wiped — this
//   is documented in docs/key-recovery.md rather than promised away.
// - WAL files of an encrypted database are encrypted by SQLCipher as well
//   (verified in test/unit/sqlcipher_driver_test.dart).
//
// What this file does NOT do:
// - It does not back up or escrow the database key anywhere: if the key is
//   lost (app data cleared, device factory reset without backup), the
//   database cannot be recovered. See docs/key-recovery.md.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:suicun/core/crypto/key_value_store.dart';

/// Secure-storage key for the random database key (base64, 32 bytes).
const String kDatabaseKeyStoreKey = 'suicun.crypto.dbKey.v1';

/// Name of the SQLite file (unchanged from stage A).
const String kDatabaseFileName = 'suicun.db';

/// Thrown when the database cannot be opened (e.g. wrong key after a
/// keystore restore mismatch, or a corrupted file).
class DatabaseEncryptionError implements Exception {
  DatabaseEncryptionError(this.message, [this.cause]);
  final String message;
  final Object? cause;

  @override
  String toString() => 'DatabaseEncryptionError: $message'
      '${cause == null ? '' : ' (caused by $cause)'}';
}

class DatabaseEncryptionService {
  DatabaseEncryptionService({KeyValueStore? store, Random? random})
      : _store = store ?? SecureStorageKeyValueStore(),
        _random = random ?? Random.secure();

  final KeyValueStore _store;
  final Random _random;

  /// Returns the database key, generating and persisting a fresh random
  /// 256-bit key on first use. The returned bytes are the raw key.
  Future<Uint8List> ensureKey() async {
    final stored = await _store.read(kDatabaseKeyStoreKey);
    if (stored != null && stored.isNotEmpty) {
      Uint8List? bytes;
      try {
        bytes = base64Decode(stored);
      } catch (_) {
        bytes = null;
      }
      if (bytes != null && bytes.length == 32) return bytes;
      // Corrupt entry: NEVER overwrite it with a fresh key — that would
      // irreversibly orphan an existing encrypted database. Fail closed.
      throw DatabaseEncryptionError(
          'stored database key is corrupt; refusing to overwrite it');
    }
    final fresh = Uint8List(32);
    for (var i = 0; i < fresh.length; i++) {
      fresh[i] = _random.nextInt(256);
    }
    await _store.write(kDatabaseKeyStoreKey, base64Encode(fresh));
    // Key material is intentionally never logged.
    return fresh;
  }

  /// Deletes the stored database key. After this, the encrypted database
  /// cannot be opened again (used only for "erase all data" flows).
  Future<void> deleteKey() => _store.delete(kDatabaseKeyStoreKey);

  /// SQLCipher key literal for `PRAGMA key`: x'<64 hex chars>'.
  /// The hex form avoids any password-based key derivation quirks.
  static String keyLiteral(Uint8List keyBytes) {
    if (keyBytes.length != 32) {
      throw DatabaseEncryptionError('database key must be 32 bytes');
    }
    final hex = keyBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final literal = "x'$hex'";
    // Defensive: the literal is built from bytes only, but assert the exact
    // shape so it can never become a SQL injection vector.
    if (!RegExp(r"^x'[0-9a-f]{64}'$").hasMatch(literal)) {
      throw DatabaseEncryptionError('internal error: bad key literal');
    }
    return literal;
  }

  /// True when [file] exists and does not have a plaintext SQLite header.
  /// A missing or empty file counts as "not encrypted" (fresh install).
  static Future<bool> isEncrypted(File file) async {
    if (!await file.exists()) return false;
    final raf = await file.open();
    try {
      final header = await raf.read(16);
      if (header.length < 16) return false;
      const plain = 'SQLite format 3\x00';
      for (var i = 0; i < 16; i++) {
        if (header[i] != plain.codeUnitAt(i)) return true;
      }
      return false;
    } finally {
      await raf.close();
    }
  }

  /// Full setup for app startup (call once in main(), before runApp):
  /// ensures the key, migrates a plaintext database if present, and
  /// returns a drift [DatabaseConnection] on the encrypted file.
  ///
  /// [dbFileOverride] is test-only: it replaces the production database
  /// file location so the full open flow can be exercised in unit tests.
  ///
  /// Throws [DatabaseEncryptionError] when the database cannot be opened
  /// (e.g. key mismatch). Callers must surface this instead of silently
  /// falling back to plaintext.
  Future<QueryExecutor> openEncryptedDatabase({File? dbFileOverride}) async {
    final dbFile = dbFileOverride ?? await databaseFile();
    final existing = await _store.read(kDatabaseKeyStoreKey);
    if ((existing == null || existing.isEmpty) && await isEncrypted(dbFile)) {
      // Key lost (keystore wiped/restore mismatch) while an encrypted DB
      // exists: do not generate and persist a new key over the problem.
      throw DatabaseEncryptionError(
          'database key is missing but an encrypted database exists');
    }
    final key = await ensureKey();
    await migrateToEncrypted(dbFile, key);
    // Fail fast with a clear error when the key is wrong: validate on a
    // short-lived raw connection BEFORE handing the file to drift.
    // (NativeDatabase.createInBackground runs `setup` lazily in another
    // isolate, so a try/catch around it cannot catch key errors.)
    await _validateKey(dbFile, key);
    return _connect(dbFile, key);
  }

  /// Opens [dbFile] with [key] on a throwaway raw connection and forces a
  /// read. Throws [DatabaseEncryptionError] when the key is wrong or the
  /// file is corrupted. A missing/empty file is treated as a fresh
  /// database (SQLCipher initializes it encrypted).
  Future<void> _validateKey(File dbFile, Uint8List key) async {
    final literal = keyLiteral(key);
    final db = sqlite3.sqlite3.open(dbFile.path);
    try {
      db.execute('PRAGMA key = "$literal";');
      _requireSqlCipher(db);
      db.select('SELECT count(*) FROM sqlite_master;');
    } on DatabaseEncryptionError {
      rethrow;
    } catch (e) {
      throw DatabaseEncryptionError(
          'database key is incorrect or the file is corrupted', e);
    } finally {
      db.close();
    }
  }

  /// Fails closed when the linked SQLite is NOT SQLCipher: a vanilla SQLite
  /// silently ignores `PRAGMA key`, which would leave data in plaintext.
  static void _requireSqlCipher(sqlite3.Database db) {
    final rows = db.select('PRAGMA cipher_version;');
    final v = rows.isEmpty ? null : rows.first.values.first;
    if (v is! String || v.isEmpty) {
      throw DatabaseEncryptionError(
          'SQLCipher is not available; refusing to use an unencrypted '
          'database');
    }
  }

  /// Migrates a plaintext [dbFile] to SQLCipher encryption in place.
  /// No-op when the file is missing or already encrypted.
  ///
  /// Uses `sqlcipher_export` into a temporary file, verifies the new file
  /// opens with the key, then atomically replaces the original. Plaintext
  /// sidecar files (-wal/-shm/-journal) are deleted.
  Future<void> migrateToEncrypted(File dbFile, Uint8List key) async {
    if (!await dbFile.exists()) return; // fresh install
    if (await isEncrypted(dbFile)) return;

    final literal = keyLiteral(key);
    final tmpPath = '${dbFile.path}.migrating';
    final tmpFile = File(tmpPath);
    if (await tmpFile.exists()) await tmpFile.delete();
    final quotedTmpPath = tmpPath.replaceAll("'", "''");

    final db = sqlite3.sqlite3.open(dbFile.path);
    try {
      _requireSqlCipher(db);
      // ATTACH with a KEY parameter keeps the key out of separate statements.
      db.execute(
          "ATTACH DATABASE '$quotedTmpPath' AS encrypted KEY \"$literal\";");
      db.execute("SELECT sqlcipher_export('encrypted');");
      db.execute('DETACH DATABASE encrypted;');
    } catch (e) {
      try {
        if (await tmpFile.exists()) await tmpFile.delete();
      } catch (_) {}
      if (e is DatabaseEncryptionError) rethrow;
      throw DatabaseEncryptionError('sqlcipher_export migration failed', e);
    } finally {
      db.close();
    }

    // Verify the migrated file before replacing the original.
    final verify = sqlite3.sqlite3.open(tmpPath);
    try {
      verify.execute('PRAGMA key = "$literal";');
      _requireSqlCipher(verify);
      verify.select('SELECT count(*) FROM sqlite_master;');
      if (!await isEncrypted(tmpFile)) {
        throw DatabaseEncryptionError(
            'migrated database is still plaintext on disk');
      }
    } catch (e) {
      try {
        await tmpFile.delete();
      } catch (_) {}
      if (e is DatabaseEncryptionError) rethrow;
      throw DatabaseEncryptionError(
          'migrated database failed to open with the new key', e);
    } finally {
      verify.close();
    }

    // Atomic replace FIRST, then clean up plaintext sidecars.
    // (Deleting the old -wal before the rename could corrupt the original
    // database if the process crashed in between.)
    await tmpFile.rename(dbFile.path);
    for (final suffix in ['-wal', '-shm', '-journal']) {
      final sidecar = File('${dbFile.path}$suffix');
      try {
        if (await sidecar.exists()) await sidecar.delete();
      } catch (_) {}
    }
  }

  /// Opens the (already encrypted) database file with drift.
  /// Runs `PRAGMA key` as the first statement on the connection.
  /// Key correctness is validated separately by [_validateKey] before this
  /// is called (the background isolate's `setup` errors cannot be caught
  /// synchronously here).
  QueryExecutor _connect(File dbFile, Uint8List key) {
    final literal = keyLiteral(key);
    return NativeDatabase.createInBackground(
      dbFile,
      setup: (raw) {
        // Must be the first statement on this connection.
        raw.execute('PRAGMA key = "$literal";');
      },
    );
  }

  /// Absolute path of the database file.
  static Future<File> databaseFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, kDatabaseFileName));
  }
}
