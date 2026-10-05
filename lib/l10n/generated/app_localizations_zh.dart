// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => '随存';

  @override
  String get appTagline => '保存以后还要找的信息';

  @override
  String get newRecord => '新建记录';

  @override
  String get searchHint => '搜索保存的信息';

  @override
  String get all => '全部';

  @override
  String get favorites => '收藏';

  @override
  String get uncategorized => '未分类';

  @override
  String get untitledRecord => '未命名记录';

  @override
  String get saving => '保存中';

  @override
  String get saved => '已保存';

  @override
  String get saveFailed => '保存失败，重试';

  @override
  String get settings => '设置';

  @override
  String get appearance => '外观';

  @override
  String get data => '数据';

  @override
  String get about => '关于';

  @override
  String get theme => '主题';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get categories => '分类';

  @override
  String get tags => '标签';

  @override
  String get addCategory => '新增分类';

  @override
  String get editCategory => '编辑分类';

  @override
  String get deleteCategory => '删除分类';

  @override
  String get deleteCategoryConfirm => '删除后，该分类下的记录将转为未分类。确认删除吗？';

  @override
  String get categoryName => '分类名称';

  @override
  String get categoryColor => '分类颜色';

  @override
  String get addTag => '新增标签';

  @override
  String get editTag => '编辑标签';

  @override
  String get deleteTag => '删除标签';

  @override
  String get deleteTagConfirm => '删除后，相关记录仍然保留，只解除标签关联。确认删除吗？';

  @override
  String get tagName => '标签名称';

  @override
  String get favorite => '收藏';

  @override
  String get unfavorite => '取消收藏';

  @override
  String get delete => '删除';

  @override
  String get restore => '恢复';

  @override
  String get permanentDelete => '彻底删除';

  @override
  String get permanentDeleteConfirm => '彻底删除后无法恢复。确认吗？';

  @override
  String get trash => '回收站';

  @override
  String get trashEmpty => '回收站为空';

  @override
  String get recordsEmpty => '还没有记录';

  @override
  String get recordsEmptyHint => '点击右下角新建记录';

  @override
  String get searchEmpty => '没有找到相关记录';

  @override
  String get searchEmptyHint => '试试其他关键词，或清除筛选条件';

  @override
  String get clearFilter => '清除筛选';

  @override
  String get backup => '备份';

  @override
  String get export => '导出';

  @override
  String get importData => '导入';

  @override
  String get exportJson => '导出 JSON 备份';

  @override
  String get exportMarkdownZip => '导出 Markdown ZIP';

  @override
  String get exportTxt => '导出 TXT';

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
  String importFailed(String error) {
    return '导入失败：$error';
  }

  @override
  String get exportSuccess => '导出成功';

  @override
  String exportFailed(String error) {
    return '导出失败：$error';
  }

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确认';

  @override
  String get save => '保存';

  @override
  String get rename => '改名';

  @override
  String get ok => '确定';

  @override
  String get titleHint => '标题（可不填）';

  @override
  String get bodyHint => '正文';

  @override
  String get selectCategory => '选择分类';

  @override
  String get selectTags => '选择标签';

  @override
  String get maxTagsReached => '最多添加 10 个标签';

  @override
  String get duplicateName => '该名称已存在';

  @override
  String get recordDeleted => '已移至回收站';

  @override
  String get undoDelete => '撤销';

  @override
  String get selectAll => '全选';

  @override
  String get batchFavorite => '批量收藏';

  @override
  String get batchDelete => '批量删除';

  @override
  String get batchCategorize => '批量分类';

  @override
  String selectedCount(int count) {
    return '已选 $count 条';
  }

  @override
  String get syncNotImplemented => '同步功能将在后续版本推出';

  @override
  String get securityNotImplemented => '安全功能将在后续版本推出';

  @override
  String get version => '版本';

  @override
  String get bodyLimit => '正文较长（超过 1 MiB），建议拆分';

  @override
  String modified(String time) {
    return '修改于 $time';
  }
}
