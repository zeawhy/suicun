// lib/features/settings/presentation/webdav_sync_page.dart
// WebDAV sync page for 随存 (Stage C).
//
// Honesty rules:
// - Never pretend "sync completed" or invent numbers.
// - All numbers and sync states come strictly from SyncOverview.
// - Password/secrets are never printed or logged.
// - Recovery key is displayed once from consumePendingRecoveryKey and never persisted.
// - No network activity is triggered automatically when disabled/unconfigured,
//   except when the user explicitly taps "Connect & sync" or "Test Connection".

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:suicun/features/categories/presentation/categories_notifier.dart';
import 'package:suicun/features/records/presentation/records_notifier.dart';
import 'package:suicun/features/sync/sync_contract.dart';
import 'package:suicun/features/sync/sync_errors.dart';
import 'package:suicun/features/sync/sync_provider.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';
import 'package:suicun/services/webdav_service.dart';
import 'package:suicun/shared/utils/date_formatter.dart';

class WebdavSyncPage extends ConsumerStatefulWidget {
  const WebdavSyncPage({super.key});

  @override
  ConsumerState<WebdavSyncPage> createState() => _WebdavSyncPageState();
}

class _WebdavSyncPageState extends ConsumerState<WebdavSyncPage> {
  // WebDAV connection controllers
  late final TextEditingController _urlController;
  late final TextEditingController _userController;
  late final TextEditingController _passController;
  late final TextEditingController _dirController;

  // Vault branch controllers: noVault branch
  late final TextEditingController _newVaultPassController;
  late final TextEditingController _confirmVaultPassController;

  // Vault branch controllers: hasVault branch
  late final TextEditingController _existingPassController;
  late final TextEditingController _recoveryKeyController;

  // Vault branch controllers: hasV1Vault (migration) branch
  late final TextEditingController _migrationPassController;

  bool _obscurePassword = true;
  bool _testing = false;
  bool _busy = false;
  bool _syncingAction = false;
  bool _disablingAction = false;
  bool _loaded = false;
  Timer? _autosaveTimer;

  /// Validation errors returned by WebdavService.validateConfig.
  List<String> _errors = [];

  // Vault probe check state
  RemoteVaultCheck? _vaultCheck;

  // noVault branch state
  bool _obscureNewPass = true;
  bool _obscureConfirmPass = true;
  bool _vaultCreated = false;
  bool _hasSavedPassword = false;
  String? _pendingRecoveryKey;
  bool _joinedExisting = false;

  // hasVault branch state
  bool _useRecoveryKey = false; // false = password, true = recovery key
  bool _obscureExistingPass = true;

  // hasV1Vault branch state
  bool _obscureMigrationPass = true;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
    _userController = TextEditingController();
    _passController = TextEditingController();
    _dirController = TextEditingController(text: '/suicun/');

    _newVaultPassController = TextEditingController();
    _confirmVaultPassController = TextEditingController();
    _existingPassController = TextEditingController();
    _recoveryKeyController = TextEditingController();
    _migrationPassController = TextEditingController();

    _loadSaved();
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _urlController.dispose();
    _userController.dispose();
    _passController.dispose();
    _dirController.dispose();

    _newVaultPassController.dispose();
    _confirmVaultPassController.dispose();
    _existingPassController.dispose();
    _recoveryKeyController.dispose();
    _migrationPassController.dispose();
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
    setState(() {
      _errors = errors;
      _vaultCheck = null;
      _vaultCreated = false;
      _hasSavedPassword = false;
      _pendingRecoveryKey = null;
    });
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

