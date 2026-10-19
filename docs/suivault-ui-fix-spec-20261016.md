# SuiVault 首页 / 设置页 UI 修改方案（交给 AI Agent 执行）

> 仓库：https://github.com/zeawhy/suicun （Flutter + Riverpod + go_router）
> 基线：main @ e332a6d（2026-10-16）
> 涉及文件：
> - `lib/features/records/presentation/home_page.dart`
> - `lib/features/records/presentation/quick_access_panel.dart`
> - `lib/features/records/presentation/clipboard_sniffer.dart`
> - `lib/features/records/data/quick_access_storage.dart`
> - `lib/shared/widgets/record_card.dart`
> - `lib/features/settings/presentation/settings_page.dart`
> - `lib/l10n/*.arb`（新文案一律加到 arb，不要硬编码中文；已有硬编码的顺手迁移即可，不强制）

## 0. 通用规则

1. 按 Phase 拆成 3 个 PR：Phase 1 → Phase 2 → Phase 3，每个 PR 只做本阶段的任务。
2. 每个 PR 提交前必须执行：`flutter analyze` 零 warning；`flutter test` 全部通过。
3. 不改数据库 schema，不改同步协议。新的本地开关一律用 SharedPreferences（复用 `sharedPreferencesProvider`）。
4. 已有的 widget Key（如 `clipboard_sniff_banner`、`clipboard_sniff_save_button`、`speed_dial_item_*`）保持不变；受影响的测试同步更新：
   `test/widget/home_redesign_test.dart`、`quick_access_redesign_test.dart`、`p2_features_test.dart`、`record_workflow_test.dart`、`test/unit/clipboard_sniffer_test.dart`。
5. 深色模式必须同时检查。

---

## Phase 1（P0：可见 Bug + 隐私）

### T1. 「最近使用」居中 → 左对齐

**文件**：`home_page.dart`，`build()` 里 `if (showQuickAndRecent) SliverToBoxAdapter(child: Column(...))`

**现状**：该 `Column` 没有设置 `crossAxisAlignment`，默认 center；`RecentOpenedBar` 不是全宽，所以标题和 chip 被居中（截图中明显偏到屏幕中间）。

**修改**：
```dart
child: Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.stretch, // 新增
  children: [ ... ],
),
```
同时确认 `RecentOpenedBar` 外层 `Padding` 使用 `EdgeInsets.symmetric(horizontal: 16)`，与「常用」标题左边缘对齐。

**验收**：「最近使用」文字与「常用」文字、卡片左边缘在同一条竖线上（x = 16dp）。

---

### T2. 「最近使用」去重 + 少量数据时隐藏

**文件**：`home_page.dart`（计算 `recentRecords` 处）

**修改**：
```dart
final quickIdSet = quickRecords.map((r) => r.id).toSet();
final recentRecords = recentOpenedIds
    .where((id) => !quickIdSet.contains(id))   // 已在常用里的不再重复显示
    .map((id) => recordMap[id])
    .whereType<RecordDetail>()
    .take(5)
    .toList();
final showRecentBar = recentRecords.isNotEmpty && records.length > 3;
```
`RecentOpenedBar` 仅在 `showRecentBar` 为 true 时渲染。

**验收**：只有 1–3 条记录时不显示「最近使用」；常用里的记录不会再出现在「最近使用」。

---

### T3. 常用胶囊标题截断（「gith…」「我…」）

**文件**：`quick_access_panel.dart` → `_QuickAccessCapsule`

**现状**：卡片宽约 170dp，右侧动作胶囊（图标 + 「查看/出示/复制」文字）占了接近一半，标题只剩 1–2 个字。

**修改**：
1. 动作胶囊改为**纯图标圆形按钮**：28×28，`BoxShape.circle`，背景 `style.accentColor.withValues(alpha: 0.12)`，图标 `style.actionIcon` size 16。
2. 用 `Semantics(label: style.actionLabel, button: true)` + `Tooltip(message: style.actionLabel)` 包住图标，保留无障碍与长按提示。
3. 整张卡片 `onTap` 仍执行 `executeQuickAction`（行为不变）。
4. 左侧类型图标容器从 30 → 28，`SizedBox(width: 8)` 保持；内边距改为 `EdgeInsets.fromLTRB(10, 8, 8, 8)`。
5. 卡片高度 68 → 64（3 个及以上的横滑列表同步调成 64）。

**验收**：360dp 宽设备、2 个常用时，标题至少显示 6 个中文字符或 10 个英文字符；「尾号 9xxx」完整显示。

