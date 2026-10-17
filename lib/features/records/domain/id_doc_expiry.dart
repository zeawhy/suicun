// lib/features/records/domain/id_doc_expiry.dart
// Expiry status logic for ID documents (Round 4 §5).
//
// Pure functions, no UI. The [IdDocExpiryStatus] is computed from the
// document's expiry date; the pill widget lives in the presentation layer.

import 'package:intl/intl.dart';
import 'package:suicun/features/records/domain/id_doc_data.dart';

/// Expiry status of an ID document.
enum IdDocExpiryStatus {
  /// The expiry date is in the past.
  expired,

  /// Expires within 90 days (including today).
  expiringSoon,

  /// Has an expiry date more than 90 days in the future.
  valid,

  /// Marked as long-term / no expiry.
  noExpiry,
}

/// Computes the expiry status for an ID document.
///
/// Rules (spec §5):
/// - [IdDocData.noExpiry] == true → [IdDocExpiryStatus.noExpiry].
/// - [IdDocData.expiryDate] == null → [IdDocExpiryStatus.valid]
///   (no date to warn about).
/// - Expiry date before today → [IdDocExpiryStatus.expired].
/// - Expiry within 90 days (inclusive) → [IdDocExpiryStatus.expiringSoon].
/// - Otherwise → [IdDocExpiryStatus.valid].
///
/// The [now] parameter is for testing; defaults to [DateTime.now].
IdDocExpiryStatus expiryStatusOf(
  IdDocData doc, {
  DateTime? now,
}) {
  if (doc.noExpiry) return IdDocExpiryStatus.noExpiry;
  final expiry = doc.expiryDate;
  if (expiry == null) return IdDocExpiryStatus.valid;

  final today = now ?? DateTime.now();
  // Compare by date only, ignoring time-of-day.
  final todayDate = DateTime(today.year, today.month, today.day);
  final expiryDate = DateTime(expiry.year, expiry.month, expiry.day);

  if (expiryDate.isBefore(todayDate)) {
    return IdDocExpiryStatus.expired;
  }
  final daysUntil = expiryDate.difference(todayDate).inDays;
  if (daysUntil <= 90) {
    return IdDocExpiryStatus.expiringSoon;
  }
  return IdDocExpiryStatus.valid;
}

/// Formats a date with [DateFormat.yMMMd] for the given locale.
///
/// Chinese: 「2030年1月1日」; English: 「Jan 1, 2030」.
/// Never hand-write date formats (spec §5).
String formatIdDocDate(DateTime date, String locale) {
  return DateFormat.yMMMd(locale).format(date);
}
