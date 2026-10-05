// lib/features/backup/data/backup_service.dart
// Handles JSON backup, Markdown ZIP export, TXT export, and JSON import.
// All export/import operations are pure Dart — no Flutter UI dependencies.

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/core/errors/app_errors.dart';
import 'package:suicun/features/categories/data/category_repository.dart';
import 'package:suicun/features/records/data/record_repository.dart';
import 'package:suicun/features/records/domain/record_model.dart';
import 'package:suicun/features/tags/data/tag_repository.dart';

const int _schemaVersion = 1;
const int _maxImportRecords = 100000;
const int _maxZipFiles = 10000;
const int _maxZipTotalBytes = 500 * 1024 * 1024; // 500 MiB

class BackupService {
  BackupService({
    required this.db,
    required this.recordRepo,
    required this.categoryRepo,
    required this.tagRepo,
  });

  final AppDatabase db;
  final RecordRepository recordRepo;
  final CategoryRepository categoryRepo;
  final TagRepository tagRepo;

  // ── Export: Full JSON ────────────────────────────────────────────────────

  /// Exports all non-deleted records (+ categories, tags, relationships) as JSON.
  Future<File> exportJson() async {
    try {
      final categories = await categoryRepo.getAllCategories();
      final tags = await tagRepo.getAllTags();
      final records = await recordRepo.searchRecords(limit: _maxImportRecords);

      // Build tag lookup for each record
      final allRecordTags = await (db.select(db.recordTags)).get();
      final tagsByRecord = <String, List<String>>{};
      for (final rt in allRecordTags) {
        tagsByRecord.putIfAbsent(rt.recordId, () => []).add(rt.tagId);
      }

      final data = {
        'schema_version': _schemaVersion,
        'exported_at': DateTime.now().toUtc().toIso8601String(),
        'categories': categories
            .map((c) => {
                  'id': c.id,
                  'name': c.name,
                  'color': c.color,
                })
            .toList(),
        'tags': tags
            .map((t) => {
                  'id': t.id,
                  'name': t.name,
                })
            .toList(),
        'records': records
            .map((r) => {
                  'id': r.id,
                  'title': r.title,
                  'body': r.body,
                  'category_id': r.categoryId,
                  'is_favorite': r.isFavorite,
                  'created_at': r.createdAt.toIso8601String(),
                  'updated_at': r.updatedAt.toIso8601String(),
                  // Sorted for deterministic backups
                  'tag_ids': (tagsByRecord[r.id] ?? [])..sort(),
                })
            .toList(),
      };

      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
      final file = File(p.join(dir.path, 'suicun_backup_$ts.json'));
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data),
        flush: true,
      );
      return file;
    } catch (e) {
      throw ExportError('JSON export failed', e);
    }
  }

  // ── Export: Markdown ZIP ─────────────────────────────────────────────────

  /// Exports all records as individual Markdown files in a ZIP archive.
  Future<File> exportMarkdownZip() async {
    try {
      final records = await recordRepo.searchRecords(limit: _maxImportRecords);
      final categories = await categoryRepo.getAllCategories();
      final catMap = {for (final c in categories) c.id: c.name};

      final archive = Archive();
      var totalBytes = 0;
      var skippedByLimit = 0;

      for (final r in records) {
        if (archive.length >= _maxZipFiles) {
          skippedByLimit++;
          continue;
        }
        final idShort = r.id.substring(0, 8);
        final safeTitle = r.title
            .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
            .replaceAll(RegExp(r'\s+'), '_');
        final truncated = safeTitle.substring(0, safeTitle.length.clamp(0, 40));
        final filename =
            truncated.isEmpty ? '$idShort.md' : '${truncated}_$idShort.md';

        final catName =
            r.categoryId != null ? catMap[r.categoryId!] ?? '' : '';
        final tagNames = r.tags.map((t) => t.name).join(', ');

        final sb = StringBuffer();
        if (r.title.isNotEmpty) sb.writeln('# ${r.title}');
        sb.writeln();
        if (catName.isNotEmpty) sb.writeln('**Category:** $catName');
        if (tagNames.isNotEmpty) sb.writeln('**Tags:** $tagNames');
        sb.writeln('**Favorite:** ${r.isFavorite}');
        sb.writeln('**Created:** ${r.createdAt.toIso8601String()}');
        sb.writeln('**Updated:** ${r.updatedAt.toIso8601String()}');
        sb.writeln();
        sb.write(r.body);

        final bytes = utf8.encode(sb.toString());
        if (totalBytes + bytes.length > _maxZipTotalBytes) {
          skippedByLimit++;
          continue;
        }
        totalBytes += bytes.length;
        archive.addFile(ArchiveFile(filename, bytes.length, bytes));
      }

      if (skippedByLimit > 0) {
        final note =
            'NOTE: $skippedByLimit record(s) skipped due to ZIP size/count limits.\n';
        final noteBytes = utf8.encode(note);
        archive.addFile(ArchiveFile('_skipped.txt', noteBytes.length, noteBytes));
      }

      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
      final zipFile = File(p.join(dir.path, 'suicun_markdown_$ts.zip'));

      final encoder = ZipEncoder();
      await zipFile.writeAsBytes(encoder.encode(archive), flush: true);
      return zipFile;
    } catch (e) {
      throw ExportError('Markdown ZIP export failed', e);
    }
  }

  // ── Export: TXT ──────────────────────────────────────────────────────────

  /// Exports all records as a single TXT file.
  Future<File> exportTxt() async {
    try {
      final records = await recordRepo.searchRecords(limit: _maxImportRecords);
      final sb = StringBuffer();

      for (final r in records) {
        sb.writeln('=' * 60);
        final title = r.title.isNotEmpty ? r.title : '(untitled)';
        sb.writeln(title);
        sb.writeln('Updated: ${r.updatedAt.toIso8601String()}');
        sb.writeln('-' * 40);
        sb.writeln(r.body);
        sb.writeln();
      }

      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
      final file = File(p.join(dir.path, 'suicun_export_$ts.txt'));
      await file.writeAsString(sb.toString(), flush: true);
      return file;
    } catch (e) {
      throw ExportError('TXT export failed', e);
    }
  }

  // ── Import: JSON ─────────────────────────────────────────────────────────

  /// Validates and previews a JSON backup file. Returns the count of new records.
  Future<int> previewJsonImport(File file) async {
    final data = await _parseAndValidateJson(file);
    final recordList = data['records'] as List;
    return recordList.length;
  }

  /// Imports a JSON backup in a single transaction. On failure rolls back.
  /// Returns the count of imported records.
  Future<int> importJson(File file) async {
    final data = await _parseAndValidateJson(file);

    final catList = data['categories'] as List;
    final tagList = data['tags'] as List;
    final recordList = data['records'] as List;

    try {
      await db.transaction(() async {
        // Import categories
        for (final cat in catList) {
          final c = cat as Map<String, dynamic>;
          final existing = await (db.select(db.categories)
                ..where((x) => x.id.equals(c['id'] as String)))
              .getSingleOrNull();
          if (existing == null) {
            await db.into(db.categories).insert(
                  CategoriesCompanion.insert(
                    id: c['id'] as String,
                    name: c['name'] as String,
                    color: Value(c['color'] as String? ?? '#4866D5'),
                  ),
                );
          }
        }

        // Import tags
        for (final tag in tagList) {
          final t = tag as Map<String, dynamic>;
          final existing = await (db.select(db.tags)
                ..where((x) => x.id.equals(t['id'] as String)))
              .getSingleOrNull();
          if (existing == null) {
            await db.into(db.tags).insert(
                  TagsCompanion.insert(
                    id: t['id'] as String,
                    name: t['name'] as String,
                  ),
                );
          }
        }

        // Import records
        for (final rec in recordList) {
          final r = rec as Map<String, dynamic>;
          final existing = await (db.select(db.records)
                ..where((x) => x.id.equals(r['id'] as String)))
              .getSingleOrNull();
          if (existing == null) {
            await db.into(db.records).insert(
                  RecordsCompanion.insert(
                    id: r['id'] as String,
                    title: Value(r['title'] as String? ?? ''),
                    body: Value(r['body'] as String? ?? ''),
                    categoryId: Value(r['category_id'] as String?),
                    isFavorite: Value(r['is_favorite'] as bool? ?? false),
                    createdAt: DateTime.parse(r['created_at'] as String),
                    updatedAt: DateTime.parse(r['updated_at'] as String),
                  ),
                );
            final tagIds = (r['tag_ids'] as List?)?.cast<String>() ?? [];
            for (final tagId in tagIds) {
              // Only insert if the tag exists in db
              final tagExists = await (db.select(db.tags)
                    ..where((t) => t.id.equals(tagId)))
                  .getSingleOrNull();
              if (tagExists != null) {
                await db.into(db.recordTags).insertOnConflictUpdate(
                      RecordTagsCompanion.insert(
                          recordId: r['id'] as String, tagId: tagId),
                    );
              }
            }
          }
        }
      });

      return recordList.length;
    } catch (e) {
      throw ImportError('JSON import transaction failed', e);
    }
  }

  /// Imports Markdown or TXT file as a new record (generates new ID).
  Future<RecordDetail> importTextFile(File file) async {
    try {
      final content = await file.readAsString();
      final name = p.basenameWithoutExtension(file.path);
      String title = '';
      String body = content;

      if (file.path.endsWith('.md')) {
        final lines = content.split('\n');
        if (lines.isNotEmpty && lines.first.startsWith('# ')) {
          title = lines.first.substring(2).trim();
          body = lines.skip(1).join('\n').trimLeft();
        }
      }

      return await recordRepo.createRecord(
        title: title.isEmpty ? name : title,
        body: body,
      );
    } catch (e) {
      throw ImportError('Text file import failed', e);
    }
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _parseAndValidateJson(File file) async {
    final raw = await file.readAsString();
    final dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (e) {
      throw const ImportError('Invalid JSON file');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const ImportError('JSON root must be an object');
    }
    final version = decoded['schema_version'];
    if (version is! int) throw const ImportError('Missing schema_version');
    if (version > _schemaVersion) {
      throw ImportError('Unsupported schema version: $version');
    }
    final records = decoded['records'];
    if (records is! List) throw const ImportError('Missing records array');
    if (records.length > _maxImportRecords) {
      throw ImportError('Too many records (${records.length} > $_maxImportRecords)');
    }
    final cats = decoded['categories'];
    if (cats is! List) throw const ImportError('Missing categories array');
    final tags = decoded['tags'];
    if (tags is! List) throw const ImportError('Missing tags array');
    return decoded;
  }
}
