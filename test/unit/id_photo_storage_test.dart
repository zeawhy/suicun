// test/unit/id_photo_storage_test.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
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

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('id_photo_test_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('id_photo_storage', () {
    test('saveIdPhoto saves front and back photos with relative path', () async {
      final sourceFile = File('${tempDir.path}/test_source.jpg');
      await sourceFile.writeAsString('fake_image_bytes');
      final xFile = XFile(sourceFile.path);

      final frontRelative = await saveIdPhoto(
        xFile,
        recordId: 'rec_100',
        isFront: true,
      );
      expect(frontRelative, isNotNull);
      expect(frontRelative, startsWith('id_photos/rec_100_front_'));
      expect(frontRelative, endsWith('.jpg'));

      final backRelative = await saveIdPhoto(
        xFile,
        recordId: 'rec_100',
        isFront: false,
      );
      expect(backRelative, isNotNull);
      expect(backRelative, startsWith('id_photos/rec_100_back_'));
      expect(backRelative, endsWith('.jpg'));

      final resolvedFront = await resolveIdPhoto(frontRelative!);
      expect(resolvedFront, isNotNull);
      expect(await resolvedFront!.exists(), isTrue);
      expect(await resolvedFront.readAsString(), 'fake_image_bytes');

      final resolvedBack = await resolveIdPhoto(backRelative!);
      expect(resolvedBack, isNotNull);
      expect(await resolvedBack!.exists(), isTrue);
    });

    test('resolveIdPhoto returns null for empty or non-existent path', () async {
      expect(await resolveIdPhoto(''), isNull);
      expect(await resolveIdPhoto('   '), isNull);
      expect(await resolveIdPhoto('id_photos/non_existent.jpg'), isNull);
    });

    test('deleteIdPhotosForRecord deletes only matching photos', () async {
      final sourceFile = File('${tempDir.path}/test_source.jpg');
      await sourceFile.writeAsString('bytes');
      final xFile = XFile(sourceFile.path);

      final photo1 = await saveIdPhoto(xFile, recordId: 'rec_1', isFront: true);
      final photo2 = await saveIdPhoto(xFile, recordId: 'rec_1', isFront: false);
      final photoOther = await saveIdPhoto(xFile, recordId: 'rec_2', isFront: true);

      expect(await resolveIdPhoto(photo1!), isNotNull);
      expect(await resolveIdPhoto(photo2!), isNotNull);
      expect(await resolveIdPhoto(photoOther!), isNotNull);

      await deleteIdPhotosForRecord('rec_1');

      expect(await resolveIdPhoto(photo1), isNull);
      expect(await resolveIdPhoto(photo2), isNull);
      expect(await resolveIdPhoto(photoOther), isNotNull);
    });
  });
}
