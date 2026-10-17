// lib/shared/widgets/single_choice_sheet.dart

import 'package:flutter/material.dart';

class SingleChoiceOption<T> {
  const SingleChoiceOption({
    required this.value,
    required this.label,
    this.subtitle,
  });

  final T value;
  final String label;
  final String? subtitle;
}

/// Shows a modal bottom sheet displaying a single-choice list of [options].
///
/// Follows SuiVault bottom sheet styling (rounded top 24dp, title in 18sp bold).
/// Selected option displays a checkmark trailing icon.
Future<T?> showSingleChoiceSheet<T>({
  required BuildContext context,
  required String title,
  required List<SingleChoiceOption<T>> options,
  required T selectedValue,
}) {
  return showModalBottomSheet<T>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final colorScheme = theme.colorScheme;

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              for (final option in options)
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
                  title: Text(
                    option.label,
                    style: TextStyle(
                      fontWeight: option.value == selectedValue
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  subtitle: option.subtitle != null
                      ? Text(option.subtitle!)
                      : null,
                  trailing: option.value == selectedValue
                      ? Icon(
                          Icons.check,
                          color: colorScheme.primary,
                        )
                      : null,
                  onTap: () => Navigator.of(ctx).pop(option.value),
                ),
            ],
          ),
        ),
      );
    },
  );
}
