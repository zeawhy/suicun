# 随存 (suicun) — 阶段 A 实现状态

> 阶段 A = 本地核心。同步 / 加密 / 上架（B/C/D）不在本阶段范围内。
> 本文档如实记录做到哪一步、跑过什么命令、什么结果；没验证的明确写"未验证"。

更新时间：2026-10-05（CST）
分支：`antigravity/stage-a`（自 main 切出）

---

## 1. 工具链（VM 实测）

| 组件 | 版本 / 路径 | 备注 |
|---|---|---|
| Flutter | 3.47.6 stable (`~/flutter/bin`) | `flutter doctor`：Flutter ✓、Android toolchain ✓（SDK 36.1.0）；Chrome / Linux desktop 缺失（与阶段 A 无关） |
| Dart | 3.13.5 | Flutter 自带 |
| Android SDK | `~/android-sdk`（platforms 35/36、build-tools 35.0.0/36.1.0） | licenses 已写入；SDK 包经 curl 直链下载（sdkmanager 走不通 Java 代理） |
| JDK | Temurin 17（`~/jdk17`） | `JAVA_HOME=~/jdk17` |
| Gradle 代理 | `~/workspace/suicun-env/gradle-proxy.sh` | 跑 `flutter build apk` 前必须先执行一次 |
| APK 构建脚本 | `~/workspace/suicun-env/flutter-build-apk.sh` | 封装全部环境变量，一键 `flutter build apk --debug` |

#### VM 上 `flutter build apk` 的环境坑（2026-10-05 实测）
1. **Gradle daemon 握手失败**：client 用 `AF_INET6` 连 `::ffff:127.0.0.1`（strace 实证），
   sandbox 里 IPv6-mapped IPv4 回环不通 → daemon 起得来但 client 永远连不上
   （`A new daemon was started but could not be connected to` / `The first result from the daemon was empty`）。
   解：`-Djava.net.preferIPv4Stack=true`。
2. **代理 TLS MITM 只吃纯 TLS 1.2 ClientHello**：Java 默认带 TLS 1.3 的 ClientHello 会被降级到 1.2
   然后晾住直到读超时；强制只发 1.3 则被 `protocol_version` alert 拒绝；curl（TLS 1.3）正常。
   解：`-Djdk.tls.client.protocols=TLSv1.2`（Java 发纯 1.2 ClientHello 即 200 OK）。
3. **JDK 不信任代理 MITM CA**：`SSL_CERT_FILE=/run/hatch/egress-tls/ca-bundle.pem`
   （`Hatch Sandbox Egress CA`，122 个证书）只对 curl/node/git 有效；`keytool -importcert`
   一次只导入 bundle 中的第一个证书，需拆成 122 个逐个导入 `~/jdk17/lib/security/cacerts`
   （JDK 重装后需重导）。注：代理对不同域名用了不同的中间证书，只导一个会遇到
   `PKIX path building failed`（如 dl.google.com）。
4. **Gradle 传参不可靠**：`GRADLE_OPTS` 只影响 client，`systemProp.*` 给 daemon 传参在本环境不稳定；
   改用 `_JAVA_OPTIONS` 环境变量，所有 JVM 进程（client + daemon）自动生效。
5. **Flutter 3.47.6 模板 pin 了不存在的 AGP 版本**：`settings.gradle.kts` 里
   `com.android.application` version `9.1.0` 从未发布（只有 9.1.0-alpha），改为 `9.4.1`
   （2026-10-05 时最新稳定版）；AGP 9.4.1 要求 Gradle ≥ 9.6.0，wrapper 从 9.3.1 升到 9.6.0。
   另：`pluginManagement` 加了 `resolutionStrategy.eachPlugin { useModule(...) }`
   绕过 plugin-marker 解析，并显式加了 `maven("https://dl.google.com/android/maven2/")`
  （`google()` 的 maven.google.com 301 跳转经代理不可靠，且 Gradle 未实际请求该仓库）。
   以上三处改动都在 `android/` 下，已提交。

依赖（`pubspec.lock` 实际解析版本，`flutter pub get` 2026-10-05）：

| 包 | 解析版本 |
|---|---|
| drift / drift_dev | 2.35.1 |
| flutter_riverpod / riverpod_generator | 3.4.3 / 4.0.9 |
| go_router | 18.0.2 |
| build_runner | 2.16.1 |
| file_picker | 13.1.0（API 大改：`FilePicker.pickFiles()` 静态方法，返回 `List<PlatformFile>`） |
| share_plus | 13.3.1（`Share.shareXFiles` 已废弃，改用 `SharePlus.instance.share(ShareParams(...))`） |
| archive | 4.0.7 |
| uuid | 4.5.1 |
| path_provider / path_provider_platform_interface | 2.1.7 / 2.1.3 |

