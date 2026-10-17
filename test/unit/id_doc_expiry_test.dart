// test/unit/id_doc_expiry_test.dart
// Unit tests for ID document expiry status (Round 4 §5, §9).

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:suicun/features/records/domain/id_doc_data.dart';
import 'package:suicun/features/records/domain/id_doc_expiry.dart';

void main() {
  // Initialize locale data for DateFormat.
  setUpAll(() async {
    await initializeDateFormatting('zh', null);
    await initializeDateFormatting('en', null);
  });

  // Fixed reference date for deterministic tests.
  final now = DateTime(2026, 10, 17);

  IdDocData docWith({DateTime? expiryDate, bool noExpiry = false}) {
    return IdDocData(
      type: 'passport',
      expiryDate: expiryDate,
      noExpiry: noExpiry,
    );
  }

  group('expiryStatusOf', () {
    test('expired: expiry date in the past', () {
      final doc = docWith(expiryDate: DateTime(2026, 10, 16));
      expect(expiryStatusOf(doc, now: now), IdDocExpiryStatus.expired);
    });

    test('expired: expiry date long ago', () {
      final doc = docWith(expiryDate: DateTime(2020, 1, 1));
      expect(expiryStatusOf(doc, now: now), IdDocExpiryStatus.expired);
    });

    test('expiringSoon: 89 days in the future', () {
      final doc = docWith(expiryDate: now.add(const Duration(days: 89)));
      expect(expiryStatusOf(doc, now: now), IdDocExpiryStatus.expiringSoon);
    });

    test('expiringSoon: exactly 90 days (boundary inclusive)', () {
      final doc = docWith(expiryDate: now.add(const Duration(days: 90)));
      expect(expiryStatusOf(doc, now: now), IdDocExpiryStatus.expiringSoon);
    });

    test('expiringSoon: today (0 days)', () {
      final doc = docWith(expiryDate: now);
      expect(expiryStatusOf(doc, now: now), IdDocExpiryStatus.expiringSoon);
    });

    test('valid: 91 days in the future', () {
      final doc = docWith(expiryDate: now.add(const Duration(days: 91)));
      expect(expiryStatusOf(doc, now: now), IdDocExpiryStatus.valid);
    });

    test('valid: far future', () {
      final doc = docWith(expiryDate: DateTime(2030, 1, 1));
      expect(expiryStatusOf(doc, now: now), IdDocExpiryStatus.valid);
    });

    test('valid: null expiry date (no date to warn about)', () {
      final doc = docWith(expiryDate: null);
      expect(expiryStatusOf(doc, now: now), IdDocExpiryStatus.valid);
    });

    test('noExpiry: flag set, even with a past date', () {
      final doc = docWith(
        expiryDate: DateTime(2020, 1, 1),
        noExpiry: true,
      );
      expect(expiryStatusOf(doc, now: now), IdDocExpiryStatus.noExpiry);
    });

    test('noExpiry: flag set, no date', () {
      final doc = docWith(noExpiry: true);
      expect(expiryStatusOf(doc, now: now), IdDocExpiryStatus.noExpiry);
    });
  });

  group('formatIdDocDate', () {
    test('Chinese locale', () {
      final date = DateTime(2030, 1, 1);
      final formatted = formatIdDocDate(date, 'zh');
      expect(formatted, contains('2030'));
      expect(formatted, contains('1月1日'));
    });

    test('English locale', () {
      final date = DateTime(2030, 1, 1);
      final formatted = formatIdDocDate(date, 'en');
      expect(formatted, 'Jan 1, 2030');
    });
  });
}
