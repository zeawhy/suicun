# 同步协议 v2 重设计方案（兼容无条件写入 WebDAV）

- 日期：2026-10-06
- 背景：坚果云 WebDAV 实测忽略 `If-None-Match`（见 `docs/probe-jianguoyun-note.md`）。
  原 v1 协议依赖"单 header.json + 条件创建"实现建库原子性，在此失效。
- 目标：v2 协议在**没有任何服务端原子性**的假设下正确工作；追加式（append-only）
  设计，所有共享状态只增不改，用确定性选择规则收敛。
- 参考：Joplin E2EE（独立 master key 对象、key_id 绑定、多密钥容忍、单活跃加密密钥）。

## 1. 核心思想

v1 的单点争抢是 `header.json`（谁创建/覆盖它，谁就定义了 vault 密钥）。
v2 取消这个单点：

- 每把主密钥是**独立对象** `v2/keys/<key_id>.<variant>.json`，随机 key_id，无争抢。
- 每条加密对象在**认证元数据（AAD）中绑定 key_id**，解密时按 key_id 找密钥。
- v2 目录下**没有任何文件会被覆写**：key_id 随机、variant 随机、revision_id 随机。
  并发只产生"多个并存"，不产生"覆盖丢失"。
- 需要"选一个"的场景（当前加密用哪把密钥）用**确定性规则**收敛，
  不依赖设备时间，不依赖最后覆盖某个共享文件。

## 2. 目录布局与数据格式

```
<syncDir>/v2/keys/<key_id>.<variant8>.json     # 密钥对象，append-only
<syncDir>/v2/objects/<revision_id>.enc        # 版本对象，append-only（沿用 v1）
```

`<syncDir>` 本人是用户配置的同步目录；**目录本身就是 vault 的身份**，v2 不再使用全局 vault_id。
（`sync_state.vault_id` 存 `"v2:" + sha256(directory)前16hex`，仅作本地行标识。）

### 2.1 密钥对象（`suicun-vault-key`）

```json
{
  "format": "suicun-vault-key",
  "protocol_version": 2,
  "key_id": "<16位hex，8字节随机>",
  "origin": "created | v1-migrated",
  "created_by_device": "<device_id>",
  "created_at": "<ISO8601>",
  "kdf": {
    "algorithm": "argon2id", "version": 19,
    "memory_kb": 65536, "iterations": 3, "parallelism": 1,
    "salt_b64": "<16字节>"
  },
  "slots": [
    {"type": "password", "nonce_b64": "<12字节>", "wrapped_b64": "<48字节>"},
    {"type": "recovery", "key_id": "<8位hex>", "nonce_b64": "<12字节>", "wrapped_b64": "<48字节>"}
  ]
}
```

- `created_at` / `created_by_device` / `origin` 仅作信息展示，**绝不用于排序或决策**。
- KDF 参数上限钳制沿用 v1（memory ≤ 256MiB 等），防恶意文件。
- slot AAD：`suicun/v2/keyslot/<key_id>/<slot_type>`。
- 恢复密钥机制沿用 v1（32 字节随机、展示格式、SHA256 域分离包装、one-shot 领取不落盘）。
- **前向兼容**：读取时枚举 `keys/` 下**所有**文件，按 key_id 分组，每组尝试全部 variant
  直到解开为止。以后密码修改追加 variant 时，老客户端无需升级即可读取。

### 2.2 数据对象

沿用 v1 envelope，加 `"key_id"` 字段：

```json
{
  "format": "suicun-revision",
  "protocol_version": 2,
  "key_id": "<16位hex>",
  "revision_id": "...", "entity_type": "...", "entity_id": "...",
  "nonce_b64": "<12字节随机>", "ciphertext_b64": "..."
}
```

- AAD：`suicun/v2/object/<key_id>/<revision_id>/<entity_type>`。
  绑定 key_id + 对象 ID + 协议版本 + 实体类型，防止元数据替换。
- payload 内部三 id 一致性检查沿用 v1。
- **迁移来的旧对象**：字节原样拷贝，无 key_id 字段 → 按 legacy 处理：
  用迁移产生的 legacy 密钥解密，以重建的 v1 AAD
  （`suicun/v1/object/<legacy_vault_id>/<revision_id>/<entity_type>`）验 tag。
  legacy_vault_id 存在 legacy 密钥对象的 `"legacy_vault_id"` 字段。

## 3. 初始化与加入（原则 1、2）

### 3.1 建库 `createVault(config, password)`

1. `listKeys()`（PROPFIND `v2/keys/`，Depth:1）。
   - 非空 → **已有库，禁止新建**，转加入流程（UI 提示"检测到已有同步库，已为你加入"）。
     （目录枚举可能暂时不完整而误判为空 → 产生第二把密钥 → 被多密钥容错吸收，无害。）
