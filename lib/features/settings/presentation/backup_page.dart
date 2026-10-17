// lib/features/settings/presentation/backup_page.dart
// Backup & restore: full backup (encrypted export + auto-detect restore),
// other exports (plaintext JSON/Markdown ZIP/TXT with warning), text import.

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  Future<bool> _confirmPlaintextExport(AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.plaintextExportConfirmTitle),
        content: Text(l10n.plaintextExportConfirm),
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
    return confirmed == true;
  }

  Future<void> _runPlaintextExport(
    AppLocalizations l10n,
    Future<File> Function() exportFn,
  ) async {
    if (_busy) return;
    final ok = await _confirmPlaintextExport(l10n);
    if (!ok || !mounted) return;
    await _runExport(l10n, exportFn);
  }

  /// Password dialog for encrypted backup. Returns the password or null.
  Future<String?> _askBackupPassword(
      AppLocalizations l10n, bool confirm) async {
    final c1 = TextEditingController();
    final c2 = TextEditingController();
    String? error;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(l10n.encryptedBackup),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.backupPasswordHint,
                  style: Theme.of(ctx).textTheme.bodySmall),
              const SizedBox(height: 12),
              TextField(
                controller: c1,
                obscureText: true,
                decoration:
                    InputDecoration(labelText: l10n.backupPassword),
              ),
              if (confirm)
                TextField(
                  controller: c2,
                  obscureText: true,
                  decoration:
                      InputDecoration(labelText: l10n.confirmPassword),
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(error!,
                      style: TextStyle(
                          color: Theme.of(ctx).colorScheme.error)),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () {
                if (confirm && c1.text != c2.text) {
                  setState(() => error = l10n.passwordMismatch);
                  return;
                }
                if (c1.text.length < 8) {
                  setState(() => error = l10n.passwordTooShort);
                  return;
                }
                Navigator.of(ctx).pop(c1.text);
              },
              child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
            ),
          ],
        ),
      ),
    );
  }

  /// §2.7: milliseconds since epoch of the last successful encrypted backup.
  Future<int?> _getLastBackupAt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('last_encrypted_backup_at');
    } catch (_) {
      return null;
    }
  }

  String _formatBackupTime(BuildContext context, int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    return DateFormat.yMMMd(Localizations.localeOf(context).toString())
        .add_Hm()
        .format(dt);
  }

  Future<void> _exportEncrypted(AppLocalizations l10n) async {
    if (_busy) return;
    final password = await _askBackupPassword(l10n, true);
    if (password == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final file =
          await ref.read(backupServiceProvider).exportEncryptedBackup(password);
      if (!mounted) return;
      // §2.7: record successful encrypted backup time.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('last_encrypted_backup_at',
            DateTime.now().millisecondsSinceEpoch);
      } catch (_) {}
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], subject: l10n.encryptedBackup),
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

  Future<void> _runRestoreBackup(AppLocalizations l10n) async {
    if (_busy) return;
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = picked.isEmpty ? null : picked.first.path;
    if (path == null || !mounted) return;

    final file = File(path);
    final service = ref.read(backupServiceProvider);

    final String content;
    try {
      content = await file.readAsString();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.importFailed(e.toString()))),
      );
      return;
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(content);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.importFailed('Invalid JSON file'))),
      );
      return;
    }

    final isEncrypted = decoded is Map<String, dynamic> &&
        decoded['format'] == 'suicun-encrypted-backup';

    if (isEncrypted) {
      final password = await _askBackupPassword(l10n, false);
      if (password == null || !mounted) return;

      int count;
      try {
        count = await service.previewEncryptedImport(file, password);
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
          title: Text(l10n.importEncryptedBackup),
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
      if (confirmed != true || !mounted) return;

      setState(() => _busy = true);
      try {
        final imported = await service.importEncryptedBackup(file, password);
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
    } else {
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
      if (confirmed != true || !mounted) return;

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
      String? subtitle,
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
            color: theme.colorScheme.onSurface,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            : null,
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
              groupTitle(l10n.fullBackup),
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    actionTile(
                      icon: Icons.lock_outline,
                      title: l10n.exportEncryptedBackupRecommended,
                      subtitle: l10n.exportEncryptedBackupSubtitle,
                      onTap: _busy ? null : () => _exportEncrypted(l10n),
                    ),
                    const Divider(height: 1, indent: 56, endIndent: 16),
                    actionTile(
                      icon: Icons.restore_outlined,
                      title: l10n.restoreBackup,
                      subtitle: l10n.restoreBackupSubtitle,
                      onTap: _busy ? null : () => _runRestoreBackup(l10n),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // §2.7: last encrypted backup status.
              FutureBuilder<int?>(
                future: _getLastBackupAt(),
                builder: (context, snapshot) {
                  final ts = snapshot.data;
                  final text = ts == null
                      ? l10n.notBackedUpYet
                      : l10n.lastBackup(_formatBackupTime(context, ts));
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      text,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: ts == null
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              groupTitle(l10n.exportOtherFormats),
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    actionTile(
                      icon: Icons.file_download_outlined,
                      title: l10n.exportJsonUnencrypted,
                      subtitle: l10n.exportJsonSubtitle,
                      onTap: _busy
                          ? null
                          : () => _runPlaintextExport(l10n, service.exportJson),
                    ),
                    const Divider(height: 1, indent: 56, endIndent: 16),
                    actionTile(
                      icon: Icons.archive_outlined,
                      title: l10n.exportMarkdownZip,
                      onTap: _busy
                          ? null
                          : () => _runPlaintextExport(
                              l10n, service.exportMarkdownZip),
                    ),
                    const Divider(height: 1, indent: 56, endIndent: 16),
                    actionTile(
                      icon: Icons.description_outlined,
                      title: l10n.exportTxt,
                      onTap: _busy
                          ? null
                          : () => _runPlaintextExport(l10n, service.exportTxt),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              groupTitle(l10n.importSectionTitle),
              Card(
                margin: EdgeInsets.zero,
                child: actionTile(
                  icon: Icons.note_add_outlined,
                  title: l10n.importMarkdownOrTxt,
                  onTap: _busy ? null : () => _runTextImport(l10n),
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
