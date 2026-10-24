// lib/features/settings/presentation/settings_page.dart
// Settings grouped per spec §4.5: Appearance / Data / Sync / Security / About.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:suicun/core/database/providers.dart';
import 'package:suicun/features/backup/data/backup_providers.dart';
import 'package:suicun/features/records/data/quick_access_storage.dart';
import 'package:suicun/features/records/presentation/template_views/id_photo_storage.dart';
import 'package:suicun/features/security/data/security_providers.dart';
import 'package:suicun/features/settings/data/privacy_prefs.dart';
import 'package:suicun/features/sync/sync_contract.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';
import 'package:suicun/shared/theme/theme_providers.dart';
import 'package:suicun/shared/widgets/single_choice_sheet.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: const SettingsView(),
    );
  }
}

class SettingsView extends ConsumerWidget {
  const SettingsView({
    super.key,
    this.onNavigate,
    this.header,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  /// Optional callback invoked when a navigation item is tapped.
  /// Typically used by a drawer to close itself before navigation.
  final VoidCallback? onNavigate;

  /// Optional header widget, displayed above settings sections.
  final Widget? header;

  /// Padding for the settings list view.
  final EdgeInsetsGeometry padding;

  void _push(BuildContext context, WidgetRef ref, String location) {
    onNavigate?.call();
    context.push(location).then((_) {
      if (context.mounted) {
        ref.invalidate(appLockEnabledProvider);
        ref.invalidate(lastEncryptedBackupAtProvider);
      }
    });
  }

  Future<void> _showThemeSheet(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    AppThemeMode currentMode,
  ) async {
    final selected = await showSingleChoiceSheet<AppThemeMode>(
      context: context,
      title: l10n.theme,
      selectedValue: currentMode,
      options: [
        SingleChoiceOption(value: AppThemeMode.system, label: l10n.themeSystem),
        SingleChoiceOption(value: AppThemeMode.light, label: l10n.themeLight),
        SingleChoiceOption(value: AppThemeMode.dark, label: l10n.themeDark),
      ],
    );
    if (selected != null) {
      ref.read(themeModeProvider.notifier).setMode(selected);
    }
  }

  Future<void> _handleClearAllData(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.clearAllDataWarningTitle),
        content: Text(l10n.clearAllDataWarningContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.continueAction),
          ),
        ],
      ),
    );
    if (proceed != true || !context.mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.clearAllDataConfirmTitle),
        content: Text(l10n.clearAllDataConfirmContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.confirmClearAllData),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    final db = ref.read(appDatabaseProvider);
    await db.transaction(() async {
      for (final table in db.allTables) {
        await db.delete(table).go();
      }
    });
    // Clear onboarding/feature prefs before the best-effort filesystem cleanup
    // below: preference state must not depend on IO completing.
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.remove(PrivacyPrefsKeys.onboardingClipboardAsked);
    await prefs.remove(PrivacyPrefsKeys.presentAutoBrightness);
    await prefs.remove(PrivacyPrefsKeys.clipboardSniffEnabled);
    await prefs.remove('clipboard_last_handled_hash');
    ref.invalidate(clipboardSniffEnabledProvider);
    ref.invalidate(presentAutoBrightnessProvider);

    await deleteAllIdPhotos();
    await ref.read(quickAccessIdsProvider.notifier).clearAll();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.clearAllDataSuccess)),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final themeMode = ref.watch(themeModeProvider);

    final themeText = switch (themeMode) {
      AppThemeMode.system => l10n.themeSystem,
      AppThemeMode.light => l10n.themeLight,
      AppThemeMode.dark => l10n.themeDark,
    };

    return ListView(
      padding: padding,
      children: [
        if (header != null) ...[
          header!,
          const SizedBox(height: 8),
        ],
        _buildSectionHeader(context, l10n.appearance),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              _navTile(
                context,
                icon: Icons.brightness_medium_outlined,
                title: l10n.theme,
                trailingText: themeText,
                onTap: () => _showThemeSheet(context, ref, l10n, themeMode),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionHeader(context, l10n.settingsGroupIdDocuments),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.light_mode_outlined),
                title: Text(l10n.presentAutoBrightnessTitle),
                subtitle: Text(
                  l10n.presentAutoBrightnessSubtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                value: ref.watch(presentAutoBrightnessProvider).value ?? false,
                onChanged: (val) {
                  ref
                      .read(presentAutoBrightnessProvider.notifier)
                      .setEnabled(val);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionHeader(context, l10n.data),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              _navTile(
                context,
                icon: Icons.folder_outlined,
                title: l10n.categories,
                onTap: () => _push(context, ref, '/settings/categories'),
              ),
              const Divider(height: 1, indent: 56, endIndent: 16),
              _navTile(
                context,
                icon: Icons.label_outlined,
                title: l10n.tags,
                onTap: () => _push(context, ref, '/settings/tags'),
              ),
              const Divider(height: 1, indent: 56, endIndent: 16),
              _navTile(
                context,
                icon: Icons.delete_outline,
                title: l10n.trash,
                onTap: () => _push(context, ref, '/trash'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionHeader(context, l10n.backupAndSync),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              () {
                final syncOverview = ref.watch(syncOverviewProvider).value;
                final lastBackupAsync = ref.watch(lastEncryptedBackupAtProvider);
                final String backupSubtitle;
                if (syncOverview?.enabled == true) {
                  backupSubtitle = l10n.backupStatusAutoOn;
                } else {
                  final lastBackupAt = lastBackupAsync.value;
                  if (lastBackupAt == null) {
                    backupSubtitle = l10n.backupStatusNever;
                  } else {
                    final diff = DateTime.now().difference(
                      DateTime.fromMillisecondsSinceEpoch(lastBackupAt),
                    );
                    final days = diff.inDays < 0 ? 0 : diff.inDays;
                    backupSubtitle = l10n.backupStatusDaysAgo(days);
                  }
                }
                return _navTile(
                  context,
                  icon: Icons.backup_outlined,
                  title: l10n.backupAndExport,
                  subtitle: backupSubtitle,
                  onTap: () => _push(context, ref, '/settings/backup'),
                );
              }(),
              const Divider(height: 1, indent: 56, endIndent: 16),
              _navTile(
                context,
                icon: Icons.cloud_outlined,
                title: l10n.webdavSync,
                trailingText: ref.watch(syncOverviewProvider).when(
                      data: (overview) => overview.enabled
                          ? l10n.syncStatusEnabled
                          : l10n.syncStatusDisabled,
                      loading: () => null,
                      error: (_, __) => null,
                    ),
                onTap: () => _push(context, ref, '/settings/webdav'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionHeader(context, l10n.securityAndPrivacy),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              _navTile(
                context,
                icon: Icons.lock_outline,
                title: l10n.appLock,
                trailingText: ref.watch(appLockEnabledProvider).when(
                      data: (enabled) => enabled
                          ? l10n.appLockStatusEnabled
                          : l10n.appLockStatusDisabled,
                      loading: () => null,
                      error: (_, __) => null,
                    ),
                onTap: () => _push(context, ref, '/settings/security'),
              ),
              const Divider(height: 1, indent: 56, endIndent: 16),
              SwitchListTile(
                secondary: const Icon(Icons.content_paste_search_outlined),
                title: Text(l10n.clipboardSniffTitle),
                subtitle: Text(
                  l10n.clipboardSniffSubtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                value: ref.watch(clipboardSniffEnabledProvider).value ?? false,
                onChanged: (val) {
                  ref
                      .read(clipboardSniffEnabledProvider.notifier)
                      .setEnabled(val);
                },
              ),
              const Divider(height: 1, indent: 56, endIndent: 16),
              SwitchListTile(
                secondary: const Icon(Icons.screenshot_monitor_outlined),
                title: Text(l10n.allowIdScreenshots),
                value: ref.watch(allowIdScreenshotsProvider).value ?? false,
                onChanged: (val) {
                  ref.read(allowIdScreenshotsProvider.notifier).setEnabled(val);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionHeader(context, l10n.about),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              _navTile(
                context,
                icon: Icons.privacy_tip_outlined,
                title: l10n.privacyPolicy,
                onTap: () => _push(context, ref, '/settings/privacy'),
              ),
              const Divider(height: 1, indent: 56, endIndent: 16),
              _navTile(
                context,
                icon: Icons.bug_report_outlined,
                title: l10n.reportIssue,
                onTap: () async {
                  final uri = Uri.parse('https://github.com/zeawhy/suicun/issues');
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
              ),
              const Divider(height: 1, indent: 56, endIndent: 16),
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final versionText =
                      snapshot.hasData ? snapshot.data!.version : '...';
                  final fullVersion = snapshot.hasData
                      ? (snapshot.data!.buildNumber.isNotEmpty
                          ? '${snapshot.data!.version}+${snapshot.data!.buildNumber}'
                          : snapshot.data!.version)
                      : null;
                  return ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(l10n.version),
                    subtitle: Text(versionText),
                    onLongPress: fullVersion != null
                        ? () async {
                            await Clipboard.setData(
                              ClipboardData(text: fullVersion),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(l10n.copied)),
                              );
                            }
                          }
                        : null,
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionHeader(
          context,
          l10n.dangerousOperations,
          color: Theme.of(context).colorScheme.error,
        ),
        Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: Icon(
              Icons.delete_forever_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              l10n.clearAllData,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: Theme.of(context)
                  .colorScheme
                  .error
                  .withValues(alpha: 0.7),
            ),
            onTap: () => _handleClearAllData(context, ref, l10n),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _navTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    String? trailingText,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null) ...[
            Text(
              trailingText,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(width: 4),
          ],
          Icon(
            Icons.chevron_right,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: color ?? Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
      ),
    );
  }
}
