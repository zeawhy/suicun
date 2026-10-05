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
  String get addCategory => '新增分类';

  @override
  String get addKeyword => '添加关键词';

  @override
  String get addTag => '新增标签';

  @override
  String get addTags => '添加标签';

  @override
  String get all => '全部';

  @override
  String get appName => '随存';

  @override
  String get appTagline => '保存以后还要找的信息';

  @override
  String get appearance => '外观';

  @override
  String get autoSaveHint => '自动保存，无需手动点击保存。';

  @override
  String get backup => '备份';

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
  String get cancel => '取消';

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
  String get clearFilter => '清除筛选';

  @override
  String get configSaved => '配置已保存';

  @override
  String get confirm => '确认';

  @override
  String connectionFailed(String error) {
    return '连接失败：$error';
  }

  @override
  String get connectionSuccess => '连接成功';

  @override
  String get data => '数据';

  @override
  String get delete => '删除';

  @override
  String get deleteCategory => '删除分类';

  @override
  String get deleteCategoryConfirm => '删除后，该分类下的记录将转为未分类。确认删除吗？';

  @override
  String get deleteTag => '删除标签';

  @override
  String get deleteTagConfirm => '删除后，相关记录仍然保留，只解除标签关联。确认删除吗？';

  @override
  String get directoryInvalid => '同步目录须以 / 开头';

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
  String get export => '导出';

  @override
  String exportFailed(String error) {
    return '导出失败：$error';
  }

  @override
  String get exportJson => '导出 JSON 备份';

  @override
  String get exportMarkdownZip => '导出 Markdown ZIP';

  @override
  String get exportSuccess => '导出成功';

  @override
  String get exportTxt => '导出 TXT';

  @override
  String get favorite => '收藏';

  @override
  String get favorites => '收藏';

  @override
  String get filterEmpty => '该筛选下没有记录';

  @override
  String get filterEmptyHint => '试试其他分类，或清除筛选条件';

  @override
  String get hidePassword => '隐藏密码';

  @override
  String get importData => '导入';

  @override
  String importFailed(String error) {
    return '导入失败：$error';
  }

  @override
  String get importJson => '从 JSON 恢复';

  @override
  String get importMarkdown => '导入 Markdown/TXT';

  @override
  String importPreview(int count) {
    return '即将导入 $count 条记录';
  }

  @override
  String importSuccess(int count) {
    return '成功导入 $count 条记录';
  }

  @override
  String get keywordHint => '输入关键词，回车添加';

  @override
  String get keywords => '关键词';

  @override
  String get keywordsEmpty => '暂无关键词，添加后可自动推荐分类';

  @override
  String get lastSync => '上次同步';

  @override
  String lastSyncToday(String time) {
    return '今天 $time';
  }

  @override
  String get linkCopied => '已复制链接';

  @override
  String get maxTagsReached => '最多添加 10 个标签';

  @override
  String modified(String time) {
    return '修改于 $time';
  }

  @override
  String get newInfo => '新建信息';

  @override
  String get newRecord => '新建记录';

  @override
  String get notYetInput => '尚未输入';

  @override
  String get ok => '确定';

  @override
  String get password => '密码';

  @override
  String get passwordRequired => '请填写密码';

  @override
  String get pendingUpload => '待上传';

  @override
  String get permanentDelete => '彻底删除';

  @override
  String get permanentDeleteConfirm => '彻底删除后无法恢复。确认吗？';

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
  String recordCount(int count) {
    return '$count 条记录';
  }

  @override
  String get recordDeleted => '已移至回收站';

  @override
  String get recordsEmpty => '还没有记录';

  @override
  String get recordsEmptyHint => '点击右下角新建记录';

  @override
  String get rename => '改名';

  @override
  String get restore => '恢复';

  @override
  String get save => '保存';

  @override
  String get saveFailed => '保存失败，重试';

  @override
  String get saved => '已保存';

  @override
  String get saving => '保存中';

  @override
  String get searchEmpty => '没有找到相关记录';

  @override
  String get searchEmptyHint => '试试其他关键词，或清除筛选条件';

  @override
  String get searchHint => '搜索保存的信息';

  @override
  String get security => '安全';

  @override
  String get securityNotImplemented => '安全功能将在后续版本推出';

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
  String get settings => '设置';

  @override
  String get showPassword => '显示密码';

  @override
  String get smartRecommend => '智能推荐';

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
  String get synced => '已同步';

  @override
  String get tagName => '标签名称';

  @override
  String get tags => '标签';

  @override
  String get tagsEmpty => '还没有标签';

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
  String get titleHint => '标题（可选）';

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
  String get untitledRecord => '未命名记录';

  @override
  String get username => '用户名';

  @override
  String get usernameRequired => '请填写用户名';

  @override
  String get version => '版本';

  @override
  String get webdavSync => 'WebDAV 同步';

  @override
  String get webdavUrl => 'WebDAV 地址';

  @override
  String get webdavUrlInvalid => 'WebDAV 地址格式不正确';

  @override
  String get webdavUrlRequired => '请填写 WebDAV 地址';

  @override
  String get appLock => '应用锁';

  @override
  String get enableAppLock => '启用应用锁';

  @override
  String get setPin => '设置 PIN';

  @override
  String get changePin => '修改 PIN';

  @override
  String get pinNotSet => '未设置';

  @override
  String get pinSet => '已设置';

  @override
  String get useBiometric => '生物识别解锁';

  @override
  String get lockTimeout => '后台锁定超时';

  @override
  String get timeoutImmediately => '立即';

  @override
  String get timeout1Min => '1 分钟';

  @override
  String get timeout5Min => '5 分钟';

  @override
  String get encryptedBackup => '加密备份';

  @override
  String get exportEncryptedBackup => '导出加密备份';

  @override
  String get importEncryptedBackup => '导入加密备份';

  @override
  String get backupPassword => '备份密码';

  @override
  String get backupPasswordHint => '换设备恢复需要此密码，请妥善保存';

  @override
  String get confirmPassword => '确认密码';

  @override
  String get passwordMismatch => '两次输入的密码不一致';

  @override
  String get passwordTooShort => '密码至少 8 位';

  @override
  String get unlockApp => '解锁随存';

  @override
  String get appLocked => '随存已锁定';

  @override
  String get enterPin => '输入 PIN 解锁';

  @override
  String get wrongPin => 'PIN 错误，请重试';

  @override
  String get pinTooShort => 'PIN 至少 4 位';

  @override
  String get pinSaved => 'PIN 已保存';

  @override
  String get securityPageTitle => '安全';

  @override
  String get encryptionOn => '本地数据库已加密';

  @override
  String get encryptionOnDesc => '数据库使用随机密钥加密，密钥保存在系统安全存储';

  @override
  String lockoutTryLater(Object seconds) {
    return '尝试次数过多，请 $seconds 秒后再试';
  }

  @override
  String get pinLabel => 'PIN';
}
