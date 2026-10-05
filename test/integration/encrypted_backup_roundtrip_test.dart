// test/integration/encrypted_backup_roundtrip_test.dart
// Stage B: encrypted backup export -> import round-trip with the REAL
// Argon2id + AES-256-GCM container (reduced KDF cost for test speed).
// path_provider is faked to a temp dir, like backup_roundtrip_test.dart.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:suicun/core/crypto/backup_crypto.dart';
import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/features/backup/data/backup_service.dart';
import 'package:suicun/features/categories/data/category_repository.dart';
import 'package:suicun/features/records/data/record_repository.dart';
import 'package:suicun/features/tags/data/tag_repository.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.tempDir);
  final Directory tempDir;

  @override
  Future<String?> getApplicationDocumentsPath() async => tempDir.path;
}

const _testKdf = BackupKdfParams(
  memoryKb: 8192,
  iterations: 1,
  parallelism: 1,
);

void main() {
  late Directory tempDir;
  late AppDatabase db;
  late BackupService backup;

  BackupService makeService(AppDatabase database) => BackupService(
        db: database,
        recordRepo: RecordRepository(database),
        categoryRepo: CategoryRepository(database),
        tagRepo: TagRepository(database),
      );

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('suicun_encbak_test');
    PathProviderPlatform.instance = _FakePathProvider(tempDir);
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    backup = makeService(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedDatabase() async {
    final categoryRepo = CategoryRepository(db);
    final tagRepo = TagRepository(db);
    final recordRepo = RecordRepository(db);

    final work = await categoryRepo.createCategory('工作', '#FF0000');
    final urgent = await tagRepo.findOrCreateTag('紧急');
    await recordRepo.createRecord(
      title: '服务器常用配置',
      body: 'Nginx 反向代理秘密内容',
      categoryId: work.id,
      isFavorite: true,
      tagIds: [urgent.id],
    );
  }

  test('encrypted export -> import round-trips all data', () async {
    await seedDatabase();

    final file = await backup.exportEncryptedBackup(
      'test-password-123',
      kdfParams: _testKdf,
    );
    expect(await file.exists(), isTrue);

    // The file must not contain plaintext secrets.
    final raw = await file.readAsString();
    expect(raw.contains('Nginx 反向代理秘密内容'), isFalse);
    expect(raw.contains('服务器常用配置'), isFalse);

    // Import into a fresh database.
    final freshDb = AppDatabase(NativeDatabase.memory());
    addTearDown(freshDb.close);
    final freshBackup = makeService(freshDb);

    final preview =
        await freshBackup.previewEncryptedImport(file, 'test-password-123');
    expect(preview, 1);

    final imported =
        await freshBackup.importEncryptedBackup(file, 'test-password-123');
    expect(imported, 1);

    final records =
        await RecordRepository(freshDb).searchRecords(limit: 50);
    expect(records.length, 1);
    expect(records.first.title, '服务器常用配置');
    expect(records.first.body, 'Nginx 反向代理秘密内容');
    expect(records.first.isFavorite, isTrue);
    expect(records.first.category?.name, '工作');
    expect(records.first.tags.map((t) => t.name), contains('紧急'));
  });

  test('wrong password fails the import with a clear error', () async {
    await seedDatabase();
    final file = await backup.exportEncryptedBackup(
      'test-password-123',
      kdfParams: _testKdf,
    );

    expect(
      () => backup.previewEncryptedImport(file, 'wrong-password'),
      throwsA(isA<Exception>()),
    );
  });
}
