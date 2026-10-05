import 'package:flutter_test/flutter_test.dart';
import 'package:suicun/features/records/data/autosave_service.dart';

void main() {
  group('Autosave logic', () {
    test('isRecordEffectivelyEmpty returns true for empty inputs', () {
      expect(isRecordEffectivelyEmpty(title: '', body: ''), isTrue);
      expect(isRecordEffectivelyEmpty(title: '  ', body: ' \n '), isTrue);
    });

    test('isRecordEffectivelyEmpty returns false when content exists', () {
      expect(isRecordEffectivelyEmpty(title: 'A', body: ''), isFalse);
      expect(isRecordEffectivelyEmpty(title: '', body: 'B'), isFalse);
    });
  });
}
