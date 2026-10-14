// lib/features/backup/data/backup_providers.dart
// Riverpod providers for backup/export/import services.

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:suicun/core/database/providers.dart';
import 'package:suicun/features/backup/data/backup_service.dart';

part 'backup_providers.g.dart';

@Riverpod(keepAlive: true)
BackupService backupService(Ref ref) => BackupService(
      db: ref.watch(appDatabaseProvider),
      recordRepo: ref.watch(recordRepositoryProvider),
      categoryRepo: ref.watch(categoryRepositoryProvider),
      tagRepo: ref.watch(tagRepositoryProvider),
    );
