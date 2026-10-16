// test/unit/quick_access_storage_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suicun/features/records/data/quick_access_storage.dart';

void main() {
  group('QuickAccessService - 常用增删', () {
    late SharedPreferences prefs;
    late QuickAccessService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      service = QuickAccessService(prefs);
    });

    test('add and remove quick access record ids', () async {
      expect(service.getQuickAccessIds(), isEmpty);

      final added1 = await service.addToQuickAccess('rec_1');
      expect(added1, isTrue);
      expect(service.getQuickAccessIds(), ['rec_1']);
      expect(service.isQuickAccess('rec_1'), isTrue);

      final added2 = await service.addToQuickAccess('rec_2');
      expect(added2, isTrue);
      expect(service.getQuickAccessIds(), ['rec_1', 'rec_2']);

      await service.removeFromQuickAccess('rec_1');
      expect(service.getQuickAccessIds(), ['rec_2']);
      expect(service.isQuickAccess('rec_1'), isFalse);
    });

    test('toggle quick access adds or removes id', () async {
      final t1 = await service.toggleQuickAccess('rec_a');
      expect(t1, isTrue);
      expect(service.isQuickAccess('rec_a'), isTrue);

      final t2 = await service.toggleQuickAccess('rec_a');
      expect(t2, isFalse);
      expect(service.isQuickAccess('rec_a'), isFalse);
    });

    test('quick access enforces maximum 6 items limit', () async {
      for (int i = 1; i <= 6; i++) {
        final ok = await service.addToQuickAccess('rec_$i');
        expect(ok, isTrue);
      }
      expect(service.getQuickAccessIds().length, 6);

      // Adding 7th item returns false and does not exceed 6
      final ok7 = await service.addToQuickAccess('rec_7');
      expect(ok7, isFalse);
      expect(service.getQuickAccessIds().length, 6);
      expect(service.getQuickAccessIds().contains('rec_7'), isFalse);

      // toggle on 7th throws StateError
      expect(() => service.toggleQuickAccess('rec_7'), throwsStateError);
    });
  });

  group('QuickAccessService - 最近搜索去重与条数限制', () {
    late SharedPreferences prefs;
    late QuickAccessService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      service = QuickAccessService(prefs);
    });

    test('deduplicates case-insensitively and puts latest search at index 0', () async {
      await service.addSearchQuery('身份证');
      await service.addSearchQuery('sfz');
      await service.addSearchQuery('SFZ'); // duplicate of sfz

      final searches = service.getRecentSearches();
      expect(searches.length, 2);
      expect(searches[0], 'SFZ');
      expect(searches[1], '身份证');
    });

    test('ignores empty or whitespace query', () async {
      await service.addSearchQuery('');
      await service.addSearchQuery('   ');
      expect(service.getRecentSearches(), isEmpty);
    });

    test('enforces maximum 8 recent search queries', () async {
      for (int i = 1; i <= 10; i++) {
        await service.addSearchQuery('query_$i');
      }
      final searches = service.getRecentSearches();
      expect(searches.length, 8);
      expect(searches.first, 'query_10');
      expect(searches.last, 'query_3');
    });

    test('clears recent searches', () async {
      await service.addSearchQuery('test');
      expect(service.getRecentSearches().length, 1);
      await service.clearRecentSearches();
      expect(service.getRecentSearches(), isEmpty);
    });
  });

  group('QuickAccessService - 最近打开记录', () {
    late SharedPreferences prefs;
    late QuickAccessService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      service = QuickAccessService(prefs);
    });

    test('records opened ids in reverse chronological order with max 10', () async {
      for (int i = 1; i <= 12; i++) {
        await service.recordOpened('rec_$i');
      }
      final recents = service.getRecentOpenedIds();
      expect(recents.length, 10);
      expect(recents.first, 'rec_12');
      expect(recents.last, 'rec_3');

      // Re-opening rec_5 brings it to the top
      await service.recordOpened('rec_5');
      final updated = service.getRecentOpenedIds();
      expect(updated.length, 10);
      expect(updated.first, 'rec_5');
      expect(updated[1], 'rec_12');
    });
  });

  group('QuickAccessService - removeEverywhere 与 clearAll', () {
    late SharedPreferences prefs;
    late QuickAccessService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      service = QuickAccessService(prefs);
    });

    test('removeEverywhere clears id from both quick access and recent opened records', () async {
      await service.addToQuickAccess('rec_1');
      await service.addToQuickAccess('rec_2');
      await service.recordOpened('rec_1');
      await service.recordOpened('rec_3');

      expect(service.getQuickAccessIds(), contains('rec_1'));
      expect(service.getRecentOpenedIds(), contains('rec_1'));

      await service.removeEverywhere('rec_1');

      expect(service.getQuickAccessIds(), ['rec_2']);
      expect(service.getRecentOpenedIds(), ['rec_3']);

      // Calling with non-existent id does not throw
      await service.removeEverywhere('non_existent_id');
      expect(service.getQuickAccessIds(), ['rec_2']);
      expect(service.getRecentOpenedIds(), ['rec_3']);
    });

    test('clearAll removes quick access, recent opened, and recent searches', () async {
      await service.addToQuickAccess('rec_1');
      await service.recordOpened('rec_2');
      await service.addSearchQuery('query_1');

      await service.clearAll();

      expect(service.getQuickAccessIds(), isEmpty);
      expect(service.getRecentOpenedIds(), isEmpty);
      expect(service.getRecentSearches(), isEmpty);
    });
  });
}