2. 为空 → 生成 32 字节随机 K、`key_id`，Argon2id 包装（沿用 v1 参数），
   PUT `v2/keys/<key_id>.<variant>.json`（**普通 PUT，无需条件**——文件名随机，无争抢）。
3. `_finishJoinV2`（见 §5）。

**删除**原 `conditionalWriteUnsupported` 建库拦截。probe 保留作诊断，不再门控任何操作。

### 3.2 加库 `joinVault(config, {password, recoveryKey})`

1. `listKeys()`：
   - 为空 → 检查 v1 `header.json`：存在 → 返回 `needsMigration`（UI 走迁移流程 §8）；
     不存在 → `vaultNotFound`。
2. 下载并解析全部密钥对象（protocol_version > 2 → `unsupportedProtocol` 停止，永不覆盖）。
3. 用所给凭据逐把尝试解锁 → 得到 `unlocked: Map<key_id, K>` 与 `locked: [key_id]`。
   - unlocked 为空 → `wrongPasswordOrKey`（**保留原数据，不做任何写入**）。
4. `_finishJoinV2`。

### 3.3 意外并发初始化

A、B 同时看到空目录，各自创建 K_A、K_B 并上传。结果：两把有效密钥并存。
- 同密码：两把都能解开，vault 视图统一。
- 不同密码：各设备解开自己知道的；遇到解不开的对象 → `locked` 计数，
  UI 温和提示"部分内容需要另一把密钥的密码"，提供输入入口；**不丢弃、不覆盖、不假装合并**。

## 4. 写入密钥选择（原则 3）

- **解密密钥**：全部已解锁密钥（历史密钥永久可用于解密）。
- **加密密钥（active）**：`activeKeyId = min(unlockedKeyIds)`（字典序最小）。
  - 确定性、无需设备时间、无需共享文件。
  - 密钥集合变化（新密钥对象到达）时重算。
- **收敛性**：目录枚举一致的设备一定选出同一把密钥；枚举暂时不一致时
  可能短暂分歧——无害，因为所有密钥的写入都可被持有者解密，待枚举一致后收敛。
  **不承诺任意网络时序下立即收敛**（见 §9 假设）。
- 零把已解锁密钥 → 同步暂停并提示需要密码（不上传、只读本地）；
  部分解锁 → 正常同步，可解密的照常，未知/未解锁密钥的对象下载后 skip 记 `locked`。

## 5. 会话与本地状态

- `VaultSession` → `MultiKeySession { keys: Map<keyId, Uint8List>, activeKeyId: String }`，
  纯内存，经 `SyncSessionHolder` 提供。
- 平台安全存储：
  - `suicun.sync.keys2`：JSON 数组，已知 key_id 列表（索引）。
  - `suicun.sync.kvault2.<key_id>`：base64(K)。v1 的 `suicun.sync.kvault.<vaultId>` 保留不动（回滚用）。
- `sync_state`：`vault_id = "v2:" + sha256(directory)前16hex`，`protocol_version = 2`。
  其余表（revisions/outbox/remote_receipts/conflicts/sync_skipped）**不变**。

## 6. 同步流程变更（原则 4；其余沿用 v1）

沿用 v1 的：不可变版本对象、父版本 DAG（computeHeads/ancestorsOf）、
持久 outbox（repository 事务内入队）、冲突保留（heads>1 → open conflict，4 种解决）、
随机 revision_id、重试沿用原 ID 与原字节、429/401/507 等错误映射、
"枚举不完整不推断删除"（只有 tombstone revision 才表示删除）。

变更点：

1. **每轮 sync 起始 `refreshKeys()`**：list `v2/keys/`，下载新增密钥文件并入会话；
   解不开的记 locked（UI 计数，不阻塞）。
2. **取消 header.json 检查**：v2 不再读取/要求 header.json。
3. **上传加密**：用 active key，envelope 写 key_id，AAD 按 §2.2。
   上传本身：有条件创建能力 → `createOnly` PUT（保留， defense in depth）；
   无 → 普通 PUT + 读回字节校验（**仅做完整性确认，不作为并发证明**）。
4. **下载解密**：按 envelope key_id 取 K；
   - key_id 未知 → 刷新 keys 后重试一次 → 仍未知 → skip(`unknown-key`)；
   - 已知但未解锁 → skip(`locked-key`)，计数供 UI 提示；
   - 解密/tag 失败 → skip(`decrypt`)（**永不入库**，沿用 v1）。
5. **密钥文件上传**：普通 PUT（随机文件名，无争抢，无需读回）。

## 7. 密码修改与恢复（原则 6）

- **恢复**：每把密钥独立 recovery slot。新设备：凭 WebDAV 凭据 + 加密密码
  解开 password slot；或凭恢复密钥解开 recovery slot。**只凭这两样恢复全部内容，
  不依赖旧手机设备密钥**（K 存在各设备自己的安全存储，换机后重新存）。
