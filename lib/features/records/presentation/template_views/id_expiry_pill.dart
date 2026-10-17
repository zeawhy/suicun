// lib/features/records/presentation/template_views/id_expiry_pill.dart
// Small pill label showing an ID document's expiry status (Round 4 §5).
//
// - Expired → red, uses theme error color.
// - Expiring soon (≤90 days) → orange, uses theme warning-ish color.
// - No expiry → neutral, "long-term valid".
// Colors are chosen to stay legible in both light and dark mode.

import 'package:flutter/material.dart';
import 'package:suicun/features/records/domain/id_doc_expiry.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';

/// A small pill-shaped label for [IdDocExpiryStatus].
///
/// Returns an empty [SizedBox] for [IdDocExpiryStatus.valid] (no label needed).
class IdExpiryPill extends StatelessWidget {
  const IdExpiryPill({super.key, required this.status});

  final IdDocExpiryStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    String text;
    Color bg;
    Color fg;

    switch (status) {
      case IdDocExpiryStatus.expired:
        text = l10n.idExpired;
        bg = isDark
            ? colorScheme.error.withValues(alpha: 0.25)
            : colorScheme.error.withValues(alpha: 0.12);
        fg = isDark
            ? Color.lerp(colorScheme.error, Colors.white, 0.4)!
            : colorScheme.error;
        break;
      case IdDocExpiryStatus.expiringSoon:
        text = l10n.idExpiringSoon;
        // Orange/amber: use a fixed hue that works in both modes.
        bg = isDark
            ? const Color(0xFF8A5A00).withValues(alpha: 0.35)
            : const Color(0xFFFF8F00).withValues(alpha: 0.15);
        fg = isDark
            ? const Color(0xFFFFB74D)
            : const Color(0xFFE65100);
        break;
      case IdDocExpiryStatus.noExpiry:
        text = l10n.idNoExpiry;
        bg = isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.06);
        fg = isDark
            ? Colors.white.withValues(alpha: 0.85)
            : Colors.black.withValues(alpha: 0.6);
        break;
      case IdDocExpiryStatus.valid:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