  int _calculateStrength(String password) {
    if (password.length >= 12 &&
        RegExp(r'[a-zA-Z]').hasMatch(password) &&
        RegExp(r'[0-9]').hasMatch(password) &&
        RegExp(r'[^a-zA-Z0-9]').hasMatch(password)) {
      return 2; // strong
    }
    if (password.length >= 8) {
      return 1; // fair
    }
    return 0; // weak
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

  Future<void> _handleConnectAndSync(AppLocalizations l10n) async {
    final service = ref.read(webdavServiceProvider);
    final errors = service.validateConfig(_currentConfig);
    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;

    setState(() {
      _busy = true;
      _vaultCheck = null;
    });

    try {
      await service.saveConfig(_currentConfig);
      final testResult = await service.testConnection(_currentConfig);
      if (!mounted) return;
      if (!testResult.ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.connectionFailed(_probeMessage(l10n, testResult))),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }

      final actions = ref.read(syncActionsProvider);
      final check = await actions.checkRemoteVault(_currentConfig);
      if (!mounted) return;
      setState(() {
        _vaultCheck = check;
      });
    } catch (e) {
      if (!mounted) return;
      final isEn = Localizations.localeOf(context).languageCode == 'en';
      final msg = _formatErrorMessage(e, english: isEn);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleCreateVault(AppLocalizations l10n) async {
    final newPass = _newVaultPassController.text;
    final confirmPass = _confirmVaultPassController.text;

    if (newPass.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.passwordTooShort),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }
    if (newPass != confirmPass) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.passwordMismatch),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final actions = ref.read(syncActionsProvider);
      await actions.createVault(_currentConfig, newPass);
      final recoveryKey = actions.consumePendingRecoveryKey();
      final joinedExisting = actions.lastCreateJoinedExisting;
      if (!mounted) return;
      if (joinedExisting) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.existingVaultJoined),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
      setState(() {
        _vaultCreated = true;
        _joinedExisting = joinedExisting;
        _pendingRecoveryKey = recoveryKey;
      });
    } catch (e) {
      if (!mounted) return;
      final isEn = Localizations.localeOf(context).languageCode == 'en';
      final msg = _formatErrorMessage(e, english: isEn);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleJoinVault(AppLocalizations l10n) async {
    setState(() => _busy = true);
    try {
      final actions = ref.read(syncActionsProvider);
      if (_useRecoveryKey) {
        final key = _recoveryKeyController.text.trim();
        await actions.joinVault(_currentConfig, recoveryKey: key);
      } else {
        final pass = _existingPassController.text;
        await actions.joinVault(_currentConfig, password: pass);
      }
      if (!mounted) return;
      await _finishSetup(l10n);
    } catch (e) {
      if (!mounted) return;
      final isEn = Localizations.localeOf(context).languageCode == 'en';
      final msg = _formatErrorMessage(e, english: isEn);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleMigrateVault(AppLocalizations l10n) async {
    final pass = _migrationPassController.text;
    if (pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.passwordRequired),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final actions = ref.read(syncActionsProvider);
      await actions.migrateV1ToV2(_currentConfig, pass);
      if (!mounted) return;
      await _finishSetup(l10n);
    } catch (e) {
      if (!mounted) return;
      final isEn = Localizations.localeOf(context).languageCode == 'en';
      final msg = _formatErrorMessage(e, english: isEn);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finishSetup(AppLocalizations l10n) async {
    setState(() => _busy = true);
    try {
      final actions = ref.read(syncActionsProvider);
      await actions.setEnabled(true);
      await actions.syncNow();
      _refreshHomeProviders();
      if (!mounted) return;
      setState(() {
        _vaultCheck = null;
        _pendingRecoveryKey = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.wizardDone),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final isEn = Localizations.localeOf(context).languageCode == 'en';
      final msg = _formatErrorMessage(e, english: isEn);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _formatErrorMessage(Object e, {required bool english}) {
    if (e is SyncError) {
      return e.message(english: english);
    }
    if (e is SyncProviderException) {
      return providerErrorMessage(e, english: english);
    }
    final raw = e.toString().split('\n').first.trim();
    final sanitized =
        raw.replaceAll(RegExp(r'://([^:]+):([^@]+)@'), r'://$1:***@');
    return sanitized.length > 120
        ? '${sanitized.substring(0, 117)}...'
        : sanitized;
  }

  /// Refreshes the providers the home screen watches, so notes restored by
  /// a sync appear as soon as the user returns to the home page.
  /// UI-layer only: does not touch the sync engine.
  void _refreshHomeProviders() {
    ref.invalidate(recordsListProvider);
    ref.invalidate(trashListProvider);
    ref.invalidate(categoriesProvider);
  }

  Future<void> _handleSyncNow(AppLocalizations l10n) async {
    setState(() => _syncingAction = true);
    try {
      final actions = ref.read(syncActionsProvider);
      await actions.syncNow();
      _refreshHomeProviders();
    } catch (e) {
      if (!mounted) return;
      final isEn = Localizations.localeOf(context).languageCode == 'en';
      final msg = _formatErrorMessage(e, english: isEn);
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
      final msg = _formatErrorMessage(e, english: isEn);
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
        _vaultCheck = null;
        _vaultCreated = false;
        _hasSavedPassword = false;
        _pendingRecoveryKey = null;
      });
    } catch (e) {
      if (!mounted) return;
      final isEn = Localizations.localeOf(context).languageCode == 'en';
      final msg = _formatErrorMessage(e, english: isEn);
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
        _refreshHomeProviders();
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
      final msg = _formatErrorMessage(e, english: isEn);
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
                  if (_vaultCheck == RemoteVaultCheck.hasVault) ...[
                    // Existing remote vault: the password/recovery-key input
                    // is the primary action, shown first. The WebDAV config
                    // collapses into a secondary section and the
                    // "Connect & sync" button is hidden to avoid implying
                    // sync can proceed without the vault credentials.
                    _buildVaultBranchCard(l10n, theme, colorScheme),
                    const SizedBox(height: 12),
                    _buildCollapsedConfigCard(l10n, theme, colorScheme),
                  ] else ...[
                    _buildSetupCard(l10n, theme, colorScheme),
                    if (_vaultCheck != null) ...[
                      const SizedBox(height: 12),
                      _buildVaultBranchCard(l10n, theme, colorScheme),
                    ],
                  ],
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
                            final msg = _formatErrorMessage(e, english: isEn);
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
              if (overview.currentStep != null)
                Padding(
                  padding: const EdgeInsets.only(left: 24, top: 6),
                  child: Text(
                    overview.currentStep!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
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
            if (!isSyncing &&
                overview.lastError != null &&
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

  Widget _buildSetupCard(
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.wizardConnectionDesc,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
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
              child: FilledButton(
                onPressed: (_testing || _busy)
                    ? null
                    : () => _handleConnectAndSync(l10n),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(l10n.connectAndSync),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: (_testing || _busy)
                    ? null
                    : () => _testConnection(l10n),
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

  /// Secondary WebDAV config section shown when a remote vault has already
  /// been detected: the credentials are already saved, so the fields start
  /// collapsed and the "Connect & sync" button is not shown in this state.
  Widget _buildCollapsedConfigCard(
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Card(
      child: ExpansionTile(
        leading: Icon(
          Icons.dns_outlined,
          color: colorScheme.onSurfaceVariant,
          semanticLabel: l10n.webdavConnectionSettings,
        ),
        title: Text(
          l10n.webdavConnectionSettings,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    tooltip: _obscurePassword
                        ? l10n.showPassword
                        : l10n.hidePassword,
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
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: (_testing || _busy)
                        ? null
                        : () => _testConnection(l10n),
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
        ],
      ),
    );
  }

  Widget _buildVaultBranchCard(
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: switch (_vaultCheck) {
          RemoteVaultCheck.noVault =>
            _buildNoVaultBranch(l10n, theme, colorScheme),
          RemoteVaultCheck.hasV1Vault =>
            _buildMigrationBranch(l10n, theme, colorScheme),
          _ => _buildHasVaultBranch(l10n, theme, colorScheme),
        },
      ),
    );
  }

  Widget _buildNoVaultBranch(
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    if (_vaultCreated) {
      // Sub-step: confirm password safety & recovery key (if present)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_joinedExisting) ...[
            Card(
              color: colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: colorScheme.onPrimaryContainer,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.existingVaultJoined,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_pendingRecoveryKey != null) ...[
            Card(
              color: colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.vpn_key_outlined,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.recoveryKeyTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: colorScheme.outlineVariant,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              _pendingRecoveryKey!,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonalIcon(
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: _pendingRecoveryKey!),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l10n.recoveryKeyCopied),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy, size: 18),
                            label: Text(l10n.copyRecoveryKey),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: colorScheme.error,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.recoveryKeyWarning,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Card(
            color: colorScheme.errorContainer.withValues(alpha: 0.3),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: colorScheme.error,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.keepPasswordSafe,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            value: _hasSavedPassword,
            onChanged: (val) {
              setState(() => _hasSavedPassword = val ?? false);
            },
            title: Text(l10n.iHaveSavedPassword),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () {
                        setState(() {
                          _vaultCreated = false;
                          _pendingRecoveryKey = null;
                        });
                      },
                child: Text(l10n.cancel),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: _hasSavedPassword && !_busy
                        ? () => _finishSetup(l10n)
                        : null,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(l10n.confirm),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    final strength = _calculateStrength(_newVaultPassController.text);
    final (strengthText, strengthIcon, strengthColor) = switch (strength) {
      2 => (
          l10n.passwordStrengthStrong,
          Icons.check_circle_outline,
          Colors.green.shade700
        ),
      1 => (
          l10n.passwordStrengthFair,
          Icons.info_outline,
          Colors.amber.shade800
        ),
      _ => (
          l10n.passwordStrengthWeak,
          Icons.shield_outlined,
          colorScheme.error
        ),
    };

    final mismatch = _newVaultPassController.text.isNotEmpty &&
        _confirmVaultPassController.text.isNotEmpty &&
        _newVaultPassController.text != _confirmVaultPassController.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.wizardNoVaultDesc,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _newVaultPassController,
          obscureText: _obscureNewPass,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: l10n.newVaultPassword,
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            suffixIcon: IconButton(
              icon: Icon(_obscureNewPass
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined),
              tooltip:
                  _obscureNewPass ? l10n.showPassword : l10n.hidePassword,
              onPressed: () =>
                  setState(() => _obscureNewPass = !_obscureNewPass),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(strengthIcon, size: 16, color: strengthColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                strengthText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: strengthColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirmVaultPassController,
          obscureText: _obscureConfirmPass,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: l10n.confirmVaultPassword,
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirmPass
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined),
              tooltip:
                  _obscureConfirmPass ? l10n.showPassword : l10n.hidePassword,
              onPressed: () =>
                  setState(() => _obscureConfirmPass = !_obscureConfirmPass),
            ),
          ),
        ),
        if (mismatch) ...[
          const SizedBox(height: 6),
          Text(
            l10n.passwordMismatch,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () {
                      setState(() => _vaultCheck = null);
                    },
              child: Text(l10n.cancel),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _busy || mismatch
                      ? null
                      : () => _handleCreateVault(l10n),
                  child: _busy
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(l10n.wizardCreating),
                          ],
                        )
                      : Text(l10n.createNewVault),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHasVaultBranch(
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.lock_open_outlined,
              color: colorScheme.primary,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              l10n.joinExistingVault,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          l10n.wizardHasVaultDesc,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(
              value: false,
              label: Text(l10n.usePassword),
              icon: const Icon(Icons.password_outlined),
            ),
            ButtonSegment(
              value: true,
              label: Text(l10n.useRecoveryKey),
              icon: const Icon(Icons.key_outlined),
            ),
          ],
          selected: {_useRecoveryKey},
          onSelectionChanged: (val) {
            setState(() => _useRecoveryKey = val.first);
          },
        ),
        const SizedBox(height: 16),
        if (!_useRecoveryKey)
          TextField(
            controller: _existingPassController,
            obscureText: _obscureExistingPass,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: l10n.vaultPassword,
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              suffixIcon: IconButton(
                icon: Icon(_obscureExistingPass
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
                tooltip: _obscureExistingPass
                    ? l10n.showPassword
                    : l10n.hidePassword,
                onPressed: () => setState(
                    () => _obscureExistingPass = !_obscureExistingPass),
              ),
            ),
          )
        else
          TextField(
            controller: _recoveryKeyController,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: l10n.vaultRecoveryKey,
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () {
                      setState(() => _vaultCheck = null);
                    },
              child: Text(l10n.cancel),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _busy ? null : () => _handleJoinVault(l10n),
                  child: _busy
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(l10n.wizardJoining),
                          ],
                        )
                      : Text(l10n.unlockAndJoin),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMigrationBranch(
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.history_toggle_off,
                      color: colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.migrationTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.migrationBody,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _migrationPassController,
          obscureText: _obscureMigrationPass,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: l10n.vaultPassword,
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            suffixIcon: IconButton(
              icon: Icon(_obscureMigrationPass
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined),
              tooltip: _obscureMigrationPass
                  ? l10n.showPassword
                  : l10n.hidePassword,
              onPressed: () => setState(
                  () => _obscureMigrationPass = !_obscureMigrationPass),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () {
                      setState(() => _vaultCheck = null);
                    },
              child: Text(l10n.cancel),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _busy ? null : () => _handleMigrateVault(l10n),
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(l10n.migrationBackupAndMigrate),
                ),
              ),
            ),
          ],
        ),
      ],
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
