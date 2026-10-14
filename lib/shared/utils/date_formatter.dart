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

  /// Formats as yyyy/MM/dd in local time (used by the home list).
  static String formatYmd(DateTime utcTime) {
    final local = utcTime.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}/${two(local.month)}/${two(local.day)}';
  }

  static String formatCardTime(DateTime utcTime, String locale) {
    final local = utcTime.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final diffDays = today.difference(day).inDays; // 日期差，跨午夜正确；未来时间按今天处理
    final zh = locale.toLowerCase().startsWith('zh');
    if (diffDays <= 0) {
      final hm = DateFormat.Hm(locale).format(local);
      return zh ? '今天 $hm' : 'Today $hm';
    }
    if (diffDays == 1) return zh ? '昨天' : 'Yesterday';
    if (local.year == now.year) return DateFormat.MMMd(locale).format(local); // zh: 10月4日
    return DateFormat.yMMMd(locale).format(local); // 往年带年份
  }
}
