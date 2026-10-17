// test/unit/id_photo_storage_test.dart
// Tests for encrypted ID photo storage (spec §2.3).

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:suicun/core/crypto/file_encryption_service.dart';
import 'package:suicun/core/crypto/key_value_store.dart';
import 'package:suicun/features/records/presentation/template_views/id_photo_storage.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.dir);

  final Directory dir;

  @override
  Future<String?> getApplicationDocumentsPath() async => dir.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late FileEncryptionService encryption;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('id_photo_test_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir);
    encryption = FileEncryptionService(store: MemoryKeyValueStore());
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('id_photo_storage (encrypted)', () {
    test('saveIdPhoto encrypts and returns .enc path', () async {
      final sourceFile = File('${tempDir.path}/test_source.jpg');
      await sourceFile.writeAsBytes(Uint8List.fromList([1, 2, 3, 4, 5]));
      final xFile = XFile(sourceFile.path);

      final frontRelative = await saveIdPhoto(
        xFile,
        recordId: 'rec_100',
        isFront: true,
        encryption: encryption,
      );
      expect(frontRelative, isNotNull);
      expect(frontRelative, startsWith('id_photos/rec_100_front_'));
      expect(frontRelative, endsWith('.enc'));

      final stored = File('${tempDir.path}/$frontRelative');
      final raw = await stored.readAsBytes();
      expect(raw.sublist(0, 4), [0x53, 0x56, 0x46, 0x31]); // "SVF1"

      final frontBytes = await loadIdPhotoBytes(frontRelative!, encryption: encryption);
      expect(frontBytes, [1, 2, 3, 4, 5]);
    });

    test('loadIdPhotoBytes returns null for empty or non-existent path', () async {
      expect(await loadIdPhotoBytes('', encryption: encryption), isNull);
      expect(await loadIdPhotoBytes('   ', encryption: encryption), isNull);
      expect(
          await loadIdPhotoBytes('id_photos/non_existent.enc',
              encryption: encryption),
          isNull);
    });

    test('deleteIdPhotosForRecord deletes only matching photos', () async {
      Future<XFile> makeXFile(String name) async {
        final f = File('${tempDir.path}/$name.jpg');
        await f.writeAsBytes(Uint8List.fromList([9, 9, 9]));
        return XFile(f.path);
      }

      final photo1 = await saveIdPhoto(await makeXFile('s1'),
          recordId: 'rec_1', isFront: true, encryption: encryption);
      final photo2 = await saveIdPhoto(await makeXFile('s2'),
          recordId: 'rec_1', isFront: false, encryption: encryption);
      final photoOther = await saveIdPhoto(await makeXFile('s3'),
          recordId: 'rec_2', isFront: true, encryption: encryption);

      expect(await loadIdPhotoBytes(photo1!, encryption: encryption), isNotNull);
      expect(await loadIdPhotoBytes(photo2!, encryption: encryption), isNotNull);
      expect(await loadIdPhotoBytes(photoOther!, encryption: encryption), isNotNull);

      await deleteIdPhotosForRecord('rec_1');

      expect(await loadIdPhotoBytes(photo1, encryption: encryption), isNull);
      expect(await loadIdPhotoBytes(photo2, encryption: encryption), isNull);
      expect(await loadIdPhotoBytes(photoOther!, encryption: encryption), isNotNull);
    });
  });
}