代码生成：`dart run build_runner build`（注意：`flutter pub run build_runner` 在本环境曾解析出旧版 entrypoint，
改用 `dart run build_runner` 后正常）。生成物：`app_database.g.dart`、`providers.g.dart`、`app_router.g.dart`、
各 `*_notifier.g.dart`、`theme_providers.g.dart`、`backup_providers.g.dart`，以及 `lib/l10n/generated/`（`flutter gen-l10n`）。

> 坑：`~/.pub-cache` 曾因早期并发 build_runner 损坏（build_runner 包内文件缺失），用
> `flutter pub cache repair --all`（重装 283 个包）修复。`l10n.yaml` 顶部多余的 `flutter:` 段已删除。

---

## 2. 阶段 A 功能完成度

| 规格条目 | 状态 | 说明 |
|---|---|---|
| 记录增删改（本地 SQLite/Drift） | ✅ | `RecordRepository`：create/update（含标签替换事务）/softDelete/restore/permanentDelete |
| 500ms 防抖自动保存 | ✅ | `EditRecordNotifier.onInputChanged`；返回时 `flush()` 强制落盘；保存串行化防止慢盘双建 |
| 保存状态指示（保存中/已保存/失败） | ✅ | AppBar 标题栏显示 |
| 分类（可选） | ✅ | 增删改、记录关联/解绑、删除分类时记录 categoryId 置空（事务） |
| 标签（可选） | ✅ | 增删改名、记录多标签关联/替换、删除标签时解绑（事务） |
| 中文子串搜索基线 | ✅ | 参数化 LIKE（`%`/`_`/`\` 转义），单字/双字/正文中段可查；多词 AND；查标题/正文/标签/分类 |
| 搜索排序 | ✅ | 标题精确(4) > 标题包含(3) > 标签/分类(2) > 正文(1)，再按收藏、更新时间 |
| 收藏 | ✅ | 编辑页星标 + 首页列表星标一键切换 |
| 回收站 | ✅ | 软删除列表、恢复、彻底删除、清空回收站（含二次确认） |
| JSON 完整备份 | ✅ | 含 schema_version、分类/标签/记录/关联；导出经系统分享 |
| Markdown ZIP 导出 | ✅ | 每记录一 .md（文件名做非法字符替换+截断+id 后缀防重名）；数量/总字节上限，超限截断并附 `_skipped.txt` 说明 |
| TXT 导出 | ✅ | 单文件，`====` 分隔 |
| JSON 导入恢复 | ✅ | 预览条数→确认→单事务导入，失败整体回滚；schema 校验（版本过大/缺字段/非法 JSON 均拒绝） |
| Markdown/TXT 导入 | ✅ | md 首行 `# ` 作标题，txt 用文件名作标题，均生成新 ID |
| 明暗主题 | ✅ | 跟随系统/浅色/深色，设置页切换 |
| 中英文界面 | ✅ | zh/en arb（81 key 对齐），跟随系统语言 |
| 搜索防注入 | ✅ | 全部参数化绑定；`%`/`_`/`\`/`'`/emoji/URL/注释注入均有单测覆盖 |

阶段 A 未做（留待后续）：批量删除/批量分类/多选模式动作（首页多选 UI 框架已搭，批量操作按钮为 TODO）、
云同步、加密、上架。

---

## 3. 测试（全部自动化，可复跑）

### 3.1 `flutter analyze`

- 命令：`flutter analyze`
- 结果：**No issues found!**（2026-10-05 最后一次运行，0 error / 0 warning / 0 info）

### 3.2 单元测试（`flutter test test/unit/`）

`test/unit/record_repository_test.dart`（30 tests）+ `test/unit/autosave_service_test.dart`（2 tests）：

- CRUD：创建/读取/更新/彻底删除、未知 id 返回 null
- 自动保存事务：创建时分类+标签一次事务写入；更新替换标签关联
- 分类标签关联：解绑分类、删除分类时记录 categoryId 置空、删除标签时解绑
- 回收站：软删除后列表排除/trash 包含、恢复、彻底删除
- 搜索排序：空查询按收藏+更新时间；标题精确 > 标题包含 > 正文；标签/分类命中 > 正文命中；收藏过滤；分类过滤；分页 limit/offset
- 中文：单字（服）、双字（服务）、正文中段（中间的一段）、多词 AND（服务 配置）
- 注入安全：`%` 不作通配符、`_` 不作单字符通配符、`\` 转义、单引号不破坏查询（`' OR '1'='1` 返回空）、emoji 字面匹配、含查询参数的 URL 字面匹配、`'; DROP TABLE records; --` 无害且表完好
- **测试中发现并修复的真实 bug**：`_searchWithTokens` 里 score 表达式在 SELECT 子句（WHERE 之前），
  但参数按"先 WHERE 后 score"顺序绑定，导致精确匹配（score 4）永远不命中。已改为 score/cond 分开收集、
  按 SQL 文本顺序绑定；排序单测现通过。

结果：**32/32 通过**

### 3.3 集成测试（`flutter test test/integration/`）

