// lib/features/settings/presentation/webdav_sync_page.dart
// WebDAV sync page, matching the design mockup.
//
// Honesty rules (sync engine is Stage C, not built yet):
// - The status card NEVER claims "sync completed" and shows no numbers.
// - "Sync now" is disabled with a "sync engine in development" note.
// - "Test connection" performs a REAL PROPFIND probe via WebdavService.
// - No "restore on new phone" button until the engine exists.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';
import 'package:suicun/services/webdav_service.dart';

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
  bool _loaded = false;
  Timer? _autosaveTimer;

  /// Validation errors as l10n keys returned by WebdavService.validateConfig.
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

  /// The feature service returns human-readable (already localized) messages.
  /// This groups them per form field by keyword.
  String? _fieldError(Set<String> fieldKeys, List<String> errors) {
    for (final e in errors) {
      final isMatch = fieldKeys.any((k) => e.contains(k));
      if (isMatch) return e;
    }
    return null;
  }

  String _probeMessage(AppLocalizations l10n, WebdavProbeResult result) {
    // detail from the service is already a localized, human-readable message.
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.webdavSync)),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildStatusCard(l10n, theme, colorScheme),
                const SizedBox(height: 12),
                _buildFormCard(l10n, theme, colorScheme),
                const SizedBox(height: 12),
                _buildE2eCard(l10n, theme, colorScheme),
              ],
            ),
    );
  }

  /// Honest status: configured vs not configured. Never claims completion.
  Widget _buildStatusCard(
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final configured = _urlController.text.trim().isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                configured ? Icons.cloud_outlined : Icons.cloud_off_outlined,
                size: 30,
                color: colorScheme.onSurfaceVariant,
                semanticLabel: l10n.webdavSync,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    configured ? l10n.syncNever : l10n.syncNotConfigured,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    configured
                        ? _urlController.text.trim()
                        : l10n.syncEngineWip,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
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
            Row(
              children: [
                Expanded(
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
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    // Sync engine is Stage C: honestly disabled.
                    onPressed: null,
                    child: Text(l10n.syncNow),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.syncEngineWip,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
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
