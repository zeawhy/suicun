# 随存 SuiVault UI/UX 改造 — 第二阶段（P1）交付文档

## 概述
- **分支**：`feat/ui-ux-plan`
- **阶段**：P1（专项三：记录卡片高密度排版与前置高频操作，专项四：主题系统语义化与深色模式适配）
- **依据**：`~/workspace/suicun-docs/suivault-ui-plan-2026-10-15.pdf`

---

## 一、修改文件清单

1. `lib/shared/theme/app_theme.dart`
   - 新增 `SuiVaultColors`（继承 `ThemeExtension<SuiVaultColors>`），实现 `success`、`warning`、`danger` 及 `categoryPalette`（学习、工作、待办、灵感、生活）。
   - 定义 light 与 dark 两套色板（依 PDF 第六节色值配置）。
   - 实现 `copyWith`、`lerp`、以及 `colorForCategory(String? name, [String? hex])` 兜底回退方法。
   - 在 `AppTheme.lightTheme()` 与 `AppTheme.darkTheme()` 的 extensions 中注册 `SuiVaultColors`。
   - 统一全局圆角规范：
     - Card：14pt
     - Input / Buttons（Filled / Outlined / Elevated）：12pt
     - Dialog：16pt
     - BottomSheet：顶部 20pt
   - 提供 `ThemeData.suiColors` 与 `BuildContext.suiColors` 快捷扩展。

2. `lib/shared/theme/theme_providers.dart`
   - 导出 `SuiVaultColors`、`SuiVaultBuildContextX`、`SuiVaultThemeDataX`，便于业务代码直接通过主题引用。

3. `lib/shared/widgets/record_card.dart`
   - 重构为三级清晰视觉梯度：
     - **第一层（头部行）**：模板类型图标（16pt：密码/证件/联系人/待办/灵感/笔记）+ 标题（单行截断，`titleMedium`）+ 收藏/置顶图标 + **右侧一键复制按钮**（针对密码/证件/联系人等含核心字段的模板显示）。
     - **第二层（内容区）**：普通笔记最多 2 行摘要；证件/密码展示脱敏主字段（密码脱敏点 `••••••••`、证件脱敏 `1101********2345`、联系人展示手机/邮箱/地址），数字使用等宽字形（`FontFeature.tabularFigures()`）。保留证件照片缩略图展示。
     - **第三层（底栏）**：分类圆点标签（从 `SuiVaultColors` 取色）+ 分类名 + 标签列表（`#tag` 胶囊）+ 右侧相对更新时间。
   - 紧凑垂直间距：外边距收紧为 `vertical: 4`，内边距优化为 `horizontal: 12, vertical: 10`，释放约 15-20% 空间，单屏多容纳 1-2 张卡片。
   - 一键复制逻辑：点击复制按钮触发 `HapticFeedback.lightImpact()`，通过 `Clipboard.setData` 复制**原文**（非脱敏文本），并弹出轻量 SnackBar 提示"已复制到剪贴板"。

4. `lib/features/records/presentation/id_presentation_page.dart`
   - **高对比放大与大字出示**：增加 `_largeTextMode`，在底栏"放大"以及点击证件号码区域时均可切换大字出示（24pt 加粗等宽数字、高对比度白色/边框提示）；保留原有照片双指 InteractiveViewer 缩放。
   - **下滑手势关闭**：在未放大状态下通过 `GestureDetector.onVerticalDragEnd`（`primaryVelocity > 300`）实现向下拉动退出页面，与双指缩放及右滑/关闭按钮无冲突。
   - **安全红线**：保留原生 MethodChannel（`com.suivault.app/secure`）的 `enableSecure` 与 `disableSecure` 逻辑，未作任何修改。

5. 清理业务组件中的 `AppTheme.xxx` 静态色硬编码（按范围控制）：
   - `lib/features/records/presentation/home_page.dart`：分类筛选弹窗圆点改为使用 `Theme.of(ctx).suiColors.colorForCategory`。
   - `lib/features/records/presentation/edit_record_page.dart`：推荐分类 Chip、分类选择弹窗及底部分类行改用 `Theme.of(context).suiColors.colorForCategory`。
   - `lib/features/categories/presentation/categories_page.dart`：分类列表图标与底色改用 `theme.suiColors.colorForCategory`。

6. 测试用例适配与补充：
   - `test/unit/theme_extension_test.dart`（新增 6 项测试）：覆盖 light/dark 色板、copyWith/lerp、分类回退、ThemeData 注册与全部全局圆角断言。
   - `test/widget/record_card_gradient_test.dart`（新增 3 项测试）：覆盖密码/证件/普通笔记三级梯度、脱敏与等宽、一键复制到剪贴板与 SnackBar、无复制按钮笔记预览。
   - `test/widget/id_presentation_enhanced_test.dart`（新增 2 项测试）：覆盖大字出示切换、下拉拖拽关闭、FLAG_SECURE 调用安全保持。
   - `test/widget/record_workflow_test.dart`：在快速测试中创建两条连续记录间增加 1s 跨秒等待，防止微秒级同秒记录在 SQLite 1秒分辨率下产生随机排序抖动。

---

## 二、自测验证结果

### 1. 静态分析 (`flutter analyze`)
```
Analyzing suicun...
No issues found! (ran in 14.7s)
```
- 0 errors / 0 warnings / 0 infos。

### 2. 测试套件 (`flutter test`)
```
03:38 +385: All tests passed!
```
- 全量 385 项测试全部通过（原 374 + 新增 11 项测试）。

### 3. 手动核验清单
- [x] **卡片三级梯度**：模板图标（16pt）+ 标题（单行截断）+ 收藏 + 右侧复制按钮；内容区脱敏+等宽；底栏分类点+标签+相对时间。
- [x] **高密度排版**：垂直外边距 4pt，内部 padding 紧凑，单屏多显示 1-2 张卡片。
- [x] **一键复制**：点击复制原文，有轻触震动反馈和 SnackBar 提示。
- [x] **出示模式增强**：支持大字出示切换（24pt 加粗等宽数字）、下滑手势平滑关闭，原生 FLAG_SECURE 保护正常生效。
- [x] **主题与深色适配**：注册 `ThemeExtension<SuiVaultColors>`，圆角 Card 14pt、Button/Input 12pt、Dialog 16pt、BottomSheet 20pt 集中规范化；深色模式下分类五彩色及背景层次分明。
- [x] **安全红线**：未动锁逻辑、未动 WebDAV 同步引擎、未修改数据库 schema。