- **密码修改（v1 范围）**：**暂不开放 UI**。
  原因：多密钥下"修改密码"语义是逐把重包装；并发重包装存在 slot 覆盖语义冲突，
  且无 delete 原语无法让旧密码真正失效。机制已预留（§2.1 的多 variant 读取），
  待设计"追加式 variant + 旧 variant 失效标记"后再开放。
  UI 在相关入口给出说明，不因此禁止普通同步。

## 8. 兼容与迁移（原则 7）

- **版本识别**：`v2/keys/` 非空 → v2 库；否则若 `<dir>/header.json` 存在 → v1 库；
  否则 → 未初始化。
- **v1 读取能力保留**：`VaultCrypto` 的 v1 header parse/open 不删除（迁移用）。
- **迁移流程**（UI 确认页："发现旧协议同步库" → [备份并迁移]）：
  1. 明确告知：旧目录原样保留作备份；迁移为一次性拷贝。
  2. 读 v1 `header.json` → 密码解出 K_vault（失败 → `wrongPasswordOrKey`，**不碰任何远端**）。
  3. 生成 v2 密钥对象（`origin: v1-migrated`，新随机 key_id，
     password slot 用原 salt/参数重包装同一 K_vault，
     recovery slot 原样搬运 wrapped 字节，附 `legacy_vault_id`）。
  4. 拷贝 `objects/` → `v2/objects/`（同 revision_id；GET 校验字节一致；中断可重跑，
     已拷贝的跳过——幂等）。
  5. 全部校验通过后，把 `header.json` **改名**为 `header.json.migrated-backup`
     （内容不动；使旧客户端看到"无 header"而安全停止，不再危险写入）。
     ⚠️ 改名是最后一步；之前任何失败都不动旧文件，重跑可恢复。
- **新协议目录**：v2 在 `<dir>/v2/`，与 v1 文件无交集，天然隔离。
- **不兼容客户端**：key 对象/ revision 的 `protocol_version > 2` → 停止并报
  `unsupportedProtocol`，永不覆盖。旧 v1 客户端不会进入 `<dir>/v2/`。

## 9. 一致性假设与剩余限制（诚实声明）

**依赖的假设**：
1. 单对象 PUT 是原子的（读到要么完整旧字节，要么完整新字节）——读回校验有意义的前提。
2. 目录枚举**最终一致**：某次 list 可能暂时缺少数个刚上传的对象（尤其坚果云这类
   可能有传播延迟的服务）。影响：active key 选择短暂分歧（无害，§4）、
   某轮同步漏掉刚到达的对象（下一轮补上）。**不承诺一轮同步看到全部远端写入**。
3. v2 不依赖任何服务端原子性；所有共享状态追加式，收敛靠确定性规则。

**剩余限制**（v1 不解决）：
- 无密钥轮换/退役机制（无法删除密钥文件；min-key_id 规则无"弃用"概念）。
- 密码修改 UI 暂不开放（§7）。
- 迁移来的旧对象 AAD 不绑定 key_id（以重建的 v1 AAD 验 tag，tag 本身仍校验）。
- 旧密码在未来的密码修改机制下仍可能解开历史 variant（无 delete 原语的固有局限）。
- 本地 secure storage 丢失 + 密码/恢复密钥全丢 = 数据不可恢复（与 v1 相同，无后门）。

**明确不做的**（用户禁令）：
- 不简单删除条件写入检查了事（v2 从设计上不再需要它，而非绕过它）。
- 不用"上传后 GET 校验"代替并发控制（它只做完整性确认）。
- 不让用户维护多个库（多密钥在同一目录、同一 vault 视图）。

## 10. UI 变更（原则 8）

1. **修复**：同步向导各 catch 处的 `e.toString()` → `SyncError.message(english: locale)`，
   `SyncError(conditionalWriteUnsupported)` 这类内部串永不直接展示。
   （`sync_errors.dart` 的中英映射已存在；另有几处 presentation 文件同样问题，一并修。）
2. 正常流程隐藏 key_id、variant、protocol_version、heads 等细节。
3. 新增用户可见状态（中英 l10n）：
   - 建库时发现已有密钥 → "检测到已有同步库，已为你加入 / An existing sync vault was found and joined"。
   - 部分密钥未解锁 → "有 N 把密钥未解锁，部分内容暂时无法显示" + [输入密码]。
   - 迁移确认页文案（§8）。
   - 密码修改暂缓说明（§7）。
4. 恢复密钥 one-shot 展示流程不变（每把新建密钥各展示一次）。

## 11. 测试计划（FakeSyncProvider 扩展，`supportsConditionalCreate=false` 为默认场景）

