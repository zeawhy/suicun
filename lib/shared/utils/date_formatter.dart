// lib/shared/utils/date_formatter.dart
// Utility for formatting DateTime values relative to the current time.

import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static String formatRelative(DateTime utcTime, String locale) {
    final local = utcTime.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inDays == 0) {
      return DateFormat.Hm(locale).format(local);
    } else if (diff.inDays < 7) {
      return DateFormat.E(locale).format(local);
    } else if (local.year == now.year) {
      return DateFormat.MMMd(locale).format(local);
    } else {
      return DateFormat.yMMMd(locale).format(local);
    }
  }

  static String formatFull(DateTime utcTime, String locale) {
    final local = utcTime.toLocal();
    return DateFormat.yMMMd(locale).add_Hm().format(local);
  }
}