---

### T4. 常用 / 最近 ID 残留（删除后的幽灵 id）

**现状**：`quick_access_record_ids`、`recent_opened_record_ids` 在记录删除后不会清理。界面显示 `2/6`（按存在的记录算），但 `toggleQuickAccess` 按存储的 id 数判断上限，可能出现「看起来只有 2 个却提示最多 6 个」。

**修改**：
1. `quick_access_storage.dart` 新增：
   ```dart
   // QuickAccessService
   Future<void> removeEverywhere(String id) async {
     await removeFromQuickAccess(id);
     final recent = getRecentOpenedIds()..remove(id);
     await _prefs.setStringList(QuickAccessKeys.recentOpenedRecordIds, recent);
   }
   Future<void> clearAll() async {
     await _prefs.remove(QuickAccessKeys.quickAccessRecordIds);
     await _prefs.remove(QuickAccessKeys.recentOpenedRecordIds);
     await _prefs.remove(QuickAccessKeys.recentSearchQueries);
   }
   ```
   并在 Notifier 层暴露对应方法，调用后 `ref.invalidate(quickAccessIdsProvider)` 和 `recentOpenedIdsProvider`。
2. 调用点：
   - `home_page.dart` `_deleteRecord` 和多选批量删除：删除后调用 `removeEverywhere(id)`；撤销删除（`restoreRecord`）**不**恢复常用，保持简单。
   - `settings_page.dart` `_handleClearAllData` 成功后调用 `clearAll()`。
   - 回收站「彻底删除」同样调用 `removeEverywhere`（在 `features/trash/presentation` 中找到对应位置）。
3. 启动兜底：`QuickAccessIdsNotifier.build()` 里不做清理（拿不到全量记录）；改为在 `home_page.dart` 中，当 `!isSearchOrFilterActive && recordsAsync.hasValue` 时，若 `quickIds` 中存在不在 `recordMap` 里的 id，用 `addPostFrameCallback` 调一次清理（仅在无筛选状态下做，避免误删）。

**验收**：设为常用 → 删除该记录 → 常用数量正确减少；连续加满 6 个、删 1 个后可以再加 1 个。补一个单测覆盖 `removeEverywhere`。

---

### T5. 剪贴板识别：默认关闭 + 文案修正 + 两行布局

**背景**：App 每次回到前台都会读剪贴板，Android 12+ 会弹系统提示「SuiVault 已从剪贴板粘贴」，和「隐私优先」的定位冲突。

**5.1 开关（默认关）**
- SharedPreferences key：`clipboard_sniff_enabled`，默认 `false`。
- 新建 `clipboardSniffEnabledProvider`（`AsyncNotifier<bool>`，放在 `quick_access_storage.dart` 或新建 `lib/features/settings/data/privacy_prefs.dart`）。
- `home_page.dart` `_checkClipboardWithDebounce()` 开头加：
  ```dart
  final enabled = await ref.read(clipboardSniffEnabledProvider.future);
  if (!enabled) return;
  ```
- 设置页「安全」分组里新增 `SwitchListTile`：
  - 标题：`剪贴板识别`
  - 副标题：`回到 App 时识别剪贴板中的证件号、地址、链接，仅在本地处理`

**5.2 已忽略内容持久化**
- `_lastDismissedClipboardText` 目前只存内存，重启后同一段内容会再次弹出。改为把 `text.hashCode.toString()` 存进 SharedPreferences key `clipboard_last_handled_hash`，比较 hash；**不要存原文**。

**5.3 链接类型文案** — `clipboard_sniffer.dart` 中 link 分支：
```dart
final host = Uri.tryParse(url)?.host ?? url;
bannerLabel: '检测到链接',
previewText: host,                 // 只展示域名，例如 github.com
actionLabel: '存为网站账号',
```
同时把 id / address 分支的 `bannerLabel` 改短为 `检测到证件号` / `检测到地址`，`actionLabel` 改为 `存为证件` / `存为地址`（去掉「一键」）。同步更新 `test/unit/clipboard_sniffer_test.dart`。

**5.4 Banner 两行布局** — `home_page.dart` `_buildClipboardSnifferBanner`：
- 中间的 `Expanded(Text(...))` 改为：
  ```dart
  Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(data.bannerLabel, style: 13 / w600 / onSurface, maxLines: 1),
        const SizedBox(height: 2),
        Text(data.previewText, style: 12 / onSurfaceVariant, maxLines: 1, overflow: ellipsis),
      ],
    ),
  ),
  ```