`test/integration/backup_roundtrip_test.dart`（6 tests，path_provider 用 fake 打到临时目录）：

- JSON 导出 → 全新空库导入 → 逐字段一致性：重新导出 JSON 与原导出逐字节等价（除 `exported_at`）；抽查记录标题/正文/收藏/分类/标签全部一致
- Markdown ZIP：解包验证每条记录一个 `.md`，文件名唯一且无路径分隔符，内容含标题/分类/标签/正文
- TXT：含全部标题正文，无标题记录显示 `(untitled)`
- 文本导入：`.md` 首行 `# ` 提取为标题；`.txt` 用文件名作标题
- 非法备份拒绝：非 JSON、根非对象、缺 schema_version、版本过大、缺 records 数组 → 全部抛 `ImportError`
- 事务性：中途失败的导入整体回滚，库内容不变

结果：**6/6 通过**

### 3.4 Widget 测试（`flutter test test/widget/`）

`test/widget/record_workflow_test.dart`（6 tests，`appDatabaseProvider` override 为内存库）：

- 首页空态（`No records yet`、新建按钮）
- 新建 → 输入 → 防抖 500ms → 状态 `Saved` → 返回后列表可见
- 搜索过滤（输入 Alpha 只剩 Alpha，清空恢复）
- 列表星标切换（star_border → star）
- 删除 → 回收站 → 恢复 → 回到首页（完整导航链）
- 设置页主题切换浅色/深色

结果：**6/6 通过**

### 3.5 全量

- 命令：`flutter test`
- 结果：**44/44 通过**（unit 32 + integration 6 + widget 6）

### 3.6 未验证项（VM 环境限制，如实列出，不虚构）

- 真机安装/运行：无 Android 真机/模拟器（VM 无 KVM），**未验证**
- 真机搜索 P95 性能（规格 §10 基线）：无真机，**未验证**
- 真机分享/文件选择（share_plus/file_picker 原生链路）：VM 上只能跑逻辑层，**未验证**
- 中文 IME 输入防抖：无真机，**未验证**

---

## 4. 构建

- 命令（依次执行）：
  1. `bash ~/workspace/suicun-env/gradle-proxy.sh`
  2. `flutter build apk --debug`
- 产物：`build/app/outputs/flutter-apk/app-debug.apk`（构建成功后填入大小/SHA）
- 构建状态：（构建进行中 / 成功 / 失败见下）

---

## 5. 文件清单（阶段 A 新增/改动）

```
lib/
  main.dart
  core/
    database/{tables,app_database,providers}.dart
    errors/app_errors.dart
    router/app_router.dart
  features/
    records/
      data/{record_repository,autosave_service}.dart
      domain/record_model.dart
      presentation/{records_notifier,edit_record_notifier,home_page,edit_record_page}.dart
    categories/
      data/category_repository.dart  domain/category_model.dart
      presentation/{categories_notifier,categories_page}.dart
    tags/
      data/tag_repository.dart  domain/tag_model.dart
      presentation/{tags_notifier,tags_page}.dart
    backup/
      data/{backup_service,backup_providers}.dart
    settings/presentation/{settings_page,backup_page}.dart
    trash/presentation/trash_page.dart
  shared/
    theme/{app_theme,theme_providers}.dart
    utils/date_formatter.dart
    widgets/record_list_tile.dart
  l10n/{app_zh,app_en}.arb + generated/
test/
  unit/{record_repository_test,autosave_service_test}.dart
  integration/backup_roundtrip_test.dart
  widget/record_workflow_test.dart
```

---

## 6. 已知偏离与阻塞

1. **Antigravity CLI 配额耗尽**（2026-10-05 09:55 CST 起）：后续实现由 Muse 直接完成，
   agy 只留下了最初 36 个文件的 scaffold（commit `083682f`）。
   - 额度策略（用户 2026-10-05 18:20/18:23 CST 指示）：agy 账号额度紧张，后续 agy 会话默认用
     `claude-sonnet-4-6`（Thinking）；Claude 模型提示用尽/限流时**不停工**，直接切
     `gemini-3.8-flash-high` 继续；只有需要强推理的疑难问题才值得等 Claude 额度恢复（且先评估）。
   - 实测 2026-10-05 18:25 CST：`gemini-3.8-flash-high` 同样 "Individual quota reached …
     Resets in 161h59m42s"（约 2026-10-12 恢复），当时所有列出模型均无可用额度。
     因此剩余工作（Gradle 打包排错等）由 Muse 直接完成，**未消耗任何 agy 推理额度**。
2. **riverpod_generator 4.x 命名变更**：`XxxNotifier` → `xxxProvider`（去 Notifier 后缀）、无 `XxxRef` 类型、
   函数与类同名会冲突（`themeMode` 函数改名 `resolvedThemeMode`）。drift 2.35 `OpenedDatabase` 改名
   `OpeningDetails`。file_picker 13 / share_plus 13 API 变更已适配。
3. 无真机：见 §3.6。
