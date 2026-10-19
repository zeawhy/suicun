# 随存 SuiVault UI/UX 改造 — 第一阶段（P0）自测与交付记录

## 1. 任务背景与目标
- **依据方案**：`~/workspace/suicun-docs/suivault-ui-plan-2026-10-15.pdf` 与 `agy-uiux-p0-task.md`
- **执行分支**：`feat/ui-ux-plan`（基于 `origin/main` / PR #5 合并节点）
- **改造范围**：
  1. **专项一：首页纵向空间释放**
     - `home_page.dart` 顶层滚动架构改造为 `CustomScrollView`
     - `quick_access_panel.dart` 改为紧凑单行横向胶囊（高度约 68pt），消除小屏及大字号溢出
  2. **专项二：0 摩擦录入**
     - 双模 FAB：短按直接进入正文编辑态并自动聚焦弹键盘；长按触发触感反馈（`HapticFeedback.mediumImpact()`）并唤起 `template_sheet.dart`
     - `edit_record_page.dart` 键盘辅助工具条：高度 48pt，由 `MediaQuery.viewInsetsOf(context).bottom` 驱动动态垫高，贴合软键盘顶部，集成模板切换胶囊、待办复选框快捷插入与智能分类推荐 Chip

---

## 2. 修改文件清单与改动点

### 2.1 专项一：首页纵向空间释放
1. **`lib/features/records/presentation/home_page.dart`**
   - 顶层滚动架构重构为 `CustomScrollView` + `Sliver` 系列组件：
     - `SliverAppBar(floating: true, snap: true, pinned: false)`：收纳顶部标题栏与搜索栏（包含平滑展开/收起过渡动画）。
     - `SliverToBoxAdapter`：包裹常用大方块/胶囊（`QuickAccessGrid`）与最近使用记录栏（`RecentOpenedBar`），随手势自然滚出视口。
     - `SliverPersistentHeader(pinned: true, delegate: _CategoryFilterHeaderDelegate(height: 46))`：分类横滑筛选栏在上滑后吸顶停留。
     - `SliverPadding(sliver: SliverList.separated(...))`：记录列表高效复用展示。
   - 保留全部既有业务逻辑：拼音/中文实时搜索、搜索历史 Chip、侧边栏设置抽屉、多选模式、左右滑动手势（Slidable）与长按操作底盘。

2. **`lib/features/records/presentation/quick_access_panel.dart`**
   - `QuickAccessGrid` 由两列纵向堆叠重构为单行横向滚动流（`_QuickAccessCapsule`），固定高度限制在 68pt 内。
   - 胶囊内标题限制单行并带省略号（`maxLines: 1, overflow: TextOverflow.ellipsis`），彻底防止在小屏幕或大字号（如 1.3x text scale）下产生 RenderFlex 溢出。
   - 保留出示模式（证件）、密码快速复制、跳转详情等原有全部交互。

### 2.2 专项二：0 摩擦录入
1. **`lib/core/router/app_router.dart`**
   - `/edit` 路由增加对 query 参数 `autofocus` 的解析：
     `final autofocus = state.uri.queryParameters['autofocus'] == 'true';`
     并透传给 `EditRecordPage(autofocus: autofocus)`。

2. **`lib/features/records/presentation/home_page.dart`（双模 FAB）**
   - 实现 `_buildDualModeFab`：
     - 外部包裹 `Tooltip(message: l10n.newRecord, triggerMode: TooltipTriggerMode.manual)`，既保留无障碍/测试 finder 兼容性，又避免默认 Tooltip 拦截长按手势。
     - `GestureDetector(onLongPress: ...)`：长按触发 `HapticFeedback.mediumImpact()`，唤起 `showTemplateSheet(context)` 选择结构化模板。
     - `FloatingActionButton.extended(onPressed: ...)`：短按直接跳转 `/edit?template=blank&autofocus=true`。

3. **`lib/features/records/presentation/edit_record_page.dart`（键盘辅助工具条）**
   - 接收 `autofocus` 参数，并在首帧回调中调度 `_bodyFocusNode.requestFocus()` 自动唤起软键盘。
   - 在底栏实现 48pt 的键盘附件工具条，通过 `AnimatedPadding(padding: EdgeInsets.only(bottom: bottomInset), duration: const Duration(milliseconds: 120), curve: Curves.easeOut)` 动态跟随键盘升降，不被遮挡。
   - 工具条内容：
     - 模板切换胶囊（展示当前模板名称，点击唤起 `showTemplateSheet` 动态切换模板并注入骨架）。
     - 快捷插入复选框按钮（`IconButton(icon: Icons.check_box_outlined)`，点击调用 `toggleCheckboxAt` 快捷格式化待办行）。
     - 智能分类推荐横向 Chip 流（复用 `suggestedCategories` 异步推荐能力）。

### 2.3 测试适配与修复
- 适配双模 FAB 交互与 PR #5 架构更新，消除旧测试直接短按期待模板弹窗与旧 `more_horiz` 菜单查找的断言问题：
  - `test/widget/home_redesign_test.dart`
  - `test/widget/blank_template_view_test.dart`
  - `test/widget/todo_template_view_test.dart`
  - `test/widget/contact_template_view_test.dart`
  - `test/widget/idea_template_view_test.dart`
  - `test/widget/password_template_view_test.dart`
  - `test/widget/delete_undo_snackbar_test.dart`
  - `test/widget/record_workflow_test.dart`

---

## 3. 自查与质量保证清单

- [x] **红线确认**：
  - 未改动数据库 schema 及迁移脚本。
  - 未改动 AppLockGate、安全锁服务。
  - 未改动 WebDAV 同步引擎及 session 恢复逻辑。
  - 未改动 P1 文件（`record_card.dart`、`app_theme.dart` 等）。
- [x] **首页滚动行为自查**：
  - 向上滚动时，SliverAppBar 与搜索栏优雅滚出视口；下拉 overscroll 时自动轻快展开。
  - 常用快取面板随滚动滚出屏幕，释放垂直空间。
  - 分类横向切换栏（All/Favorites/Categories）吸顶固定，切换分类正常。
- [x] **快取胶囊自查**：
  - 常用区固定 68pt 单行横向滚动，文本超长省略，不同屏幕宽度与大字号缩放无 overflow。
- [x] **双模 FAB 自查**：
  - 短按直接进入备忘录编辑态，焦点自动落在正文输入框，键盘呼出。
  - 长按触发振动，唤起模板选择 BottomSheet，选择对应模板正确进入编辑态。
- [x] **键盘辅助工具条自查**：
  - 软键盘弹起时，底栏平滑向上贴合软键盘顶部（48pt），无遮挡。
  - 模板切换、待办复选框插入、智能分类推荐功能均工作正常。

---

## 4. 自动化验证结果

### 4.1 静态代码分析
```bash
export PATH="$HOME/flutter/bin:$PATH" && flutter analyze
```
**输出**：
```
Analyzing suicun...                                             
No issues found! (ran in 14.5s)
```
- **0 errors, 0 warnings**。

### 4.2 单元与 Widget 测试套件
```bash
export PATH="$HOME/flutter/bin:$PATH" && flutter test
```
**输出**：
```
03:14 +374: All tests passed!
```
- **374 / 374 测试全部通过（100% 通过率）**。