在现有 `test/unit/sync/` 基础上新增 `sync_v2_test.dart`（及必要的 fake 扩展：
预置 v1 vault 的 helper、keys 目录 list 支持——当前 fake 的 list 按路径前缀工作，
确认可覆盖 `v2/keys/`）：

1. **A 初始化 B 加入**：A createVault → 建记录/分类/标签 → syncNow；
   B joinVault(同密码) → syncNow → 数据全对；存储字节无明文。
2. **并发初始化（同密码）**：A、B 同步执行 createVault → 两把密钥并存；
   各自 syncNow 后两端数据互通；active key 收敛到同一 key_id（min）。
3. **并发初始化（不同密码）**：两把密钥；A 只能解开自己的；
   B 的对象在 A 端记 locked、不丢弃；A 输入 B 的密码后解锁可见。
4. **密钥对象晚到/目录不完整**：list 时隐藏某 key 文件 → active key 暂为 min(可见)；
   恢复完整 list → 收敛到全局 min；期间写入的对象两端最终都可读。
5. **双端离线同改一条**：冲突保留（沿用既有冲突测试模式，v2 envelope 下重跑）。
6. **上传成功后超时/进程退出/重复重试**：timeoutAfterPut → 重试幂等，远端单对象；
   新 engine 同 DB 重建 session 后不重复上传。
7. **新机完整恢复**：双密钥 vault（含历史密钥加密的对象）→ 全新 DB recover →
   全部记录/分类/标签/收藏恢复。
8. **错误密码/密钥篡改**：错密码 join → wrongPasswordOrKey 且远端未被改动；
   篡改某 key 文件字节 → 该文件 skip，其他密钥正常；篡改对象密文 → skip 不入库。
9. **v1→v2 迁移**：fake 中预置 v1 vault（header.json + 3 个对象）→ 迁移 →
   v2 可读全部；header.json 已改名备份；旧对象字节与 v1 一致；
   中途（拷贝 2/3 后）中断 → 重跑完成；迁移失败（错密码）→ 远端零改动。
10. **无条件写入全程**：以上全部在 `supportsConditionalCreate=false` 的 fake 上跑；
    另在 `=true` 的 fake 上跑核心流程回归（v2 不依赖条件写入，但有则用）。

`flutter analyze` 0 issue；全量 `flutter test` 全绿。v1 既有测试不得 weaken；
`4g`（无条件创建抛 conditionalWriteUnsupported）预期变更——v1 建库拦截已删除，
该断言改为"v2 建库在无条件写入服务上成功"。

## 12. 数据格式变更清单

| 项目 | v1 | v2 |
|---|---|---|
| 密钥载体 | 单 `header.json`（争抢点） | `v2/keys/<key_id>.<variant>.json`（多个并存） |
| vault 身份 | `vault_id`（UUID） | 同步目录本身；`sync_state.vault_id="v2:"+sha256(dir)` 仅本地标识 |
| 对象路径 | `objects/<rev>.enc` | `v2/objects/<rev>.enc` |
| envelope | 无 key_id | `+ key_id` 字段 |
| AAD（对象） | `suicun/v1/object/<vault>/<rev>/<type>` | `suicun/v2/object/<key_id>/<rev>/<type>` |
| AAD（slot） | `suicun/v1/header/<vault>/<type>` | `suicun/v2/keyslot/<key_id>/<type>` |
| 条件写入 | 建库强制要求 | **不再要求**（有则用，无亦可） |
| secure storage | `suicun.sync.kvault.<vaultId>` | `suicun.sync.keys2` 索引 + `suicun.sync.kvault2.<key_id>`（v1 键保留） |
| DB schema | v3 | v4（`sync_state` 语义变更；重命名/新增列以最小迁移实现，revisions 等表不变） |

## 13. 实施顺序

1. `vault_crypto.dart`：v2 密钥对象 create/parse/open（双 slot）+ v2 envelope 加解密
   （AAD 含 key_id）+ legacy 对象解密（v1 AAD 重建）。**v1 函数全部保留**。
2. `webdav_sync_provider.dart`：probe 保留（诊断）；上传路径保留能力感知
   （有条件则用）。`list` 需覆盖 `v2/keys/`（已有通用实现，确认）。
3. `sync_engine.dart`：MultiKeySession；createVault/joinVault/recoverFromRemote 重写；
   sync pass 的 key 刷新、解密路由、active key 加密；删除建库门控；
   迁移 `migrateV1ToV2()`（UI 通过 contract 调用）。
4. `sync_contract.dart`：新状态（lockedKeyCount、needsMigration）与其他层解耦。
5. UI：向导/设置/恢复页的错误展示修复 + 新增文案（中英）。
6. 测试：§11。
7. 文档：`docs/product-spec.md` 同步协议章节改写为 v2、`docs/sync-v2-migration.md`、
   `docs/implementation-status.md` 更新。
