// lib/features/settings/presentation/webdav_sync_page.dart
// WebDAV sync page for 随存 (Stage C).
//
// Honesty rules:
// - Never pretend "sync completed" or invent numbers.
// - All numbers and sync states come strictly from SyncOverview.
// - Password/secrets are never printed or logged.
// - No network activity is triggered automatically when disabled/unconfigured,
//   except when the user explicitly taps "Test Connection".

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:suicun/features/sync/sync_contract.dart';
import 'package:suicun/features/sync/sync_errors.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';
import 'package:suicun/services/webdav_service.dart';
import 'package:suicun/shared/utils/date_formatter.dart';

class WebdavSyncPage extends ConsumerStatefulWidget {
  const WebdavSyncPage({super.key});

  @override
  ConsumerState<WebdavSyncPage> createState() => _WebdavSyncPageState();
}

class _WebdavSyncPageState extends ConsumerState<WebdavSyncPage> {
  late final TextEditingController _urlController;
  late final TextEditingController _userController;
  late final TextEditingController _passController;
  late final TextEditingController _dirController;

  bool _obscurePassword = true;
  bool _testing = false;
  bool _syncingAction = false;
  bool _disablingAction = false;
  bool _loaded = false;
  Timer? _autosaveTimer;

  /// Validation errors returned by WebdavService.validateConfig.
  List<String> _errors = [];

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
    _userController = TextEditingController();
    _passController = TextEditingController();
    _dirController = TextEditingController(text: '/suicun/');
    _loadSaved();
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _urlController.dispose();
    _userController.dispose();
    _passController.dispose();
    _dirController.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    final saved = await ref.read(webdavServiceProvider).loadConfig();
    if (!mounted) return;
    setState(() {
      if (saved != null) {
        _urlController.text = saved.serverUrl;
        _userController.text = saved.username;
        _passController.text = saved.password;
        _dirController.text = saved.directory;
      }
      _loaded = true;
    });
  }

  WebdavConfig get _currentConfig => WebdavConfig(
        serverUrl: _urlController.text.trim(),
        username: _userController.text.trim(),
        password: _passController.text,
        directory: _dirController.text.trim().isEmpty
            ? '/'
            : _dirController.text.trim(),
      );

  void _onFieldChanged() {
    final errors =
        ref.read(webdavServiceProvider).validateConfig(_currentConfig);
    setState(() => _errors = errors);
    _autosaveTimer?.cancel();
    if (errors.isEmpty) {
      _autosaveTimer = Timer(const Duration(milliseconds: 800), () async {
        try {
          await ref.read(webdavServiceProvider).saveConfig(_currentConfig);
        } catch (_) {}
      });
    }
  }

  String? _fieldError(Set<String> fieldKeys, List<String> errors) {
    for (final e in errors) {
      final isMatch = fieldKeys.any((k) => e.contains(k));
      if (isMatch) return e;
    }
    return null;
  }

  String _probeMessage(AppLocalizations l10n, WebdavProbeResult result) {
    final detail = result.detail;
    if (detail != null && detail.isNotEmpty) return detail;
    return switch (result.failure) {
      WebdavProbeFailure.notHttps => l10n.probeNotHttps,
      WebdavProbeFailure.timeout => l10n.probeTimeout,
      WebdavProbeFailure.unauthorized => l10n.probeUnauthorized,
      WebdavProbeFailure.notFound => l10n.probeNotFound,
      WebdavProbeFailure.network => l10n.probeUnreachable,
      WebdavProbeFailure.serverError => l10n.probeServerError,
      _ => l10n.probeUnknown,
    };
  }

  Future<void> _testConnection(AppLocalizations l10n) async {
    final service = ref.read(webdavServiceProvider);
    final errors = service.validateConfig(_currentConfig);
    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;

    setState(() => _testing = true);
    final WebdavProbeResult result;
    try {
      result = await service.testConnection(_currentConfig);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
    if (!mounted) return;
    if (result.ok) {
      try {
        await service.saveConfig(_currentConfig);
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.connectionSuccess),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.connectionFailed(_probeMessage(l10n, result))),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _handleSyncNow(AppLocalizations l10n) async {
    setState(() => _syncingAction = true);
    try {
      final actions = ref.read(syncActionsProvider);
      await actions.syncNow();
    } catch (e) {
      if (!mounted) return;
      final isEn = Localizations.localeOf(context).languageCode == 'en';
      final msg = e is SyncError ? e.message(english: isEn) : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _syncingAction = false);
    }
  }

  Future<void> _confirmDisableSync(AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.disableSync),
        content: Text(l10n.disableSyncConfirm),
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

    setState(() => _disablingAction = true);
    try {
      final actions = ref.read(syncActionsProvider);
      await actions.disableSync(removeCredentials: false);
    } catch (e) {
      if (!mounted) return;
      final isEn = Localizations.localeOf(context).languageCode == 'en';
      final msg = e is SyncError ? e.message(english: isEn) : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _disablingAction = false);
    }
  }

  Future<void> _confirmRemoveCredentials(AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.removeCredentials),
        content: Text(l10n.removeCredentialsConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _disablingAction = true);
    try {
      final actions = ref.read(syncActionsProvider);
      await actions.disableSync(removeCredentials: true);
      await ref.read(webdavServiceProvider).clearConfig();
      if (!mounted) return;
      setState(() {
        _urlController.clear();
        _userController.clear();
        _passController.clear();
        _dirController.text = '/suicun/';
        _errors.clear();
      });
    } catch (e) {
      if (!mounted) return;
      final isEn = Localizations.localeOf(context).languageCode == 'en';
      final msg = e is SyncError ? e.message(english: isEn) : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _disablingAction = false);
    }
  }

  void _showE2eDialog(AppLocalizations l10n) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.e2eEncryption),
        content: Text(l10n.e2eWipDialog),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }

  Future<void> _promptUnlockKeys(AppLocalizations l10n) async {
    final controller = TextEditingController();
    bool obscure = true;
    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.unlockKeyPrompt),
          content: TextField(
            controller: controller,
            obscureText: obscure,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.vaultPassword,
              hintText: l10n.enterKeyPassword,
              suffixIcon: IconButton(
                icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setDialogState(() => obscure = !obscure),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: Text(l10n.confirm),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (password == null || password.isEmpty || !mounted) return;

    try {
      final actions = ref.read(syncActionsProvider);
      final unlocked = await actions.unlockKeys(password: password);
      if (!mounted) return;
      if (unlocked > 0) {
        await actions.syncNow();
      } else {
        final isEn = Localizations.localeOf(context).languageCode == 'en';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              const SyncError(SyncErrorCode.wrongPasswordOrKey).message(english: isEn),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final isEn = Localizations.localeOf(context).languageCode == 'en';
      final msg = e is SyncError ? e.message(english: isEn) : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final overviewAsync = ref.watch(syncOverviewProvider);

    final bool isEnabled = overviewAsync.maybeWhen(
      data: (overview) => overview.enabled,
      orElse: () => false,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.webdavSync)),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildStatusSection(l10n, theme, colorScheme, overviewAsync),
                const SizedBox(height: 12),
                if (!isEnabled) ...[
                  _buildStartSetupCard(l10n, theme, colorScheme),
                  const SizedBox(height: 12),
                  _buildFormCard(l10n, theme, colorScheme),
                ] else ...[
                  _buildReadOnlyConfigCard(l10n, theme, colorScheme),
                ],
                const SizedBox(height: 12),
                _buildE2eCard(l10n, theme, colorScheme),
              ],
            ),
    );
  }

  Widget _buildStatusSection(
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme colorScheme,
    AsyncValue<SyncOverview> overviewAsync,
  ) {
    return overviewAsync.when(
      data: (overview) => _buildLiveStatusCard(l10n, theme, colorScheme, overview),
      loading: () => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
              Text(
                l10n.saving,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      error: (err, stack) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 36,
                color: colorScheme.outline,
                semanticLabel: l10n.syncStatusUnavailable,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.syncStatusUnavailable,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.syncStatusUnavailableDesc,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveStatusCard(
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme colorScheme,
    SyncOverview overview,
  ) {
    final localeName = Localizations.localeOf(context).toString();
    final lastSuccessStr = overview.lastSuccessAt != null
        ? l10n.lastSuccess(DateFormatter.formatFull(overview.lastSuccessAt!, localeName))
        : l10n.lastSuccessNever;

    final isSyncing = overview.syncing || _syncingAction;
    final canSyncNow = overview.enabled && !isSyncing && !_disablingAction;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  overview.enabled
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_off_outlined,
                  size: 28,
                  color: overview.enabled
                      ? colorScheme.primary
                      : colorScheme.outline,
                  semanticLabel: overview.enabled
                      ? l10n.syncStatusEnabled
                      : l10n.syncStatusDisabled,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    overview.enabled
                        ? l10n.syncStatusEnabled
                        : l10n.syncStatusDisabled,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Switch(
                  value: overview.enabled,
                  onChanged: _disablingAction
                      ? null
                      : (val) async {
                          try {
                            final actions = ref.read(syncActionsProvider);
                            await actions.setEnabled(val);
                          } catch (e) {
                            if (!mounted) return;
                            final isEn = Localizations.localeOf(context).languageCode == 'en';
                            final msg = e is SyncError ? e.message(english: isEn) : e.toString();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(msg),
                                backgroundColor: colorScheme.error,
                              ),
                            );
                          }
                        },
                ),
              ],
            ),
            const Divider(height: 24),
            if (isSyncing) ...[
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.syncStatusSyncing,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Icon(
                  Icons.history_outlined,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                  semanticLabel: l10n.lastSync,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    lastSuccessStr,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.upload_file_outlined,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                  semanticLabel: l10n.pendingUpload,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.pendingCount(overview.pendingCount),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                  semanticLabel: l10n.syncedRecordCount(
                      overview.syncedRecords, overview.totalRecords),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.syncedRecordCount(
                        overview.syncedRecords, overview.totalRecords),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: overview.conflictCount > 0
                  ? () => context.push('/settings/webdav/conflicts')
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      overview.conflictCount > 0
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_outline,
                      size: 20,
                      color: overview.conflictCount > 0
                          ? colorScheme.error
                          : colorScheme.onSurfaceVariant,
                      semanticLabel: l10n.conflictCount(overview.conflictCount),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.conflictCount(overview.conflictCount),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: overview.conflictCount > 0
                              ? colorScheme.error
                              : null,
                          fontWeight: overview.conflictCount > 0
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (overview.conflictCount > 0) ...[
                      Text(
                        l10n.viewConflicts,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (overview.lockedKeyCount > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.tertiaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_clock_outlined,
                      size: 20,
                      color: colorScheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.lockedKeysNotice(overview.lockedKeyCount),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onTertiaryContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      onPressed: () => _promptUnlockKeys(l10n),
                      child: Text(l10n.unlockKeyPrompt),
                    ),
                  ],
                ),
              ),
            ],
            if (overview.lastError != null &&
                overview.lastError!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 20,
                      color: colorScheme.onErrorContainer,
                      semanticLabel: l10n.saveFailed,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        overview.lastError!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                icon: isSyncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.sync),
                label: Text(l10n.syncNow),
                onPressed: canSyncNow ? () => _handleSyncNow(l10n) : null,
              ),
            ),
            if (overview.enabled) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: _disablingAction
                            ? null
                            : () => _confirmDisableSync(l10n),
                        child: Text(l10n.disableSync),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: colorScheme.error,
                        ),
                        onPressed: _disablingAction
                            ? null
                            : () => _confirmRemoveCredentials(l10n),
                        child: Text(l10n.removeCredentials),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStartSetupCard(
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Card(
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.sync_alt_outlined,
              size: 32,
              color: colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.webdavSync,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.syncStatusDisabled,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                ),
                onPressed: () => context.push('/settings/webdav/wizard'),
                child: Text(l10n.startSyncSetup),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyConfigCard(
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final serverUrl = _urlController.text.trim();
    final username = _userController.text.trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.settings,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.dns_outlined,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                  semanticLabel: l10n.webdavUrl,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.webdavUrl,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        serverUrl.isEmpty ? '-' : serverUrl,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                  semanticLabel: l10n.username,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.username,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        username.isEmpty ? '-' : username,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard(
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _formRow(
              l10n: l10n,
              theme: theme,
              colorScheme: colorScheme,
              label: l10n.webdavUrl,
              controller: _urlController,
              hint: 'https://dav.example.com',
              keyboardType: TextInputType.url,
              errorKeywords: const {'服务器地址', 'WebDAV', 'https://', 'URL'},
            ),
            _formRow(
              l10n: l10n,
              theme: theme,
              colorScheme: colorScheme,
              label: l10n.username,
              controller: _userController,
              errorKeywords: const {'用户名'},
            ),
            _formRow(
              l10n: l10n,
              theme: theme,
              colorScheme: colorScheme,
              label: l10n.password,
              controller: _passController,
              obscure: _obscurePassword,
              errorKeywords: const {'密码'},
              suffix: IconButton(
                icon: Icon(_obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
                tooltip:
                    _obscurePassword ? l10n.showPassword : l10n.hidePassword,
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            _formRow(
              l10n: l10n,
              theme: theme,
              colorScheme: colorScheme,
              label: l10n.syncDirectory,
              controller: _dirController,
              errorKeywords: const {'目录'},
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: _testing ? null : () => _testConnection(l10n),
                child: _testing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.testConnection),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formRow({
    required AppLocalizations l10n,
    required ThemeData theme,
    required ColorScheme colorScheme,
    required String label,
    required TextEditingController controller,
    required Set<String> errorKeywords,
    String? hint,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
  }) {
    final errorMessage = _fieldError(errorKeywords, _errors);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 104,
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscure,
                  keyboardType: keyboardType,
                  autocorrect: false,
                  enableSuggestions: false,
                  onChanged: (_) => _onFieldChanged(),
                  decoration: InputDecoration(
                    hintText: hint,
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: colorScheme.primary, width: 1.5),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: colorScheme.error, width: 1.5),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: colorScheme.error, width: 1.5),
                    ),
                    suffixIcon: suffix,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          if (errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(left: 112, top: 4),
              child: Text(
                errorMessage,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildE2eCard(
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(Icons.lock_outline, color: colorScheme.primary),
        title: Text(l10n.e2eEncryption),
        subtitle: Text(l10n.e2eDesc),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.e2eEnabled,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right,
                color: colorScheme.onSurfaceVariant),
          ],
        ),
        onTap: () => _showE2eDialog(l10n),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
