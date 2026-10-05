// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get about => 'About';

  @override
  String get addCategory => 'Add Category';

  @override
  String get addKeyword => 'Add keyword';

  @override
  String get addTag => 'Add Tag';

  @override
  String get addTags => 'Add tags';

  @override
  String get all => 'All';

  @override
  String get appName => 'Suicun';

  @override
  String get appTagline => 'Save it now, find it later';

  @override
  String get appearance => 'Appearance';

  @override
  String get autoSaveHint => 'Auto-saved, no need to tap save.';

  @override
  String get backup => 'Backup';

  @override
  String get batchCategorize => 'Categorize';

  @override
  String get batchDelete => 'Delete';

  @override
  String get batchFavorite => 'Favorite';

  @override
  String get bodyHint => 'Write down info you\'ll want to find later…';

  @override
  String get bodyLimit => 'Body is large (>1 MiB), consider splitting';

  @override
  String get cancel => 'Cancel';

  @override
  String get categories => 'Categories';

  @override
  String get categoriesEmpty => 'No categories yet';

  @override
  String get category => 'Category';

  @override
  String get categoryColor => 'Category Color';

  @override
  String get categoryName => 'Category Name';

  @override
  String get clearFilter => 'Clear Filters';

  @override
  String get configSaved => 'Configuration saved';

  @override
  String get confirm => 'Confirm';

  @override
  String connectionFailed(String error) {
    return 'Connection failed: $error';
  }

  @override
  String get connectionSuccess => 'Connection successful';

  @override
  String get data => 'Data';

  @override
  String get delete => 'Delete';

  @override
  String get deleteCategory => 'Delete Category';

  @override
  String get deleteCategoryConfirm =>
      'Records in this category will become uncategorized. Delete?';

  @override
  String get deleteTag => 'Delete Tag';

  @override
  String get deleteTagConfirm =>
      'Records with this tag will keep their content; the tag association will be removed. Delete?';

  @override
  String get directoryInvalid => 'Sync directory must start with /';

  @override
  String get duplicateName => 'Name already exists';

  @override
  String get e2eDesc => 'Content is encrypted before upload to your storage.';

  @override
  String get e2eEnabled => 'Enabled';

  @override
  String get e2eEncryption => 'End-to-end encryption';

  @override
  String get e2eWipDialog =>
      'End-to-end encryption will be enabled with the sync engine (Stage C).';

  @override
  String get editCategory => 'Edit Category';

  @override
  String get editInfo => 'Edit Info';

  @override
  String get editTag => 'Edit Tag';

  @override
  String get export => 'Export';

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get exportJson => 'Export JSON Backup';

  @override
  String get exportMarkdownZip => 'Export Markdown ZIP';

  @override
  String get exportSuccess => 'Export successful';

  @override
  String get exportTxt => 'Export TXT';

  @override
  String get favorite => 'Favorite';

  @override
  String get favorites => 'Favorites';

  @override
  String get filterEmpty => 'No records for this filter';

  @override
  String get filterEmptyHint => 'Try another category or clear the filter';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get importData => 'Import';

  @override
  String importFailed(String error) {
    return 'Import failed: $error';
  }

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
  String get keywordHint => 'Type a keyword, Enter to add';

  @override
  String get keywords => 'Keywords';

  @override
  String get keywordsEmpty =>
      'No keywords yet — add some to enable smart suggestions';

  @override
  String get lastSync => 'Last sync';

  @override
  String lastSyncToday(String time) {
    return 'Today $time';
  }

  @override
  String get linkCopied => 'Link copied';

  @override
  String get maxTagsReached => 'Maximum 10 tags';

  @override
  String modified(String time) {
    return 'Modified $time';
  }

  @override
  String get newInfo => 'New Info';

  @override
  String get newRecord => 'New Record';

  @override
  String get notYetInput => 'Nothing entered yet';

  @override
  String get ok => 'OK';

  @override
  String get password => 'Password';

  @override
  String get passwordRequired => 'Password is required';

  @override
  String get pendingUpload => 'Pending upload';

  @override
  String get permanentDelete => 'Delete Permanently';

  @override
  String get permanentDeleteConfirm =>
      'This cannot be undone. Delete permanently?';

  @override
  String get probeInvalidConfig => 'Configuration incomplete';

  @override
  String get probeNotFound => 'Directory not found on server';

  @override
  String get probeNotHttps => 'HTTPS URLs only';

  @override
  String get probeServerError => 'Server error';

  @override
  String get probeTimeout => 'Connection timed out';

  @override
  String get probeTls => 'TLS handshake failed; check the URL or certificate';

  @override
  String get probeUnauthorized => 'Wrong username or password';

  @override
  String get probeUnknown => 'Unknown error';

  @override
  String get probeUnreachable => 'Cannot reach the server';

  @override
  String recordCount(int count) {
    return '$count records';
  }

  @override
  String get recordDeleted => 'Moved to trash';

  @override
  String get recordsEmpty => 'No records yet';

  @override
  String get recordsEmptyHint => 'Tap + to create your first record';

  @override
  String get rename => 'Rename';

  @override
  String get restore => 'Restore';

  @override
  String get save => 'Save';

  @override
  String get saveFailed => 'Save failed, retry';

  @override
  String get saved => 'Saved';

  @override
  String get saving => 'Saving…';

  @override
  String get searchEmpty => 'No results found';

  @override
  String get searchEmptyHint => 'Try different keywords or clear filters';

  @override
  String get searchHint => 'Search saved info';

  @override
  String get security => 'Security';

  @override
  String get securityNotImplemented =>
      'Security features will be available in a future version';

  @override
  String get selectAll => 'Select All';

  @override
  String get selectCategory => 'Select Category';

  @override
  String get selectTags => 'Select Tags';

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String get settings => 'Settings';

  @override
  String get showPassword => 'Show password';

  @override
  String get smartRecommend => 'Smart suggestion';

  @override
  String get sync => 'Sync';

  @override
  String get syncCompleted => 'Sync completed';

  @override
  String get syncDirectory => 'Sync directory';

  @override
  String get syncEngineWip => 'Sync engine in development (Stage C)';

  @override
  String get syncNever => 'Never synced';

  @override
  String get syncNotConfigured => 'Sync not configured';

  @override
  String get syncNotImplemented => 'Sync will be available in a future version';

  @override
  String get syncNow => 'Sync Now';

  @override
  String get synced => 'Synced';

  @override
  String get tagName => 'Tag Name';

  @override
  String get tags => 'Tags';

  @override
  String get tagsEmpty => 'No tags yet';

  @override
  String get testConnection => 'Test Connection';

  @override
  String get theme => 'Theme';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get themeSystem => 'System';

  @override
  String get titleHint => 'Title (optional)';

  @override
  String get trash => 'Trash';

  @override
  String get trashEmpty => 'Trash is empty';

  @override
  String get uncategorized => 'Uncategorized';

  @override
  String get undoDelete => 'Undo';

  @override
  String get unfavorite => 'Unfavorite';

  @override
  String get untitledRecord => 'Untitled';

  @override
  String get username => 'Username';

  @override
  String get usernameRequired => 'Username is required';

  @override
  String get version => 'Version';

  @override
  String get webdavSync => 'WebDAV Sync';

  @override
  String get webdavUrl => 'WebDAV URL';

  @override
  String get webdavUrlInvalid => 'WebDAV URL is invalid';

  @override
  String get webdavUrlRequired => 'WebDAV URL is required';

  @override
  String get appLock => 'App lock';

  @override
  String get enableAppLock => 'Enable app lock';

  @override
  String get setPin => 'Set PIN';

  @override
  String get changePin => 'Change PIN';

  @override
  String get pinNotSet => 'Not set';

  @override
  String get pinSet => 'Set';

  @override
  String get useBiometric => 'Unlock with biometrics';

  @override
  String get lockTimeout => 'Lock after background';

  @override
  String get timeoutImmediately => 'Immediately';

  @override
  String get timeout1Min => '1 minute';

  @override
  String get timeout5Min => '5 minutes';

  @override
  String get encryptedBackup => 'Encrypted backup';

  @override
  String get exportEncryptedBackup => 'Export encrypted backup';

  @override
  String get importEncryptedBackup => 'Import encrypted backup';

  @override
  String get backupPassword => 'Backup password';

  @override
  String get backupPasswordHint =>
      'Needed to restore on a new device. Keep it safe.';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get passwordMismatch => 'Passwords do not match';

  @override
  String get passwordTooShort => 'Password must be at least 8 characters';

  @override
  String get unlockApp => 'Unlock Suicun';

  @override
  String get appLocked => 'Suicun is locked';

  @override
  String get enterPin => 'Enter PIN to unlock';

  @override
  String get wrongPin => 'Wrong PIN, try again';

  @override
  String get pinTooShort => 'PIN must be at least 4 digits';

  @override
  String get pinSaved => 'PIN saved';

  @override
  String get securityPageTitle => 'Security';

  @override
  String get encryptionOn => 'Local database is encrypted';

  @override
  String get encryptionOnDesc =>
      'Encrypted with a random key stored in system secure storage';

  @override
  String lockoutTryLater(Object seconds) {
    return 'Too many attempts, try again in ${seconds}s';
  }

  @override
  String get pinLabel => 'PIN';
}
