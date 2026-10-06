// lib/features/settings/presentation/backup_page.dart
// Backup & restore: JSON export/import, Markdown ZIP export, TXT export.
// Restyled with grouped cards; all business logic unchanged.

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:suicun/core/errors/app_errors.dart';
import 'package:suicun/features/backup/data/backup_providers.dart';
import 'package:suicun/features/records/presentation/records_notifier.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';

class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  bool _busy = false;

  Future<void> _runExport(
    AppLocalizations l10n,
    Future<File> Function() exportFn,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await exportFn();
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: l10n.backup,
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.exportSuccess)),
        );
      }
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.exportFailed(e.message))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runJsonImport(AppLocalizations l10n) async {
    if (_busy) return;
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = picked.isEmpty ? null : picked.first.path;
    if (path == null) return;

    final service = ref.read(backupServiceProvider);
    final file = File(path);

    int count;
    try {
      count = await service.previewJsonImport(file);
    } on AppError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.importFailed(e.message))),
      );
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.importData),
        content: Text(l10n.importPreview(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final imported = await service.importJson(file);
      ref.invalidate(recordsListProvider);
      ref.invalidate(trashListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.importSuccess(imported))),
        );
      }
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.importFailed(e.message))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runTextImport(AppLocalizations l10n) async {
    if (_busy) return;
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['md', 'markdown', 'txt'],
    );
    final path = picked.isEmpty ? null : picked.first.path;
    if (path == null) return;

    setState(() => _busy = true);
    try {
      await ref.read(backupServiceProvider).importTextFile(File(path));
      ref.invalidate(recordsListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.importSuccess(1))),
        );
      }
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.importFailed(e.message))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final service = ref.watch(backupServiceProvider);

    Widget groupTitle(String text) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(
          text,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
      );
    }

    Widget actionTile({
      required IconData icon,
      required String title,
      required VoidCallback? onTap,
    }) {
      return ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Icon(
              icon,
              size: 20,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        title: Text(
          title,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        onTap: onTap,
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.backup)),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              groupTitle(l10n.export),
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    actionTile(
                      icon: Icons.file_download_outlined,
                      title: l10n.exportJson,
                      onTap: _busy
                          ? null
                          : () => _runExport(l10n, service.exportJson),
                    ),
                    const Divider(height: 1, indent: 56, endIndent: 16),
                    actionTile(
                      icon: Icons.archive_outlined,
                      title: l10n.exportMarkdownZip,
                      onTap: _busy
                          ? null
                          : () => _runExport(l10n, service.exportMarkdownZip),
                    ),
                    const Divider(height: 1, indent: 56, endIndent: 16),
                    actionTile(
                      icon: Icons.description_outlined,
                      title: l10n.exportTxt,
                      onTap: _busy
                          ? null
                          : () => _runExport(l10n, service.exportTxt),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              groupTitle(l10n.importData),
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    actionTile(
                      icon: Icons.restore_outlined,
                      title: l10n.importJson,
                      onTap: _busy ? null : () => _runJsonImport(l10n),
                    ),
                    const Divider(height: 1, indent: 56, endIndent: 16),
                    actionTile(
                      icon: Icons.note_add_outlined,
                      title: l10n.importMarkdown,
                      onTap: _busy ? null : () => _runTextImport(l10n),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black26,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}
