import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suicun/features/records/domain/record_model.dart';
import 'package:suicun/features/records/presentation/search/pinyin_search_helper.dart';

void main() {
  group('matchesPinyinOrText', () {
    test('matches empty query to true', () {
      expect(matchesPinyinOrText(text: '身份证', query: ''), isTrue);
      expect(matchesPinyinOrText(text: '身份证', query: '   '), isTrue);
    });

    test('matches original substring directly', () {
      expect(matchesPinyinOrText(text: '我的身份证', query: '身份'), isTrue);
      expect(matchesPinyinOrText(text: 'Home Address', query: 'address'), isTrue);
      expect(matchesPinyinOrText(text: 'Home Address', query: 'ADDRESS'), isTrue);
    });

    test('matches pinyin first letter abbreviation', () {
      expect(matchesPinyinOrText(text: '身份证', query: 'sfz'), isTrue);
      expect(matchesPinyinOrText(text: '身份证', query: 'SFZ'), isTrue);
      expect(matchesPinyinOrText(text: '家庭地址', query: 'dz'), isTrue);
      expect(matchesPinyinOrText(text: '家庭地址', query: 'jtdz'), isTrue);
      expect(matchesPinyinOrText(text: '银行卡密码', query: 'yhk'), isTrue);
    });

    test('returns false when no match found', () {
      expect(matchesPinyinOrText(text: '身份证', query: 'xyz'), isFalse);
      expect(matchesPinyinOrText(text: '家庭地址', query: 'abc'), isFalse);
    });
  });

  group('matchesRecordPinyinOrText', () {
    final now = DateTime.now().toUtc();
    final sampleRecord = RecordDetail(
      record: RecordModel(
        id: 'r1',
        title: '身份证件',
        body: '姓名：张三\n证件号码：110101199001011234',
        isFavorite: false,
        createdAt: now,
        updatedAt: now,
      ),
      tags: const [],
    );

    test('matches title with pinyin or text', () {
      expect(matchesRecordPinyinOrText(sampleRecord, 'sfz'), isTrue);
      expect(matchesRecordPinyinOrText(sampleRecord, '证件'), isTrue);
    });

    test('matches body with pinyin or text', () {
      expect(matchesRecordPinyinOrText(sampleRecord, 'zs'), isTrue); // 张三 -> zs
      expect(matchesRecordPinyinOrText(sampleRecord, '110101'), isTrue);
      expect(matchesRecordPinyinOrText(sampleRecord, 'zjhm'), isTrue); // 证件号码 -> zjhm
    });

    test('returns false when neither title nor body matches', () {
      expect(matchesRecordPinyinOrText(sampleRecord, '银行密码'), isFalse);
      expect(matchesRecordPinyinOrText(sampleRecord, 'yh'), isFalse);
    });
  });

  group('findMatchRanges', () {
    test('direct substring matching finds correct ranges', () {
      final ranges = findMatchRanges(text: 'Alpha note beta note', query: 'note');
      expect(ranges, const [MatchRange(6, 10), MatchRange(16, 20)]);
    });

    test('pinyin acronym matching finds correct ranges', () {
      final ranges = findMatchRanges(text: '我的身份证号码', query: 'sfz');
      expect(ranges, const [MatchRange(2, 5)]); // "身份证"
    });

    test('case-insensitive acronym matching', () {
      final ranges = findMatchRanges(text: '家庭住址', query: 'JTZZ');
      expect(ranges, const [MatchRange(0, 4)]);
    });

    test('overlapping matches merge gracefully', () {
      final ranges = findMatchRanges(text: 'abcde', query: 'bcd');
      expect(ranges, const [MatchRange(1, 4)]);
    });
  });

  group('buildHighlightedSpans', () {
    test('returns unhighlighted span if query is empty or not matched', () {
      final spans = buildHighlightedSpans(
        text: 'Hello world',
        query: 'xyz',
        baseStyle: null,
        highlightStyle: null,
      );
      expect(spans.length, 1);
      expect(spans.first.text, 'Hello world');
    });

    test('highlights matched pinyin in Chinese text', () {
      const baseStyle = TextStyle(color: Color(0xFF000000));
      const highlightStyle = TextStyle(color: Color(0xFFFF0000));
      final spans = buildHighlightedSpans(
        text: '我的身份证件',
        query: 'sfz',
        baseStyle: baseStyle,
        highlightStyle: highlightStyle,
      );
      expect(spans.length, 3);
      expect(spans[0].text, '我的');
      expect(spans[0].style, baseStyle);
      expect(spans[1].text, '身份证');
      expect(spans[1].style, highlightStyle);
      expect(spans[2].text, '件');
      expect(spans[2].style, baseStyle);
    });
  });
}

