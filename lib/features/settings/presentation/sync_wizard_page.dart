// lib/features/settings/presentation/sync_wizard_page.dart
// First-time sync setup wizard for 随存 (Stage C).
//
// Honesty rules:
// - Never pretend "sync completed" or invent numbers.
// - Password/secrets are never printed or logged.
// - Recovery key is displayed once from consumePendingRecoveryKey and never persisted.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:suicun/features/sync/sync_contract.dart';
import 'package:suicun/features/sync/sync_errors.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';
import 'package:suicun/services/webdav_service.dart';

class SyncWizardPage extends ConsumerStatefulWidget {
  const SyncWizardPage({super.key});

  @override
  ConsumerState<SyncWizardPage> createState() => _SyncWizardPageState();
}

class _SyncWizardPageState extends ConsumerState<SyncWizardPage> {
  int _currentStep = 0;
  bool _busy = false;

  // Step 0: Connection Test
  late final TextEditingController _urlController;
  late final TextEditingController _userController;
  late final TextEditingController _passController;
  late final TextEditingController _dirController;
  bool _obscurePassword = true;
  List<String> _connectionErrors = [];

  // Step 1: Vault Setup
  RemoteVaultCheck? _vaultCheck;

  // Step 1 - noVault branch
  late final TextEditingController _newVaultPassController;
  late final TextEditingController _confirmVaultPassController;
  bool _obscureNewPass = true;
  bool _obscureConfirmPass = true;
  bool _vaultCreated = false;
  bool _hasSavedPassword = false;
  String? _pendingRecoveryKey;

  // Step 1 - hasVault branch
  bool _useRecoveryKey = false; // false = password, true = recovery key
  late final TextEditingController _existingPassController;
  late final TextEditingController _recoveryKeyController;
  bool _obscureExistingPass = true;

  // Step 1 - hasV1Vault (migration) branch
  late final TextEditingController _migrationPassController;
  bool _obscureMigrationPass = true;

  bool _joinedExisting = false;

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

