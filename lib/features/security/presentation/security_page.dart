// lib/features/security/presentation/security_page.dart
// Stage B: security settings (app lock + encrypted backup), spec §4.5/§9.

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:suicun/core/errors/app_errors.dart';
import 'package:suicun/features/backup/data/backup_providers.dart';
import 'package:suicun/features/security/data/app_lock_service.dart';
import 'package:suicun/features/security/data/security_providers.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';

class SecurityPage extends ConsumerStatefulWidget {
  const SecurityPage({super.key});

  @override
  ConsumerState<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends ConsumerState<SecurityPage> {
  bool _loading = true;
  bool _enabled = false;
  bool _hasPin = false;
  bool _biometric = false;
  bool _deviceSupportsAuth = false;
  LockTimeout _timeout = LockTimeout.oneMinute;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final service = ref.read(appLockServiceProvider);
    final results = await Future.wait([
      service.isEnabled(),
      service.hasPin(),
      service.isBiometricEnabled(),
      service.deviceSupportsAuth(),
      service.getTimeout(),
    ]);
    if (!mounted) return;
    setState(() {
      _enabled = results[0] as bool;
      _hasPin = results[1] as bool;
      _biometric = results[2] as bool;
      _deviceSupportsAuth = results[3] as bool;
      _timeout = results[4] as LockTimeout;
      _loading = false;
    });
  }

  Future<void> _toggleEnabled(bool value) async {
    final service = ref.read(appLockServiceProvider);
    if (value && !await service.canUnlock()) {
      // Enabling requires at least one unlock method: guide to set a PIN.
      if (!mounted) return;
      final set = await _askPin(context, ref);
      if (set != true) return;
    }
    await service.setEnabled(value);
    ref.invalidate(appLockEnabledProvider);
    await _reload();
  }

  /// PIN setup dialog. Returns true when a PIN was saved.
  Future<bool?> _askPin(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final c1 = TextEditingController();
    final c2 = TextEditingController();
    String? error;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(l10n.setPin),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: c1,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 12,
                decoration: InputDecoration(
                  labelText: l10n.pinLabel,
                  hintText: l10n.pinTooShort,
                ),
              ),
              TextField(
                controller: c2,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 12,
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
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () async {
                if (c1.text != c2.text) {
                  setState(() => error = l10n.passwordMismatch);
                  return;
                }
                if (c1.text.trim().length < 4) {
                  setState(() => error = l10n.pinTooShort);
                  return;
                }
                final saved = await ref
                    .read(appLockServiceProvider)
                    .setPin(c1.text.trim());
                if (!saved) {
                  setState(() => error = l10n.pinTooShort);
                  return;
                }
                if (ctx.mounted) Navigator.of(ctx).pop(true);
              },
              child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
            ),
          ],
        ),
      ),
    );
    if (ok == true && context.mounted) {
      final l10nNow = AppLocalizations.of(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10nNow.pinSaved)));
      await _reload();
    }
    return ok;
  }

  Future<void> _toggleBiometric(bool value) async {
    final service = ref.read(appLockServiceProvider);
    if (value) {
      // Verify the user can actually authenticate before enabling.
      final ok = await service.authenticateBiometric(
        reason: AppLocalizations.of(context).unlockApp,
      );
      if (!ok) return;
    }
    await service.setBiometricEnabled(value);
    await _reload();
  }

  Future<void> _changeTimeout(LockTimeout? value) async {
    if (value == null) return;
    await ref.read(appLockServiceProvider).setTimeout(value);
    await _reload();
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

  Future<void> _exportEncrypted(AppLocalizations l10n) async {
    if (_busy) return;
    final password = await _askBackupPassword(l10n, true);
    if (password == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final file =
          await ref.read(backupServiceProvider).exportEncryptedBackup(password);
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

  Future<void> _importEncrypted(AppLocalizations l10n) async {
    if (_busy) return;
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = picked.isEmpty ? null : picked.first.path;
    if (path == null || !mounted) return;
    final password = await _askBackupPassword(l10n, false);
    if (password == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final service = ref.read(backupServiceProvider);
      final file = File(path);
      final count = await service.previewEncryptedImport(file, password);
      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.importEncryptedBackup),
          content: Text(l10n.importPreview(count)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
      final imported = await service.importEncryptedBackup(file, password);
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    String timeoutLabel(LockTimeout t) => switch (t) {
          LockTimeout.immediately => l10n.timeoutImmediately,
          LockTimeout.oneMinute => l10n.timeout1Min,
          LockTimeout.fiveMinutes => l10n.timeout5Min,
        };

    Widget sectionHeader(String title) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.securityPageTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // Database encryption status (informational).
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2FA36B).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.verified_user_outlined,
                          color: Color(0xFF2FA36B),
                          size: 22,
                        ),
                      ),
                    ),
                    title: Text(
                      l10n.encryptionOn,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(l10n.encryptionOnDesc),
                  ),
                ),
                sectionHeader(l10n.appLock),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.screen_lock_portrait_outlined),
                        title: Text(l10n.enableAppLock),
                        value: _enabled,
                        onChanged: _busy ? null : _toggleEnabled,
                      ),
                      const Divider(height: 1, indent: 56, endIndent: 16),
                      ListTile(
                        leading: const Icon(Icons.pin_outlined),
                        title: Text(_hasPin ? l10n.changePin : l10n.setPin),
                        subtitle: Text(_hasPin ? l10n.pinSet : l10n.pinNotSet),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _busy ? null : () => _askPin(context, ref),
                      ),
                      const Divider(height: 1, indent: 56, endIndent: 16),
                      SwitchListTile(
                        secondary: const Icon(Icons.fingerprint),
                        title: Text(l10n.useBiometric),
                        value: _biometric,
                        onChanged:
                            _deviceSupportsAuth && !_busy ? _toggleBiometric : null,
                      ),
                      const Divider(height: 1, indent: 56, endIndent: 16),
                      ListTile(
                        leading: const Icon(Icons.timer_outlined),
                        title: Text(l10n.lockTimeout),
                        trailing: DropdownButton<LockTimeout>(
                          value: _timeout,
                          underline: const SizedBox.shrink(),
                          borderRadius: BorderRadius.circular(12),
                          items: [
                            for (final t in LockTimeout.values)
                              DropdownMenuItem(
                                  value: t, child: Text(timeoutLabel(t))),
                          ],
                          onChanged: _busy ? null : _changeTimeout,
                        ),
                      ),
                    ],
                  ),
                ),
                sectionHeader(l10n.encryptedBackup),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.upload_outlined,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        title: Text(
                          l10n.exportEncryptedBackup,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(l10n.backupPasswordHint),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _busy ? null : () => _exportEncrypted(l10n),
                      ),
                      const Divider(height: 1, indent: 56, endIndent: 16),
                      ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.download_outlined,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        title: Text(
                          l10n.importEncryptedBackup,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _busy ? null : () => _importEncrypted(l10n),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