- 「忽略」改成 `IconButton(Icons.close, size: 18)`，tooltip `忽略`，保留 Key `clipboard_sniff_ignore_button`。
- 容器 padding 改为 `EdgeInsets.fromLTRB(12, 10, 4, 10)`。

**验收**：新安装默认不读剪贴板，系统不弹提示；打开开关后复制 `https://github.com/xxx`，banner 显示「检测到链接 / github.com」+「存为网站账号」，文字不截断。

---

## Phase 2（P1：交互概念收敛）

### T6. 「收藏 / 置顶 / 常用」收敛为两个概念

**现状**：卡片星标 = 收藏；左滑「置顶」实际调用的也是 `_toggleFavorite`（`onPinToggle: () => _toggleFavorite(r)`）；长按菜单里还有「设为常用」。三个入口，两种状态。

**目标**：
- ⭐ **收藏**：卡片右上角星标，只用于「收藏」tab 筛选。
- 📌 **常用**：固定在顶部常用面板（最多 6 个）。

**修改**：
1. `home_page.dart` 抽出 `Future<void> _toggleQuickAccess(RecordDetail r)`（把 `_showRecordActionSheet` 里「设为常用」的逻辑原样移过去，包括 SnackBar 和满 6 个的提示）。长按菜单改为调用它。
2. `record_card.dart`：
   - 新增参数 `required bool isQuickAccess`、`required VoidCallback onQuickAccessToggle`；删除 `onPinToggle`。
   - 左滑第一个 `SlidableAction`：图标 `isQuickAccess ? Icons.push_pin : Icons.push_pin_outlined`，文案 `isQuickAccess ? '取消常用' : '设为常用'`，`onPressed: onQuickAccessToggle`。
   - 标题行在 `isQuickAccess` 为 true 时，在标题后显示一个 12dp 的 `Icons.push_pin` 小图标（`onSurfaceVariant`，alpha 0.6）。
3. `home_page.dart` 传参：`isQuickAccess: quickIds.contains(r.id)`、`onQuickAccessToggle: () => _toggleQuickAccess(r)`。
4. 清理 arb 中 `pinRecord` / `unpinRecord` 的使用（key 可以保留，改用新 key `setQuickAccess` / `unsetQuickAccess`）。

**验收**：左滑「设为常用」后，顶部常用面板立刻出现该记录；星标只影响「收藏」tab。

---

### T7. 颜色语义统一：圆点 = 分类色

**现状**：「最近使用」chip 的圆点用的是类型色（memo 为棕色 `0xFF785700`），列表卡片中同一条记录的圆点却是分类色（「工作」= 蓝）。

**修改**：`quick_access_panel.dart` → `_RecentItemChip`，圆点颜色改为：
```dart
final dotColor = record.category != null
    ? theme.suiColors.colorForCategory(record.category!.name, record.category!.color)
    : theme.colorScheme.outline;
```
（需要 `import 'package:suicun/shared/theme/app_theme.dart';`）
类型差异改用图标表达：圆点后加 `Icon(style.icon, size: 14, color: onSurfaceVariant)`，或者直接用图标替换圆点（二选一，推荐替换：图标 14dp + 分类色）。

**验收**：同一条记录在「最近使用」和列表里的颜色一致。

---

### T8. 卡片右上角按钮位置对齐

**现状**：`record_card.dart` 标题行顺序是「标题 → 星标 → 复制（有可复制内容时才出现）」，导致有无复制按钮的卡片星标位置不同（截图中 x≈612 vs x≈750）。

**修改**：顺序改为「标题 → 复制（可选）→ 星标」，星标永远在最右侧。两个 IconButton 的 `constraints` 统一为 `BoxConstraints.tightFor(width: 32, height: 32)`，间距 `SizedBox(width: 4)`。

**验收**：任意两张卡片的星标右边缘对齐。

---

### T9. 左滑提示「«」只引导一次

**现状**：每张卡右侧都有 `Icons.keyboard_double_arrow_left`，视觉噪音大，还占掉一列宽度，导致底部时间与卡片右边缘不对齐。

