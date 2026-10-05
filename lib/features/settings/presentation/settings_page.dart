// lib/features/settings/presentation/settings_page.dart
// Settings grouped per spec §4.5: Appearance / Data / Sync / Security / About.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
        children: [
          _buildSectionHeader(context, l10n.appearance),
          ListTile(
            leading: const Icon(Icons.brightness_medium_outlined),
            title: Text(l10n.theme),
            trailing: DropdownButton<AppThemeMode>(
              value: themeMode,
              underline: const SizedBox.shrink(),
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
          _buildSectionHeader(context, l10n.data),
          _navTile(
            context,
            icon: Icons.folder_outlined,
            title: l10n.categories,
            onTap: () => context.push('/settings/categories'),
          ),
          _navTile(
            context,
            icon: Icons.label_outlined,
            title: l10n.tags,
            onTap: () => context.push('/settings/tags'),
          ),
          _navTile(
            context,
            icon: Icons.backup_outlined,
            title: l10n.backup,
            onTap: () => context.push('/settings/backup'),
          ),
          _navTile(
            context,
            icon: Icons.delete_outline,
            title: l10n.trash,
            onTap: () => context.push('/trash'),
          ),
          _buildSectionHeader(context, l10n.sync),
          _navTile(
            context,
            icon: Icons.cloud_outlined,
            title: l10n.webdavSync,
            onTap: () => context.push('/settings/webdav'),
          ),
          _buildSectionHeader(context, l10n.security),
          _navTile(
            context,
            icon: Icons.lock_outline,
            title: l10n.security,
            onTap: () => context.push('/settings/security'),
          ),
          _buildSectionHeader(context, l10n.about),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.version),
            subtitle: const Text('0.1.0 (Stage A)'),
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
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: Icon(
        Icons.chevron_right,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
