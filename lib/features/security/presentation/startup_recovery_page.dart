// lib/features/security/presentation/startup_recovery_page.dart
// Recoverable startup failure page (§2.6).
//
// Replaces the old dead-end `_StartupFailureApp` in main.dart. Uses
// AppLocalizations (no hardcoded bilingual text). Technical error details
// are collapsed and sanitized (no key material).

import 'package:flutter/material.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';

/// Root app shown when startup fails. Wraps [StartupRecoveryPage] with
/// localization support.
class StartupRecoveryApp extends StatelessWidget {
  const StartupRecoveryApp({
    super.key,
    required this.dataUnreadable,
    required this.technicalDetails,
    required this.onRetry,
    required this.onStartOver,
  });

  /// True for "data cannot be read" (case 1), false for unknown errors (case 2).
  final bool dataUnreadable;

  /// Raw technical error text (sanitized before display).
  final String technicalDetails;

  /// Re-runs the startup flow.
  final VoidCallback onRetry;

  /// Performs the reset + restart flow (case 1 only).
  final VoidCallback onStartOver;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: StartupRecoveryPage(
        dataUnreadable: dataUnreadable,
        technicalDetails: technicalDetails,
        onRetry: onRetry,
        onStartOver: onStartOver,
      ),
    );
  }
}

class StartupRecoveryPage extends StatelessWidget {
  const StartupRecoveryPage({
    super.key,
    required this.dataUnreadable,
    required this.technicalDetails,
    required this.onRetry,
    required this.onStartOver,
  });

  final bool dataUnreadable;
  final String technicalDetails;
  final VoidCallback onRetry;
  final VoidCallback onStartOver;

  /// Removes anything that could be key material from error text.
  /// The service never logs keys, but this is defense in depth.
  static String sanitizeDetails(String raw) {
    var out = raw.replaceAll(
      RegExp(r'[A-Za-z0-9+/=]{32,}'),
      '[redacted]',
    );
    out = out.replaceAll(RegExp(r"x'[0-9a-fA-F]{32,}'"), '[redacted]');
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sanitized = sanitizeDetails(technicalDetails);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              Icon(
                dataUnreadable ? Icons.lock_outline : Icons.error_outline,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                dataUnreadable ? l10n.cantReadData : l10n.startupFailed,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              if (dataUnreadable)
                Text(
                  l10n.cantReadDataDesc,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 24),
              if (dataUnreadable) ...[
                FilledButton(
                  onPressed: () => _confirmStartOver(context, l10n),
                  child: Text(l10n.startOver),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: onRetry,
                  child: Text(l10n.retry),
                ),
              ] else
                FilledButton(
                  onPressed: onRetry,
                  child: Text(l10n.retry),
                ),
              const SizedBox(height: 24),
              ExpansionTile(
                title: Text(
                  l10n.technicalDetails,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      sanitized,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmStartOver(
      BuildContext context, AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.startOver),
        content: Text(l10n.startOverConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l10n.startOver),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      onStartOver();
    }
  }
}