    _loadConfig();
  }

  @override
  void dispose() {
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

  Future<void> _loadConfig() async {
    final service = ref.read(webdavServiceProvider);
    final saved = await service.loadConfig();
    if (saved != null && mounted) {
      setState(() {
        _urlController.text = saved.serverUrl;
        _userController.text = saved.username;
        _passController.text = saved.password;
        _dirController.text = saved.directory;
      });
    }
  }

  WebdavConfig get _config => WebdavConfig(
        serverUrl: _urlController.text.trim(),
        username: _userController.text.trim(),
        password: _passController.text,
        directory: _dirController.text.trim(),
      );

  String _probeMessage(AppLocalizations l10n, WebdavProbeResult result) {
    if (result.detail != null && result.detail!.isNotEmpty) {
      return result.detail!;
    }
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

  // --- Step 0 Action ---
  Future<void> _handleTestAndContinue(AppLocalizations l10n) async {
    final service = ref.read(webdavServiceProvider);
    final errors = service.validateConfig(_config);
    setState(() => _connectionErrors = errors);
    if (errors.isNotEmpty) return;

    setState(() => _busy = true);
    try {
      await service.saveConfig(_config);
      final testResult = await service.testConnection(_config);
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
      final check = await actions.checkRemoteVault(_config);
      if (!mounted) return;
      setState(() {
        _vaultCheck = check;
        _currentStep = 1;
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
      if (mounted) setState(() => _busy = false);
    }
  }

  // --- Step 1 Action (Create Vault) ---
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
      await actions.createVault(_config, newPass);
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
      final msg = e is SyncError ? e.message(english: isEn) : e.toString();
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

  // --- Step 1 Action (Join Vault) ---
  Future<void> _handleJoinVault(AppLocalizations l10n) async {
    setState(() => _busy = true);
    try {
      final actions = ref.read(syncActionsProvider);
      if (_useRecoveryKey) {
        final key = _recoveryKeyController.text.trim();
        await actions.joinVault(_config, recoveryKey: key);
      } else {
        final pass = _existingPassController.text;
        await actions.joinVault(_config, password: pass);
      }
      if (!mounted) return;
      setState(() {
        _currentStep = 2;
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
      if (mounted) setState(() => _busy = false);
    }
  }

  // --- Step 1 Action (Migrate v1 Vault) ---
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
      await actions.migrateV1ToV2(_config, pass);
      if (!mounted) return;
      setState(() {
        _currentStep = 2;
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
      if (mounted) setState(() => _busy = false);
    }
  }

  // --- Step 2 Action (Start Sync) ---
  Future<void> _handleStartSync(AppLocalizations l10n) async {
    setState(() => _busy = true);
    try {
      final actions = ref.read(syncActionsProvider);
      await actions.setEnabled(true);
      await actions.syncNow();
      if (!mounted) return;
      setState(() {
        _currentStep = 3;
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
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Calculates password strength:
  /// strong: length >= 12 && has letter, digit, symbol
  /// fair: length >= 8
  /// weak: otherwise
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.wizardTitle),
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepCancel: _busy || _currentStep == 0 || _currentStep == 3
            ? null
            : () {
                setState(() {
                  _currentStep -= 1;
                });
              },
        controlsBuilder: (context, details) => const SizedBox.shrink(),
        steps: [
          Step(
            title: Text(l10n.wizardStepConnection),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            content: _buildStep0Connection(l10n, theme, colorScheme),
          ),
          Step(
            title: Text(l10n.wizardStepVault),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            content: _buildStep1Vault(l10n, theme, colorScheme),
          ),
          Step(
            title: Text(l10n.wizardStepMerge),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.indexed,
            content: _buildStep2Merge(l10n, theme, colorScheme),
          ),
          Step(
            title: Text(l10n.wizardDone),
            isActive: _currentStep >= 3,
            state: _currentStep == 3 ? StepState.complete : StepState.indexed,
            content: _buildStep3Done(l10n, theme, colorScheme),
          ),
        ],
      ),
    );
  }

  Widget _buildStep0Connection(
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.wizardConnectionDesc,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _urlController,
          keyboardType: TextInputType.url,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: l10n.webdavUrl,
            hintText: 'https://dav.example.com',
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _userController,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: l10n.username,
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passController,
          obscureText: _obscurePassword,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: l10n.password,
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined),
              tooltip:
                  _obscurePassword ? l10n.showPassword : l10n.hidePassword,
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _dirController,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: l10n.syncDirectory,
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        if (_connectionErrors.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final err in _connectionErrors)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                err,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: _busy ? null : () => _handleTestAndContinue(l10n),
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.wizardTestAndContinue),
          ),
        ),
      ],
    );
  }

  Widget _buildStep1Vault(
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    if (_vaultCheck == RemoteVaultCheck.noVault) {
      return _buildNoVaultBranch(l10n, theme, colorScheme);
    } else if (_vaultCheck == RemoteVaultCheck.hasV1Vault) {
      return _buildMigrationBranch(l10n, theme, colorScheme);
    } else {
      return _buildHasVaultBranch(l10n, theme, colorScheme);
    }
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
                    onPressed: _hasSavedPassword
                        ? () {
                            setState(() {
                              _pendingRecoveryKey = null;
                              _currentStep = 2;
                            });
                          }
                        : null,
                    child: Text(l10n.confirm),
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
                      setState(() => _currentStep = 0);
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
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () {
                      setState(() => _currentStep = 0);
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
                      : Text(l10n.joinExistingVault),
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
                      setState(() => _currentStep = 0);
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

  Widget _buildStep2Merge(
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    int? pendingCount;
    try {
      pendingCount = ref.read(syncOverviewProvider).value?.pendingCount;
    } catch (_) {}

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  color: colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.wizardMergeInfo,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (pendingCount != null) ...[
          const SizedBox(height: 12),
          Text(
            l10n.wizardMergeCount(pendingCount),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
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
                      setState(() => _currentStep = 1);
                    },
              child: Text(l10n.cancel),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _busy ? null : () => _handleStartSync(l10n),
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.startSync),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep3Done(
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Center(
          child: Icon(
            Icons.check_circle_outline,
            size: 64,
            color: Colors.green.shade700,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.wizardDone,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.wizardDoneDesc,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: () => context.pop(),
            child: Text(l10n.backToSync),
          ),
        ),
      ],
    );
  }
}
