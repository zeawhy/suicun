// test/unit/display_title_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:suicun/features/records/domain/record_model.dart';
import 'package:suicun/shared/utils/display_title.dart';

void main() {
  group('displayTitleFor / displayTitleFrom', () {
    final now = DateTime.now();

    RecordDetail makeRecord({required String title, required String body}) {
      return RecordDetail(
        record: RecordModel(
          id: 'test-id',
          title: title,
          body: body,
          isFavorite: false,
          createdAt: now,
          updatedAt: now,
        ),
        tags: const [],
      );
    }

    test('returns existing non-empty title directly', () {
      final r = makeRecord(
        title: '我的护照',
        body: '证件类型：护照\n姓名：张三\n证件号码：E12345678',
      );
      expect(displayTitleFor(r, untitled: '未命名记录'), '我的护照');
    });

    test('ID document template: formats docType and name', () {
      final r = makeRecord(
        title: '',
        body: '证件类型：身份证\n姓名：张三\n证件号码：110101199003072391',
      );
      // Legacy body decodes to type key 'cn_resident_id'; without a
      // context the fallback is defaultDocType.
      expect(
          displayTitleFor(r,
              untitled: '未命名记录', defaultDocType: '证件'),
          '证件 · 张三');
    });

    test('ID document template without name: formats docType only', () {
      final r = makeRecord(
        title: '',
        body: '证件类型：港澳通行证\n证件号码：C12345678',
      );
      expect(
          displayTitleFor(r,
              untitled: '未命名记录', defaultDocType: '证件'),
          '证件');
    });

    test('ID document template without docType: uses default docType', () {
      final r = makeRecord(
        title: '',
        body: '姓名：李四\n证件号码：110101199003072391',
      );
      expect(
          displayTitleFor(r,
              untitled: '未命名记录', defaultDocType: '证件'),
          '证件 · 李四');
    });

    test('ID document template empty fields: falls back to default docType', () {
      final r = makeRecord(
        title: '',
        body: '证件类型：\n证件号码：12345',
      );
      expect(
          displayTitleFor(r,
              untitled: '未命名记录', defaultDocType: '证件'),
          '证件');
    });

    test('Password template: returns website/app name', () {
      final r = makeRecord(
        title: '',
        body: '网站/应用：github.com\n用户名：zeawhy\n密码：secret123',
      );
      expect(displayTitleFor(r, untitled: '未命名记录'), 'github.com');
    });

    test('Password template without website: falls back to untitled', () {
      final r = makeRecord(
        title: '',
        body: '用户名：zeawhy\n密码：secret123',
      );
      expect(displayTitleFor(r, untitled: '未命名记录'), '未命名记录');
    });

    test('Contact template: returns contact name', () {
      final r = makeRecord(
        title: '',
        body: '姓名：王五\n电话：13800000000',
      );
      expect(displayTitleFor(r, untitled: '未命名记录'), '王五');
    });

    test('Contact template without name: falls back to untitled', () {
      final r = makeRecord(
        title: '',
        body: '电话：13800000000\n邮箱：test@example.com',
      );
      expect(displayTitleFor(r, untitled: '未命名记录'), '未命名记录');
    });

    test('Plain note without title: returns untitled', () {
      final r = makeRecord(
        title: '',
        body: '今天天气不错，去超市买了一些水果。',
      );
      expect(displayTitleFor(r, untitled: '未命名记录'), '未命名记录');
    });
  });
}
