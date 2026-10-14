# WebDAV 条件写入探针记录（脱敏）

- 日期：2026-10-06
- 服务：坚果云 WebDAV（`dav.jianguoyun.com/dav/`），用户自有账号，真机实测
- App 版本：stage-c-20261006（含 UI 美化合并版），分支 `antigravity/stage-c`

## 探针做法（代码位置：`lib/features/sync/webdav_sync_provider.dart` → `probe()`）

1. 向临时目录 PUT 探针文件，请求头携带 `If-None-Match: *`（`createOnly: true`）。
2. 对同一路径再次 PUT，同样携带 `If-None-Match: *`。
   - 符合规范的服务器：文件已存在 → 返回 `412 Precondition Failed` → 判定支持条件创建。
   - 实际结果：**返回 2xx（直接覆盖）** → 判定不支持。
3. GET 探针文件取 ETag，再 PUT 携带伪造 `If-Match`，期望 412（此步仅在拿到 ETag 时执行）。

## 结论

坚果云 WebDAV **忽略 `If-None-Match` 请求头**，不支持条件创建（大概率也不支持 `If-Match` 条件更新）。
因此按原规格 §10/§11.3.5，`createVault` 被 `SyncError(conditionalWriteUnsupported)` 拦截，
建库流程无法继续。这是服务器行为实测结论，非客户端误判。

## 脱敏说明

本记录不包含：WebDAV 用户名/密码、Authorization 头、加密密码、恢复密钥、
主密钥、笔记正文、完整请求 URL（仅域名）。探针使用的临时文件名均为随机生成，
测试后已删除。

## 后续

原规格"缺少条件写入就禁止所有同步"的要求已按用户指示调整，
见 `docs/sync-redesign-plan.md`（v2 追加式多密钥协议，不再依赖条件写入）。
