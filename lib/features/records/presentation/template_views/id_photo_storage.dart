// lib/features/records/presentation/template_views/id_photo_storage.dart
// ID photo storage with encryption at rest (spec §2.3).
//
// Photos are encrypted with AES-256-GCM (FileEncryptionService) before
// being written to the app's private documents directory under `id_photos/`.
// Files use the `.enc` extension: `id_photos/{recordId}_{front|back}_{timestamp}.enc`.
// Plaintext is NEVER written to disk (no temp files); UI renders via
// `Image.memory` from [loadIdPhotoBytes].

import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:suicun/core/crypto/file_encryption_service.dart';

/// Saves an ID card photo (already compressed at pick time via
/// `maxWidth:2000, maxHeight:2000, imageQuality:85`) encrypted to the app's
/// private documents directory.
///
/// Returns the relative path `id_photos/{recordId}_{front|back}_{timestamp}.enc`,
/// or `null` if saving fails. The [picked] temp file is deleted after
/// successful encryption.
Future<String?> saveIdPhoto(
  XFile picked, {
  required String recordId,
  required bool isFront,
  FileEncryptionService? encryption,
}) async {
  try {
    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(appDir.path, 'id_photos'));
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    final side = isFront ? 'front' : 'back';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${recordId}_${side}_$timestamp.enc';
    final target = File(p.join(photosDir.path, fileName));

    final plain = await picked.readAsBytes();
    await (encryption ?? FileEncryptionService())
        .writeEncrypted(target, plain);

    // Delete the image_picker temp file now that the encrypted copy exists.
    try {
      await File(picked.path).delete();
    } catch (_) {}

    return 'id_photos/$fileName';
  } catch (_) {
    return null;
  }
}

/// Loads and decrypts a photo by its relative path
/// (e.g. `id_photos/xxx.enc`). Returns the raw image bytes for `Image.memory`.
///
/// Returns `null` if [relativePath] is empty, the file does not exist, or
/// decryption fails. No plaintext temp file is ever written.
Future<Uint8List?> loadIdPhotoBytes(
  String relativePath, {
  FileEncryptionService? encryption,
}) async {
  final trimmed = relativePath.trim();
  if (trimmed.isEmpty) return null;

  try {
    final appDir = await getApplicationDocumentsDirectory();
    final file = File(p.join(appDir.path, trimmed));
    if (!await file.exists()) return null;
    return await (encryption ?? FileEncryptionService()).readDecrypted(file);
  } catch (_) {
    return null;
  }
}

/// Deletes a single ID photo file by its relative path (e.g. `id_photos/xxx.enc`).
Future<void> deleteIdPhotoFile(String relativePath) async {
  try {
    final trimmed = relativePath.trim();
    if (trimmed.isEmpty) return;
    final appDir = await getApplicationDocumentsDirectory();
    final file = File(p.join(appDir.path, trimmed));
    if (await file.exists()) {
      await file.delete();
    }
  } catch (_) {
    // Ignore errors during cleanup
  }
}

/// Deletes all ID photo files associated with [recordId] (both `.enc` and
/// legacy `.jpg`).
Future<void> deleteIdPhotosForRecord(String recordId) async {
  try {
    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(appDir.path, 'id_photos'));
    if (!await photosDir.exists()) return;

    final prefix = '${recordId}_';
    await for (final entity in photosDir.list()) {
      if (entity is File) {
        final name = p.basename(entity.path);
        if (name.startsWith(prefix)) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
    }
  } catch (_) {
    // Ignore errors during cleanup
  }
}

/// Deletes all ID photo files in the `id_photos/` directory.
Future<void> deleteAllIdPhotos() async {
  try {
    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(appDir.path, 'id_photos'));
    if (!await photosDir.exists()) return;
    await for (final entity in photosDir.list()) {
      try {
        await entity.delete(recursive: true);
      } catch (_) {}
    }
  } catch (_) {
    // Ignore errors during cleanup
  }
}

/// Migrates legacy plaintext `.jpg` photos to encrypted `.enc` files.
///
/// For each `.jpg` in `id_photos/`, encrypts it to a `.enc` file, updates
/// the corresponding record's [IdDocData] photo path via [updateRecordPhotoPath],
/// then deletes the original `.jpg`. Progress is recorded via [onProgress]
/// after each file; if interrupted, already-migrated files are skipped on
/// the next run (their `.jpg` is gone).
///
/// [updateRecordPhotoPath] receives (recordId, oldRelativePath, newRelativePath)
/// and must persist the change through the record repository (so sync outbox
/// gets a new revision). Returns the number of files migrated.
Future<int> migrateLegacyPhotos({
  required Future<void> Function(
      String recordId, String oldPath, String newPath) updateRecordPhotoPath,
  Future<void> Function(int done, int total)? onProgress,
  FileEncryptionService? encryption,
}) async {
  final svc = encryption ?? FileEncryptionService();
  final appDir = await getApplicationDocumentsDirectory();
  final photosDir = Directory(p.join(appDir.path, 'id_photos'));
  if (!await photosDir.exists()) return 0;

  final jpgs = <File>[];
  await for (final entity in photosDir.list()) {
    if (entity is File && entity.path.toLowerCase().endsWith('.jpg')) {
      jpgs.add(entity);
    }
  }

  var migrated = 0;
  for (var i = 0; i < jpgs.length; i++) {
    final jpg = jpgs[i];
    try {
      final name = p.basename(jpg.path);
      // Expected: {recordId}_{front|back}_{timestamp}.jpg
      final recordId = name.split('_').first;
      final newName = '${p.basenameWithoutExtension(name)}.enc';
      final target = File(p.join(photosDir.path, newName));

      final plain = await jpg.readAsBytes();
      await svc.writeEncrypted(target, plain);

      final oldRel = 'id_photos/$name';
      final newRel = 'id_photos/$newName';
      await updateRecordPhotoPath(recordId, oldRel, newRel);

      await jpg.delete();
      migrated++;
    } catch (_) {
      // Skip failed files; retry next run.
    }
    try {
      await onProgress?.call(i + 1, jpgs.length);
    } catch (_) {}
  }
  return migrated;
}
