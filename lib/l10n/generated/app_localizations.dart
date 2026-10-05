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
    Locale('en')
  ];

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

  /// No description provided for @newRecord.
  ///
  /// In zh, this message translates to:
  /// **'新建记录'**
  String get newRecord;

  /// No description provided for @searchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索保存的信息'**
  String get searchHint;

  /// No description provided for @all.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get all;

  /// No description provided for @favorites.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get favorites;

  /// No description provided for @uncategorized.
  ///
  /// In zh, this message translates to:
  /// **'未分类'**
  String get uncategorized;

  /// No description provided for @untitledRecord.
  ///
  /// In zh, this message translates to:
  /// **'未命名记录'**
  String get untitledRecord;

  /// No description provided for @saving.
  ///
  /// In zh, this message translates to:
  /// **'保存中'**
  String get saving;

  /// No description provided for @saved.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get saved;

  /// No description provided for @saveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败，重试'**
  String get saveFailed;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @appearance.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get appearance;

  /// No description provided for @data.
  ///
  /// In zh, this message translates to:
  /// **'数据'**
  String get data;

  /// No description provided for @about.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get about;

  /// No description provided for @theme.
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get theme;

  /// No description provided for @themeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get themeDark;

  /// No description provided for @themeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get themeSystem;

  /// No description provided for @categories.
  ///
  /// In zh, this message translates to:
  /// **'分类'**
  String get categories;

  /// No description provided for @tags.
  ///
  /// In zh, this message translates to:
  /// **'标签'**
  String get tags;

  /// No description provided for @addCategory.
  ///
  /// In zh, this message translates to:
  /// **'新增分类'**
  String get addCategory;

  /// No description provided for @editCategory.
  ///
  /// In zh, this message translates to:
  /// **'编辑分类'**
  String get editCategory;

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

  /// No description provided for @categoryName.
  ///
  /// In zh, this message translates to:
  /// **'分类名称'**
  String get categoryName;

  /// No description provided for @categoryColor.
  ///
  /// In zh, this message translates to:
  /// **'分类颜色'**
  String get categoryColor;

  /// No description provided for @addTag.
  ///
  /// In zh, this message translates to:
  /// **'新增标签'**
  String get addTag;

  /// No description provided for @editTag.
  ///
  /// In zh, this message translates to:
  /// **'编辑标签'**
  String get editTag;

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

  /// No description provided for @tagName.
  ///
  /// In zh, this message translates to:
  /// **'标签名称'**
  String get tagName;

  /// No description provided for @favorite.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get favorite;

  /// No description provided for @unfavorite.
  ///
  /// In zh, this message translates to:
  /// **'取消收藏'**
  String get unfavorite;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @restore.
  ///
  /// In zh, this message translates to:
  /// **'恢复'**
  String get restore;

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

  /// No description provided for @recordsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有记录'**
  String get recordsEmpty;

  /// No description provided for @recordsEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'点击右下角新建记录'**
  String get recordsEmptyHint;

  /// No description provided for @searchEmpty.
  ///
  /// In zh, this message translates to:
  /// **'没有找到相关记录'**
  String get searchEmpty;

  /// No description provided for @searchEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'试试其他关键词，或清除筛选条件'**
  String get searchEmptyHint;

  /// No description provided for @clearFilter.
  ///
  /// In zh, this message translates to:
  /// **'清除筛选'**
  String get clearFilter;

  /// No description provided for @backup.
  ///
  /// In zh, this message translates to:
  /// **'备份'**
  String get backup;

  /// No description provided for @export.
  ///
  /// In zh, this message translates to:
  /// **'导出'**
  String get export;

  /// No description provided for @importData.
  ///
  /// In zh, this message translates to:
  /// **'导入'**
  String get importData;

  /// No description provided for @exportJson.
  ///
  /// In zh, this message translates to:
  /// **'导出 JSON 备份'**
  String get exportJson;

  /// No description provided for @exportMarkdownZip.
  ///
  /// In zh, this message translates to:
  /// **'导出 Markdown ZIP'**
  String get exportMarkdownZip;

  /// No description provided for @exportTxt.
  ///
  /// In zh, this message translates to:
  /// **'导出 TXT'**
  String get exportTxt;

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

  /// No description provided for @importPreview.
  ///
  /// In zh, this message translates to:
  /// **'即将导入 {count} 条记录'**
  String importPreview(int count);

  /// No description provided for @importSuccess.
  ///
  /// In zh, this message translates to:
  /// **'成功导入 {count} 条记录'**
  String importSuccess(int count);

  /// No description provided for @importFailed.
  ///
  /// In zh, this message translates to:
  /// **'导入失败：{error}'**
  String importFailed(String error);

  /// No description provided for @exportSuccess.
  ///
  /// In zh, this message translates to:
  /// **'导出成功'**
  String get exportSuccess;

  /// No description provided for @exportFailed.
  ///
  /// In zh, this message translates to:
  /// **'导出失败：{error}'**
  String exportFailed(String error);

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确认'**
  String get confirm;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @rename.
  ///
  /// In zh, this message translates to:
  /// **'改名'**
  String get rename;

  /// No description provided for @ok.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get ok;

  /// No description provided for @titleHint.
  ///
  /// In zh, this message translates to:
  /// **'标题（可不填）'**
  String get titleHint;

  /// No description provided for @bodyHint.
  ///
  /// In zh, this message translates to:
  /// **'正文'**
  String get bodyHint;

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

  /// No description provided for @maxTagsReached.
  ///
  /// In zh, this message translates to:
  /// **'最多添加 10 个标签'**
  String get maxTagsReached;

  /// No description provided for @duplicateName.
  ///
  /// In zh, this message translates to:
  /// **'该名称已存在'**
  String get duplicateName;

  /// No description provided for @recordDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已移至回收站'**
  String get recordDeleted;

  /// No description provided for @undoDelete.
  ///
  /// In zh, this message translates to:
  /// **'撤销'**
  String get undoDelete;

  /// No description provided for @selectAll.
  ///
  /// In zh, this message translates to:
  /// **'全选'**
  String get selectAll;

  /// No description provided for @batchFavorite.
  ///
  /// In zh, this message translates to:
  /// **'批量收藏'**
  String get batchFavorite;

  /// No description provided for @batchDelete.
  ///
  /// In zh, this message translates to:
  /// **'批量删除'**
  String get batchDelete;

  /// No description provided for @batchCategorize.
  ///
  /// In zh, this message translates to:
  /// **'批量分类'**
  String get batchCategorize;

  /// No description provided for @selectedCount.
  ///
  /// In zh, this message translates to:
  /// **'已选 {count} 条'**
  String selectedCount(int count);

  /// No description provided for @syncNotImplemented.
  ///
  /// In zh, this message translates to:
  /// **'同步功能将在后续版本推出'**
  String get syncNotImplemented;

  /// No description provided for @securityNotImplemented.
  ///
  /// In zh, this message translates to:
  /// **'安全功能将在后续版本推出'**
  String get securityNotImplemented;

  /// No description provided for @version.
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get version;

  /// No description provided for @bodyLimit.
  ///
  /// In zh, this message translates to:
  /// **'正文较长（超过 1 MiB），建议拆分'**
  String get bodyLimit;

  /// No description provided for @modified.
  ///
  /// In zh, this message translates to:
  /// **'修改于 {time}'**
  String modified(String time);
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
      'that was used.');
}
