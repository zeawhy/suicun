// test/unit/note_template_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:suicun/features/records/presentation/note_template.dart';
import 'package:suicun/l10n/generated/app_localizations_en.dart';
import 'package:suicun/l10n/generated/app_localizations_zh.dart';

void main() {
  final l10nZh = AppLocalizationsZh();
  final l10nEn = AppLocalizationsEn();

  group('NoteTemplate', () {
    test('contains 5 templates with unique ids', () {
      expect(NoteTemplate.all.length, 5);
      final ids = NoteTemplate.all.map((t) => t.id).toSet();
      expect(ids.length, 5);
      expect(
        ids,
        containsAll(['blank', 'password', 'idea', 'todo', 'contact']),
      );
    });

    test('names and descriptions are non-empty in both zh and en', () {
      for (final template in NoteTemplate.all) {
        expect(template.getTitle(l10nZh).trim(), isNotEmpty);
        expect(template.getTitle(l10nEn).trim(), isNotEmpty);
        expect(template.getDescription(l10nZh).trim(), isNotEmpty);
        expect(template.getDescription(l10nEn).trim(), isNotEmpty);
      }
    });

    test('preset templates (non-blank) have non-empty bodies in zh and en', () {
      final nonBlank = NoteTemplate.all.where((t) => t.id != 'blank');
      expect(nonBlank.length, 4);

      for (final template in nonBlank) {
        expect(template.bodyZh.trim(), isNotEmpty);
        expect(template.bodyEn.trim(), isNotEmpty);
        expect(template.getBody('zh').trim(), isNotEmpty);
        expect(template.getBody('en').trim(), isNotEmpty);
      }

      final blank = NoteTemplate.byId('blank')!;
      expect(blank.bodyZh, isEmpty);
      expect(blank.bodyEn, isEmpty);
      expect(blank.getBody('zh'), isEmpty);
      expect(blank.getBody('en'), isEmpty);
    });

    test('password template body contains secret/password line in zh and en', () {
      final passwordTemplate = NoteTemplate.byId('password');
      expect(passwordTemplate, isNotNull);
      expect(passwordTemplate!.bodyZh, contains('密码：'));
      expect(passwordTemplate.bodyEn, contains('Password:'));
    });

    test('byId retrieves template or null for unknown id', () {
      expect(NoteTemplate.byId('idea')?.id, 'idea');
      expect(NoteTemplate.byId('todo')?.id, 'todo');
      expect(NoteTemplate.byId('contact')?.id, 'contact');
      expect(NoteTemplate.byId('unknown'), isNull);
      expect(NoteTemplate.byId(null), isNull);
    });
  });
}
