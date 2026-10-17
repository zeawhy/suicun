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
  String get accountPasswordLabel => 'Account & password';

  @override
  String get addCategory => 'Add Category';

  @override
  String get addKeyword => 'Add keyword';

  @override
  String get addTag => 'Add Tag';

  @override
  String get addTags => 'Add tags';

  @override
  String get addressInfoLabel => 'Address information';

  @override
  String get all => 'All';

  @override
  String get allowIdScreenshots => 'Allow screenshots of ID pages';

  @override
  String get appLock => 'App lock';

  @override
  String get appLockStatusDisabled => 'Disabled';

  @override
  String get appLockStatusEnabled => 'Enabled';

  @override
  String get appLocked => 'SuiVault is locked';

  @override
  String get appName => 'SuiVault';

  @override
  String get appTagline => 'Save it now, find it later';

  @override
  String get appearance => 'Appearance';

  @override
  String get autoSaveHint => 'Auto-saved, no need to tap save.';

  @override
  String get backSide => 'Back';

  @override
  String get backToSync => 'Back to sync settings';

  @override
  String get backup => 'Backup';

  @override
  String get backupAndExport => 'Backup and export';

  @override
  String get backupAndSync => 'Backup & sync';

  @override
  String get backupPassword => 'Backup password';

  @override
  String get backupPasswordHint =>
      'Needed to restore on a new device. Keep it safe.';

  @override
  String backupPhotoSizeWarn(int count, String size) {
    return 'This backup includes $count ID photos (about $size)';
  }

  @override
  String get backupReminderText =>
      'Your data is stored only on this phone. Turn on encrypted backup or sync to keep it safe.';

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
  String get cameraPermissionDenied => 'Camera access is needed to take photos';

  @override
  String get cameraRationaleMessage =>
      'Taking photos is used to capture ID photos, which are saved only to this app\'s private storage';

  @override
  String get cameraRationaleTitle => 'Camera Permission';

  @override
  String get cancel => 'Cancel';

  @override
  String get cantReadData => 'Can\'t read data on this device';

  @override
  String get cantReadDataDesc =>
      'This usually happens after switching phones, resetting your phone, or a system data transfer. You can start over, then restore from an encrypted backup or WebDAV sync.';

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
  String get changeCategory => 'Change category';

  @override
  String get changePin => 'Change PIN';

  @override
  String get chooseFromGallery => 'Choose from gallery';

  @override
  String get choosePhotoSide => 'Choose photo';

  @override
  String get clearAllData => 'Clear all data';

  @override
  String get clearAllDataConfirmContent =>
      'This action cannot be undone. All local records and ID photos will be permanently deleted.';

  @override
  String get clearAllDataConfirmTitle => 'Final confirmation';

  @override
  String get clearAllDataSuccess => 'All data cleared successfully';

  @override
  String get clearAllDataWarningContent =>
      'This will delete all records, categories, tags, and ID photos. This action cannot be undone.';

  @override
  String get clearAllDataWarningTitle => 'Clear all data?';

  @override
  String get clearFilter => 'Clear Filters';

  @override
  String get clearRecentSearches => 'Clear recent searches';

  @override
  String get clipboardSniffSubtitle =>
      'Detect IDs, addresses and links when tapping +';

  @override
  String get clipboardSniffTitle => 'Clipboard detection';

  @override
  String get closeAction => 'Close';

  @override
  String get configSaved => 'Configuration saved';

  @override
  String get confirm => 'Confirm';

  @override
  String get confirmClearAllData => 'I confirm to delete all data';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get confirmVaultPassword => 'Confirm encryption password';

  @override
  String conflictCount(int count) {
    return 'Conflicts: $count';
  }

  @override
  String get conflictHistoryNote =>
      'The discarded version is kept in history and will not be deleted.';

  @override
  String get conflictTypeCategory => 'Category';

  @override
  String get conflictTypeRecord => 'Record';

  @override
  String get conflictTypeTag => 'Tag';

  @override
  String get conflictsEmpty => 'No unresolved conflicts';

  @override
  String get conflictsTitle => 'Sync conflicts';

  @override
  String get connectAndSync => 'Connect & sync';

  @override
  String get connectWebdavSync => 'Connect WebDAV sync';

  @override
  String connectionFailed(String error) {
    return 'Connection failed: $error';
  }

  @override
  String get connectionSuccess => 'Connection successful';

  @override
  String get continueAction => 'Continue';

  @override
  String get copied => 'Copied';

  @override
  String get copiedToClipboardMsg => 'Copied to clipboard';

  @override
  String get copy => 'Copy';

  @override
  String get copyNumberAction => 'Copy number';

  @override
  String get copyRecoveryKey => 'Copy';

  @override
  String get createNewVault => 'Create new vault';

  @override
  String get createdAtPrefix => 'Created';

  @override
  String get dangerousOperations => 'Dangerous operations';

  @override
  String get data => 'Data';

  @override
  String get defaultCategoryIdeas => 'Ideas';

  @override
  String get defaultCategoryLife => 'Life';

  @override
  String get defaultCategoryStudy => 'Study';

  @override
  String get defaultCategoryTodo => 'To Do';

  @override
  String get defaultCategoryWork => 'Work';

  @override
  String get delete => 'Delete';

  @override
  String get deleteCategory => 'Delete Category';

  @override
  String get deleteCategoryConfirm =>
      'Records in this category will become uncategorized. Delete?';

  @override
  String get deleteRecordConfirm =>
      'You can restore it from Trash after deletion.';

  @override
  String get deleteRecordTitle => 'Delete this record?';

  @override
  String get deleteTag => 'Delete Tag';

  @override
  String get deleteTagConfirm =>
      'Records with this tag will keep their content; the tag association will be removed. Delete?';

  @override
  String get directoryInvalid => 'Sync directory must start with /';

  @override
  String get disableSync => 'Disable sync';

  @override
  String get disableSyncConfirm =>
      'Disabling sync stops network tasks; local data is kept. Confirm?';

  @override
  String get docTypeCustomHint => 'Enter document type';

  @override
  String get docTypeDriverLicense => 'Driver License';

  @override
  String get docTypeHmtPermit => 'Exit-Entry Permit (HK/Macau)';

  @override
  String get docTypeIdCard => 'ID Card';

  @override
  String get docTypeOther => 'Other';

  @override
  String get docTypePassport => 'Passport';

  @override
  String get docTypePropertyCert => 'Property Certificate';

  @override
  String get docTypeSocialCard => 'Social Security Card';

  @override
  String get docTypeVehicleLicense => 'Vehicle License';

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
  String get enableAppLock => 'Enable app lock';

  @override
  String get encryptedBackup => 'Encrypted backup';

  @override
  String get encryptionOn => 'Local database is encrypted';

  @override
  String get encryptionOnDesc =>
      'Encrypted with a random key stored in system secure storage';

  @override
  String get enterKeyPassword => 'Enter password to unlock keys';

  @override
  String get enterPin => 'Enter PIN to unlock';

  @override
  String get existingVaultJoined =>
      'An existing sync vault was found and joined';

  @override
  String get export => 'Export';

  @override
  String get exportEncryptedBackup => 'Export encrypted backup';

  @override
  String get exportEncryptedBackupRecommended =>
      'Export Encrypted Backup (Recommended)';

  @override
  String get exportEncryptedBackupSubtitle =>
      'Password required; use when restoring on another device';

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get exportJson => 'Export JSON Backup';

  @override
  String get exportJsonSubtitle => 'Plaintext, readable by anyone';

  @override
  String get exportJsonUnencrypted => 'Export JSON (Unencrypted)';

  @override
  String get exportMarkdownZip => 'Export Markdown ZIP';

  @override
  String get exportOtherFormats => 'Export in Other Formats';

  @override
  String get exportPlainNoPhotos => 'Plain exports don\'t include ID photos';

  @override
  String get exportSuccess => 'Export successful';

  @override
  String get exportTxt => 'Export TXT';

  @override
  String get favorite => 'Favorite';

  @override
  String get favoriteFailed => 'Couldn\'t update favorite, please try again';

  @override
  String get favorites => 'Favorites';

  @override
  String get fieldAddress => 'Address';

  @override
  String get fieldDocName => 'Name';

  @override
  String get fieldDocNumber => 'Document number';

  @override
  String get fieldDocType => 'Document type';

  @override
  String get fieldEmail => 'Email';

  @override
  String get fieldIdea => 'Idea';

  @override
  String get fieldName => 'Name';

  @override
  String get fieldNextAction => 'Next action';

  @override
  String get fieldNotes => 'Notes';

  @override
  String get fieldPassword => 'Password';

  @override
  String get fieldPhone => 'Phone';

  @override
  String get fieldPhotoBack => 'ID photo back';

  @override
  String get fieldPhotoFront => 'ID photo front';

  @override
  String get fieldSource => 'Source';

  @override
  String get fieldUsername => 'Username / Email';

  @override
  String get fieldValidUntil => 'Valid until';

  @override
  String get fieldWebsite => 'Website / App';

  @override
  String get filterEmpty => 'No records for this filter';

  @override
  String get filterEmptyHint => 'Try another category or clear the filter';

  @override
  String get formatBold => 'Bold';

  @override
  String get formatBullet => 'Bulleted list';

  @override
  String get formatCheckbox => 'Checkbox';

  @override
  String get formatHeading => 'Heading';

  @override
  String get frontSide => 'Front';

  @override
  String get fullBackup => 'Full Backup';

  @override
  String get galleryPermissionMessage =>
      'Saving ID photos to the system gallery requires gallery permission. Photos are saved to the local gallery only';

  @override
  String get galleryPermissionTitle => 'Gallery Permission';

  @override
  String get goToWebdavSettings => 'Open WebDAV settings';

  @override
  String get hideNumberAction => 'Hide number';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get iHaveSavedPassword => 'I have saved the encryption password';

  @override
  String get idCardBackPhoto => 'Back photo';

  @override
  String get idCardFlipBack => 'Flip back';

  @override
  String get idCardFrontPhoto => 'Front photo';

  @override
  String get idCardHintFlip => 'Tap to flip · Long-press to copy number';

  @override
  String get idCardHintNoFlip => 'Long-press to copy number';

  @override
  String get idCardMoreActions => 'More actions';

  @override
  String get idCardTapToReveal => 'Tap to reveal';

  @override
  String idCardValidUntil(String date) {
    return 'Valid until $date';
  }

  @override
  String get idDocumentInfo => 'ID information';

  @override
  String get idExpired => 'Expired';

  @override
  String get idExpiringSoon => 'Expires soon';

  @override
  String get idFieldExpiryDate => 'Expiry date';

  @override
  String get idFieldIssueDate => 'Issue date';

  @override
  String get idFieldIssuingCountry => 'Issuing country';

  @override
  String get idFieldName => 'Name';

  @override
  String get idFieldNote => 'Note';

  @override
  String get idFieldNumber => 'Document number';

  @override
  String get idFieldType => 'Document type';

  @override
  String get idNoExpiry => 'No expiry';

  @override
  String get idNumberCopied => 'Document number copied';

  @override
  String get idNumberCopiedMsg => 'ID number copied to clipboard';

  @override
  String idNumberLastDigits(String digits) {
    return 'Last $digits digits';
  }

  @override
  String get idOriginalType => 'Original type';

  @override
  String get idPhotoAdd => 'Add photo';

  @override
  String get idPhotoBack => 'Back photo';

  @override
  String get idPhotoFront => 'Front photo';

  @override
  String get idPhotoPick => 'Choose from gallery';

  @override
  String get idPhotoRemove => 'Remove';

  @override
  String get idPhotoReplace => 'Replace';

  @override
  String get idPhotoTake => 'Take photo';

  @override
  String get idTypeCnResidentId => 'China Resident ID';

  @override
  String get idTypeDriverLicense => 'Driver\'s license';

  @override
  String get idTypeGroupChina => 'China documents';

  @override
  String get idTypeHealthInsurance => 'Health insurance card';

  @override
  String get idTypeHkMoPermit => 'HK-Macau Travel Permit';

  @override
  String get idTypeNationalId => 'ID card';

  @override
  String get idTypeOther => 'Other';

  @override
  String get idTypePassport => 'Passport';

  @override
  String get idTypeResidencePermit => 'Residence permit';

  @override
  String get idTypeSocialSecurity => 'Social security card';

  @override
  String get idTypeStudentId => 'Student ID';

  @override
  String get idTypeTwPermit => 'Taiwan Travel Permit';

  @override
  String get importData => 'Import';

  @override
  String get importEncryptedBackup => 'Import encrypted backup';

  @override
  String importFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get importJson => 'Restore from JSON';

  @override
  String get importMarkdown => 'Import Markdown/TXT';

  @override
  String get importMarkdownOrTxt => 'Import Markdown / TXT';

  @override
  String importPreview(int count) {
    return 'About to import $count records';
  }

  @override
  String get importSectionTitle => 'Import';

  @override
  String importSuccess(int count) {
    return 'Imported $count records';
  }

  @override
  String infoCount(int count) {
    return '$count items';
  }

  @override
  String get joinExistingVault => 'Join existing vault';

  @override
  String get keepBoth => 'Keep both';

  @override
  String get keepLocal => 'Keep this version';

  @override
  String get keepPasswordSafe =>
      'Keep your encryption password safe: it cannot be recovered if lost. Your WebDAV login cannot restore note contents.';

  @override
  String get keepRemote => 'Keep other version';

  @override
  String keywordCount(int count) {
    return '$count keywords';
  }

  @override
  String get keywordHint => 'Type a keyword, Enter to add';

  @override
  String get keywords => 'Keywords';

  @override
  String get keywordsEmpty =>
      'No keywords yet — add some to enable smart suggestions';

  @override
  String get landscapeAction => 'Landscape';

  @override
  String lastBackup(String time) {
    return 'Last backup: $time';
  }

  @override
  String lastSuccess(String time) {
    return 'Last success: $time';
  }

  @override
  String get lastSuccessNever => 'Never synced successfully';

  @override
  String get lastSync => 'Last sync';

  @override
  String lastSyncTime(String time) {
    return 'Last sync: $time';
  }

  @override
  String lastSyncToday(String time) {
    return 'Today $time';
  }

  @override
  String get later => 'Later';

  @override
  String get linkCopied => 'Link copied';

  @override
  String get localVersion => 'This device';

  @override
  String get lockTimeout => 'Lock after background';

  @override
  String lockedKeysNotice(int count) {
    return '$count keys are still locked; some content is temporarily unavailable';
  }

  @override
  String lockoutTryLater(Object seconds) {
    return 'Too many attempts, try again in ${seconds}s';
  }

  @override
  String get manage => 'Manage';

  @override
  String get manageCategories => 'Manage categories';

  @override
  String get manageKeywords => 'Manage keywords';

  @override
  String get manualMerge => 'Merge manually';

  @override
  String get maxTagsReached => 'Maximum 10 tags';

  @override
  String get memoNoteLabel => 'Memo note';

  @override
  String get mergeBodyHint => 'Merged body';

  @override
  String get mergeDialogTitle => 'Merge manually';

  @override
  String get mergeTitleHint => 'Merged title';

  @override
  String get migrationBackupAndMigrate => 'Backup and Migrate';

  @override
  String get migrationBody =>
      'The legacy directory will be kept as a backup; migration is a one-time copy. After migrating, append-only sync with protocol v2 will be used.';

  @override
  String get migrationTitle => 'Old protocol vault found';

  @override
  String modified(String time) {
    return 'Modified $time';
  }

  @override
  String get multiSelectActions => 'Multi-select';

  @override
  String get myRecords => 'My Info';

  @override
  String get newInfo => 'New Info';

  @override
  String get newRecord => 'New Record';

  @override
  String get newVaultPassword => 'New vault password';

  @override
  String get noIdNumberRecorded => 'No ID number recorded';

  @override
  String get noPhotoOrNumber => 'No photo or number available';

  @override
  String get notBackedUpYet => 'Not backed up yet';

  @override
  String get notFilled => 'Not set';

  @override
  String get notYetInput => 'Nothing entered yet';

  @override
  String get ok => 'OK';

  @override
  String get onboardingClipboardBody =>
      'After copying ID numbers, addresses, or links, SuiVault can suggest one-tap saving when tapping \"+\". Processed locally only, never uploaded.';

  @override
  String get onboardingClipboardEnable => 'Enable';

  @override
  String get onboardingClipboardFooter =>
      'You can change this anytime in Settings › Security & Privacy';

  @override
  String get onboardingClipboardNotNow => 'Not Now';

  @override
  String get onboardingClipboardTitle => 'Enable Clipboard Recognition?';

  @override
  String get openSettings => 'Open settings';

  @override
  String get password => 'Password';

  @override
  String get passwordChangeDeferred =>
      'Password change is not available yet; normal sync is unaffected';

  @override
  String get passwordCopied => 'Password copied';

  @override
  String get passwordMismatch => 'Passwords do not match';

  @override
  String get passwordRequired => 'Password is required';

  @override
  String get passwordStrengthFair => 'Fair';

  @override
  String get passwordStrengthStrong => 'Strong';

  @override
  String get passwordStrengthWeak =>
      'Weak (12+ characters with letters, numbers and symbols recommended)';

  @override
  String get passwordTooShort => 'Password must be at least 8 characters';

  @override
  String pendingCount(int count) {
    return 'Pending upload: $count';
  }

  @override
  String get pendingUpload => 'Pending upload';

  @override
  String get permanentDelete => 'Delete Permanently';

  @override
  String get permanentDeleteConfirm =>
      'This cannot be undone. Delete permanently?';

  @override
  String get photoNotOnThisDevice => 'Photo not on this device';

  @override
  String get pinLabel => 'PIN';

  @override
  String get pinNotSet => 'Not set';

  @override
  String get pinRecord => 'Pin to top';

  @override
  String get pinSaved => 'PIN saved';

  @override
  String get pinSet => 'Set';

  @override
  String get pinTooShort => 'PIN must be at least 4 digits';

  @override
  String get plaintextExportConfirm =>
      'The exported file is unencrypted and contains sensitive information such as ID numbers and passwords. Continue?';

  @override
  String get plaintextExportConfirmTitle => 'Unencrypted Export';

  @override
  String get presentAutoBrightnessSubtitle => 'Easier to read or scan';

  @override
  String get presentAutoBrightnessTitle => 'Boost brightness';

  @override
  String get presentBrightness => 'Brightness';

  @override
  String get presentDocument => 'Show document';

  @override
  String get presentIdDocument => 'Present ID';

  @override
  String get privacyPolicy => 'Privacy Policy';

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
  String get quickAccessAdded => 'Added to quick access';

  @override
  String get quickAccessHint => 'Long-press any record to set as quick access';

  @override
  String get quickAccessLimitReached => 'Maximum 6 quick access items allowed';

  @override
  String get quickAccessRemoved => 'Removed from quick access';

  @override
  String get quickAccessTitle => 'Quick access';

  @override
  String get quickAdd => 'Quick add';

  @override
  String get quickAddressCopied => 'Address copied to clipboard';

  @override
  String get quickPasswordCopied => 'Password copied to clipboard';

  @override
  String get recentlyUsed => 'Recently used';

  @override
  String recordCount(int count) {
    return '$count records';
  }

  @override
  String get recordDeleted => 'Moved to trash';

  @override
  String get recordTitleContact => 'Contact record';

  @override
  String get recordTitleIdDocument => 'ID Document';

  @override
  String get recordTitleIdea => 'Idea record';

  @override
  String get recordTitleNote => 'Note record';

  @override
  String get recordTitlePassword => 'Password record';

  @override
  String get recordTitleTodo => 'To-do record';

  @override
  String get recordsEmpty => 'No info saved yet';

  @override
  String get recordsEmptyHint => 'Tap \"+ New Info\" below to start saving';

  @override
  String get recoverDesc =>
      'On a new device, download previously uploaded data from WebDAV and rebuild the local library. Only successfully uploaded data can be restored; offline edits that were never uploaded cannot be recovered.';

  @override
  String recoverFailedObjects(int count) {
    return 'Failed objects: $count';
  }

  @override
  String get recoverFromWebdav => 'Restore from WebDAV';

  @override
  String recoverPartial(int count) {
    return 'Partially complete: $count objects failed. You can retry.';
  }

  @override
  String get recoverPhaseConnecting => 'Connecting…';

  @override
  String get recoverPhaseDone => 'Recovery complete';

  @override
  String get recoverPhaseDownloading => 'Downloading objects…';

  @override
  String get recoverPhaseError => 'Recovery failed';

  @override
  String get recoverPhaseListing => 'Listing remote objects…';

  @override
  String get recoverPhaseRebuilding => 'Rebuilding local library…';

  @override
  String recoverProgress(int done, int total) {
    return '$done of $total';
  }

  @override
  String recoverRecordsRestored(int count) {
    return 'Records restored: $count';
  }

  @override
  String get recoveryKeyCopied => 'Recovery key copied';

  @override
  String get recoveryKeyTitle => 'Recovery key';

  @override
  String get recoveryKeyWarning =>
      'This is the only time the recovery key will be shown. Write it down or save it somewhere safe now — it cannot be shown again.';

  @override
  String get remoteVersion => 'Other version';

  @override
  String get removeCredentials => 'Remove credentials';

  @override
  String get removeCredentialsConfirm =>
      'Removing credentials disables sync and deletes the saved WebDAV login; local data is kept. Confirm?';

  @override
  String get rename => 'Rename';

  @override
  String get renameCategory => 'Rename';

  @override
  String get reportIssue => 'Feedback / Report Issue';

  @override
  String get resolveSuccess => 'Conflict resolved';

  @override
  String get resolving => 'Working…';

  @override
  String get restore => 'Restore';

  @override
  String get restoreBackup => 'Restore Backup';

  @override
  String get restoreBackupSubtitle => 'Supports encrypted and JSON backups';

  @override
  String get restoreDataTitle => 'Restore your data?';

  @override
  String get retry => 'Retry';

  @override
  String get save => 'Save';

  @override
  String get saveFailed => 'Save failed, tap to retry';

  @override
  String get savePhotoFailed => 'Save failed, please try again';

  @override
  String get saveToGallery => 'Save to gallery';

  @override
  String get saved => 'Saved';

  @override
  String get savedToGallery => 'Saved to gallery';

  @override
  String get saving => 'Saving…';

  @override
  String get search => 'Search';

  @override
  String get searchEmpty => 'No matching info found';

  @override
  String get searchEmptyHint => 'Try different keywords or clear search';

  @override
  String get searchHint => 'Search title, content, supports pinyin';

  @override
  String get searchPromptEmpty => 'Enter keywords to search all records';

  @override
  String get security => 'Security';

  @override
  String get securityAndPrivacy => 'Security & privacy';

  @override
  String get securityNotImplemented =>
      'Security features will be available in a future version';

  @override
  String get securityPageTitle => 'Security';

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
  String get setPin => 'Set PIN';

  @override
  String get setQuickAccess => 'Set as quick access';

  @override
  String get setUp => 'Set up';

  @override
  String get settings => 'Settings';

  @override
  String get sharePhoto => 'Share photo';

  @override
  String get showNumberAction => 'Show number';

  @override
  String get showPassword => 'Show password';

  @override
  String get smartRecommend => 'Smart suggestion';

  @override
  String get sniffSaveAccount => 'Save as website account';

  @override
  String get sniffSaveAddress => 'Save as address';

  @override
  String get sniffSaveId => 'Save as ID document';

  @override
  String get sortRecentlyCreated => 'Recently created';

  @override
  String get sortRecentlyEdited => 'Recently edited';

  @override
  String get sortTitle => 'Sort';

  @override
  String get sortTitleAZ => 'Title A–Z';

  @override
  String get speedDialAddress => 'Address';

  @override
  String get speedDialBlank => 'Blank note';

  @override
  String get speedDialId => 'ID document';

  @override
  String get speedDialPassword => 'Password';

  @override
  String get startOver => 'Start over';

  @override
  String get startOverConfirm =>
      'The unreadable data on this device will be erased. This can\'t be undone.';

  @override
  String get startRecovery => 'Start recovery';

  @override
  String get startSync => 'Start sync';

  @override
  String get startSyncSetup => 'Start sync setup';

  @override
  String get startupFailed => 'Couldn\'t start';

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
  String get syncStatusDisabled => 'Sync disabled';

  @override
  String get syncStatusEnabled => 'Sync enabled';

  @override
  String get syncStatusSyncing => 'Syncing…';

  @override
  String get syncStatusUnavailable => 'Sync status unavailable';

  @override
  String get syncStatusUnavailableDesc =>
      'The sync engine is still being wired up. Please try again later.';

  @override
  String get synced => 'Synced';

  @override
  String syncedRecordCount(int synced, int total) {
    return 'Synced $synced / $total records';
  }

  @override
  String get tagName => 'Tag Name';

  @override
  String get tags => 'Tags';

  @override
  String get tagsEmpty => 'No tags yet';

  @override
  String get takePhoto => 'Take photo';

  @override
  String get technicalDetails => 'Technical details';

  @override
  String get templateBlank => 'Blank note';

  @override
  String get templateBlankDesc => 'Start from a blank note';

  @override
  String get templateContact => 'Contact';

  @override
  String get templateContactDesc => 'Name, phone, email and address';

  @override
  String get templateIdDocument => 'ID Document';

  @override
  String get templateIdDocumentDesc =>
      'ID cards, driver licenses with photos and auto-masked numbers';

  @override
  String get templateIdea => 'Quick idea';

  @override
  String get templateIdeaDesc => 'Idea, source and next action';

  @override
  String get templatePassword => 'Save a password';

  @override
  String get templatePasswordDesc =>
      'Website, username and password with auto-masked password';

  @override
  String get templateSheetTitle => 'Choose a template';

  @override
  String get templateTodo => 'To-do list';

  @override
  String get templateTodoDesc => 'Checklist with checkbox items';

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
  String timeToday(String time) {
    return 'Today $time';
  }

  @override
  String get timeYesterday => 'Yesterday';

  @override
  String get timeout1Min => '1 minute';

  @override
  String get timeout5Min => '5 minutes';

  @override
  String get timeoutImmediately => 'Immediately';

  @override
  String get titleHint => 'Title (optional)';

  @override
  String get today => 'Today';

  @override
  String todoProgress(int done, int total) {
    return '$done of $total done';
  }

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
  String get unlockAndJoin => 'Unlock & Join';

  @override
  String get unlockApp => 'Unlock SuiVault';

  @override
  String get unlockKeyPrompt => 'Unlock Key';

  @override
  String get unpinRecord => 'Unpin';

  @override
  String get unsetQuickAccess => 'Remove from quick access';

  @override
  String get untitledRecord => 'Untitled';

  @override
  String updatedAt(String time) {
    return 'Updated $time';
  }

  @override
  String get useBiometric => 'Unlock with biometrics';

  @override
  String get usePassword => 'Use encryption password';

  @override
  String get useRecoveryKey => 'Use recovery key';

  @override
  String get username => 'Username';

  @override
  String get usernameRequired => 'Username is required';

  @override
  String get vaultPassword => 'Encryption password';

  @override
  String get vaultRecoveryKey => 'Recovery key';

  @override
  String get version => 'Version';

  @override
  String get viewAction => 'View';

  @override
  String get viewConflicts => 'View conflicts';

  @override
  String get viewPhoto => 'View photo';

  @override
  String get webdavConnectionSettings => 'WebDAV connection settings';

  @override
  String get webdavSync => 'WebDAV Sync';

  @override
  String get webdavUrl => 'WebDAV URL';

  @override
  String get webdavUrlInvalid => 'WebDAV URL is invalid';

  @override
  String get webdavUrlRequired => 'WebDAV URL is required';

  @override
  String get wizardConnectionDesc =>
      'Tests the connection to your WebDAV server and checks whether the directory already holds a vault.';

  @override
  String get wizardCreating => 'Creating vault…';

  @override
  String get wizardDone => 'Sync setup complete';

  @override
  String get wizardDoneDesc =>
      'Your encrypted vault is ready. You can start syncing now.';

  @override
  String get wizardHasVaultDesc =>
      'A vault already exists in this directory. Enter the encryption password or recovery key to join.';

  @override
  String get wizardJoining => 'Joining vault…';

  @override
  String wizardMergeCount(int count) {
    return 'Items pending sync: $count';
  }

  @override
  String get wizardMergeInfo =>
      'Your local data will never be directly replaced by the remote copy. Sync merges both sides; any conflicts can be resolved manually later.';

  @override
  String get wizardNoVaultDesc =>
      'No vault found in this directory. You can create a new encrypted vault.';

  @override
  String get wizardStepConnection => 'Connection test';

  @override
  String get wizardStepMerge => 'Merge preview';

  @override
  String get wizardStepSecurity => 'Encryption setup';

  @override
  String get wizardStepVault => 'Choose vault';

  @override
  String get wizardTestAndContinue => 'Test & continue';

  @override
  String get wizardTitle => 'Sync setup wizard';

  @override
  String get wrongPin => 'Wrong PIN, try again';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get zoomInAction => 'Zoom in';
}
