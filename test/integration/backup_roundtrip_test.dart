// test/integration/backup_roundtrip_test.dart
// Integration test: JSON export -> fresh database -> JSON import, verifying
// field-by-field data consistency; Markdown ZIP and TXT export validation;
// text-file import; import validation errors.
//
// path_provider is faked so BackupService writes into a temp directory.

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/core/errors/app_errors.dart';
import 'package:suicun/features/backup/data/backup_service.dart';
import 'package:suicun/features/categories/data/category_repository.dart';
import 'package:suicun/features/records/data/record_repository.dart';
import 'package:suicun/features/tags/data/tag_repository.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.dir);

  final Directory dir;

  @override
  Future<String?> getApplicationDocumentsPath() async => dir.path;
}

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
    tempDir = await Directory.systemTemp.createTemp('suicun_backup_test');
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

  /// Seeds a representative dataset: categories, tags, favorites,
  /// Chinese text, emoji, untitled records.
  Future<void> seedDatabase() async {
    final categoryRepo = CategoryRepository(db);
    final tagRepo = TagRepository(db);
    final recordRepo = RecordRepository(db);

    final work = await categoryRepo.createCategory('工作', '#FF0000');
    final life = await categoryRepo.createCategory('生活', '#00FF00');
    final urgent = await tagRepo.findOrCreateTag('紧急');
    final idea = await tagRepo.findOrCreateTag('灵感💡');

    await recordRepo.createRecord(
      title: '服务器常用配置',
      body: 'Nginx 反向代理\n这是正文中间的测试内容 👍',
      categoryId: work.id,
      isFavorite: true,
      tagIds: [urgent.id, idea.id],
    );
    await recordRepo.createRecord(
      title: '',
      body: '只有正文的记录',
      categoryId: life.id,
    );
    await recordRepo.createRecord(
      title: 'Shopping list',
      body: 'milk & eggs 100%',
      tagIds: [idea.id],
    );
    await recordRepo.createRecord(title: 'Plain', body: 'plain body');
  }

  Map<String, dynamic> stripVolatile(Map<String, dynamic> data) {
    final copy = Map<String, dynamic>.from(data);
    copy.remove('exported_at');
    return copy;
  }

  test('JSON export -> fresh DB import round-trip is field-identical',
      () async {
    await seedDatabase();

    // 1. Export
    final exportFile = await backup.exportJson();
    expect(await exportFile.exists(), isTrue);
    final exported =
        jsonDecode(await exportFile.readAsString()) as Map<String, dynamic>;
    expect(exported['schema_version'], 1);
    expect((exported['records'] as List), hasLength(4));
    expect((exported['categories'] as List), hasLength(2));
    expect((exported['tags'] as List), hasLength(2));

    // 2. Import into a FRESH database (simulates 删库后恢复)
    final freshDb = AppDatabase(NativeDatabase.memory());
    final freshBackup = makeService(freshDb);
    try {
      final previewCount = await freshBackup.previewJsonImport(exportFile);
      expect(previewCount, 4);

      final importedCount = await freshBackup.importJson(exportFile);
      expect(importedCount, 4);

      // 3. Re-export from the restored DB and compare (minus timestamps)
      final reExportFile = await freshBackup.exportJson();
      final reExported =
          jsonDecode(await reExportFile.readAsString()) as Map<String, dynamic>;

      expect(
        stripVolatile(reExported),
        equals(stripVolatile(exported)),
        reason: 're-exported JSON must be identical to the original export',
      );

      // 4. Spot-check domain-level fields of a rich record
      final restored = await RecordRepository(freshDb)
          .searchRecords(query: '服务器');
      expect(restored, hasLength(1));
      final r = restored.first;
      expect(r.title, '服务器常用配置');
      expect(r.body, contains('正文中间的测试内容 👍'));
      expect(r.isFavorite, isTrue);
      expect(r.category?.name, '工作');
      expect(r.tags.map((t) => t.name), containsAll(['紧急', '灵感💡']));
    } finally {
      await freshDb.close();
    }
  });

  test('Markdown ZIP export contains one valid .md per record', () async {
    await seedDatabase();

    final zipFile = await backup.exportMarkdownZip();
    expect(await zipFile.exists(), isTrue);

    final archive = ZipDecoder().decodeBytes(await zipFile.readAsBytes());
    final mdFiles =
        archive.files.where((f) => f.name.endsWith('.md')).toList();
    expect(mdFiles, hasLength(4));

    final names = mdFiles.map((f) => f.name).toList();
    // Filenames are unique (id suffix) and filesystem-safe
    expect(names.toSet(), hasLength(4));
    for (final n in names) {
      expect(n.contains('/'), isFalse);
      expect(n.contains('\\'), isFalse);
    }

    // The rich record's markdown contains title, category, tags, body
    final rich = mdFiles.firstWhere(
      (f) => utf8.decode(f.content as List<int>).contains('服务器常用配置'),
    );
    final richText = utf8.decode(rich.content as List<int>);
    expect(richText, contains('# 服务器常用配置'));
    expect(richText, contains('工作'));
    expect(richText, contains('紧急'));
    expect(richText, contains('Nginx 反向代理'));
  });

  test('TXT export contains all records in readable form', () async {
    await seedDatabase();

    final txtFile = await backup.exportTxt();
    final text = await txtFile.readAsString();

    expect(text, contains('服务器常用配置'));
    expect(text, contains('Nginx 反向代理'));
    expect(text, contains('(untitled)')); // the title-less record
    expect(text, contains('Shopping list'));
    expect(text, contains('milk & eggs 100%'));
  });

  test('importTextFile extracts markdown title and keeps txt as-is',
      () async {
    final md = File('${tempDir.path}/notes.md');
    await md.writeAsString('# 我的标题\n\n正文第一行\n正文第二行\n');
    final fromMd = await backup.importTextFile(md);
    expect(fromMd.title, '我的标题');
    expect(fromMd.body, contains('正文第一行'));

    final txt = File('${tempDir.path}/todo.txt');
    await txt.writeAsString('buy milk\n');
    final fromTxt = await backup.importTextFile(txt);
    expect(fromTxt.title, 'todo');
    expect(fromTxt.body, contains('buy milk'));
  });

  test('import validation rejects malformed backups', () async {
    Future<void> expectImportError(String content) async {
      final f = File('${tempDir.path}/bad_${content.hashCode}.json');
      await f.writeAsString(content);
      await expectLater(
        backup.importJson(f),
        throwsA(isA<ImportError>()),
      );
    }

    await expectImportError('not json at all {{{');
    await expectImportError('["just", "a", "list"]');
    await expectImportError('{"no_schema": true}');
    await expectImportError(
        '{"schema_version": 999, "records": [], "categories": [], "tags": []}');
    await expectImportError(
        '{"schema_version": 1, "categories": [], "tags": []}');
  });

  test('import is transactional: failure rolls back everything', () async {
    await seedDatabase();
    final before = await RecordRepository(db).searchRecords();

    // A backup whose second record references a bogus type must fail cleanly.
    // We craft it by hand: valid envelope, one bad record entry.
    final bad = File('${tempDir.path}/bad_records.json');
    await bad.writeAsString(jsonEncode({
      'schema_version': 1,
      'categories': [],
      'tags': [],
      'records': [
        {
          'id': 'ok-1',
          'title': 't',
          'body': 'b',
          'category_id': null,
          'is_favorite': false,
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          'tag_ids': [],
        },
        'this-is-not-a-record-object',
      ],
    }));

    await expectLater(backup.importJson(bad), throwsA(isA<ImportError>()));

    final after = await RecordRepository(db).searchRecords();
    expect(after.map((r) => r.id).toSet(),
        equals(before.map((r) => r.id).toSet()));
  });
}
