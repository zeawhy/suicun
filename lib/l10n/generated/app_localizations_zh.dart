// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get about => '关于';

  @override
  String get accountPasswordLabel => '账号密码';

  @override
  String get addCategory => '新增分类';

  @override
  String get addKeyword => '添加关键词';

  @override
  String get addTag => '新增标签';

  @override
  String get addTags => '添加标签';

  @override
  String get addressInfoLabel => '地址信息';

  @override
  String get all => '全部';

  @override
  String get allowIdScreenshots => '允许截屏证件页面';

  @override
  String get appLock => '应用锁';

  @override
  String get appLockStatusDisabled => '未开启';

  @override
  String get appLockStatusEnabled => '已开启';

  @override
  String get appLocked => '随存已锁定';

  @override
  String get appName => '随存';

  @override
  String get appTagline => '保存以后还要找的信息';

  @override
  String get appearance => '外观';

  @override
  String get autoSaveHint => '自动保存，无需手动点击保存。';

  @override
  String get backSide => '背面';

  @override
  String get backToSync => '返回同步设置';

  @override
  String get backup => '备份';

  @override
  String get backupAndExport => '备份与导出';

  @override
  String get backupAndSync => '备份与同步';

  @override
  String get backupPassword => '备份密码';

  @override
  String get backupPasswordHint => '换设备恢复需要此密码，请妥善保存';

  @override
  String backupPhotoSizeWarn(int count, String size) {
    return '备份包含 $count 张证件照片，文件约 $size';
  }

  @override
  String get backupReminderText => '你的数据只保存在这台手机上，建议开启加密备份或同步。';

  @override
  String get batchCategorize => '批量分类';

  @override
  String get batchDelete => '批量删除';

  @override
  String get batchFavorite => '批量收藏';

  @override
  String get bodyHint => '写下以后还要找的信息……';

  @override
  String get bodyLimit => '正文较长（超过 1 MiB），建议拆分';

  @override
  String get cameraPermissionDenied => '需要相机权限才能拍照';

  @override
  String get cameraRationaleMessage => '拍照用于拍摄证件照片，仅保存到本应用私有目录';

  @override
  String get cameraRationaleTitle => '相机权限说明';

  @override
  String get cancel => '取消';

  @override
  String get cantReadData => '无法读取本机数据';

  @override
  String get cantReadDataDesc =>
      '这通常发生在换机、刷机或系统数据迁移之后。你可以重新开始，然后从加密备份或 WebDAV 同步恢复数据。';

  @override
  String get categories => '分类';

  @override
  String get categoriesEmpty => '还没有分类';

  @override
  String get category => '分类';

  @override
  String get categoryColor => '分类颜色';

  @override
  String get categoryName => '分类名称';

  @override
  String get changeCategory => '修改分类';

  @override
  String get changePin => '修改 PIN';

  @override
  String get chooseFromGallery => '从相册选择';

  @override
  String get choosePhotoSide => '选择照片';

  @override
  String get clearAllData => '清除全部数据';

  @override
  String get clearAllDataConfirmContent => '此操作无法撤销，所有本地记录及证件照片将被彻底删除。';

  @override
  String get clearAllDataConfirmTitle => '最终确认';

  @override
  String get clearAllDataSuccess => '已清除全部数据';

  @override
  String get clearAllDataWarningContent => '将删除所有记录、分类、标签及证件照片，不可恢复。';

  @override
  String get clearAllDataWarningTitle => '清除全部数据？';

  @override
  String get clearFilter => '清除筛选';

  @override
  String get clearRecentSearches => '清空最近搜索';

  @override
  String get clipboardSniffSubtitle => '点击 + 时识别证件号、地址、链接';

  @override
  String get clipboardSniffTitle => '剪贴板识别';

  @override
  String get closeAction => '关闭';

  @override
  String get configSaved => '配置已保存';

  @override
  String get confirm => '确认';

  @override
  String get confirmClearAllData => '我确认要删除全部数据';

  @override
  String get confirmPassword => '确认密码';

  @override
  String get confirmVaultPassword => '确认加密密码';

  @override
  String conflictCount(int count) {
    return '冲突：$count';
  }

  @override
  String get conflictHistoryNote => '被弃用的版本会保留到历史记录，不会被删除。';

  @override
  String get conflictTypeCategory => '分类';

  @override
  String get conflictTypeRecord => '记录';

  @override
  String get conflictTypeTag => '标签';

  @override
  String get conflictsEmpty => '没有未解决的冲突';

  @override
  String get conflictsTitle => '同步冲突';

  @override
  String get connectAndSync => '连接并同步';

  @override
  String get connectWebdavSync => '连接 WebDAV 同步';

  @override
  String connectionFailed(String error) {
    return '连接失败：$error';
  }

  @override
  String get connectionSuccess => '连接成功';

  @override
  String get continueAction => '继续';

  @override
  String get copied => '已复制';

  @override
  String get copiedToClipboardMsg => '已复制到剪贴板';

  @override
  String get docNumberCopied => '已复制证件号码';

  @override
  String get copy => '复制';

  @override
  String get copyNumberAction => '复制号码';

  @override
  String get copyRecoveryKey => '复制';

  @override
  String get createNewVault => '创建新库';

  @override
  String get createdAtPrefix => '创建于';

  @override
  String get dangerousOperations => '危险操作';

  @override
  String get data => '数据';

  @override
  String get settingsGroupIdDocuments => '证件';

  @override
  String get defaultCategoryIdeas => '灵感';

  @override
  String get defaultCategoryLife => '生活';

  @override
  String get defaultCategoryStudy => '学习';

  @override
  String get defaultCategoryTodo => '待办';

  @override
  String get defaultCategoryWork => '工作';

  @override
  String get delete => '删除';

  @override
  String get deleteCategory => '删除分类';

  @override
  String get deleteCategoryConfirm => '删除后，该分类下的记录将转为未分类。确认删除吗？';

  @override
  String get deleteRecordConfirm => '删除后可在回收站找回。';

  @override
  String get deleteRecordTitle => '删除这条记录？';

  @override
  String get deleteTag => '删除标签';

  @override
  String get deleteTagConfirm => '删除后，相关记录仍然保留，只解除标签关联。确认删除吗？';

  @override
  String get directoryInvalid => '同步目录须以 / 开头';

  @override
  String get disableSync => '关闭同步';

  @override
  String get disableSyncConfirm => '关闭同步将停止网络任务，本地数据保留。确认吗？';

  @override
  String get docTypeCustomHint => '请输入证件类型';

  @override
  String get docTypeDriverLicense => '驾驶证';

  @override
  String get docTypeHmtPermit => '港澳通行证';

  @override
  String get docTypeIdCard => '身份证';

  @override
  String get docTypeOther => '其他';

  @override
  String get docTypePassport => '护照';

  @override
  String get docTypePropertyCert => '房产证';

  @override
  String get docTypeSocialCard => '社保卡';

  @override
  String get docTypeVehicleLicense => '行驶证';

  @override
  String get duplicateName => '该名称已存在';

  @override
  String get e2eDesc => '内容加密后上传到你的存储空间。';

  @override
  String get e2eEnabled => '已开启';

  @override
  String get e2eEncryption => '端到端加密';

  @override
  String get e2eWipDialog => '端到端加密将在同步引擎（阶段 C）上线时启用。';

  @override
  String get editCategory => '编辑分类';

  @override
  String get editInfo => '编辑信息';

  @override
  String get editTag => '编辑标签';

  @override
  String get enableAppLock => '启用应用锁';

  @override
  String get encryptedBackup => '加密备份';

  @override
  String get encryptionOn => '本地数据库已加密';

  @override
  String get encryptionOnDesc => '数据库使用随机密钥加密，密钥保存在系统安全存储';

  @override
  String get enterKeyPassword => '输入密钥加密密码';

  @override
  String get enterPin => '输入 PIN 解锁';

  @override
  String get existingVaultJoined => '检测到已有同步库，已为你加入';

  @override
  String get export => '导出';

  @override
  String get exportEncryptedBackup => '导出加密备份';

  @override
  String get exportEncryptedBackupRecommended => '导出加密备份（推荐）';

  @override
  String get exportEncryptedBackupSubtitle => '需设置密码，换设备恢复时使用';

  @override
  String exportFailed(String error) {
    return '导出失败：$error';
  }

  @override
  String get exportJson => '导出 JSON 备份';

  @override
  String get exportJsonSubtitle => '明文，任何人可读取';

  @override
  String get exportJsonUnencrypted => '导出 JSON（未加密）';

  @override
  String get exportMarkdownZip => '导出 Markdown ZIP';

  @override
  String get exportOtherFormats => '导出为其他格式';

  @override
  String get exportPlainNoPhotos => '明文导出不包含证件照片';

  @override
  String get exportSuccess => '导出成功';

  @override
  String get exportTxt => '导出 TXT';

  @override
  String get favorite => '收藏';

  @override
  String get favoriteFailed => '收藏失败，请重试';

  @override
  String get favorites => '收藏';

  @override
  String get fieldAddress => '地址';

  @override
  String get fieldDocName => '姓名';

  @override
  String get fieldDocNumber => '证件号码';

  @override
  String get fieldDocType => '证件类型';

  @override
  String get fieldEmail => '邮箱';

  @override
  String get fieldIdea => '灵感';

  @override
  String get fieldName => '姓名';

  @override
  String get fieldNextAction => '下一步行动';

  @override
  String get fieldNotes => '备注';

  @override
  String get fieldPassword => '密码';

  @override
  String get fieldPhone => '电话';

  @override
  String get fieldPhotoBack => '证件照片反面';

  @override
  String get fieldPhotoFront => '证件照片正面';

  @override
  String get fieldSource => '来源';

  @override
  String get fieldUsername => '用户名 / 邮箱';

  @override
  String get fieldValidUntil => '有效期至';

  @override
  String get fieldWebsite => '网站 / 应用';

  @override
  String get filterEmpty => '该筛选下没有记录';

  @override
  String get filterEmptyHint => '试试其他分类，或清除筛选条件';

  @override
  String get formatBold => '加粗';

  @override
  String get formatBullet => '无序列表';

  @override
  String get formatCheckbox => '勾选框';

  @override
  String get formatHeading => '标题';

  @override
  String get frontSide => '正面';

  @override
  String get fullBackup => '完整备份';

  @override
  String get galleryPermissionMessage => '保存证件照片到系统相册需要相册权限，照片仅保存到本地相册';

  @override
  String get galleryPermissionTitle => '相册权限说明';

  @override
  String get goToWebdavSettings => '前往 WebDAV 设置';

  @override
  String get hideNumberAction => '隐藏号码';

  @override
  String get hidePassword => '隐藏密码';

  @override
  String get iHaveSavedPassword => '我已妥善保存加密密码';

  @override
  String get idCardBackPhoto => '背面照片';

  @override
  String get idCardFlipBack => '翻回正面';

  @override
  String get idCardFrontPhoto => '正面照片';

  @override
  String get idCardHintFlip => '点击卡片翻面 · 长按复制号码';

  @override
  String get idCardHintNoFlip => '长按卡片复制号码';

  @override
  String get idCardMoreActions => '更多操作';

  @override
  String get idCardTapToReveal => '点击查看';

  @override
  String idCardValidUntil(String date) {
    return '有效期至 $date';
  }

  @override
  String get idDocumentInfo => '证件信息';

  @override
  String get idExpired => '已过期';

  @override
  String get idExpiringSoon => '即将到期';

  @override
  String get idFieldExpiryDate => '有效期至';

  @override
  String get idFieldIssueDate => '签发日期';

  @override
  String get idFieldIssuingCountry => '签发国家';

  @override
  String get idFieldName => '姓名';

  @override
  String get idFieldNote => '备注';

  @override
  String get idFieldNumber => '证件号码';

  @override
  String get idFieldType => '证件类型';

  @override
  String get idNoExpiry => '长期';

  @override
  String get idNumberCopied => '证件号码已复制';

  @override
  String get idNumberCopiedMsg => '证件号码已复制到剪贴板';

  @override
  String idNumberLastDigits(String digits) {
    return '尾号 $digits';
  }

  @override
  String get idOriginalType => '原类型';

  @override
  String get idPhotoAdd => '添加照片';

  @override
  String get idPhotoBack => '反面照片';

  @override
  String get idPhotoFront => '正面照片';

  @override
  String get idPhotoPick => '从相册选择';

  @override
  String get idPhotoRemove => '删除';

  @override
  String get idPhotoReplace => '更换';

  @override
  String get idPhotoTake => '拍照';

  @override
  String get idTypeCnResidentId => '中国居民身份证';

  @override
  String get idTypeDriverLicense => '驾驶证';

  @override
  String get idTypeGroupChina => '中国证件';

  @override
  String get idTypeHealthInsurance => '医保卡';

  @override
  String get idTypeHkMoPermit => '港澳通行证';

  @override
  String get idTypeNationalId => '身份证';

  @override
  String get idTypeOther => '其他证件';

  @override
  String get idTypePassport => '护照';

  @override
  String get idTypeResidencePermit => '居留卡';

  @override
  String get idTypeSocialSecurity => '社保卡';

  @override
  String get idTypeStudentId => '学生证';

  @override
  String get idTypeTwPermit => '台湾通行证';

  @override
  String get importData => '导入';

  @override
  String get importEncryptedBackup => '导入加密备份';

  @override
  String importFailed(String error) {
    return '导入失败：$error';
  }

  @override
  String get importJson => '从 JSON 恢复';

  @override
  String get importMarkdown => '导入 Markdown/TXT';

  @override
  String get importMarkdownOrTxt => '导入 Markdown / TXT';

  @override
  String importPreview(int count) {
    return '即将导入 $count 条记录';
  }

  @override
  String get importSectionTitle => '导入';

  @override
  String importSuccess(int count) {
    return '成功导入 $count 条记录';
  }

  @override
  String infoCount(int count) {
    return '$count 条信息';
  }

  @override
  String get joinExistingVault => '加入已有库';

  @override
  String get keepBoth => '分别保留';

  @override
  String get keepLocal => '保留本机版本';

  @override
  String get keepPasswordSafe => '请妥善保管加密密码：丢失后无法找回，WebDAV 账号密码不能恢复笔记内容。';

  @override
  String get keepRemote => '保留另一版本';

  @override
  String keywordCount(int count) {
    return '$count 个关键词';
  }

  @override
  String get keywordHint => '输入关键词，回车添加';

  @override
  String get keywords => '关键词';

  @override
  String get keywordsEmpty => '暂无关键词，添加后可自动推荐分类';

  @override
  String get landscapeAction => '横屏';

  @override
  String lastBackup(String time) {
    return '上次备份：$time';
  }

  @override
  String lastSuccess(String time) {
    return '上次成功：$time';
  }

  @override
  String get lastSuccessNever => '从未成功同步';

  @override
  String get lastSync => '上次同步';

  @override
  String lastSyncTime(String time) {
    return '上次同步时间：$time';
  }

  @override
  String lastSyncToday(String time) {
    return '今天 $time';
  }

  @override
  String get later => '稍后';

  @override
  String get linkCopied => '已复制链接';

  @override
  String get localVersion => '本机版本';

  @override
  String get lockTimeout => '后台锁定超时';

  @override
  String lockedKeysNotice(int count) {
    return '有 $count 把密钥未解锁，部分内容暂时无法显示';
  }

  @override
  String lockoutTryLater(Object seconds) {
    return '尝试次数过多，请 $seconds 秒后再试';
  }

  @override
  String get manage => '管理';

  @override
  String get manageCategories => '管理分类';

  @override
  String get manageKeywords => '管理关键词';

  @override
  String get manualMerge => '手动合并';

  @override
  String get maxTagsReached => '最多添加 10 个标签';

  @override
  String get memoNoteLabel => '备忘笔记';

  @override
  String get mergeBodyHint => '合并后的正文';

  @override
  String get mergeDialogTitle => '手动合并';

  @override
  String get mergeTitleHint => '合并后的标题';

  @override
  String get migrationBackupAndMigrate => '备份并迁移';

  @override
  String get migrationBody => '旧目录原样保留作备份，迁移为一次性拷贝。迁移后可使用新协议进行无冲突追加同步。';

  @override
  String get migrationTitle => '发现旧协议同步库';

  @override
  String modified(String time) {
    return '修改于 $time';
  }

  @override
  String get multiSelectActions => '多选操作';

  @override
  String get myRecords => '我的信息';

  @override
  String get newInfo => '新建信息';

  @override
  String get newRecord => '新建记录';

  @override
  String get newVaultPassword => '新库加密密码';

  @override
  String get noIdNumberRecorded => '未记录证件号码';

  @override
  String get noPhotoOrNumber => '暂无证件照片与号码';

  @override
  String get photoNotOnDevice => '照片未保存在此设备';

  @override
  String get notBackedUpYet => '尚未备份';

  @override
  String get notFilled => '未填写';

  @override
  String get notYetInput => '尚未输入';

  @override
  String get ok => '确定';

  @override
  String get onboardingClipboardBody =>
      '复制证件号、地址或网址后，点「+」时随存会提示你一键保存。内容只在本机识别，不会上传。';

  @override
  String get onboardingClipboardEnable => '开启';

  @override
  String get onboardingClipboardFooter => '可随时在 设置 › 安全与隐私 中更改';

  @override
  String get onboardingClipboardNotNow => '暂不';

  @override
  String get onboardingClipboardTitle => '开启剪贴板识别？';

  @override
  String get openSettings => '去设置';

  @override
  String get password => '密码';

  @override
  String get passwordChangeDeferred => '密码修改功能暂未开放，普通同步不受影响';

  @override
  String get passwordCopied => '密码已复制';

  @override
  String get passwordMismatch => '两次输入的密码不一致';

  @override
  String get passwordRequired => '请填写密码';

  @override
  String get passwordStrengthFair => '密码强度：中';

  @override
  String get passwordStrengthStrong => '密码强度：强';

  @override
  String get passwordStrengthWeak => '密码强度：弱（建议 12 位以上，混合字母、数字和符号）';

  @override
  String get passwordTooShort => '密码至少 8 位';

  @override
  String pendingCount(int count) {
    return '待上传：$count';
  }

  @override
  String get pendingUpload => '待上传';

  @override
  String get permanentDelete => '彻底删除';

  @override
  String get permanentDeleteConfirm => '彻底删除后无法恢复。确认吗？';

  @override
  String get photoNotOnThisDevice => '照片未保存在此设备';

  @override
  String get pinLabel => 'PIN';

  @override
  String get pinNotSet => '未设置';

  @override
  String get pinRecord => '置顶';

  @override
  String get pinSaved => 'PIN 已保存';

  @override
  String get pinSet => '已设置';

  @override
  String get pinTooShort => 'PIN 至少 4 位';

  @override
  String get plaintextExportConfirm => '导出的文件未加密，包含证件号和密码等敏感信息。确定继续？';

  @override
  String get plaintextExportConfirmTitle => '未加密导出确认';

  @override
  String get presentAutoBrightnessSubtitle => '方便他人查看或扫码';

  @override
  String get presentAutoBrightnessTitle => '全屏查看时调高亮度';

  @override
  String get presentBrightness => '亮度';

  @override
  String get presentDocument => '出示证件';

  @override
  String get presentIdDocument => '出示证件';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get probeInvalidConfig => '配置不完整';

  @override
  String get probeNotFound => '服务器上找不到该目录';

  @override
  String get probeNotHttps => '仅支持 HTTPS 地址';

  @override
  String get probeServerError => '服务器错误';

  @override
  String get probeTimeout => '连接超时';

  @override
  String get probeTls => 'TLS 握手失败，请检查地址或证书';

  @override
  String get probeUnauthorized => '用户名或密码错误';

  @override
  String get probeUnknown => '未知错误';

  @override
  String get probeUnreachable => '无法连接到服务器';

  @override
  String get quickAccessAdded => '已设为常用';

  @override
  String get quickAccessHint => '长按任意记录可设为常用';

  @override
  String get quickAccessLimitReached => '常用最多只能添加 6 个';

  @override
  String get quickAccessRemoved => '已取消常用';

  @override
  String get quickAccessTitle => '常用';

  @override
  String get quickAdd => '快速添加';

  @override
  String get quickAddressCopied => '已复制地址到剪贴板';

  @override
  String get quickPasswordCopied => '已复制密码到剪贴板';

  @override
  String get recentlyUsed => '最近使用';

  @override
  String recordCount(int count) {
    return '$count 条记录';
  }

  @override
  String get recordDeleted => '已移至回收站';

  @override
  String get recordTitleContact => '联系人记录';

  @override
  String get recordTitleIdDocument => '证件记录';

  @override
  String get recordTitleIdea => '灵感记录';

  @override
  String get recordTitleNote => '备忘记录';

  @override
  String get recordTitlePassword => '密码记录';

  @override
  String get recordTitleTodo => '待办记录';

  @override
  String get recordsEmpty => '还没有保存的信息';

  @override
  String get recordsEmptyHint => '点击下方「＋ 新建信息」开始保存';

  @override
  String get recoverDesc =>
      '在新设备上从 WebDAV 下载已上传的数据，重建本地库。只能恢复已成功上传的数据；尚未上传的离线编辑无法找回。';

  @override
  String recoverFailedObjects(int count) {
    return '失败对象：$count';
  }

  @override
  String get recoverFromWebdav => '从 WebDAV 恢复';

  @override
  String recoverPartial(int count) {
    return '部分完成，有 $count 个对象失败，可重试继续。';
  }

  @override
  String get recoverPhaseConnecting => '正在连接…';

  @override
  String get recoverPhaseDone => '恢复完成';

  @override
  String get recoverPhaseDownloading => '正在下载对象…';

  @override
  String get recoverPhaseError => '恢复失败';

  @override
  String get recoverPhaseListing => '正在列出远端对象…';

  @override
  String get recoverPhaseRebuilding => '正在重建本地库…';

  @override
  String recoverProgress(int done, int total) {
    return '已完成 $done / 共 $total';
  }

  @override
  String recoverRecordsRestored(int count) {
    return '已恢复记录：$count';
  }

  @override
  String get recoveryKeyCopied => '恢复密钥已复制';

  @override
  String get recoveryKeyTitle => '恢复密钥';

  @override
  String get recoveryKeyWarning => '这是恢复密钥唯一的展示机会，请立即抄写或保存到安全的地方，关闭后无法再次查看。';

  @override
  String get remoteVersion => '另一版本';

  @override
  String get removeCredentials => '移除凭据';

  @override
  String get removeCredentialsConfirm =>
      '移除凭据将关闭同步并删除已保存的 WebDAV 账号密码，本地数据保留。确认吗？';

  @override
  String get rename => '改名';

  @override
  String get renameCategory => '重命名';

  @override
  String get reportIssue => '反馈问题';

  @override
  String get resolveSuccess => '冲突已解决';

  @override
  String get resolving => '正在处理…';

  @override
  String get restore => '恢复';

  @override
  String get restoreBackup => '恢复备份';

  @override
  String get restoreBackupSubtitle => '支持加密备份与 JSON 备份';

  @override
  String get restoreDataTitle => '要恢复数据吗？';

  @override
  String get retry => '重试';

  @override
  String get save => '保存';

  @override
  String get saveFailed => '保存失败，点击重试';

  @override
  String get savePhotoFailed => '保存失败，请重试';

  @override
  String get saveToGallery => '保存到相册';

  @override
  String get saved => '已保存';

  @override
  String get savedToGallery => '已保存到相册';

  @override
  String get saving => '保存中…';

  @override
  String get search => '搜索';

  @override
  String get searchEmpty => '没有找到相关信息';

  @override
  String get searchEmptyHint => '试试其他关键词，或清除搜索条件';

  @override
  String get searchHint => '搜索标题、内容，支持拼音首字母';

  @override
  String get searchPromptEmpty => '输入关键词搜索全部记录';

  @override
  String get security => '安全';

  @override
  String get securityAndPrivacy => '安全与隐私';

  @override
  String get securityNotImplemented => '安全功能将在后续版本推出';

  @override
  String get securityPageTitle => '安全';

  @override
  String get selectAll => '全选';

  @override
  String get selectCategory => '选择分类';

  @override
  String get selectTags => '选择标签';

  @override
  String selectedCount(int count) {
    return '已选 $count 条';
  }

  @override
  String get setPin => '设置 PIN';

  @override
  String get setQuickAccess => '设为常用';

  @override
  String get setUp => '去设置';

  @override
  String get settings => '设置';

  @override
  String get sharePhoto => '分享照片';

  @override
  String get showNumberAction => '显示号码';

  @override
  String get showPassword => '显示密码';

  @override
  String get smartRecommend => '智能推荐';

  @override
  String get sniffSaveAccount => '存为网站账号';

  @override
  String get sniffSaveAddress => '存为地址';

  @override
  String get sniffSaveId => '存为证件';

  @override
  String get sortRecentlyCreated => '最近创建';

  @override
  String get sortRecentlyEdited => '最近编辑';

  @override
  String get sortTitle => '排序';

  @override
  String get sortTitleAZ => '标题 A–Z';

  @override
  String get speedDialAddress => '地址';

  @override
  String get speedDialBlank => '空白速记';

  @override
  String get speedDialId => '证件';

  @override
  String get speedDialPassword => '密码';

  @override
  String get startOver => '重新开始';

  @override
  String get startOverConfirm => '本机无法读取的数据将被清除，无法撤销。';

  @override
  String get startRecovery => '开始恢复';

  @override
  String get startSync => '开始同步';

  @override
  String get startSyncSetup => '开始同步设置';

  @override
  String get startupFailed => '启动失败';

  @override
  String get sync => '同步';

  @override
  String get syncCompleted => '同步已完成';

  @override
  String get syncDirectory => '同步目录';

  @override
  String get syncEngineWip => '同步引擎开发中（阶段 C）';

  @override
  String get syncNever => '未同步';

  @override
  String get syncNotConfigured => '尚未配置同步';

  @override
  String get syncNotImplemented => '同步功能将在后续版本推出';

  @override
  String get syncNow => '立即同步';

  @override
  String get syncStatusDisabled => '未启用';

  @override
  String get syncStatusEnabled => '已启用';

  @override
  String get syncStatusSyncing => '正在同步…';

  @override
  String get syncStatusUnavailable => '同步状态不可用';

  @override
  String get syncStatusUnavailableDesc => '同步引擎正在接入，稍后再试。';

  @override
  String get synced => '已同步';

  @override
  String get syncStatusOk => '同步正常';

  @override
  String get syncStatusError => '同步出错';

  @override
  String syncedRecordCount(int synced, int total) {
    return '已同步 $synced / 共 $total 条记录';
  }

  @override
  String get tagName => '标签名称';

  @override
  String get tags => '标签';

  @override
  String get tagsEmpty => '还没有标签';

  @override
  String get takePhoto => '拍照';

  @override
  String get technicalDetails => '技术详情';

  @override
  String get templateBlank => '空白笔记';

  @override
  String get templateBlankDesc => '从空白开始自由记录';

  @override
  String get templateContact => '联系人';

  @override
  String get templateContactDesc => '姓名、电话、邮箱与地址';

  @override
  String get templateIdDocument => '证件';

  @override
  String get templateIdDocumentDesc => '身份证、驾驶证等证件照与号码，号码自动掩码';

  @override
  String get templateIdea => '灵感速记';

  @override
  String get templateIdeaDesc => '灵感、来源与下一步行动';

  @override
  String get templatePassword => '记密码';

  @override
  String get templatePasswordDesc => '网站、账号与密码，密码自动掩码';

  @override
  String get templateSheetTitle => '选择模版';

  @override
  String get templateTodo => '待办清单';

  @override
  String get templateTodoDesc => '复选框式待办事项';

  @override
  String get testConnection => '测试连接';

  @override
  String get theme => '主题';

  @override
  String get themeDark => '深色';

  @override
  String get themeLight => '浅色';

  @override
  String get themeSystem => '跟随系统';

  @override
  String timeToday(String time) {
    return '今天 $time';
  }

  @override
  String get timeYesterday => '昨天';

  @override
  String get timeout1Min => '1 分钟';

  @override
  String get timeout5Min => '5 分钟';

  @override
  String get timeoutImmediately => '立即';

  @override
  String get titleHint => '标题（可选）';

  @override
  String get today => '今天';

  @override
  String todoProgress(int done, int total) {
    return '已完成 $done / $total';
  }

  @override
  String get trash => '回收站';

  @override
  String get trashEmpty => '回收站为空';

  @override
  String get uncategorized => '未分类';

  @override
  String get undoDelete => '撤销';

  @override
  String get unfavorite => '取消收藏';

  @override
  String get unlockAndJoin => '解锁并加入';

  @override
  String get unlockApp => '解锁随存';

  @override
  String get unlockKeyPrompt => '解锁密钥';

  @override
  String get unpinRecord => '取消置顶';

  @override
  String get unsetQuickAccess => '取消常用';

  @override
  String get untitledRecord => '未命名记录';

  @override
  String updatedAt(String time) {
    return '更新于 $time';
  }

  @override
  String get useBiometric => '生物识别解锁';

  @override
  String get usePassword => '使用加密密码';

  @override
  String get useRecoveryKey => '使用恢复密钥';

  @override
  String get username => '用户名';

  @override
  String get usernameRequired => '请填写用户名';

  @override
  String get vaultPassword => '加密密码';

  @override
  String get vaultRecoveryKey => '恢复密钥';

  @override
  String get version => '版本';

  @override
  String get viewAction => '查看';

  @override
  String get viewConflicts => '查看冲突';

  @override
  String get viewPhoto => '查看大图';

  @override
  String get webdavConnectionSettings => 'WebDAV 连接配置';

  @override
  String get webdavSync => 'WebDAV 同步';

  @override
  String get webdavUrl => 'WebDAV 地址';

  @override
  String get webdavUrlInvalid => 'WebDAV 地址格式不正确';

  @override
  String get webdavUrlRequired => '请填写 WebDAV 地址';

  @override
  String get wizardConnectionDesc => '将测试与 WebDAV 服务器的连接，并检查目录中是否已有同步库。';

  @override
  String get wizardCreating => '正在创建同步库…';

  @override
  String get wizardDone => '同步设置完成';

  @override
  String get wizardDoneDesc => '加密同步库已就绪，可以开始同步。';

  @override
  String get wizardHasVaultDesc => '该目录下已存在同步库，请输入加密密码或恢复密钥加入。';

  @override
  String get wizardJoining => '正在加入同步库…';

  @override
  String wizardMergeCount(int count) {
    return '待同步内容：$count 条';
  }

  @override
  String get wizardMergeInfo => '本地已有内容不会被远端直接替换；同步将合并两端数据，出现的冲突可稍后手动解决。';

  @override
  String get wizardNoVaultDesc => '该目录下没有同步库，可以创建一个新加密库。';

  @override
  String get wizardStepConnection => '连接测试';

  @override
  String get wizardStepMerge => '合并确认';

  @override
  String get wizardStepSecurity => '加密配置';

  @override
  String get wizardStepVault => '选择同步库';

  @override
  String get wizardTestAndContinue => '测试并继续';

  @override
  String get wizardTitle => '同步设置向导';

  @override
  String get wrongPin => 'PIN 错误，请重试';

  @override
  String get yesterday => '昨天';

  @override
  String get zoomInAction => '放大';
}
