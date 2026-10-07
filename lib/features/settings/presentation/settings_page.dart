// lib/features/settings/presentation/settings_page.dart
// Settings grouped per spec §4.5: Appearance / Data / Sync / Security / About.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:suicun/features/sync/sync_contract.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';
import 'package:suicun/shared/theme/theme_providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _buildSectionHeader(context, l10n.appearance),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.brightness_medium_outlined),
              title: Text(l10n.theme),
              trailing: DropdownButton<AppThemeMode>(
                value: themeMode,
                underline: const SizedBox.shrink(),
                borderRadius: BorderRadius.circular(12),
                onChanged: (mode) {
                  if (mode != null) {
                    ref.read(themeModeProvider.notifier).setMode(mode);
                  }
                },
                items: [
                  DropdownMenuItem(
                      value: AppThemeMode.system,
                      child: Text(l10n.themeSystem)),
                  DropdownMenuItem(
                      value: AppThemeMode.light, child: Text(l10n.themeLight)),
                  DropdownMenuItem(
                      value: AppThemeMode.dark, child: Text(l10n.themeDark)),
                ],
              ),
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
                  onTap: () => context.push('/settings/categories'),
                ),
                const Divider(height: 1, indent: 56, endIndent: 16),
                _navTile(
                  context,
                  icon: Icons.label_outlined,
                  title: l10n.tags,
                  onTap: () => context.push('/settings/tags'),
                ),
                const Divider(height: 1, indent: 56, endIndent: 16),
                _navTile(
                  context,
                  icon: Icons.backup_outlined,
                  title: l10n.backup,
                  onTap: () => context.push('/settings/backup'),
                ),
                const Divider(height: 1, indent: 56, endIndent: 16),
                _navTile(
                  context,
                  icon: Icons.delete_outline,
                  title: l10n.trash,
                  onTap: () => context.push('/trash'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionHeader(context, l10n.sync),
          Card(
            margin: EdgeInsets.zero,
            child: _navTile(
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
              onTap: () => context.push('/settings/webdav'),
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionHeader(context, l10n.security),
          Card(
            margin: EdgeInsets.zero,
            child: _navTile(
              context,
              icon: Icons.lock_outline,
              title: l10n.security,
              onTap: () => context.push('/settings/security'),
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionHeader(context, l10n.about),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(l10n.version),
              subtitle: const Text('0.1.0+1'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _navTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? trailingText,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
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

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
      ),
    );
  }
}
