import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suicun/core/crypto/database_encryption_service.dart';
import 'package:suicun/core/database/app_database.dart';
import 'package:suicun/core/database/providers.dart';
import 'package:suicun/core/router/app_router.dart';
import 'package:suicun/features/records/data/id_doc_body_migration.dart';
import 'package:suicun/features/security/presentation/app_lock_gate.dart';
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

  late final AppDatabase db;
  try {
    final connection =
        await DatabaseEncryptionService().openEncryptedDatabase();
    db = AppDatabase(connection);
    // Run a cheap query to confirm the migrated schema is usable.
    await db.customSelect('SELECT count(*) AS n FROM sqlite_master;').get();
  } on DatabaseEncryptionError catch (e) {
    runApp(_StartupFailureApp(message: e.message));
    return;
  } catch (e) {
    runApp(_StartupFailureApp(message: 'unexpected startup error: $e'));
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

  // The container lives for the whole process lifetime; the OS reclaims it on
  // exit (UncontrolledProviderScope does not dispose it).
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const AppLockGate(child: SuicunApp()),
    ),
  );
}

/// Shown when the encrypted database cannot be opened. The app refuses to
/// run rather than falling back to plaintext.
class _StartupFailureApp extends StatelessWidget {
  const _StartupFailureApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  '无法打开加密数据库',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Database could not be opened. The app will not run '
                  'without encryption.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                SelectableText(message,
                    style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SuicunApp extends ConsumerWidget {
  const SuicunApp({super.key, this.locale});

  final Locale? locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final currentThemeMode = ref.watch(resolvedThemeModeProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      locale: locale,
      themeMode: currentThemeMode,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }
}
