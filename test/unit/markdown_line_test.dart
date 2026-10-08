import 'package:flutter_test/flutter_test.dart';
import 'package:suicun/features/records/presentation/markdown_line.dart';

void main() {
  group('parseMarkdownLine', () {
    test('parses level-1 heading', () {
      final line = parseMarkdownLine('# Title');
      expect(line.isHeading, isTrue);
      expect(line.headingLevel, 1);
      expect(line.isBullet, isFalse);
      expect(line.content, 'Title');
    });

    test('parses level-2 and level-3 headings', () {
      expect(parseMarkdownLine('## Sub').headingLevel, 2);
      expect(parseMarkdownLine('### Deep').headingLevel, 3);
      expect(parseMarkdownLine('### Deep').content, 'Deep');
    });

    test('hash without trailing space is not a heading', () {
      final line = parseMarkdownLine('#Title');
      expect(line.isHeading, isFalse);
      expect(line.isBullet, isFalse);
      expect(line.content, isNull);
    });

    test('parses bullet items', () {
      final line = parseMarkdownLine('- item one');
      expect(line.isBullet, isTrue);
      expect(line.isHeading, isFalse);
      expect(line.content, 'item one');
    });

    test('dash without trailing space is not a bullet', () {
      final line = parseMarkdownLine('-5 apples');
      expect(line.isBullet, isFalse);
      expect(line.content, isNull);
    });

    test('plain line is neither heading nor bullet', () {
      final line = parseMarkdownLine('just some text');
      expect(line.isHeading, isFalse);
      expect(line.isBullet, isFalse);
      expect(line.rawLine, 'just some text');
    });

    test('heading consumes all whitespace after the marker', () {
      final line = parseMarkdownLine('#  spaced  out  ');
      expect(line.isHeading, isTrue);
      expect(line.content, 'spaced  out  ');
    });
  });

  group('parseBoldSegments', () {
    test('splits plain and bold parts', () {
      final segs = parseBoldSegments('a **b** c');
      expect(segs, [
        const InlineSegment(text: 'a ', bold: false),
        const InlineSegment(text: 'b', bold: true),
        const InlineSegment(text: ' c', bold: false),
      ]);
    });

    test('whole string bold', () {
      final segs = parseBoldSegments('**all**');
      expect(segs, [const InlineSegment(text: 'all', bold: true)]);
    });

    test('multiple bold parts', () {
      final segs = parseBoldSegments('**x** and **y**');
      expect(segs.map((s) => s.bold), [true, false, true]);
    });

    test('unclosed markers stay plain', () {
      final segs = parseBoldSegments('a **b');
      expect(segs.length, 1);
      expect(segs.first.bold, isFalse);
      expect(segs.first.text, 'a **b');
    });

    test('empty marker pair stays plain', () {
      final segs = parseBoldSegments('****');
      expect(segs.length, 1);
      expect(segs.first.bold, isFalse);
    });

    test('empty string yields no segments', () {
      expect(parseBoldSegments(''), isEmpty);
    });
  });

  group('toggleCheckboxAt', () {
    test('inserts marker at line start', () {
      final r = toggleCheckboxAt('hello\nworld', 7);
      expect(r.text, 'hello\n☐ world');
      expect(r.cursorOffset, 9);
    });

    test('removes existing marker', () {
      final r = toggleCheckboxAt('☐ task', 4);
      expect(r.text, 'task');
      expect(r.cursorOffset, 2);
    });

    test('removes checked marker too', () {
      final r = toggleCheckboxAt('☑ done', 3);
      expect(r.text, 'done');
    });

    test('works on first line', () {
      final r = toggleCheckboxAt('abc', 1);
      expect(r.text, '☐ abc');
    });
  });

  group('toggleHeadingAt', () {
    test('inserts heading marker', () {
      final r = toggleHeadingAt('Title', 2);
      expect(r.text, '# Title');
      expect(r.cursorOffset, 4);
    });

    test('removes existing heading marker', () {
      final r = toggleHeadingAt('## Sub', 4);
      expect(r.text, 'Sub');
      expect(r.cursorOffset, 1);
    });

    test('operates on the cursor line only', () {
      final r = toggleHeadingAt('a\nb', 2);
      expect(r.text, 'a\n# b');
    });
  });

  group('toggleBulletAt', () {
    test('inserts bullet marker', () {
      final r = toggleBulletAt('item', 2);
      expect(r.text, '- item');
      expect(r.cursorOffset, 4);
    });

    test('removes existing bullet marker', () {
      final r = toggleBulletAt('- item', 3);
      expect(r.text, 'item');
      expect(r.cursorOffset, 1);
    });

    test('negative numbers are untouched on insert', () {
      final r = toggleBulletAt('-5', 1);
      expect(r.text, '- -5');
    });
  });

  group('applyBold', () {
    test('wraps selection', () {
      final r = applyBold('hello world', 6, 11);
      expect(r.text, 'hello **world**');
      expect(r.cursorOffset, 15);
    });

    test('inserts markers with cursor in middle when no selection', () {
      final r = applyBold('hello', 5, 5);
      expect(r.text, 'hello****');
      expect(r.cursorOffset, 7);
    });

    test('handles reversed selection', () {
      final r = applyBold('hello world', 11, 6);
      expect(r.text, 'hello **world**');
    });

    test('clamps out-of-range offsets', () {
      final r = applyBold('hi', 0, 99);
      expect(r.text, '**hi**');
    });
  });
}
