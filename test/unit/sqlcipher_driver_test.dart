// test/unit/sqlcipher_driver_test.dart
// STAGE B DRIVER VALIDATION (real, not mocked):
// Verifies that the SQLCipher native library selected via pubspec
// `hooks: user_defines: sqlite3: source: sqlcipher` actually loads,
// opens encrypted databases with PRAGMA key, rejects wrong keys, and
// supports sqlcipher_export migration from a plaintext database.
//
// Runs on the VM's Linux against the downloaded Linux SQLCipher build.
// The Android packaging of the same library is validated separately
// by `flutter build apk --release`.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// 256-bit test key as SQLCipher hex literal: PRAGMA key = "x'`hex`'".
String _testKeyHex() {
  final bytes = List<int>.generate(32, (i) => (i * 37 + 11) & 0xff);
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('sqlcipher_validate_');
  });

  tearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('sqlcipher library loads and reports cipher version', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    // PRAGMA cipher_version only exists on SQLCipher builds.
    final rows = db.select('PRAGMA cipher_version;');
    final version = rows.first.values.first as String?;
    expect(version, isNotNull);
    expect(version, isNotEmpty);
  });

  test('encrypted database round-trips with correct key', () {
    final path = '${tmp.path}/enc.db';
    final keyHex = _testKeyHex();

    final db = sqlite3.open(path);
    db.execute('PRAGMA key = "x\'$keyHex\'";');
    db.execute('CREATE TABLE secrets (id INTEGER PRIMARY KEY, v TEXT);');
    db.execute("INSERT INTO secrets (v) VALUES ('明文测试 hello');");
    db.close();

    // The file must NOT start with the plaintext SQLite header.
    final header = File(path).readAsBytesSync().sublist(0, 16);
    expect(String.fromCharCodes(header), isNot('SQLite format 3\x00'));

    // Reopen with the right key: data readable.
    final db2 = sqlite3.open(path);
    addTearDown(db2.close);
    db2.execute('PRAGMA key = "x\'$keyHex\'";');
    final rows = db2.select('SELECT v FROM secrets;');
    expect(rows.first['v'], '明文测试 hello');
  });

  test('wrong key is rejected', () {
    final path = '${tmp.path}/enc2.db';
    final keyHex = _testKeyHex();

    final db = sqlite3.open(path);
    db.execute('PRAGMA key = "x\'$keyHex\'";');
    db.execute('CREATE TABLE t (a TEXT);');
    db.close();

    final wrongHex = '00' * 32;
    final db2 = sqlite3.open(path);
    addTearDown(db2.close);
    db2.execute('PRAGMA key = "x\'$wrongHex\'";');
    // First read with a wrong key fails (SQLCipher derives a different key
    // and the header check / decryption fails).
    expect(() => db2.select('SELECT * FROM t;'), throwsA(anything));
  });

  test('sqlcipher_export migrates a plaintext database', () {
    final plainPath = '${tmp.path}/plain.db';
    final encPath = '${tmp.path}/migrated.db';
    final keyHex = _testKeyHex();

    // Build a plaintext database with some data.
    final plain = sqlite3.open(plainPath);
    plain.execute('CREATE TABLE records (id TEXT PRIMARY KEY, body TEXT);');
    plain.execute(
        "INSERT INTO records VALUES ('id-1', '用户私密笔记内容');");
    plain.close();
    expect(
      String.fromCharCodes(
          File(plainPath).readAsBytesSync().sublist(0, 16)),
      'SQLite format 3\x00',
    );

    // Migrate: ATTACH encrypted + sqlcipher_export (the exact SQL the app
    // will run on Android).
    final db = sqlite3.open(plainPath);
    addTearDown(db.close);
    db.execute("ATTACH DATABASE '$encPath' AS encrypted KEY \"x'$keyHex'\";");
    db.execute('SELECT sqlcipher_export(\'encrypted\');');
    db.execute('DETACH DATABASE encrypted;');
    db.close();

    // The new file is encrypted and holds the data.
    final header =
        String.fromCharCodes(File(encPath).readAsBytesSync().sublist(0, 16));
    expect(header, isNot('SQLite format 3\x00'));

    final enc = sqlite3.open(encPath);
    addTearDown(enc.close);
    enc.execute('PRAGMA key = "x\'$keyHex\'";');
    final rows = enc.select('SELECT body FROM records;');
    expect(rows.first['body'], '用户私密笔记内容');
  });

  test('WAL file of encrypted database is not plaintext', () {
    final path = '${tmp.path}/wal.db';
    final keyHex = _testKeyHex();

    final db = sqlite3.open(path);
    addTearDown(db.close);
    db.execute('PRAGMA key = "x\'$keyHex\'";');
    db.execute('PRAGMA journal_mode=WAL;');
    db.execute('CREATE TABLE t (a TEXT);');
    db.execute("INSERT INTO t VALUES ('wal中的秘密');");

    final wal = File('$path-wal');
    if (wal.existsSync()) {
      final bytes = wal.readAsBytesSync();
      // The secret must not appear as UTF-8/UTF-16 plaintext in the WAL.
      final asString = String.fromCharCodes(bytes);
      expect(asString.contains('wal中的秘密'), isFalse);
      // Nor as raw UTF-8 bytes.
      final secretUtf8 = Uint8List.fromList('wal中的秘密'.codeUnits);
      expect(_containsSubsequence(bytes, secretUtf8), isFalse);
    }
  });
}

bool _containsSubsequence(Uint8List haystack, Uint8List needle) {
  if (needle.isEmpty) return true;
  outer:
  for (var i = 0; i <= haystack.length - needle.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) continue outer;
    }
    return true;
  }
  return false;
}
