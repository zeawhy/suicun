// lib/features/records/presentation/template_views/updated_at_text.dart
// Formatted "Updated at" relative time widget for template reading views.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';

class UpdatedAtText extends StatelessWidget {
  const UpdatedAtText({
    super.key,
    required this.dateTime,
  });

  final DateTime dateTime;

  static String format(DateTime dateTime, BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final isZh = locale.toLowerCase().startsWith('zh');

    final local = dateTime.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final diffDays = today.difference(day).inDays;

    final hm = DateFormat.Hm(locale).format(local);

    String timeStr;
    if (diffDays <= 0) {
      timeStr = '${l10n.today} $hm';
    } else if (diffDays == 1) {
      timeStr = '${l10n.yesterday} $hm';
    } else if (local.year == now.year) {
      if (isZh) {
        timeStr = '${local.month}月${local.day}日 $hm';
      } else {
        final mmmd = DateFormat.MMMd(locale).format(local);
        timeStr = '$mmmd, $hm';
      }
    } else {
      if (isZh) {
        timeStr = '${local.year}年${local.month}月${local.day}日';
      } else {
        timeStr = DateFormat('yyyy-MM-dd HH:mm').format(local);
      }
    }

    return l10n.updatedAt(timeStr);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Center(
        child: Text(
          format(dateTime, context),
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
}