**修改**：
1. `RecordCard` 新增参数 `bool showSwipeHint = false`；为 false 时不渲染该 `Padding + Icon`（不要留占位）。
2. SharedPreferences key `swipe_hint_seen`（bool）。新建 `swipeHintSeenProvider`。
3. `home_page.dart`：`showSwipeHint: index == 0 && !swipeHintSeen && !_isMultiSelect`。
4. 任何一个 `SlidableAction` 被点击时，把 `swipe_hint_seen` 设为 true（在 `RecordCard` 新增 `onAnySlideAction` 回调，或在 home 的各 onXxx 回调里统一设置）。
5. 可选增强：首次显示时，对第一张卡片做一次 `Slidable.of(context)?.openEndActionPane()` 再 600ms 后 `close()` 的演示动画，只执行一次。

**验收**：首次只有第一张卡显示提示；用过一次左滑后再也不显示；卡片底部时间与卡片右内边距对齐。

---

### T10. 列表中身份证照片缩略图默认模糊

**文件**：`record_card.dart` → `_buildThumbnail()`

**修改**：
```dart
ClipRRect(
  borderRadius: BorderRadius.circular(8),
  child: Stack(
    alignment: Alignment.center,
    children: [
      ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Image.file(file, width: 60, height: 60, fit: BoxFit.cover),
      ),
      Icon(Icons.visibility_off_outlined, size: 18, color: Colors.white70),
    ],
  ),
)
```
（`import 'dart:ui' show ImageFilter;`）列表中始终模糊，进入详情 / 出示模式时才显示清晰图。尺寸沿用现有值，不要改布局。

**验收**：首页列表看不清证件内容；进入详情页显示正常。

---

## Phase 3（P2：布局与信息架构）

### T11. 搜索态精简

**文件**：`home_page.dart`

**修改**：
1. `showQuickAndRecent` 改为：
   ```dart
   final showQuickAndRecent = !_searchExpanded && !isSearchOrFilterActive && !_isMultiSelect;
   ```
2. 分类 tab（`SliverPersistentHeader`）在 `_searchExpanded` 时不渲染。
3. `_openSearch` 中，已保存 `_savedCategoryId / _savedFavoritesOnly` 后，**立即清空**分类和收藏筛选（`setCategory(null)`、`setFavoritesOnly(false)`），保证搜索是全局的；`_cancelSearch` 已有恢复逻辑，保持不变。
4. `_searchExpanded && filter.query.trim().isEmpty` 时不渲染记录列表，改为 `SliverFillRemaining(hasScrollBody: false)` 居中显示弱提示：图标 `Icons.search` 32dp + 文案 `输入关键词搜索全部记录`（`onSurfaceVariant`）。最近搜索 chips 保留在 AppBar bottom。
5. hintText 改为 `搜索标题、内容，支持拼音首字母`。

**验收**：点搜索后，页面只剩搜索框、最近搜索、提示；输入后只显示结果列表 + 「N 条信息」。取消后恢复原分类与滚动位置。

---

### T12. 分类 tab：右侧渐隐 + 管理入口 + 收藏区分

**文件**：`home_page.dart` → `_CategoryFilterBar`

**修改**：
1. 外层改为 `Row([Expanded(ShaderMask(...SingleChildScrollView...)), 管理按钮])`。
2. `ShaderMask` 右侧 24dp 渐隐：
   ```dart
   ShaderMask(
     shaderCallback: (rect) => const LinearGradient(
       begin: Alignment.centerLeft, end: Alignment.centerRight,
       colors: [Colors.black, Colors.black, Colors.transparent],
       stops: [0.0, 0.92, 1.0],
     ).createShader(rect),
     blendMode: BlendMode.dstIn,
     child: SingleChildScrollView(...),
   )
   ```
3. 右侧固定 `IconButton(Icons.tune_rounded, size: 20)`，tooltip `管理分类`，点击 `context.push('/settings/categories')`。
4. 「收藏」tab 文案前加 `Icon(Icons.star_rounded, size: 14)`，和普通分类在视觉上区分开。

**验收**：分类多时，右侧有渐隐暗示可滑动；管理按钮始终可见。

---

### T13. 释放底栏：设置移到顶部左侧，FAB 悬浮

**现状**：`bottomNavigationBar` 里只有「设置」文字按钮 + FAB，占了约 90dp 高的一整条。

