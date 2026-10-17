import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('zh'),
    Locale('en'),
  ];

  /// No description provided for @about.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get about;

  /// No description provided for @accountPasswordLabel.
  ///
  /// In zh, this message translates to:
  /// **'账号密码'**
  String get accountPasswordLabel;

  /// No description provided for @addCategory.
  ///
  /// In zh, this message translates to:
  /// **'新增分类'**
  String get addCategory;

  /// No description provided for @addKeyword.
  ///
  /// In zh, this message translates to:
  /// **'添加关键词'**
  String get addKeyword;

  /// No description provided for @addTag.
  ///
  /// In zh, this message translates to:
  /// **'新增标签'**
  String get addTag;

  /// No description provided for @addTags.
  ///
  /// In zh, this message translates to:
  /// **'添加标签'**
  String get addTags;

  /// No description provided for @addressInfoLabel.
  ///
  /// In zh, this message translates to:
  /// **'地址信息'**
  String get addressInfoLabel;

  /// No description provided for @all.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get all;

  /// No description provided for @allowIdScreenshots.
  ///
  /// In zh, this message translates to:
  /// **'允许截屏证件页面'**
  String get allowIdScreenshots;

  /// No description provided for @appLock.
  ///
  /// In zh, this message translates to:
  /// **'应用锁'**
  String get appLock;

  /// No description provided for @appLockStatusDisabled.
  ///
  /// In zh, this message translates to:
  /// **'未开启'**
  String get appLockStatusDisabled;

  /// No description provided for @appLockStatusEnabled.
  ///
  /// In zh, this message translates to:
  /// **'已开启'**
  String get appLockStatusEnabled;

  /// No description provided for @appLocked.
  ///
  /// In zh, this message translates to:
  /// **'随存已锁定'**
  String get appLocked;

  /// No description provided for @appName.
  ///
  /// In zh, this message translates to:
  /// **'随存'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In zh, this message translates to:
  /// **'保存以后还要找的信息'**
  String get appTagline;

  /// No description provided for @appearance.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get appearance;

  /// No description provided for @autoSaveHint.
  ///
  /// In zh, this message translates to:
  /// **'自动保存，无需手动点击保存。'**
  String get autoSaveHint;

  /// No description provided for @backSide.
  ///
  /// In zh, this message translates to:
  /// **'背面'**
  String get backSide;

  /// No description provided for @backToSync.
  ///
  /// In zh, this message translates to:
  /// **'返回同步设置'**
  String get backToSync;

  /// No description provided for @backup.
  ///
  /// In zh, this message translates to:
  /// **'备份'**
  String get backup;

  /// No description provided for @backupAndExport.
  ///
  /// In zh, this message translates to:
  /// **'备份与导出'**
  String get backupAndExport;

  /// No description provided for @backupAndSync.
  ///
  /// In zh, this message translates to:
  /// **'备份与同步'**
  String get backupAndSync;

  /// No description provided for @backupPassword.
  ///
  /// In zh, this message translates to:
  /// **'备份密码'**
  String get backupPassword;

  /// No description provided for @backupPasswordHint.
  ///
  /// In zh, this message translates to:
  /// **'换设备恢复需要此密码，请妥善保存'**
  String get backupPasswordHint;

  /// No description provided for @backupPhotoSizeWarn.
  ///
  /// In zh, this message translates to:
  /// **'备份包含 {count} 张证件照片，文件约 {size}'**
  String backupPhotoSizeWarn(int count, String size);

  /// No description provided for @backupReminderText.
  ///
  /// In zh, this message translates to:
  /// **'你的数据只保存在这台手机上，建议开启加密备份或同步。'**
  String get backupReminderText;

  /// No description provided for @batchCategorize.
  ///
  /// In zh, this message translates to:
  /// **'批量分类'**
  String get batchCategorize;

  /// No description provided for @batchDelete.
  ///
  /// In zh, this message translates to:
  /// **'批量删除'**
  String get batchDelete;

  /// No description provided for @batchFavorite.
  ///
  /// In zh, this message translates to:
  /// **'批量收藏'**
  String get batchFavorite;

  /// No description provided for @bodyHint.
  ///
  /// In zh, this message translates to:
  /// **'写下以后还要找的信息……'**
  String get bodyHint;

  /// No description provided for @bodyLimit.
  ///
  /// In zh, this message translates to:
  /// **'正文较长（超过 1 MiB），建议拆分'**
  String get bodyLimit;

  /// No description provided for @cameraPermissionDenied.
  ///
  /// In zh, this message translates to:
  /// **'需要相机权限才能拍照'**
  String get cameraPermissionDenied;

  /// No description provided for @cameraRationaleMessage.
  ///
  /// In zh, this message translates to:
  /// **'拍照用于拍摄证件照片，仅保存到本应用私有目录'**
  String get cameraRationaleMessage;

  /// No description provided for @cameraRationaleTitle.
  ///
  /// In zh, this message translates to:
  /// **'相机权限说明'**
  String get cameraRationaleTitle;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @cantReadData.
  ///
  /// In zh, this message translates to:
  /// **'无法读取本机数据'**
  String get cantReadData;

  /// No description provided for @cantReadDataDesc.
  ///
  /// In zh, this message translates to:
  /// **'这通常发生在换机、刷机或系统数据迁移之后。你可以重新开始，然后从加密备份或 WebDAV 同步恢复数据。'**
  String get cantReadDataDesc;

  /// No description provided for @categories.
  ///
  /// In zh, this message translates to:
  /// **'分类'**
  String get categories;

  /// No description provided for @categoriesEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有分类'**
  String get categoriesEmpty;

  /// No description provided for @category.
  ///
  /// In zh, this message translates to:
  /// **'分类'**
  String get category;

  /// No description provided for @categoryColor.
  ///
  /// In zh, this message translates to:
  /// **'分类颜色'**
  String get categoryColor;

  /// No description provided for @categoryName.
  ///
  /// In zh, this message translates to:
  /// **'分类名称'**
  String get categoryName;

  /// No description provided for @changeCategory.
  ///
  /// In zh, this message translates to:
  /// **'修改分类'**
  String get changeCategory;

  /// No description provided for @changePin.
  ///
  /// In zh, this message translates to:
  /// **'修改 PIN'**
  String get changePin;

  /// No description provided for @chooseFromGallery.
  ///
  /// In zh, this message translates to:
  /// **'从相册选择'**
  String get chooseFromGallery;

  /// No description provided for @choosePhotoSide.
  ///
  /// In zh, this message translates to:
  /// **'选择照片'**
  String get choosePhotoSide;

  /// No description provided for @clearAllData.
  ///
  /// In zh, this message translates to:
  /// **'清除全部数据'**
  String get clearAllData;

  /// No description provided for @clearAllDataConfirmContent.
  ///
  /// In zh, this message translates to:
  /// **'此操作无法撤销，所有本地记录及证件照片将被彻底删除。'**
  String get clearAllDataConfirmContent;

  /// No description provided for @clearAllDataConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'最终确认'**
  String get clearAllDataConfirmTitle;

  /// No description provided for @clearAllDataSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已清除全部数据'**
  String get clearAllDataSuccess;

  /// No description provided for @clearAllDataWarningContent.
  ///
  /// In zh, this message translates to:
  /// **'将删除所有记录、分类、标签及证件照片，不可恢复。'**
  String get clearAllDataWarningContent;

  /// No description provided for @clearAllDataWarningTitle.
  ///
  /// In zh, this message translates to:
  /// **'清除全部数据？'**
  String get clearAllDataWarningTitle;

  /// No description provided for @clearFilter.
  ///
  /// In zh, this message translates to:
  /// **'清除筛选'**
  String get clearFilter;

  /// No description provided for @clearRecentSearches.
  ///
  /// In zh, this message translates to:
  /// **'清空最近搜索'**
  String get clearRecentSearches;

  /// No description provided for @clipboardSniffSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'点击 + 时识别证件号、地址、链接'**
  String get clipboardSniffSubtitle;

  /// No description provided for @clipboardSniffTitle.
  ///
  /// In zh, this message translates to:
  /// **'剪贴板识别'**
  String get clipboardSniffTitle;

  /// No description provided for @closeAction.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get closeAction;

  /// No description provided for @configSaved.
  ///
  /// In zh, this message translates to:
  /// **'配置已保存'**
  String get configSaved;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确认'**
  String get confirm;

  /// No description provided for @confirmClearAllData.
  ///
  /// In zh, this message translates to:
  /// **'我确认要删除全部数据'**
  String get confirmClearAllData;

  /// No description provided for @confirmPassword.
  ///
  /// In zh, this message translates to:
  /// **'确认密码'**
  String get confirmPassword;

  /// No description provided for @confirmVaultPassword.
  ///
  /// In zh, this message translates to:
  /// **'确认加密密码'**
  String get confirmVaultPassword;

  /// No description provided for @conflictCount.
  ///
  /// In zh, this message translates to:
  /// **'冲突：{count}'**
  String conflictCount(int count);

  /// No description provided for @conflictHistoryNote.
  ///
  /// In zh, this message translates to:
  /// **'被弃用的版本会保留到历史记录，不会被删除。'**
  String get conflictHistoryNote;

  /// No description provided for @conflictTypeCategory.
  ///
  /// In zh, this message translates to:
  /// **'分类'**
  String get conflictTypeCategory;

  /// No description provided for @conflictTypeRecord.
  ///
  /// In zh, this message translates to:
  /// **'记录'**
  String get conflictTypeRecord;

  /// No description provided for @conflictTypeTag.
  ///
  /// In zh, this message translates to:
  /// **'标签'**
  String get conflictTypeTag;

  /// No description provided for @conflictsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'没有未解决的冲突'**
  String get conflictsEmpty;

  /// No description provided for @conflictsTitle.
  ///
  /// In zh, this message translates to:
  /// **'同步冲突'**
  String get conflictsTitle;

  /// No description provided for @connectAndSync.
  ///
  /// In zh, this message translates to:
  /// **'连接并同步'**
  String get connectAndSync;

  /// No description provided for @connectWebdavSync.
  ///
  /// In zh, this message translates to:
  /// **'连接 WebDAV 同步'**
  String get connectWebdavSync;

  /// No description provided for @connectionFailed.
  ///
  /// In zh, this message translates to:
  /// **'连接失败：{error}'**
  String connectionFailed(String error);

  /// No description provided for @connectionSuccess.
  ///
  /// In zh, this message translates to:
  /// **'连接成功'**
  String get connectionSuccess;

  /// No description provided for @continueAction.
  ///
  /// In zh, this message translates to:
  /// **'继续'**
  String get continueAction;

  /// No description provided for @copied.
  ///
  /// In zh, this message translates to:
  /// **'已复制'**
  String get copied;

  /// No description provided for @copiedToClipboardMsg.
  ///
  /// In zh, this message translates to:
  /// **'已复制到剪贴板'**
  String get copiedToClipboardMsg;

  /// Snackbar message after copying an ID document number from a record card
  ///
  /// In zh, this message translates to:
  /// **'已复制证件号码'**
  String get docNumberCopied;

  /// No description provided for @copy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get copy;

  /// No description provided for @copyNumberAction.
  ///
  /// In zh, this message translates to:
  /// **'复制号码'**
  String get copyNumberAction;

  /// No description provided for @copyRecoveryKey.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get copyRecoveryKey;

  /// No description provided for @createNewVault.
  ///
  /// In zh, this message translates to:
  /// **'创建新库'**
  String get createNewVault;

  /// No description provided for @createdAtPrefix.
  ///
  /// In zh, this message translates to:
  /// **'创建于'**
  String get createdAtPrefix;

  /// No description provided for @dangerousOperations.
  ///
  /// In zh, this message translates to:
  /// **'危险操作'**
  String get dangerousOperations;

  /// No description provided for @data.
  ///
  /// In zh, this message translates to:
  /// **'数据'**
  String get data;

  /// Settings section header for ID document related options
  ///
  /// In zh, this message translates to:
  /// **'证件'**
  String get settingsGroupIdDocuments;

  /// No description provided for @defaultCategoryIdeas.
  ///
  /// In zh, this message translates to:
  /// **'灵感'**
  String get defaultCategoryIdeas;

  /// No description provided for @defaultCategoryLife.
  ///
  /// In zh, this message translates to:
  /// **'生活'**
  String get defaultCategoryLife;

  /// No description provided for @defaultCategoryStudy.
  ///
  /// In zh, this message translates to:
  /// **'学习'**
  String get defaultCategoryStudy;

  /// No description provided for @defaultCategoryTodo.
  ///
  /// In zh, this message translates to:
  /// **'待办'**
  String get defaultCategoryTodo;

  /// No description provided for @defaultCategoryWork.
  ///
  /// In zh, this message translates to:
  /// **'工作'**
  String get defaultCategoryWork;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @deleteCategory.
  ///
  /// In zh, this message translates to:
  /// **'删除分类'**
  String get deleteCategory;

  /// No description provided for @deleteCategoryConfirm.
  ///
  /// In zh, this message translates to:
  /// **'删除后，该分类下的记录将转为未分类。确认删除吗？'**
  String get deleteCategoryConfirm;

  /// No description provided for @deleteRecordConfirm.
  ///
  /// In zh, this message translates to:
  /// **'删除后可在回收站找回。'**
  String get deleteRecordConfirm;

  /// No description provided for @deleteRecordTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除这条记录？'**
  String get deleteRecordTitle;

  /// No description provided for @deleteTag.
  ///
  /// In zh, this message translates to:
  /// **'删除标签'**
  String get deleteTag;

  /// No description provided for @deleteTagConfirm.
  ///
  /// In zh, this message translates to:
  /// **'删除后，相关记录仍然保留，只解除标签关联。确认删除吗？'**
  String get deleteTagConfirm;

  /// No description provided for @directoryInvalid.
  ///
  /// In zh, this message translates to:
  /// **'同步目录须以 / 开头'**
  String get directoryInvalid;

  /// No description provided for @disableSync.
  ///
  /// In zh, this message translates to:
  /// **'关闭同步'**
  String get disableSync;

  /// No description provided for @disableSyncConfirm.
  ///
  /// In zh, this message translates to:
  /// **'关闭同步将停止网络任务，本地数据保留。确认吗？'**
  String get disableSyncConfirm;

  /// No description provided for @docTypeCustomHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入证件类型'**
  String get docTypeCustomHint;

  /// No description provided for @docTypeDriverLicense.
  ///
  /// In zh, this message translates to:
  /// **'驾驶证'**
  String get docTypeDriverLicense;

  /// No description provided for @docTypeHmtPermit.
  ///
  /// In zh, this message translates to:
  /// **'港澳通行证'**
  String get docTypeHmtPermit;

  /// No description provided for @docTypeIdCard.
  ///
  /// In zh, this message translates to:
  /// **'身份证'**
  String get docTypeIdCard;

  /// No description provided for @docTypeOther.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get docTypeOther;

  /// No description provided for @docTypePassport.
  ///
  /// In zh, this message translates to:
  /// **'护照'**
  String get docTypePassport;

  /// No description provided for @docTypePropertyCert.
  ///
  /// In zh, this message translates to:
  /// **'房产证'**
  String get docTypePropertyCert;

  /// No description provided for @docTypeSocialCard.
  ///
  /// In zh, this message translates to:
  /// **'社保卡'**
  String get docTypeSocialCard;

  /// No description provided for @docTypeVehicleLicense.
  ///
  /// In zh, this message translates to:
  /// **'行驶证'**
  String get docTypeVehicleLicense;

  /// No description provided for @duplicateName.
  ///
  /// In zh, this message translates to:
  /// **'该名称已存在'**
  String get duplicateName;

  /// No description provided for @e2eDesc.
  ///
  /// In zh, this message translates to:
  /// **'内容加密后上传到你的存储空间。'**
  String get e2eDesc;

  /// No description provided for @e2eEnabled.
  ///
  /// In zh, this message translates to:
  /// **'已开启'**
  String get e2eEnabled;

  /// No description provided for @e2eEncryption.
  ///
  /// In zh, this message translates to:
  /// **'端到端加密'**
  String get e2eEncryption;

  /// No description provided for @e2eWipDialog.
  ///
  /// In zh, this message translates to:
  /// **'端到端加密将在同步引擎（阶段 C）上线时启用。'**
  String get e2eWipDialog;

  /// No description provided for @editCategory.
  ///
  /// In zh, this message translates to:
  /// **'编辑分类'**
  String get editCategory;

  /// No description provided for @editInfo.
  ///
  /// In zh, this message translates to:
  /// **'编辑信息'**
  String get editInfo;

  /// No description provided for @editTag.
  ///
  /// In zh, this message translates to:
  /// **'编辑标签'**
  String get editTag;

  /// No description provided for @enableAppLock.
  ///
  /// In zh, this message translates to:
  /// **'启用应用锁'**
  String get enableAppLock;

  /// No description provided for @encryptedBackup.
  ///
  /// In zh, this message translates to:
  /// **'加密备份'**
  String get encryptedBackup;

  /// No description provided for @encryptionOn.
  ///
  /// In zh, this message translates to:
  /// **'本地数据库已加密'**
  String get encryptionOn;

  /// No description provided for @encryptionOnDesc.
  ///
  /// In zh, this message translates to:
  /// **'数据库使用随机密钥加密，密钥保存在系统安全存储'**
  String get encryptionOnDesc;

  /// No description provided for @enterKeyPassword.
  ///
  /// In zh, this message translates to:
  /// **'输入密钥加密密码'**
  String get enterKeyPassword;

  /// No description provided for @enterPin.
  ///
  /// In zh, this message translates to:
  /// **'输入 PIN 解锁'**
  String get enterPin;

  /// No description provided for @existingVaultJoined.
  ///
  /// In zh, this message translates to:
  /// **'检测到已有同步库，已为你加入'**
  String get existingVaultJoined;

  /// No description provided for @export.
  ///
  /// In zh, this message translates to:
  /// **'导出'**
  String get export;

  /// No description provided for @exportEncryptedBackup.
  ///
  /// In zh, this message translates to:
  /// **'导出加密备份'**
  String get exportEncryptedBackup;

  /// No description provided for @exportEncryptedBackupRecommended.
  ///
  /// In zh, this message translates to:
  /// **'导出加密备份（推荐）'**
  String get exportEncryptedBackupRecommended;

  /// No description provided for @exportEncryptedBackupSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'需设置密码，换设备恢复时使用'**
  String get exportEncryptedBackupSubtitle;

  /// No description provided for @exportFailed.
  ///
  /// In zh, this message translates to:
  /// **'导出失败：{error}'**
  String exportFailed(String error);

  /// No description provided for @exportJson.
  ///
  /// In zh, this message translates to:
  /// **'导出 JSON 备份'**
  String get exportJson;

  /// No description provided for @exportJsonSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'明文，任何人可读取'**
  String get exportJsonSubtitle;

  /// No description provided for @exportJsonUnencrypted.
  ///
  /// In zh, this message translates to:
  /// **'导出 JSON（未加密）'**
  String get exportJsonUnencrypted;

  /// No description provided for @exportMarkdownZip.
  ///
  /// In zh, this message translates to:
  /// **'导出 Markdown ZIP'**
  String get exportMarkdownZip;

  /// No description provided for @exportOtherFormats.
  ///
  /// In zh, this message translates to:
  /// **'导出为其他格式'**
  String get exportOtherFormats;

  /// No description provided for @exportPlainNoPhotos.
  ///
  /// In zh, this message translates to:
  /// **'明文导出不包含证件照片'**
  String get exportPlainNoPhotos;

  /// No description provided for @exportSuccess.
  ///
  /// In zh, this message translates to:
  /// **'导出成功'**
  String get exportSuccess;

  /// No description provided for @exportTxt.
  ///
  /// In zh, this message translates to:
  /// **'导出 TXT'**
  String get exportTxt;

  /// No description provided for @favorite.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get favorite;

  /// No description provided for @favoriteFailed.
  ///
  /// In zh, this message translates to:
  /// **'收藏失败，请重试'**
  String get favoriteFailed;

  /// No description provided for @favorites.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get favorites;

  /// No description provided for @fieldAddress.
  ///
  /// In zh, this message translates to:
  /// **'地址'**
  String get fieldAddress;

  /// No description provided for @fieldDocName.
  ///
  /// In zh, this message translates to:
  /// **'姓名'**
  String get fieldDocName;

  /// No description provided for @fieldDocNumber.
  ///
  /// In zh, this message translates to:
  /// **'证件号码'**
  String get fieldDocNumber;

  /// No description provided for @fieldDocType.
  ///
  /// In zh, this message translates to:
  /// **'证件类型'**
  String get fieldDocType;

  /// No description provided for @fieldEmail.
  ///
  /// In zh, this message translates to:
  /// **'邮箱'**
  String get fieldEmail;

  /// No description provided for @fieldIdea.
  ///
  /// In zh, this message translates to:
  /// **'灵感'**
  String get fieldIdea;

  /// No description provided for @fieldName.
  ///
  /// In zh, this message translates to:
  /// **'姓名'**
  String get fieldName;

  /// No description provided for @fieldNextAction.
  ///
  /// In zh, this message translates to:
  /// **'下一步行动'**
  String get fieldNextAction;

  /// No description provided for @fieldNotes.
  ///
  /// In zh, this message translates to:
  /// **'备注'**
  String get fieldNotes;

  /// No description provided for @fieldPassword.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get fieldPassword;

  /// No description provided for @fieldPhone.
  ///
  /// In zh, this message translates to:
  /// **'电话'**
  String get fieldPhone;

  /// No description provided for @fieldPhotoBack.
  ///
  /// In zh, this message translates to:
  /// **'证件照片反面'**
  String get fieldPhotoBack;

  /// No description provided for @fieldPhotoFront.
  ///
  /// In zh, this message translates to:
  /// **'证件照片正面'**
  String get fieldPhotoFront;

  /// No description provided for @fieldSource.
  ///
  /// In zh, this message translates to:
  /// **'来源'**
  String get fieldSource;

  /// No description provided for @fieldUsername.
  ///
  /// In zh, this message translates to:
  /// **'用户名 / 邮箱'**
  String get fieldUsername;

  /// No description provided for @fieldValidUntil.
  ///
  /// In zh, this message translates to:
  /// **'有效期至'**
  String get fieldValidUntil;

  /// No description provided for @fieldWebsite.
  ///
  /// In zh, this message translates to:
  /// **'网站 / 应用'**
  String get fieldWebsite;

  /// No description provided for @filterEmpty.
  ///
  /// In zh, this message translates to:
  /// **'该筛选下没有记录'**
  String get filterEmpty;

  /// No description provided for @filterEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'试试其他分类，或清除筛选条件'**
  String get filterEmptyHint;

  /// No description provided for @formatBold.
  ///
  /// In zh, this message translates to:
  /// **'加粗'**
  String get formatBold;

  /// No description provided for @formatBullet.
  ///
  /// In zh, this message translates to:
  /// **'无序列表'**
  String get formatBullet;

  /// No description provided for @formatCheckbox.
  ///
  /// In zh, this message translates to:
  /// **'勾选框'**
  String get formatCheckbox;

  /// No description provided for @formatHeading.
  ///
  /// In zh, this message translates to:
  /// **'标题'**
  String get formatHeading;

  /// No description provided for @frontSide.
  ///
  /// In zh, this message translates to:
  /// **'正面'**
  String get frontSide;

  /// No description provided for @fullBackup.
  ///
  /// In zh, this message translates to:
  /// **'完整备份'**
  String get fullBackup;

  /// No description provided for @galleryPermissionMessage.
  ///
  /// In zh, this message translates to:
  /// **'保存证件照片到系统相册需要相册权限，照片仅保存到本地相册'**
  String get galleryPermissionMessage;

  /// No description provided for @galleryPermissionTitle.
  ///
  /// In zh, this message translates to:
  /// **'相册权限说明'**
  String get galleryPermissionTitle;

  /// No description provided for @goToWebdavSettings.
  ///
  /// In zh, this message translates to:
  /// **'前往 WebDAV 设置'**
  String get goToWebdavSettings;

  /// No description provided for @hideNumberAction.
  ///
  /// In zh, this message translates to:
  /// **'隐藏号码'**
  String get hideNumberAction;

  /// No description provided for @hidePassword.
  ///
  /// In zh, this message translates to:
  /// **'隐藏密码'**
  String get hidePassword;

  /// No description provided for @iHaveSavedPassword.
  ///
  /// In zh, this message translates to:
  /// **'我已妥善保存加密密码'**
  String get iHaveSavedPassword;

  /// No description provided for @idCardBackPhoto.
  ///
  /// In zh, this message translates to:
  /// **'背面照片'**
  String get idCardBackPhoto;

  /// No description provided for @idCardFlipBack.
  ///
  /// In zh, this message translates to:
  /// **'翻回正面'**
  String get idCardFlipBack;

  /// No description provided for @idCardFrontPhoto.
  ///
  /// In zh, this message translates to:
  /// **'正面照片'**
  String get idCardFrontPhoto;

  /// No description provided for @idCardHintFlip.
  ///
  /// In zh, this message translates to:
  /// **'点击卡片翻面 · 长按复制号码'**
  String get idCardHintFlip;

  /// No description provided for @idCardHintNoFlip.
  ///
  /// In zh, this message translates to:
  /// **'长按卡片复制号码'**
  String get idCardHintNoFlip;

  /// No description provided for @idCardMoreActions.
  ///
  /// In zh, this message translates to:
  /// **'更多操作'**
  String get idCardMoreActions;

  /// No description provided for @idCardTapToReveal.
  ///
  /// In zh, this message translates to:
  /// **'点击查看'**
  String get idCardTapToReveal;

  /// No description provided for @idCardValidUntil.
  ///
  /// In zh, this message translates to:
  /// **'有效期至 {date}'**
  String idCardValidUntil(String date);

  /// No description provided for @idDocumentInfo.
  ///
  /// In zh, this message translates to:
  /// **'证件信息'**
  String get idDocumentInfo;

  /// No description provided for @idExpired.
  ///
  /// In zh, this message translates to:
  /// **'已过期'**
  String get idExpired;

  /// No description provided for @idExpiringSoon.
  ///
  /// In zh, this message translates to:
  /// **'即将到期'**
  String get idExpiringSoon;

  /// No description provided for @idFieldExpiryDate.
  ///
  /// In zh, this message translates to:
  /// **'有效期至'**
  String get idFieldExpiryDate;

  /// No description provided for @idFieldIssueDate.
  ///
  /// In zh, this message translates to:
  /// **'签发日期'**
  String get idFieldIssueDate;

  /// No description provided for @idFieldIssuingCountry.
  ///
  /// In zh, this message translates to:
  /// **'签发国家'**
  String get idFieldIssuingCountry;

  /// No description provided for @idFieldName.
  ///
  /// In zh, this message translates to:
  /// **'姓名'**
  String get idFieldName;

  /// No description provided for @idFieldNote.
  ///
  /// In zh, this message translates to:
  /// **'备注'**
  String get idFieldNote;

  /// No description provided for @idFieldNumber.
  ///
  /// In zh, this message translates to:
  /// **'证件号码'**
  String get idFieldNumber;

  /// No description provided for @idFieldType.
  ///
  /// In zh, this message translates to:
  /// **'证件类型'**
  String get idFieldType;

  /// No description provided for @idNoExpiry.
  ///
  /// In zh, this message translates to:
  /// **'长期'**
  String get idNoExpiry;

  /// No description provided for @idNumberCopied.
  ///
  /// In zh, this message translates to:
  /// **'证件号码已复制'**
  String get idNumberCopied;

  /// No description provided for @idNumberCopiedMsg.
  ///
  /// In zh, this message translates to:
  /// **'证件号码已复制到剪贴板'**
  String get idNumberCopiedMsg;

  /// No description provided for @idNumberLastDigits.
  ///
  /// In zh, this message translates to:
  /// **'尾号 {digits}'**
  String idNumberLastDigits(String digits);

  /// No description provided for @idOriginalType.
  ///
  /// In zh, this message translates to:
  /// **'原类型'**
  String get idOriginalType;

  /// No description provided for @idPhotoAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加照片'**
  String get idPhotoAdd;

  /// No description provided for @idPhotoBack.
  ///
  /// In zh, this message translates to:
  /// **'反面照片'**
  String get idPhotoBack;

  /// No description provided for @idPhotoFront.
  ///
  /// In zh, this message translates to:
  /// **'正面照片'**
  String get idPhotoFront;

  /// No description provided for @idPhotoPick.
  ///
  /// In zh, this message translates to:
  /// **'从相册选择'**
  String get idPhotoPick;

  /// No description provided for @idPhotoRemove.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get idPhotoRemove;

  /// No description provided for @idPhotoReplace.
  ///
  /// In zh, this message translates to:
  /// **'更换'**
  String get idPhotoReplace;

  /// No description provided for @idPhotoTake.
  ///
  /// In zh, this message translates to:
  /// **'拍照'**
  String get idPhotoTake;

  /// No description provided for @idTypeCnResidentId.
  ///
  /// In zh, this message translates to:
  /// **'中国居民身份证'**
  String get idTypeCnResidentId;

  /// No description provided for @idTypeDriverLicense.
  ///
  /// In zh, this message translates to:
  /// **'驾驶证'**
  String get idTypeDriverLicense;

  /// No description provided for @idTypeGroupChina.
  ///
  /// In zh, this message translates to:
  /// **'中国证件'**
  String get idTypeGroupChina;

  /// No description provided for @idTypeHealthInsurance.
  ///
  /// In zh, this message translates to:
  /// **'医保卡'**
  String get idTypeHealthInsurance;

  /// No description provided for @idTypeHkMoPermit.
  ///
  /// In zh, this message translates to:
  /// **'港澳通行证'**
  String get idTypeHkMoPermit;

  /// No description provided for @idTypeNationalId.
  ///
  /// In zh, this message translates to:
  /// **'身份证'**
  String get idTypeNationalId;

  /// No description provided for @idTypeOther.
  ///
  /// In zh, this message translates to:
  /// **'其他证件'**
  String get idTypeOther;

  /// No description provided for @idTypePassport.
  ///
  /// In zh, this message translates to:
  /// **'护照'**
  String get idTypePassport;

  /// No description provided for @idTypeResidencePermit.
  ///
  /// In zh, this message translates to:
  /// **'居留卡'**
  String get idTypeResidencePermit;

  /// No description provided for @idTypeSocialSecurity.
  ///
  /// In zh, this message translates to:
  /// **'社保卡'**
  String get idTypeSocialSecurity;

  /// No description provided for @idTypeStudentId.
  ///
  /// In zh, this message translates to:
  /// **'学生证'**
  String get idTypeStudentId;

  /// No description provided for @idTypeTwPermit.
  ///
  /// In zh, this message translates to:
  /// **'台湾通行证'**
  String get idTypeTwPermit;

  /// No description provided for @importData.
  ///
  /// In zh, this message translates to:
  /// **'导入'**
  String get importData;

  /// No description provided for @importEncryptedBackup.
  ///
  /// In zh, this message translates to:
  /// **'导入加密备份'**
  String get importEncryptedBackup;

  /// No description provided for @importFailed.
  ///
  /// In zh, this message translates to:
  /// **'导入失败：{error}'**
  String importFailed(String error);

  /// No description provided for @importJson.
  ///
  /// In zh, this message translates to:
  /// **'从 JSON 恢复'**
  String get importJson;

  /// No description provided for @importMarkdown.
  ///
  /// In zh, this message translates to:
  /// **'导入 Markdown/TXT'**
  String get importMarkdown;

  /// No description provided for @importMarkdownOrTxt.
  ///
  /// In zh, this message translates to:
  /// **'导入 Markdown / TXT'**
  String get importMarkdownOrTxt;

  /// No description provided for @importPreview.
  ///
  /// In zh, this message translates to:
  /// **'即将导入 {count} 条记录'**
  String importPreview(int count);

  /// No description provided for @importSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入'**
  String get importSectionTitle;

  /// No description provided for @importSuccess.
  ///
  /// In zh, this message translates to:
  /// **'成功导入 {count} 条记录'**
  String importSuccess(int count);

  /// No description provided for @infoCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 条信息'**
  String infoCount(int count);

  /// No description provided for @joinExistingVault.
  ///
  /// In zh, this message translates to:
  /// **'加入已有库'**
  String get joinExistingVault;

  /// No description provided for @keepBoth.
  ///
  /// In zh, this message translates to:
  /// **'分别保留'**
  String get keepBoth;

  /// No description provided for @keepLocal.
  ///
  /// In zh, this message translates to:
  /// **'保留本机版本'**
  String get keepLocal;

  /// No description provided for @keepPasswordSafe.
  ///
  /// In zh, this message translates to:
  /// **'请妥善保管加密密码：丢失后无法找回，WebDAV 账号密码不能恢复笔记内容。'**
  String get keepPasswordSafe;

  /// No description provided for @keepRemote.
  ///
  /// In zh, this message translates to:
  /// **'保留另一版本'**
  String get keepRemote;

  /// No description provided for @keywordCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个关键词'**
  String keywordCount(int count);

  /// No description provided for @keywordHint.
  ///
  /// In zh, this message translates to:
  /// **'输入关键词，回车添加'**
  String get keywordHint;

  /// No description provided for @keywords.
  ///
  /// In zh, this message translates to:
  /// **'关键词'**
  String get keywords;

  /// No description provided for @keywordsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无关键词，添加后可自动推荐分类'**
  String get keywordsEmpty;

  /// No description provided for @landscapeAction.
  ///
  /// In zh, this message translates to:
  /// **'横屏'**
  String get landscapeAction;

  /// No description provided for @lastBackup.
  ///
  /// In zh, this message translates to:
  /// **'上次备份：{time}'**
  String lastBackup(String time);

  /// No description provided for @lastSuccess.
  ///
  /// In zh, this message translates to:
  /// **'上次成功：{time}'**
  String lastSuccess(String time);

  /// No description provided for @lastSuccessNever.
  ///
  /// In zh, this message translates to:
  /// **'从未成功同步'**
  String get lastSuccessNever;

  /// No description provided for @lastSync.
  ///
  /// In zh, this message translates to:
  /// **'上次同步'**
  String get lastSync;

  /// No description provided for @lastSyncTime.
  ///
  /// In zh, this message translates to:
  /// **'上次同步时间：{time}'**
  String lastSyncTime(String time);

  /// No description provided for @lastSyncToday.
  ///
  /// In zh, this message translates to:
  /// **'今天 {time}'**
  String lastSyncToday(String time);

  /// No description provided for @later.
  ///
  /// In zh, this message translates to:
  /// **'稍后'**
  String get later;

  /// No description provided for @linkCopied.
  ///
  /// In zh, this message translates to:
  /// **'已复制链接'**
  String get linkCopied;

  /// No description provided for @localVersion.
  ///
  /// In zh, this message translates to:
  /// **'本机版本'**
  String get localVersion;

  /// No description provided for @lockTimeout.
  ///
  /// In zh, this message translates to:
  /// **'后台锁定超时'**
  String get lockTimeout;

  /// No description provided for @lockedKeysNotice.
  ///
  /// In zh, this message translates to:
  /// **'有 {count} 把密钥未解锁，部分内容暂时无法显示'**
  String lockedKeysNotice(int count);

  /// No description provided for @lockoutTryLater.
  ///
  /// In zh, this message translates to:
  /// **'尝试次数过多，请 {seconds} 秒后再试'**
  String lockoutTryLater(Object seconds);

  /// No description provided for @manage.
  ///
  /// In zh, this message translates to:
  /// **'管理'**
  String get manage;

  /// No description provided for @manageCategories.
  ///
  /// In zh, this message translates to:
  /// **'管理分类'**
  String get manageCategories;

  /// No description provided for @manageKeywords.
  ///
  /// In zh, this message translates to:
  /// **'管理关键词'**
  String get manageKeywords;

  /// No description provided for @manualMerge.
  ///
  /// In zh, this message translates to:
  /// **'手动合并'**
  String get manualMerge;

  /// No description provided for @maxTagsReached.
  ///
  /// In zh, this message translates to:
  /// **'最多添加 10 个标签'**
  String get maxTagsReached;

  /// No description provided for @memoNoteLabel.
  ///
  /// In zh, this message translates to:
  /// **'备忘笔记'**
  String get memoNoteLabel;

  /// No description provided for @mergeBodyHint.
  ///
  /// In zh, this message translates to:
  /// **'合并后的正文'**
  String get mergeBodyHint;

  /// No description provided for @mergeDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'手动合并'**
  String get mergeDialogTitle;

  /// No description provided for @mergeTitleHint.
  ///
  /// In zh, this message translates to:
  /// **'合并后的标题'**
  String get mergeTitleHint;

  /// No description provided for @migrationBackupAndMigrate.
  ///
  /// In zh, this message translates to:
  /// **'备份并迁移'**
  String get migrationBackupAndMigrate;

  /// No description provided for @migrationBody.
  ///
  /// In zh, this message translates to:
  /// **'旧目录原样保留作备份，迁移为一次性拷贝。迁移后可使用新协议进行无冲突追加同步。'**
  String get migrationBody;

  /// No description provided for @migrationTitle.
  ///
  /// In zh, this message translates to:
  /// **'发现旧协议同步库'**
  String get migrationTitle;

  /// No description provided for @modified.
  ///
  /// In zh, this message translates to:
  /// **'修改于 {time}'**
  String modified(String time);

  /// No description provided for @multiSelectActions.
  ///
  /// In zh, this message translates to:
  /// **'多选操作'**
  String get multiSelectActions;

  /// No description provided for @myRecords.
  ///
  /// In zh, this message translates to:
  /// **'我的信息'**
  String get myRecords;

  /// No description provided for @newInfo.
  ///
  /// In zh, this message translates to:
  /// **'新建信息'**
  String get newInfo;

  /// No description provided for @newRecord.
  ///
  /// In zh, this message translates to:
  /// **'新建记录'**
  String get newRecord;

  /// No description provided for @newVaultPassword.
  ///
  /// In zh, this message translates to:
  /// **'新库加密密码'**
  String get newVaultPassword;

  /// No description provided for @noIdNumberRecorded.
  ///
  /// In zh, this message translates to:
  /// **'未记录证件号码'**
  String get noIdNumberRecorded;

  /// No description provided for @noPhotoOrNumber.
  ///
  /// In zh, this message translates to:
  /// **'暂无证件照片与号码'**
  String get noPhotoOrNumber;

  /// No description provided for @photoNotOnDevice.
  ///
  /// In zh, this message translates to:
  /// **'照片未保存在此设备'**
  String get photoNotOnDevice;

  /// No description provided for @notBackedUpYet.
  ///
  /// In zh, this message translates to:
  /// **'尚未备份'**
  String get notBackedUpYet;

  /// No description provided for @notFilled.
  ///
  /// In zh, this message translates to:
  /// **'未填写'**
  String get notFilled;

  /// No description provided for @notYetInput.
  ///
  /// In zh, this message translates to:
  /// **'尚未输入'**
  String get notYetInput;

  /// No description provided for @ok.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get ok;

  /// No description provided for @onboardingClipboardBody.
  ///
  /// In zh, this message translates to:
  /// **'复制证件号、地址或网址后，点「+」时随存会提示你一键保存。内容只在本机识别，不会上传。'**
  String get onboardingClipboardBody;

  /// No description provided for @onboardingClipboardEnable.
  ///
  /// In zh, this message translates to:
  /// **'开启'**
  String get onboardingClipboardEnable;

  /// No description provided for @onboardingClipboardFooter.
  ///
  /// In zh, this message translates to:
  /// **'可随时在 设置 › 安全与隐私 中更改'**
  String get onboardingClipboardFooter;

  /// No description provided for @onboardingClipboardNotNow.
  ///
  /// In zh, this message translates to:
  /// **'暂不'**
  String get onboardingClipboardNotNow;

  /// No description provided for @onboardingClipboardTitle.
  ///
  /// In zh, this message translates to:
  /// **'开启剪贴板识别？'**
  String get onboardingClipboardTitle;

  /// No description provided for @openSettings.
  ///
  /// In zh, this message translates to:
  /// **'去设置'**
  String get openSettings;

  /// No description provided for @password.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get password;

  /// No description provided for @passwordChangeDeferred.
  ///
  /// In zh, this message translates to:
  /// **'密码修改功能暂未开放，普通同步不受影响'**
  String get passwordChangeDeferred;

  /// No description provided for @passwordCopied.
  ///
  /// In zh, this message translates to:
  /// **'密码已复制'**
  String get passwordCopied;

  /// No description provided for @passwordMismatch.
  ///
  /// In zh, this message translates to:
  /// **'两次输入的密码不一致'**
  String get passwordMismatch;

  /// No description provided for @passwordRequired.
  ///
  /// In zh, this message translates to:
  /// **'请填写密码'**
  String get passwordRequired;

  /// No description provided for @passwordStrengthFair.
  ///
  /// In zh, this message translates to:
  /// **'密码强度：中'**
  String get passwordStrengthFair;

  /// No description provided for @passwordStrengthStrong.
  ///
  /// In zh, this message translates to:
  /// **'密码强度：强'**
  String get passwordStrengthStrong;

  /// No description provided for @passwordStrengthWeak.
  ///
  /// In zh, this message translates to:
  /// **'密码强度：弱（建议 12 位以上，混合字母、数字和符号）'**
  String get passwordStrengthWeak;

  /// No description provided for @passwordTooShort.
  ///
  /// In zh, this message translates to:
  /// **'密码至少 8 位'**
  String get passwordTooShort;

  /// No description provided for @pendingCount.
  ///
  /// In zh, this message translates to:
  /// **'待上传：{count}'**
  String pendingCount(int count);

  /// No description provided for @pendingUpload.
  ///
  /// In zh, this message translates to:
  /// **'待上传'**
  String get pendingUpload;

  /// No description provided for @permanentDelete.
  ///
  /// In zh, this message translates to:
  /// **'彻底删除'**
  String get permanentDelete;

  /// No description provided for @permanentDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'彻底删除后无法恢复。确认吗？'**
  String get permanentDeleteConfirm;

  /// No description provided for @photoNotOnThisDevice.
  ///
  /// In zh, this message translates to:
  /// **'照片未保存在此设备'**
  String get photoNotOnThisDevice;

  /// No description provided for @pinLabel.
  ///
  /// In zh, this message translates to:
  /// **'PIN'**
  String get pinLabel;

  /// No description provided for @pinNotSet.
  ///
  /// In zh, this message translates to:
  /// **'未设置'**
  String get pinNotSet;

  /// No description provided for @pinRecord.
  ///
  /// In zh, this message translates to:
  /// **'置顶'**
  String get pinRecord;

  /// No description provided for @pinSaved.
  ///
  /// In zh, this message translates to:
  /// **'PIN 已保存'**
  String get pinSaved;

  /// No description provided for @pinSet.
  ///
  /// In zh, this message translates to:
  /// **'已设置'**
  String get pinSet;

  /// No description provided for @pinTooShort.
  ///
  /// In zh, this message translates to:
  /// **'PIN 至少 4 位'**
  String get pinTooShort;

  /// No description provided for @plaintextExportConfirm.
  ///
  /// In zh, this message translates to:
  /// **'导出的文件未加密，包含证件号和密码等敏感信息。确定继续？'**
  String get plaintextExportConfirm;

  /// No description provided for @plaintextExportConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'未加密导出确认'**
  String get plaintextExportConfirmTitle;

  /// No description provided for @presentAutoBrightnessSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'方便他人查看或扫码'**
  String get presentAutoBrightnessSubtitle;

  /// No description provided for @presentAutoBrightnessTitle.
  ///
  /// In zh, this message translates to:
  /// **'全屏查看时调高亮度'**
  String get presentAutoBrightnessTitle;

  /// No description provided for @presentBrightness.
  ///
  /// In zh, this message translates to:
  /// **'亮度'**
  String get presentBrightness;

  /// No description provided for @presentDocument.
  ///
  /// In zh, this message translates to:
  /// **'出示证件'**
  String get presentDocument;

  /// No description provided for @presentIdDocument.
  ///
  /// In zh, this message translates to:
  /// **'出示证件'**
  String get presentIdDocument;

  /// No description provided for @privacyPolicy.
  ///
  /// In zh, this message translates to:
  /// **'隐私政策'**
  String get privacyPolicy;

  /// No description provided for @probeInvalidConfig.
  ///
  /// In zh, this message translates to:
  /// **'配置不完整'**
  String get probeInvalidConfig;

  /// No description provided for @probeNotFound.
  ///
  /// In zh, this message translates to:
  /// **'服务器上找不到该目录'**
  String get probeNotFound;

  /// No description provided for @probeNotHttps.
  ///
  /// In zh, this message translates to:
  /// **'仅支持 HTTPS 地址'**
  String get probeNotHttps;

  /// No description provided for @probeServerError.
  ///
  /// In zh, this message translates to:
  /// **'服务器错误'**
  String get probeServerError;

  /// No description provided for @probeTimeout.
  ///
  /// In zh, this message translates to:
  /// **'连接超时'**
  String get probeTimeout;

  /// No description provided for @probeTls.
  ///
  /// In zh, this message translates to:
  /// **'TLS 握手失败，请检查地址或证书'**
  String get probeTls;

  /// No description provided for @probeUnauthorized.
  ///
  /// In zh, this message translates to:
  /// **'用户名或密码错误'**
  String get probeUnauthorized;

  /// No description provided for @probeUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知错误'**
  String get probeUnknown;

  /// No description provided for @probeUnreachable.
  ///
  /// In zh, this message translates to:
  /// **'无法连接到服务器'**
  String get probeUnreachable;

  /// No description provided for @quickAccessAdded.
  ///
  /// In zh, this message translates to:
  /// **'已设为常用'**
  String get quickAccessAdded;

  /// No description provided for @quickAccessHint.
  ///
  /// In zh, this message translates to:
  /// **'长按任意记录可设为常用'**
  String get quickAccessHint;

  /// No description provided for @quickAccessLimitReached.
  ///
  /// In zh, this message translates to:
  /// **'常用最多只能添加 6 个'**
  String get quickAccessLimitReached;

  /// No description provided for @quickAccessRemoved.
  ///
  /// In zh, this message translates to:
  /// **'已取消常用'**
  String get quickAccessRemoved;

  /// No description provided for @quickAccessTitle.
  ///
  /// In zh, this message translates to:
  /// **'常用'**
  String get quickAccessTitle;

  /// No description provided for @quickAdd.
  ///
  /// In zh, this message translates to:
  /// **'快速添加'**
  String get quickAdd;

  /// No description provided for @quickAddressCopied.
  ///
  /// In zh, this message translates to:
  /// **'已复制地址到剪贴板'**
  String get quickAddressCopied;

  /// No description provided for @quickPasswordCopied.
  ///
  /// In zh, this message translates to:
  /// **'已复制密码到剪贴板'**
  String get quickPasswordCopied;

  /// No description provided for @recentlyUsed.
  ///
  /// In zh, this message translates to:
  /// **'最近使用'**
  String get recentlyUsed;

  /// No description provided for @recordCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 条记录'**
  String recordCount(int count);

  /// No description provided for @recordDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已移至回收站'**
  String get recordDeleted;

  /// No description provided for @recordTitleContact.
  ///
  /// In zh, this message translates to:
  /// **'联系人记录'**
  String get recordTitleContact;

  /// No description provided for @recordTitleIdDocument.
  ///
  /// In zh, this message translates to:
  /// **'证件记录'**
  String get recordTitleIdDocument;

  /// No description provided for @recordTitleIdea.
  ///
  /// In zh, this message translates to:
  /// **'灵感记录'**
  String get recordTitleIdea;

  /// No description provided for @recordTitleNote.
  ///
  /// In zh, this message translates to:
  /// **'备忘记录'**
  String get recordTitleNote;

  /// No description provided for @recordTitlePassword.
  ///
  /// In zh, this message translates to:
  /// **'密码记录'**
  String get recordTitlePassword;

  /// No description provided for @recordTitleTodo.
  ///
  /// In zh, this message translates to:
  /// **'待办记录'**
  String get recordTitleTodo;

  /// No description provided for @recordsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有保存的信息'**
  String get recordsEmpty;

  /// No description provided for @recordsEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'点击下方「＋ 新建信息」开始保存'**
  String get recordsEmptyHint;

  /// No description provided for @recoverDesc.
  ///
  /// In zh, this message translates to:
  /// **'在新设备上从 WebDAV 下载已上传的数据，重建本地库。只能恢复已成功上传的数据；尚未上传的离线编辑无法找回。'**
  String get recoverDesc;

  /// No description provided for @recoverFailedObjects.
  ///
  /// In zh, this message translates to:
  /// **'失败对象：{count}'**
  String recoverFailedObjects(int count);

  /// No description provided for @recoverFromWebdav.
  ///
  /// In zh, this message translates to:
  /// **'从 WebDAV 恢复'**
  String get recoverFromWebdav;

  /// No description provided for @recoverPartial.
  ///
  /// In zh, this message translates to:
  /// **'部分完成，有 {count} 个对象失败，可重试继续。'**
  String recoverPartial(int count);

  /// No description provided for @recoverPhaseConnecting.
  ///
  /// In zh, this message translates to:
  /// **'正在连接…'**
  String get recoverPhaseConnecting;

  /// No description provided for @recoverPhaseDone.
  ///
  /// In zh, this message translates to:
  /// **'恢复完成'**
  String get recoverPhaseDone;

  /// No description provided for @recoverPhaseDownloading.
  ///
  /// In zh, this message translates to:
  /// **'正在下载对象…'**
  String get recoverPhaseDownloading;

  /// No description provided for @recoverPhaseError.
  ///
  /// In zh, this message translates to:
  /// **'恢复失败'**
  String get recoverPhaseError;

  /// No description provided for @recoverPhaseListing.
  ///
  /// In zh, this message translates to:
  /// **'正在列出远端对象…'**
  String get recoverPhaseListing;

  /// No description provided for @recoverPhaseRebuilding.
  ///
  /// In zh, this message translates to:
  /// **'正在重建本地库…'**
  String get recoverPhaseRebuilding;

  /// No description provided for @recoverProgress.
  ///
  /// In zh, this message translates to:
  /// **'已完成 {done} / 共 {total}'**
  String recoverProgress(int done, int total);

  /// No description provided for @recoverRecordsRestored.
  ///
  /// In zh, this message translates to:
  /// **'已恢复记录：{count}'**
  String recoverRecordsRestored(int count);

  /// No description provided for @recoveryKeyCopied.
  ///
  /// In zh, this message translates to:
  /// **'恢复密钥已复制'**
  String get recoveryKeyCopied;

  /// No description provided for @recoveryKeyTitle.
  ///
  /// In zh, this message translates to:
  /// **'恢复密钥'**
  String get recoveryKeyTitle;

  /// No description provided for @recoveryKeyWarning.
  ///
  /// In zh, this message translates to:
  /// **'这是恢复密钥唯一的展示机会，请立即抄写或保存到安全的地方，关闭后无法再次查看。'**
  String get recoveryKeyWarning;

  /// No description provided for @remoteVersion.
  ///
  /// In zh, this message translates to:
  /// **'另一版本'**
  String get remoteVersion;

  /// No description provided for @removeCredentials.
  ///
  /// In zh, this message translates to:
  /// **'移除凭据'**
  String get removeCredentials;

  /// No description provided for @removeCredentialsConfirm.
  ///
  /// In zh, this message translates to:
  /// **'移除凭据将关闭同步并删除已保存的 WebDAV 账号密码，本地数据保留。确认吗？'**
  String get removeCredentialsConfirm;

  /// No description provided for @rename.
  ///
  /// In zh, this message translates to:
  /// **'改名'**
  String get rename;

  /// No description provided for @renameCategory.
  ///
  /// In zh, this message translates to:
  /// **'重命名'**
  String get renameCategory;

  /// No description provided for @reportIssue.
  ///
  /// In zh, this message translates to:
  /// **'反馈问题'**
  String get reportIssue;

  /// No description provided for @resolveSuccess.
  ///
  /// In zh, this message translates to:
  /// **'冲突已解决'**
  String get resolveSuccess;

  /// No description provided for @resolving.
  ///
  /// In zh, this message translates to:
  /// **'正在处理…'**
  String get resolving;

  /// No description provided for @restore.
  ///
  /// In zh, this message translates to:
  /// **'恢复'**
  String get restore;

  /// No description provided for @restoreBackup.
  ///
  /// In zh, this message translates to:
  /// **'恢复备份'**
  String get restoreBackup;

  /// No description provided for @restoreBackupSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'支持加密备份与 JSON 备份'**
  String get restoreBackupSubtitle;

  /// No description provided for @restoreDataTitle.
  ///
  /// In zh, this message translates to:
  /// **'要恢复数据吗？'**
  String get restoreDataTitle;

  /// No description provided for @retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @saveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败，点击重试'**
  String get saveFailed;

  /// No description provided for @savePhotoFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败，请重试'**
  String get savePhotoFailed;

  /// No description provided for @saveToGallery.
  ///
  /// In zh, this message translates to:
  /// **'保存到相册'**
  String get saveToGallery;

  /// No description provided for @saved.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get saved;

  /// No description provided for @savedToGallery.
  ///
  /// In zh, this message translates to:
  /// **'已保存到相册'**
  String get savedToGallery;

  /// No description provided for @saving.
  ///
  /// In zh, this message translates to:
  /// **'保存中…'**
  String get saving;

  /// No description provided for @search.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get search;

  /// No description provided for @searchEmpty.
  ///
  /// In zh, this message translates to:
  /// **'没有找到相关信息'**
  String get searchEmpty;

  /// No description provided for @searchEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'试试其他关键词，或清除搜索条件'**
  String get searchEmptyHint;

  /// No description provided for @searchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索标题、内容，支持拼音首字母'**
  String get searchHint;

  /// No description provided for @searchPromptEmpty.
  ///
  /// In zh, this message translates to:
  /// **'输入关键词搜索全部记录'**
  String get searchPromptEmpty;

  /// No description provided for @security.
  ///
  /// In zh, this message translates to:
  /// **'安全'**
  String get security;

  /// No description provided for @securityAndPrivacy.
  ///
  /// In zh, this message translates to:
  /// **'安全与隐私'**
  String get securityAndPrivacy;

  /// No description provided for @securityNotImplemented.
  ///
  /// In zh, this message translates to:
  /// **'安全功能将在后续版本推出'**
  String get securityNotImplemented;

  /// No description provided for @securityPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'安全'**
  String get securityPageTitle;

  /// No description provided for @selectAll.
  ///
  /// In zh, this message translates to:
  /// **'全选'**
  String get selectAll;

  /// No description provided for @selectCategory.
  ///
  /// In zh, this message translates to:
  /// **'选择分类'**
  String get selectCategory;

  /// No description provided for @selectTags.
  ///
  /// In zh, this message translates to:
  /// **'选择标签'**
  String get selectTags;

  /// No description provided for @selectedCount.
  ///
  /// In zh, this message translates to:
  /// **'已选 {count} 条'**
  String selectedCount(int count);

  /// No description provided for @setPin.
  ///
  /// In zh, this message translates to:
  /// **'设置 PIN'**
  String get setPin;

  /// No description provided for @setQuickAccess.
  ///
  /// In zh, this message translates to:
  /// **'设为常用'**
  String get setQuickAccess;

  /// No description provided for @setUp.
  ///
  /// In zh, this message translates to:
  /// **'去设置'**
  String get setUp;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @sharePhoto.
  ///
  /// In zh, this message translates to:
  /// **'分享照片'**
  String get sharePhoto;

  /// No description provided for @showNumberAction.
  ///
  /// In zh, this message translates to:
  /// **'显示号码'**
  String get showNumberAction;

  /// No description provided for @showPassword.
  ///
  /// In zh, this message translates to:
  /// **'显示密码'**
  String get showPassword;

  /// No description provided for @smartRecommend.
  ///
  /// In zh, this message translates to:
  /// **'智能推荐'**
  String get smartRecommend;

  /// No description provided for @sniffSaveAccount.
  ///
  /// In zh, this message translates to:
  /// **'存为网站账号'**
  String get sniffSaveAccount;

  /// No description provided for @sniffSaveAddress.
  ///
  /// In zh, this message translates to:
  /// **'存为地址'**
  String get sniffSaveAddress;

  /// No description provided for @sniffSaveId.
  ///
  /// In zh, this message translates to:
  /// **'存为证件'**
  String get sniffSaveId;

  /// No description provided for @sortRecentlyCreated.
  ///
  /// In zh, this message translates to:
  /// **'最近创建'**
  String get sortRecentlyCreated;

  /// No description provided for @sortRecentlyEdited.
  ///
  /// In zh, this message translates to:
  /// **'最近编辑'**
  String get sortRecentlyEdited;

  /// No description provided for @sortTitle.
  ///
  /// In zh, this message translates to:
  /// **'排序'**
  String get sortTitle;

  /// No description provided for @sortTitleAZ.
  ///
  /// In zh, this message translates to:
  /// **'标题 A–Z'**
  String get sortTitleAZ;

  /// No description provided for @speedDialAddress.
  ///
  /// In zh, this message translates to:
  /// **'地址'**
  String get speedDialAddress;

  /// No description provided for @speedDialBlank.
  ///
  /// In zh, this message translates to:
  /// **'空白速记'**
  String get speedDialBlank;

  /// No description provided for @speedDialId.
  ///
  /// In zh, this message translates to:
  /// **'证件'**
  String get speedDialId;

  /// No description provided for @speedDialPassword.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get speedDialPassword;

  /// No description provided for @startOver.
  ///
  /// In zh, this message translates to:
  /// **'重新开始'**
  String get startOver;

  /// No description provided for @startOverConfirm.
  ///
  /// In zh, this message translates to:
  /// **'本机无法读取的数据将被清除，无法撤销。'**
  String get startOverConfirm;

  /// No description provided for @startRecovery.
  ///
  /// In zh, this message translates to:
  /// **'开始恢复'**
  String get startRecovery;

  /// No description provided for @startSync.
  ///
  /// In zh, this message translates to:
  /// **'开始同步'**
  String get startSync;

  /// No description provided for @startSyncSetup.
  ///
  /// In zh, this message translates to:
  /// **'开始同步设置'**
  String get startSyncSetup;

  /// No description provided for @startupFailed.
  ///
  /// In zh, this message translates to:
  /// **'启动失败'**
  String get startupFailed;

  /// No description provided for @sync.
  ///
  /// In zh, this message translates to:
  /// **'同步'**
  String get sync;

  /// No description provided for @syncCompleted.
  ///
  /// In zh, this message translates to:
  /// **'同步已完成'**
  String get syncCompleted;

  /// No description provided for @syncDirectory.
  ///
  /// In zh, this message translates to:
  /// **'同步目录'**
  String get syncDirectory;

  /// No description provided for @syncEngineWip.
  ///
  /// In zh, this message translates to:
  /// **'同步引擎开发中（阶段 C）'**
  String get syncEngineWip;

  /// No description provided for @syncNever.
  ///
  /// In zh, this message translates to:
  /// **'未同步'**
  String get syncNever;

  /// No description provided for @syncNotConfigured.
  ///
  /// In zh, this message translates to:
  /// **'尚未配置同步'**
  String get syncNotConfigured;

  /// No description provided for @syncNotImplemented.
  ///
  /// In zh, this message translates to:
  /// **'同步功能将在后续版本推出'**
  String get syncNotImplemented;

  /// No description provided for @syncNow.
  ///
  /// In zh, this message translates to:
  /// **'立即同步'**
  String get syncNow;

  /// No description provided for @syncStatusDisabled.
  ///
  /// In zh, this message translates to:
  /// **'未启用'**
  String get syncStatusDisabled;

  /// No description provided for @syncStatusEnabled.
  ///
  /// In zh, this message translates to:
  /// **'已启用'**
  String get syncStatusEnabled;

  /// No description provided for @syncStatusSyncing.
  ///
  /// In zh, this message translates to:
  /// **'正在同步…'**
  String get syncStatusSyncing;

  /// No description provided for @syncStatusUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'同步状态不可用'**
  String get syncStatusUnavailable;

  /// No description provided for @syncStatusUnavailableDesc.
  ///
  /// In zh, this message translates to:
  /// **'同步引擎正在接入，稍后再试。'**
  String get syncStatusUnavailableDesc;

  /// No description provided for @synced.
  ///
  /// In zh, this message translates to:
  /// **'已同步'**
  String get synced;

  /// Tooltip for home page sync badge when sync is healthy
  ///
  /// In zh, this message translates to:
  /// **'同步正常'**
  String get syncStatusOk;

  /// Tooltip for home page sync badge when last sync failed
  ///
  /// In zh, this message translates to:
  /// **'同步出错'**
  String get syncStatusError;

  /// No description provided for @syncedRecordCount.
  ///
  /// In zh, this message translates to:
  /// **'已同步 {synced} / 共 {total} 条记录'**
  String syncedRecordCount(int synced, int total);

  /// No description provided for @tagName.
  ///
  /// In zh, this message translates to:
  /// **'标签名称'**
  String get tagName;

  /// No description provided for @tags.
  ///
  /// In zh, this message translates to:
  /// **'标签'**
  String get tags;

  /// No description provided for @tagsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有标签'**
  String get tagsEmpty;

  /// No description provided for @takePhoto.
  ///
  /// In zh, this message translates to:
  /// **'拍照'**
  String get takePhoto;

  /// No description provided for @technicalDetails.
  ///
  /// In zh, this message translates to:
  /// **'技术详情'**
  String get technicalDetails;

  /// No description provided for @templateBlank.
  ///
  /// In zh, this message translates to:
  /// **'空白笔记'**
  String get templateBlank;

  /// No description provided for @templateBlankDesc.
  ///
  /// In zh, this message translates to:
  /// **'从空白开始自由记录'**
  String get templateBlankDesc;

  /// No description provided for @templateContact.
  ///
  /// In zh, this message translates to:
  /// **'联系人'**
  String get templateContact;

  /// No description provided for @templateContactDesc.
  ///
  /// In zh, this message translates to:
  /// **'姓名、电话、邮箱与地址'**
  String get templateContactDesc;

  /// No description provided for @templateIdDocument.
  ///
  /// In zh, this message translates to:
  /// **'证件'**
  String get templateIdDocument;

  /// No description provided for @templateIdDocumentDesc.
  ///
  /// In zh, this message translates to:
  /// **'身份证、驾驶证等证件照与号码，号码自动掩码'**
  String get templateIdDocumentDesc;

  /// No description provided for @templateIdea.
  ///
  /// In zh, this message translates to:
  /// **'灵感速记'**
  String get templateIdea;

  /// No description provided for @templateIdeaDesc.
  ///
  /// In zh, this message translates to:
  /// **'灵感、来源与下一步行动'**
  String get templateIdeaDesc;

  /// No description provided for @templatePassword.
  ///
  /// In zh, this message translates to:
  /// **'记密码'**
  String get templatePassword;

  /// No description provided for @templatePasswordDesc.
  ///
  /// In zh, this message translates to:
  /// **'网站、账号与密码，密码自动掩码'**
  String get templatePasswordDesc;

  /// No description provided for @templateSheetTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择模版'**
  String get templateSheetTitle;

  /// No description provided for @templateTodo.
  ///
  /// In zh, this message translates to:
  /// **'待办清单'**
  String get templateTodo;

  /// No description provided for @templateTodoDesc.
  ///
  /// In zh, this message translates to:
  /// **'复选框式待办事项'**
  String get templateTodoDesc;

  /// No description provided for @testConnection.
  ///
  /// In zh, this message translates to:
  /// **'测试连接'**
  String get testConnection;

  /// No description provided for @theme.
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get theme;

  /// No description provided for @themeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get themeLight;

  /// No description provided for @themeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get themeSystem;

  /// No description provided for @timeToday.
  ///
  /// In zh, this message translates to:
  /// **'今天 {time}'**
  String timeToday(String time);

  /// No description provided for @timeYesterday.
  ///
  /// In zh, this message translates to:
  /// **'昨天'**
  String get timeYesterday;

  /// No description provided for @timeout1Min.
  ///
  /// In zh, this message translates to:
  /// **'1 分钟'**
  String get timeout1Min;

  /// No description provided for @timeout5Min.
  ///
  /// In zh, this message translates to:
  /// **'5 分钟'**
  String get timeout5Min;

  /// No description provided for @timeoutImmediately.
  ///
  /// In zh, this message translates to:
  /// **'立即'**
  String get timeoutImmediately;

  /// No description provided for @titleHint.
  ///
  /// In zh, this message translates to:
  /// **'标题（可选）'**
  String get titleHint;

  /// No description provided for @today.
  ///
  /// In zh, this message translates to:
  /// **'今天'**
  String get today;

  /// No description provided for @todoProgress.
  ///
  /// In zh, this message translates to:
  /// **'已完成 {done} / {total}'**
  String todoProgress(int done, int total);

  /// No description provided for @trash.
  ///
  /// In zh, this message translates to:
  /// **'回收站'**
  String get trash;

  /// No description provided for @trashEmpty.
  ///
  /// In zh, this message translates to:
  /// **'回收站为空'**
  String get trashEmpty;

  /// No description provided for @uncategorized.
  ///
  /// In zh, this message translates to:
  /// **'未分类'**
  String get uncategorized;

  /// No description provided for @undoDelete.
  ///
  /// In zh, this message translates to:
  /// **'撤销'**
  String get undoDelete;

  /// No description provided for @unfavorite.
  ///
  /// In zh, this message translates to:
  /// **'取消收藏'**
  String get unfavorite;

  /// No description provided for @unlockAndJoin.
  ///
  /// In zh, this message translates to:
  /// **'解锁并加入'**
  String get unlockAndJoin;

  /// No description provided for @unlockApp.
  ///
  /// In zh, this message translates to:
  /// **'解锁随存'**
  String get unlockApp;

  /// No description provided for @unlockKeyPrompt.
  ///
  /// In zh, this message translates to:
  /// **'解锁密钥'**
  String get unlockKeyPrompt;

  /// No description provided for @unpinRecord.
  ///
  /// In zh, this message translates to:
  /// **'取消置顶'**
  String get unpinRecord;

  /// No description provided for @unsetQuickAccess.
  ///
  /// In zh, this message translates to:
  /// **'取消常用'**
  String get unsetQuickAccess;

  /// No description provided for @untitledRecord.
  ///
  /// In zh, this message translates to:
  /// **'未命名记录'**
  String get untitledRecord;

  /// No description provided for @updatedAt.
  ///
  /// In zh, this message translates to:
  /// **'更新于 {time}'**
  String updatedAt(String time);

  /// No description provided for @useBiometric.
  ///
  /// In zh, this message translates to:
  /// **'生物识别解锁'**
  String get useBiometric;

  /// No description provided for @usePassword.
  ///
  /// In zh, this message translates to:
  /// **'使用加密密码'**
  String get usePassword;

  /// No description provided for @useRecoveryKey.
  ///
  /// In zh, this message translates to:
  /// **'使用恢复密钥'**
  String get useRecoveryKey;

  /// No description provided for @username.
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get username;

  /// No description provided for @usernameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请填写用户名'**
  String get usernameRequired;

  /// No description provided for @vaultPassword.
  ///
  /// In zh, this message translates to:
  /// **'加密密码'**
  String get vaultPassword;

  /// No description provided for @vaultRecoveryKey.
  ///
  /// In zh, this message translates to:
  /// **'恢复密钥'**
  String get vaultRecoveryKey;

  /// No description provided for @version.
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get version;

  /// No description provided for @viewAction.
  ///
  /// In zh, this message translates to:
  /// **'查看'**
  String get viewAction;

  /// No description provided for @viewConflicts.
  ///
  /// In zh, this message translates to:
  /// **'查看冲突'**
  String get viewConflicts;

  /// No description provided for @viewPhoto.
  ///
  /// In zh, this message translates to:
  /// **'查看大图'**
  String get viewPhoto;

  /// No description provided for @webdavConnectionSettings.
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 连接配置'**
  String get webdavConnectionSettings;

  /// No description provided for @webdavSync.
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 同步'**
  String get webdavSync;

  /// No description provided for @webdavUrl.
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 地址'**
  String get webdavUrl;

  /// No description provided for @webdavUrlInvalid.
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 地址格式不正确'**
  String get webdavUrlInvalid;

  /// No description provided for @webdavUrlRequired.
  ///
  /// In zh, this message translates to:
  /// **'请填写 WebDAV 地址'**
  String get webdavUrlRequired;

  /// No description provided for @wizardConnectionDesc.
  ///
  /// In zh, this message translates to:
  /// **'将测试与 WebDAV 服务器的连接，并检查目录中是否已有同步库。'**
  String get wizardConnectionDesc;

  /// No description provided for @wizardCreating.
  ///
  /// In zh, this message translates to:
  /// **'正在创建同步库…'**
  String get wizardCreating;

  /// No description provided for @wizardDone.
  ///
  /// In zh, this message translates to:
  /// **'同步设置完成'**
  String get wizardDone;

  /// No description provided for @wizardDoneDesc.
  ///
  /// In zh, this message translates to:
  /// **'加密同步库已就绪，可以开始同步。'**
  String get wizardDoneDesc;

  /// No description provided for @wizardHasVaultDesc.
  ///
  /// In zh, this message translates to:
  /// **'该目录下已存在同步库，请输入加密密码或恢复密钥加入。'**
  String get wizardHasVaultDesc;

  /// No description provided for @wizardJoining.
  ///
  /// In zh, this message translates to:
  /// **'正在加入同步库…'**
  String get wizardJoining;

  /// No description provided for @wizardMergeCount.
  ///
  /// In zh, this message translates to:
  /// **'待同步内容：{count} 条'**
  String wizardMergeCount(int count);

  /// No description provided for @wizardMergeInfo.
  ///
  /// In zh, this message translates to:
  /// **'本地已有内容不会被远端直接替换；同步将合并两端数据，出现的冲突可稍后手动解决。'**
  String get wizardMergeInfo;

  /// No description provided for @wizardNoVaultDesc.
  ///
  /// In zh, this message translates to:
  /// **'该目录下没有同步库，可以创建一个新加密库。'**
  String get wizardNoVaultDesc;

  /// No description provided for @wizardStepConnection.
  ///
  /// In zh, this message translates to:
  /// **'连接测试'**
  String get wizardStepConnection;

  /// No description provided for @wizardStepMerge.
  ///
  /// In zh, this message translates to:
  /// **'合并确认'**
  String get wizardStepMerge;

  /// No description provided for @wizardStepSecurity.
  ///
  /// In zh, this message translates to:
  /// **'加密配置'**
  String get wizardStepSecurity;

  /// No description provided for @wizardStepVault.
  ///
  /// In zh, this message translates to:
  /// **'选择同步库'**
  String get wizardStepVault;

  /// No description provided for @wizardTestAndContinue.
  ///
  /// In zh, this message translates to:
  /// **'测试并继续'**
  String get wizardTestAndContinue;

  /// No description provided for @wizardTitle.
  ///
  /// In zh, this message translates to:
  /// **'同步设置向导'**
  String get wizardTitle;

  /// No description provided for @wrongPin.
  ///
  /// In zh, this message translates to:
  /// **'PIN 错误，请重试'**
  String get wrongPin;

  /// No description provided for @yesterday.
  ///
  /// In zh, this message translates to:
  /// **'昨天'**
  String get yesterday;

  /// No description provided for @zoomInAction.
  ///
  /// In zh, this message translates to:
  /// **'放大'**
  String get zoomInAction;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
