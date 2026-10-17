import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suicun/core/crypto/database_encryption_service.dart';
import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/core/database/providers.dart';
import 'package:suicun/core/router/app_router.dart';
import 'package:suicun/features/records/data/id_doc_body_migration.dart';
import 'package:suicun/features/security/presentation/app_lock_gate.dart';
import 'package:suicun/features/security/presentation/startup_recovery_page.dart';
import 'package:suicun/features/sync/sync_contract.dart';
import 'package:suicun/features/sync/sync_providers.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';
import 'package:suicun/shared/theme/app_theme.dart';
import 'package:suicun/shared/theme/theme_providers.dart';

/// Stage B: the database is always opened encrypted.
///
/// Startup sequence:
/// 1. Ensure the random database key exists in the platform secure storage.
/// 2. Migrate a plaintext database to SQLCipher if one is present.
/// 3. Open the encrypted database and inject it into the provider graph.
///
/// If any step fails, a fatal error screen is shown instead of running
/// with a plaintext database. There is no silent fallback.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await runStartup();
}

/// Re-runnable startup flow (§2.6). Called once from main(), and again
/// after a recovery reset or a manual retry from the recovery page.
Future<void> runStartup() async {
  late final AppDatabase db;
  try {
    final connection =
        await DatabaseEncryptionService().openEncryptedDatabase();
    db = AppDatabase(connection);
    // Run a cheap query to confirm the migrated schema is usable.
    await db.customSelect('SELECT count(*) AS n FROM sqlite_master;').get();
  } on DatabaseEncryptionError catch (e) {
    _showRecovery(dataUnreadable: true, details: e.toString());
    return;
  } on PlatformException catch (e) {
    // Secure storage failure (e.g. keystore unavailable after device change).
    _showRecovery(dataUnreadable: true, details: e.toString());
    return;
  } catch (e) {
    _showRecovery(dataUnreadable: false, details: e.toString());
    return;
  }

  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      syncOverviewProvider
          .overrideWith((ref) => ref.watch(syncEngineProvider).overviewStream),
      conflictsProvider
          .overrideWith((ref) => ref.watch(syncEngineProvider).conflictsStream),
      syncActionsProvider.overrideWith((ref) => ref.watch(syncEngineProvider)),
    ],
  );
  // The engine is lazy; create it now so the vault session is restored (and
  // the enqueuer hook installed) before the user can save anything. Otherwise
  // edits made before opening a sync page would silently skip the outbox.
  container.read(syncEngineProvider);

  // Round 5 §1.2: one-time background migration of legacy ID document
  // bodies to the structured format. Fire-and-forget; never blocks startup.
  runIdDocBodyMigration(container);

  // After a recovery reset, show the one-time restore prompt.
  final prefs = await SharedPreferences.getInstance();
  final showRestorePrompt =
      prefs.getBool('show_restore_prompt_after_recovery') ?? false;
  if (showRestorePrompt) {
    await prefs.remove('show_restore_prompt_after_recovery');
  }

  // The container lives for the whole process lifetime; the OS reclaims it on
  // exit (UncontrolledProviderScope does not dispose it).
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: AppLockGate(
        child: SuicunApp(showRestorePrompt: showRestorePrompt),
      ),
    ),
  );
}

/// Shows the recoverable startup failure page.
void _showRecovery({required bool dataUnreadable, required String details}) {
  runApp(
    StartupRecoveryApp(
      dataUnreadable: dataUnreadable,
      technicalDetails: details,
      onRetry: () => runStartup(),
      onStartOver: () async {
        await DatabaseEncryptionService().resetForRecovery();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('show_restore_prompt_after_recovery', true);
        await runStartup();
      },
    ),
  );
}

class SuicunApp extends ConsumerStatefulWidget {
  const SuicunApp({super.key, this.locale, this.showRestorePrompt = false});

  final Locale? locale;

  /// When true, shows the one-time "restore your data?" dialog after startup
  /// (§2.6, shown after a recovery reset).
  final bool showRestorePrompt;

  @override
  ConsumerState<SuicunApp> createState() => _SuicunAppState();
}

class _SuicunAppState extends ConsumerState<SuicunApp> {
  bool _restorePromptShown = false;

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final currentThemeMode = ref.watch(resolvedThemeModeProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      locale: widget.locale,
      themeMode: currentThemeMode,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      // §1.6.3: CountryLocalizations for localized country names in IdDocForm.
      localizationsDelegates: [
        ...AppLocalizations.localizationsDelegates,
        CountryLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) {
        if (widget.showRestorePrompt && !_restorePromptShown) {
          _restorePromptShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showRestoreDialog(context, router);
          });
        }
        return child!;
      },
    );
  }

  void _showRestoreDialog(BuildContext context, GoRouter router) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.restoreDataTitle),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              router.go('/settings/backup');
            },
            child: Text(l10n.importEncryptedBackup),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              router.go('/settings/webdav');
            },
            child: Text(l10n.connectWebdavSync),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.later),
          ),
        ],
      ),
    );
  }
}
