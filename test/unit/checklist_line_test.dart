// test/unit/checklist_line_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:suicun/features/records/presentation/checklist_line.dart';

void main() {
  group('parseChecklistLines', () {
    test('recognizes ☐ and ☑ with checked state and extracts content', () {
      final unchecked = parseChecklistLines('☐ 事项一');
      expect(unchecked.length, 1);
      expect(unchecked.first.isChecklist, isTrue);
      expect(unchecked.first.checked, isFalse);
      expect(unchecked.first.content, '事项一');
      expect(unchecked.first.rawLine, '☐ 事项一');

      final checked = parseChecklistLines('☑ 事项二');
      expect(checked.length, 1);
      expect(checked.first.isChecklist, isTrue);
      expect(checked.first.checked, isTrue);
      expect(checked.first.content, '事项二');
      expect(checked.first.rawLine, '☑ 事项二');
    });

    test('tolerates full-width space, tab, half-width space, and no space', () {
      final fullWidth = parseChecklistLines('☐\u3000全角事项');
      expect(fullWidth.length, 1);
      expect(fullWidth.first.isChecklist, isTrue);
      expect(fullWidth.first.checked, isFalse);
      expect(fullWidth.first.content, '全角事项');

      final tab = parseChecklistLines('☑\tTab事项');
      expect(tab.length, 1);
      expect(tab.first.isChecklist, isTrue);
      expect(tab.first.checked, isTrue);
      expect(tab.first.content, 'Tab事项');

      final multipleSpaces = parseChecklistLines('☐   多空格事项');
      expect(multipleSpaces.length, 1);
      expect(multipleSpaces.first.isChecklist, isTrue);
      expect(multipleSpaces.first.content, '多空格事项');

      final noSpace = parseChecklistLines('☐无空格事项');
      expect(noSpace.length, 1);
      expect(noSpace.first.isChecklist, isTrue);
      expect(noSpace.first.content, '无空格事项');
    });

    test('recognizes empty content when line has marker only or marker with spaces', () {
      final boxOnly = parseChecklistLines('☐');
      expect(boxOnly.length, 1);
      expect(boxOnly.first.isChecklist, isTrue);
      expect(boxOnly.first.checked, isFalse);
      expect(boxOnly.first.content, '');

      final checkedBoxOnly = parseChecklistLines('☑');
      expect(checkedBoxOnly.length, 1);
      expect(checkedBoxOnly.first.isChecklist, isTrue);
      expect(checkedBoxOnly.first.checked, isTrue);
      expect(checkedBoxOnly.first.content, '');

      final withSpaces = parseChecklistLines('☐   ');
      expect(withSpaces.length, 1);
      expect(withSpaces.first.isChecklist, isTrue);
      expect(withSpaces.first.content, '');
    });

    test('does not recognize lines with marker not at line start', () {
      final leadingSpace = parseChecklistLines(' ☐ 事项');
      expect(leadingSpace.length, 1);
      expect(leadingSpace.first.isChecklist, isFalse);
      expect(leadingSpace.first.checked, isFalse);
      expect(leadingSpace.first.content, isNull);

      final prefixText = parseChecklistLines('待办：☐ 事项');
      expect(prefixText.length, 1);
      expect(prefixText.first.isChecklist, isFalse);
      expect(prefixText.first.content, isNull);

      final bracketCheck = parseChecklistLines('[ ] 事项');
      expect(bracketCheck.length, 1);
      expect(bracketCheck.first.isChecklist, isFalse);
    });

    test('returns empty list for empty input', () {
      expect(parseChecklistLines(''), isEmpty);
    });

    test('correctly parses multiline mixed text and handles CRLF', () {
      const text = '☐ 购买牛奶\r\n普通备注文本\r\n☑ 提交周报\r\n网站：https://example.com';
      final lines = parseChecklistLines(text);
      expect(lines.length, 4);

      expect(lines[0].isChecklist, isTrue);
      expect(lines[0].checked, isFalse);
      expect(lines[0].content, '购买牛奶');

      expect(lines[1].isChecklist, isFalse);
      expect(lines[1].rawLine, '普通备注文本');
      expect(lines[1].content, isNull);

      expect(lines[2].isChecklist, isTrue);
      expect(lines[2].checked, isTrue);
      expect(lines[2].content, '提交周报');

      expect(lines[3].isChecklist, isFalse);
      expect(lines[3].rawLine, '网站：https://example.com');
    });
  });

  group('toggleChecklistLine', () {
    test('toggles ☐ to ☑ and preserves rest of characters', () {
      final line = ChecklistLine(
        isChecklist: true,
        rawLine: '☐  事项一：详情说明',
        checked: false,
        content: '事项一：详情说明',
      );
      expect(toggleChecklistLine(line), '☑  事项一：详情说明');
    });

    test('toggles ☑ to ☐ and preserves rest of characters', () {
      final line = ChecklistLine(
        isChecklist: true,
        rawLine: '☑\u3000全角空格事项',
        checked: true,
        content: '全角空格事项',
      );
      expect(toggleChecklistLine(line), '☐\u3000全角空格事项');
    });

    test('toggles single box character lines', () {
      final unchecked = ChecklistLine(isChecklist: true, rawLine: '☐', checked: false, content: '');
      expect(toggleChecklistLine(unchecked), '☑');

      final checked = ChecklistLine(isChecklist: true, rawLine: '☑', checked: true, content: '');
      expect(toggleChecklistLine(checked), '☐');
    });

    test('returns non-checklist line unchanged', () {
      final nonChecklist = ChecklistLine(
        isChecklist: false,
        rawLine: '普通文本行',
        checked: false,
        content: null,
      );
      expect(toggleChecklistLine(nonChecklist), '普通文本行');
    });
  });

  group('toggleChecklistLineAt', () {
    test('toggles checklist line at given index across multiple lines', () {
      const text = '☐ 事项一\n☐ 事项二\n☐ 事项三';
      final toggled = toggleChecklistLineAt(text, 1);
      expect(toggled, '☐ 事项一\n☑ 事项二\n☐ 事项三');

      final toggledBack = toggleChecklistLineAt(toggled, 1);
      expect(toggledBack, text);
    });

    test('preserves CRLF line endings when present', () {
      const text = '☐ 事项一\r\n☐ 事项二';
      final toggled = toggleChecklistLineAt(text, 0);
      expect(toggled, '☑ 事项一\r\n☐ 事项二');
    });

    test('returns original text unchanged when index is out of bounds', () {
      const text = '☐ 事项一\n☐ 事项二';
      expect(toggleChecklistLineAt(text, -1), text);
      expect(toggleChecklistLineAt(text, 2), text);
      expect(toggleChecklistLineAt(text, 100), text);
    });

    test('returns original text unchanged when target line is not a checklist item', () {
      const text = '标题\n☐ 事项一\n结尾备注';
      expect(toggleChecklistLineAt(text, 0), text);
      expect(toggleChecklistLineAt(text, 2), text);
    });

    test('returns original text unchanged for empty input', () {
      expect(toggleChecklistLineAt('', 0), '');
      expect(toggleChecklistLineAt('', -1), '');
    });
  });
}
