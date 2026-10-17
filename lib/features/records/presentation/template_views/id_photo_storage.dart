// lib/features/records/presentation/template_views/id_photo_storage.dart

import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Saves an ID card photo to the app's private documents directory under `id_photos/`.
///
/// Returns the relative path `id_photos/{recordId}_{front|back}_{timestamp}.jpg`,
/// or `null` if saving fails.
Future<String?> saveIdPhoto(
  XFile picked, {
  required String recordId,
  required bool isFront,
}) async {
  try {
    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(appDir.path, 'id_photos'));
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    final side = isFront ? 'front' : 'back';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${recordId}_${side}_$timestamp.jpg';
    final targetPath = p.join(photosDir.path, fileName);

    await picked.saveTo(targetPath);
    return 'id_photos/$fileName';
  } catch (_) {
    return null;
  }
}

/// Resolves a relative photo path (e.g. `id_photos/xxx.jpg`) to an absolute [File].
///
/// Returns `null` if [relativePath] is empty or the file does not exist.
Future<File?> resolveIdPhoto(String relativePath) async {
  final trimmed = relativePath.trim();
  if (trimmed.isEmpty) return null;

  try {
    final appDir = await getApplicationDocumentsDirectory();
    final file = File(p.join(appDir.path, trimmed));
    if (await file.exists()) {
      return file;
    }
    return null;
  } catch (_) {
    return null;
  }
}

/// Deletes a single ID photo file by its relative path (e.g. `id_photos/xxx.jpg`).
Future<void> deleteIdPhotoFile(String relativePath) async {
  try {
    final file = await resolveIdPhoto(relativePath);
    if (file != null) {
      await file.delete();
    }
  } catch (_) {
    // Ignore errors during cleanup
  }
}

/// Deletes all ID photo files associated with [recordId].
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