**修改**：
1. 删除 `bottomNavigationBar` 中的这个 Container（多选模式的逻辑保持不变）。
2. 普通态 `SliverAppBar` 增加 `leading: IconButton(icon: Icon(Icons.menu_rounded), tooltip: l10n.settings, onPressed: _toggleSettings)`。设置抽屉从左侧滑出，入口放在左侧方向一致。标题间距 `titleSpacing: 4`。
3. FAB 改用 `Scaffold.floatingActionButton: _isMultiSelect ? null : _buildSpeedDialFab(context)`，`floatingActionButtonLocation: FloatingActionButtonLocation.endFloat`。
4. `_buildSpeedDialOverlay` 中 `bottomPadding` 改为 `MediaQuery.paddingOf(context).bottom + 16`，`right: 16`，确保覆盖层上的 FAB 与 Scaffold FAB 位置完全重合（打开 speed dial 时不能跳动）。展开项的 `bottom` 同步改为 `bottomPadding + 56 + 16`。
5. 列表底部 padding 保持 `80`，避免最后一张卡被 FAB 挡住。

**验收**：底部不再有白色底栏；speed dial 开合时 FAB 不跳位；返回键关闭顺序不变（speed dial → 设置抽屉 → 退出）。

---

### T14. 记录少时显示「快速添加」

**文件**：`home_page.dart`

**修改**：在记录列表 `SliverPadding` 之后，当 `!isSearchOrFilterActive && !_searchExpanded && !_isMultiSelect && records.length < 3` 时，追加一个 `SliverToBoxAdapter`：
- 标题 `快速添加`（13 / w600 / onSurfaceVariant），左边距 16。
- 下面一行 `Wrap(spacing: 8, runSpacing: 8)`，复用 `_getSpeedDialItems(context, isDark)` 的数据，渲染成和 speed dial item 同样样式的胶囊（白底、28dp 彩色圆形图标 + 文字），点击 `context.push(item.route)`。
- 把 `_buildSpeedDialItem` 内部的 `Material + InkWell + Row` 抽成 `_TemplateChip` 组件，供两处复用（speed dial 外层动画不变）。
- 上面这几个条件同时满足时，把列表 `SliverPadding` 的 bottom padding 从 80 改为 16，由快速添加区块自己再加 bottom 96。

**验收**：只有 1 条记录时，下方出现 4 个模板胶囊，点击直接进入对应模板。

---

### T15. 设置页信息架构

**文件**：`settings_page.dart` → `SettingsView.build`

**目标结构**：
```
外观
  └ 主题                      跟随系统  >
数据
  ├ 分类                                >
  ├ 标签                                >
  └ 回收站                              >
备份与同步
  ├ 备份与导出                          >
  └ WebDAV 同步               已启用    >
安全与隐私
  ├ 应用锁                    已开启    >
  └ 剪贴板识别                    [开关]   ← T5 新增
关于
  └ （保持现状）
危险操作
  └ 清除全部数据（红色）                >
```

**修改**：
1. 「备份」tile 从「数据」分组移到新的「备份与同步」分组（复用 `l10n.sync` 的 header 位置，标题文案改为 `备份与同步`，新增 arb key `backupAndSync`）。
2. 「安全」分组标题改为 `安全与隐私`；里面的 tile 标题从 `l10n.security` 改为 `应用锁`（新增 key `appLock`），`trailingText` 显示 `已开启 / 未开启`——在 `lib/features/security/` 中找到现有的应用锁状态 provider 读取；如果没有，就在 `/settings/security` 页使用的同一数据源上包一层 FutureProvider。
3. 「清除全部数据」从「数据」Card 中移出，放到列表最后一个独立 Card，分组标题 `危险操作`，`_buildSectionHeader` 增加可选参数 `color`，这里传 `colorScheme.error`。
4. 主题 tile：去掉 `DropdownButton`，改用 `_navTile(trailingText: 当前模式文案)`；点击弹 `showModalBottomSheet`，内含 3 个 `RadioListTile`，样式参考首页 `_showSortSheet`。这样所有 tile 的右侧值统一为「灰色次要文字 + chevron」。
5. 分组间距保持 16。

**验收**：设置页不再出现「安全 → 安全」；右侧状态文字样式全部一致；「清除全部数据」位于最底部且单独成组。

---

## 回归检查清单（每个 PR 都要过一遍）

- [ ] 浅色 / 深色模式截图对比：首页（0 条、1 条、10 条记录）、搜索态、设置抽屉
- [ ] 360dp 宽设备（如 Pixel 4a 模拟器）无溢出黄条
- [ ] 常用 0 / 1 / 2 / 3+ 个时的布局
- [ ] 返回键：speed dial 打开 → 设置打开 → 搜索态，逐级关闭
- [ ] 多选模式进出正常，FAB 与底栏状态正确
- [ ] FLAG_SECURE 仍然生效（不要动 MainActivity 相关代码）
