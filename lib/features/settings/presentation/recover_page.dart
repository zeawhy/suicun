// lib/features/settings/presentation/recover_page.dart
// Recovery flow from WebDAV for 随存 (Stage C).
//
// Honesty rules:
// - Never pretend "recovery complete" or invent progress numbers.
// - All phases and counts strictly reflect Stream<RecoveryProgress>.
// - Password/secrets are never printed or logged.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suicun/features/sync/sync_contract.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';
import 'package:suicun/services/webdav_service.dart';

class RecoverPage extends ConsumerStatefulWidget {
  const RecoverPage({super.key});

  @override
  ConsumerState<RecoverPage> createState() => _RecoverPageState();
}

class _RecoverPageState extends ConsumerState<RecoverPage> {
  // WebDAV config fields
  late final TextEditingController _urlController;
  late final TextEditingController _userController;
  late final TextEditingController _passController;
  late final TextEditingController _dirController;
  bool _obscurePassword = true;

  // Encryption credentials
  bool _useRecoveryKey = false;
  late final TextEditingController _vaultPassController;
  late final TextEditingController _recoveryKeyController;
  bool _obscureVaultPass = true;

  // Form errors
  List<String> _formErrors = [];

  // Recovery Stream state
  StreamSubscription<RecoveryProgress>? _subscription;
  bool _isRecovering = false;
  RecoveryProgress? _progress;
  String? _streamError;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
    _userController = TextEditingController();
    _passController = TextEditingController();
    _dirController = TextEditingController(text: '/suicun/');

    _vaultPassController = TextEditingController();
    _recoveryKeyController = TextEditingController();

    _loadConfig();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _urlController.dispose();
    _userController.dispose();
    _passController.dispose();
    _dirController.dispose();

    _vaultPassController.dispose();
    _recoveryKeyController.dispose();
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

  String _phaseLabel(AppLocalizations l10n, String phase) {
    return switch (phase.toLowerCase()) {
      'connecting' => l10n.recoverPhaseConnecting,
      'listing' => l10n.recoverPhaseListing,
      'downloading' => l10n.recoverPhaseDownloading,
      'rebuilding' => l10n.recoverPhaseRebuilding,
      'done' => l10n.recoverPhaseDone,
      'error' => l10n.recoverPhaseError,
      _ => phase,
    };
  }

  void _startRecovery() {
    final l10n = AppLocalizations.of(context);
    final service = ref.read(webdavServiceProvider);
    final errors = service.validateConfig(_config);

    if (!_useRecoveryKey && _vaultPassController.text.isEmpty) {
      errors.add(l10n.passwordRequired);
    } else if (_useRecoveryKey && _recoveryKeyController.text.trim().isEmpty) {
      errors.add(l10n.vaultRecoveryKey);
    }

    setState(() => _formErrors = errors);
    if (errors.isNotEmpty) return;

    _subscription?.cancel();
    setState(() {
      _isRecovering = true;
      _streamError = null;
      _progress = null;
    });

    final actions = ref.read(syncActionsProvider);
    final stream = actions.recoverFromRemote(
      _config,
      password: _useRecoveryKey ? null : _vaultPassController.text,
      recoveryKey: _useRecoveryKey ? _recoveryKeyController.text.trim() : null,
    );

    _subscription = stream.listen(
      (progress) {
        if (!mounted) return;
        setState(() {
          _progress = progress;
          if (progress.done) {
            _isRecovering = false;
          }
        });
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _isRecovering = false;
          _streamError = err.toString();
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          _isRecovering = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.recoverFromWebdav),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top description card
            Card(
              color: colorScheme.surfaceContainerHighest,
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
                        l10n.recoverDesc,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Progress UI if started
            if (_progress != null || _streamError != null) ...[
              _buildProgressCard(context, l10n),
              const SizedBox(height: 16),
            ],
            // Configuration & Credentials form (disabled during recovery)
            _buildForm(context, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final progress = _progress;

    final hasError = _streamError != null || (progress?.error != null);
    final isDone = progress?.done == true;
    final hasFailedObjects = (progress?.failedObjects ?? 0) > 0;

    final double? progressValue =
        (progress != null && progress.totalObjects > 0)
            ? progress.doneObjects / progress.totalObjects
            : null;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (_isRecovering)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (hasError)
                  Icon(Icons.error_outline, color: colorScheme.error, size: 24)
                else if (isDone && !hasFailedObjects)
                  Icon(Icons.check_circle_outline,
                      color: Colors.green.shade700, size: 24)
                else
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.amber.shade800, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasError
                        ? l10n.recoverPhaseError
                        : isDone
                            ? (hasFailedObjects
                                ? l10n.recoverPartial(progress!.failedObjects)
                                : l10n.recoverPhaseDone)
                            : (progress != null
                                ? _phaseLabel(l10n, progress.phase)
                                : l10n.recoverPhaseConnecting),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: hasError
                          ? colorScheme.error
                          : isDone && !hasFailedObjects
                              ? Colors.green.shade700
                              : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _isRecovering || isDone ? progressValue : null,
            ),
            if (progress != null) ...[
              const SizedBox(height: 12),
              Text(
                l10n.recoverProgress(progress.doneObjects, progress.totalObjects),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.recoverRecordsRestored(progress.recordsRestored),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (progress.failedObjects > 0) ...[
                const SizedBox(height: 4),
                Text(
                  l10n.recoverFailedObjects(progress.failedObjects),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
              ],
            ],
            if (hasError) ...[
              const SizedBox(height: 8),
              Text(
                _streamError ?? progress?.error ?? '',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            ],
            if ((hasError || (isDone && hasFailedObjects)) && !_isRecovering) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: _startRecovery,
                  child: Text(l10n.retry),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final enabled = !_isRecovering;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.settings,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlController,
              enabled: enabled,
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: l10n.webdavUrl,
                hintText: 'https://dav.example.com',
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _userController,
              enabled: enabled,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: l10n.username,
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passController,
              enabled: enabled,
              obscureText: _obscurePassword,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: l10n.password,
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  tooltip:
                      _obscurePassword ? l10n.showPassword : l10n.hidePassword,
                  onPressed: enabled
                      ? () =>
                          setState(() => _obscurePassword = !_obscurePassword)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dirController,
              enabled: enabled,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: l10n.syncDirectory,
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.wizardStepSecurity,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
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
              onSelectionChanged: enabled
                  ? (val) {
                      setState(() => _useRecoveryKey = val.first);
                    }
                  : null,
            ),
            const SizedBox(height: 12),
            if (!_useRecoveryKey)
              TextField(
                controller: _vaultPassController,
                enabled: enabled,
                obscureText: _obscureVaultPass,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: l10n.vaultPassword,
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureVaultPass
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    tooltip: _obscureVaultPass
                        ? l10n.showPassword
                        : l10n.hidePassword,
                    onPressed: enabled
                        ? () => setState(
                            () => _obscureVaultPass = !_obscureVaultPass)
                        : null,
                  ),
                ),
              )
            else
              TextField(
                controller: _recoveryKeyController,
                enabled: enabled,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: l10n.vaultRecoveryKey,
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            if (_formErrors.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final err in _formErrors)
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
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: enabled ? _startRecovery : null,
                child: Text(l10n.startRecovery),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
