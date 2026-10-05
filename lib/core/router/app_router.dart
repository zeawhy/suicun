import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:suicun/features/records/presentation/home_page.dart';
import 'package:suicun/features/records/presentation/edit_record_page.dart';
import 'package:suicun/features/settings/presentation/settings_page.dart';
import 'package:suicun/features/settings/presentation/webdav_sync_page.dart';
import 'package:suicun/features/trash/presentation/trash_page.dart';
import 'package:suicun/features/settings/presentation/backup_page.dart';
import 'package:suicun/features/categories/presentation/categories_page.dart';
import 'package:suicun/features/tags/presentation/tags_page.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomePage(),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) => const EditRecordPage(),
          ),
          GoRoute(
            path: 'edit/:id',
            builder: (context, state) {
              final id = state.pathParameters['id'];
              return EditRecordPage(recordId: id);
            },
          ),
          GoRoute(
            path: 'settings',
            builder: (context, state) => const SettingsPage(),
            routes: [
              GoRoute(
                path: 'backup',
                builder: (context, state) => const BackupPage(),
              ),
              GoRoute(
                path: 'categories',
                builder: (context, state) => const CategoriesPage(),
              ),
              GoRoute(
                path: 'tags',
                builder: (context, state) => const TagsPage(),
              ),
              GoRoute(
                path: 'webdav',
                builder: (context, state) => const WebdavSyncPage(),
              ),
            ],
          ),
          GoRoute(
            path: 'trash',
            builder: (context, state) => const TrashPage(),
          ),
        ],
      ),
    ],
  );
}
