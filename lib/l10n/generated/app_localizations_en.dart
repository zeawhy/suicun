// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Suicun';

  @override
  String get appTagline => 'Save it now, find it later';

  @override
  String get newRecord => 'New Record';

  @override
  String get searchHint => 'Search saved info';

  @override
  String get all => 'All';

  @override
  String get favorites => 'Favorites';

  @override
  String get uncategorized => 'Uncategorized';

  @override
  String get untitledRecord => 'Untitled';

  @override
  String get saving => 'Saving…';

  @override
  String get saved => 'Saved';

  @override
  String get saveFailed => 'Save failed, retry';

  @override
  String get settings => 'Settings';

  @override
  String get appearance => 'Appearance';

  @override
  String get data => 'Data';

  @override
  String get about => 'About';

  @override
  String get theme => 'Theme';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystem => 'System';

  @override
  String get categories => 'Categories';

  @override
  String get tags => 'Tags';

  @override
  String get addCategory => 'Add Category';

  @override
  String get editCategory => 'Edit Category';

  @override
  String get deleteCategory => 'Delete Category';

  @override
  String get deleteCategoryConfirm =>
      'Records in this category will become uncategorized. Delete?';

  @override
  String get categoryName => 'Category Name';

  @override
  String get categoryColor => 'Category Color';

  @override
  String get addTag => 'Add Tag';

  @override
  String get editTag => 'Edit Tag';

  @override
  String get deleteTag => 'Delete Tag';

  @override
  String get deleteTagConfirm =>
      'Records with this tag will keep their content; the tag association will be removed. Delete?';

  @override
  String get tagName => 'Tag Name';

  @override
  String get favorite => 'Favorite';

  @override
  String get unfavorite => 'Unfavorite';

  @override
  String get delete => 'Delete';

  @override
  String get restore => 'Restore';

  @override
  String get permanentDelete => 'Delete Permanently';

  @override
  String get permanentDeleteConfirm =>
      'This cannot be undone. Delete permanently?';

  @override
  String get trash => 'Trash';

  @override
  String get trashEmpty => 'Trash is empty';

  @override
  String get recordsEmpty => 'No records yet';

  @override
  String get recordsEmptyHint => 'Tap + to create your first record';

  @override
  String get searchEmpty => 'No results found';

  @override
  String get searchEmptyHint => 'Try different keywords or clear filters';

  @override
  String get clearFilter => 'Clear Filters';

  @override
  String get backup => 'Backup';

  @override
  String get export => 'Export';

  @override
  String get importData => 'Import';

  @override
  String get exportJson => 'Export JSON Backup';

  @override
  String get exportMarkdownZip => 'Export Markdown ZIP';

  @override
  String get exportTxt => 'Export TXT';

  @override
  String get importJson => 'Restore from JSON';

  @override
  String get importMarkdown => 'Import Markdown/TXT';

  @override
  String importPreview(int count) {
    return 'About to import $count records';
  }

  @override
  String importSuccess(int count) {
    return 'Imported $count records';
  }

  @override
  String importFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get exportSuccess => 'Export successful';

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get save => 'Save';

  @override
  String get rename => 'Rename';

  @override
  String get ok => 'OK';

  @override
  String get titleHint => 'Title (optional)';

  @override
  String get bodyHint => 'Body';

  @override
  String get selectCategory => 'Select Category';

  @override
  String get selectTags => 'Select Tags';

  @override
  String get maxTagsReached => 'Maximum 10 tags';

  @override
  String get duplicateName => 'Name already exists';

  @override
  String get recordDeleted => 'Moved to trash';

  @override
  String get undoDelete => 'Undo';

  @override
  String get selectAll => 'Select All';

  @override
  String get batchFavorite => 'Favorite';

  @override
  String get batchDelete => 'Delete';

  @override
  String get batchCategorize => 'Categorize';

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String get syncNotImplemented => 'Sync will be available in a future version';

  @override
  String get securityNotImplemented =>
      'Security features will be available in a future version';

  @override
  String get version => 'Version';

  @override
  String get bodyLimit => 'Body is large (>1 MiB), consider splitting';

  @override
  String modified(String time) {
    return 'Modified $time';
  }
}
