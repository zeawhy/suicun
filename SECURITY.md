# Security Policy

[English](#english) | [简体中文](#简体中文)

---

<a name="english"></a>
## English

### Supported versions

Only the latest version released on [Google Play](https://play.google.com/store/apps/details?id=com.suivault.app) or [GitHub Releases](https://github.com/zeawhy/suicun/releases) receives security updates.

| Version | Supported |
| --- | --- |
| Latest release (Google Play / GitHub Releases) | :white_check_mark: |
| Older releases | :x: |

---

### Reporting a vulnerability

Please **do not** report security vulnerabilities through public GitHub issues.

- **Preferred method**: Submit a report via GitHub Private Vulnerability Reporting at [zeawhy/suicun/security/advisories/new](https://github.com/zeawhy/suicun/security/advisories/new).
- **Alternative method**: Send an email to [yuliuslux@outlook.com](mailto:yuliuslux@outlook.com) with a subject line prefixed with `[SuiVault Security]`.

When submitting a report, please include:
1. Affected version(s) of SuiVault.
2. Step-by-step reproduction instructions.
3. Impact assessment and potential attack vectors.
4. Proof of Concept (PoC) scripts, files, or reproduction logs (if available).
5. **Important**: Do **not** include any real personal or sensitive data in reports and PoCs.

---

### Response process

SuiVault is maintained by an individual developer. We adhere to realistic and responsible response timelines:

- **Within 7 days**: Acknowledge receipt of the vulnerability report.
- **Within 30 days**: Provide an assessment result and remediation plan.
- **Upon release**: Publish a GitHub Security Advisory and publicly credit the reporter (with the reporter's consent).
- **Coordinated disclosure**: Default 90-day coordinated disclosure period before any public disclosure.

---

### Scope

#### In scope
- Local database encryption and key lifecycle management.
- Encrypted backup container format (generation, export, and restoration).
- ID document photo and attachment encryption at rest.
- WebDAV synchronization end-to-end encryption (E2EE) and transport security.
- App lock bypass vulnerabilities.
- Android system backup or unauthorized data extraction leading to sensitive data exposure.
- Data leakage or corruption occurring during backup, restore, or database migration flows.

#### Out of scope
- Devices that are rooted, jailbroken, or compromised by malware.
- Vulnerabilities within the user's self-hosted or third-party WebDAV server infrastructure.
- Attacks requiring physical access to an unlocked device.
- Social engineering attacks against users.
- Known public vulnerabilities in third-party dependencies (you are welcome to notify us to update dependencies via regular GitHub issues).

---

### Security design

The following security architecture details reflect the actual implementation in the codebase:

1. **Local Database Encryption (SQLCipher)**
   - Database files (`suicun.db` and associated WAL/journal files) are encrypted using SQLCipher (`PRAGMA key = "x'<hex>'"`) via native assets / sqlite3.
   - A cryptographically secure random 256-bit database key is generated on first launch (`Random.secure()`).
   - The key is persisted in platform secure storage backed by the Android Keystore using `flutter_secure_storage` under key `suicun.crypto.dbKey.v1`.
   - The key is **never** derived from a user PIN and is never uploaded or escrowed.
   - *Code references*: [`lib/core/crypto/database_encryption_service.dart`](lib/core/crypto/database_encryption_service.dart), [`lib/core/crypto/key_value_store.dart`](lib/core/crypto/key_value_store.dart), [`pubspec.yaml`](pubspec.yaml).

2. **Encrypted Backup (Argon2id + AES-256-GCM)**
   - Exported backups use a self-contained JSON container (`format: "suicun-encrypted-backup"`, `version: 1`).
   - Password key derivation uses **Argon2id** (following RFC 9106 recommendations):
     - Algorithm: `argon2id` (version 19 / 0x13)
     - Memory: `65536` KiB (64 MiB)
     - Iterations: `3`
     - Parallelism: `1` (ensures performance on lower-end devices)
     - Salt: 16 cryptographically random bytes (base64 encoded)
     - Hash length: 32 bytes (256 bits)
   - Payload encryption uses **AES-256-GCM** with a 12-byte random nonce and 16-byte authentication MAC.
   - Backup passwords are never stored or escrowed.
   - *Code reference*: [`lib/core/crypto/backup_crypto.dart`](lib/core/crypto/backup_crypto.dart).

3. **ID Document Photo Encryption (AES-256-GCM)**
   - ID card photos are encrypted at rest prior to being written to the app's private documents directory under `id_photos/`.
   - File naming and extension: `id_photos/{recordId}_{front|back}_{timestamp}.enc`.
   - Container format: 4-byte magic `"SVF1"` (`0x53, 0x56, 0x46, 0x31`) + 12-byte nonce + ciphertext + 16-byte MAC.
   - A dedicated 256-bit photo encryption key is generated randomly on first use and stored in the Android Keystore via `flutter_secure_storage` under key `suicun.crypto.fileKey.v1`.
   - Unencrypted temporary image files from the image picker are deleted immediately after encryption. Plaintext is never stored to disk and decrypted bytes reside only in memory for rendering.
   - *Code references*: [`lib/core/crypto/file_encryption_service.dart`](lib/core/crypto/file_encryption_service.dart), [`lib/features/records/presentation/template_views/id_photo_storage.dart`](lib/features/records/presentation/template_views/id_photo_storage.dart).

4. **WebDAV Synchronization (End-to-End Encryption & Transport Security)**
   - **End-to-End Encryption (E2EE)**: Sync data is encrypted on the device before transmission. The remote WebDAV server only receives encrypted JSON envelopes (`suicun-vault-header`, `suicun-vault-key`, `suicun-revision`), never plaintext notes or credentials.
   - Vault encryption keys are derived via Argon2id (64 MiB memory, 3 iterations, 1 parallelism, 16-byte salt, 32-byte hash) or a SHA-256 wrapped 256-bit recovery key. Revisions are encrypted using AES-256-GCM with a 12-byte random nonce and authenticated additional data (AAD).
   - **Transport Security**: HTTPS (`https://`) is strictly enforced both at configuration validation and runtime connection levels. HTTP URLs and cross-scheme redirects from HTTPS to HTTP are rejected.
   - WebDAV server credentials are stored in secure storage under prefix `suicun.webdav.*`.
   - *Code references*: [`lib/features/sync/vault_crypto.dart`](lib/features/sync/vault_crypto.dart), [`lib/services/webdav_service.dart`](lib/services/webdav_service.dart), [`lib/features/sync/webdav_sync_provider.dart`](lib/features/sync/webdav_sync_provider.dart).

5. **Android System Backup & Data Extraction Prevention**
   - Android auto-backup and device-to-device transfers are completely disabled via `android:allowBackup="false"` and `android:fullBackupContent="false"` in `AndroidManifest.xml`.
   - `data_extraction_rules.xml` excludes all storage domains (`root`, `file`, `database`, `sharedpref`, `external`) from both `<cloud-backup>` and `<device-transfer>` to prevent leaking unencrypted photos or creating unrecoverable databases (since Keystore keys cannot be transferred across devices).
   - *Code references*: [`android/app/src/main/AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml), [`android/app/src/main/res/xml/data_extraction_rules.xml`](android/app/src/main/res/xml/data_extraction_rules.xml).

6. **Zero Tracking, Zero Telemetry, No Third-Party SDKs**
   - SuiVault has no user account system, no centralized servers, and collects zero telemetry or analytics data.
   - No advertising, analytics, or tracking SDKs are bundled into the application.
   - *Code reference*: [`pubspec.yaml`](pubspec.yaml).

7. **Known Security Limitations & Boundary Assumptions**
   - **Forgotten Backup Password**: Mathematically irrecoverable due to Argon2id + AES-256-GCM without backdoor.
   - **Lost Local Database Key**: If the application data is cleared or the device is wiped without an existing encrypted backup, the database cannot be decrypted or recovered (the 256-bit key is in Keystore only).
   - **App Lock Boundaries**: App PIN is hashed with Argon2id (16 MiB, 2 iterations, 1 parallelism, stored in `suicun.applock.pinHash.v2`) with a 30s lockout after 5 failures. However, the app lock gates the UI only and relies on Android OS device authentication fallback (`local_auth`). Root access or physical control of an unlocked device can bypass UI locks; the database encryption operates independently.
   - **Flash Storage Wear-Leveling**: Migrating legacy plaintext SQLite databases using `sqlcipher_export` deletes the old unencrypted file, but flash memory controllers may retain physical block remnants that cannot be wiped by user-space apps.
   - **Disabled System Backup**: Moving to a new phone requires either importing an encrypted backup file or using WebDAV sync.
   - *Code / doc references*: [`docs/key-recovery.md`](docs/key-recovery.md), [`lib/features/security/data/app_lock_service.dart`](lib/features/security/data/app_lock_service.dart).

---

### Past advisories

- None. New advisories will be listed here as security issues are addressed.

---

<a name="简体中文"></a>
## 简体中文

### 支持的版本

只有发布在 [Google Play](https://play.google.com/store/apps/details?id=com.suivault.app) 或 [GitHub Releases](https://github.com/zeawhy/suicun/releases) 上的最新版本接受安全修复。

| 版本 | 是否支持安全更新 |
| --- | --- |
| 最新正式发布版（Google Play / GitHub Releases） | :white_check_mark: |
| 历史旧版本 | :x: |

---

### 报告安全漏洞

请**不要**通过公开的 GitHub Issue 提交安全漏洞。

- **首选方式**：通过 GitHub「私密漏洞报告」（Private Vulnerability Reporting）提交：[zeawhy/suicun/security/advisories/new](https://github.com/zeawhy/suicun/security/advisories/new)。
- **备选方式**：发送邮件至 [yuliuslux@outlook.com](mailto:yuliuslux@outlook.com)，邮件标题请以 `[SuiVault Security]` 开头。

报告中请尽可能包含以下信息：
1. 受影响的 SuiVault 版本。
2. 详细的复现步骤。
3. 漏洞影响范围与潜在攻击场景。
4. 概念验证（PoC）脚本、文件或日志（如有）。
5. **重要说明**：请**不要**在报告和 PoC 中附带任何真实的个人敏感数据。

---

### 响应流程

SuiVault 为个人独立维护的开源项目，我们承诺按实际能力推进，不设立无法兑现的时限：

- **7 天内**：确认收到漏洞报告。
- **30 天内**：给出漏洞评估结果及修复计划。
- **修复发布后**：公开 GitHub Security Advisory，并在获得报告人同意的前提下公开致谢。
- **协调披露**：默认采用 90 天协调披露期（Coordinated Vulnerability Disclosure）。

---

### 适用范围

#### 范围内
- 本地数据库加密与密钥生命周期管理。
- 加密备份容器格式（导出与恢复）。
- 证件照片及附件的静态存储加密。
- WebDAV 同步的端到端加密（E2EE）与传输安全。
- 应用锁绕过漏洞。
- Android 系统备份或未授权数据提取导致的数据泄露。
- 备份恢复或数据库迁移过程中的数据泄露或损坏。

#### 范围外
- 已 Root、越狱或已被恶意软件控制的设备。
- 用户自行搭建或使用的第三方 WebDAV 服务器本身的安全性问题。
- 需要物理接触已解锁手机的本地攻击。
- 针对用户的社会工程学攻击。
- 第三方依赖库中已公开的已知漏洞（欢迎通过常规 GitHub Issue 提醒我们升级依赖）。

---

### 安全架构设计

以下安全设计均与代码库实际实现核对一致：

1. **本地数据库加密（SQLCipher）**
   - 数据库文件（`suicun.db` 及关联的 WAL / journal 文件）通过原生 SQLCipher（`PRAGMA key = "x'<hex>'"'`）加密。
   - 首次启动时通过密码学安全随机数生成 256 位随机数据库密钥（`Random.secure()`）。
   - 密钥保存在 Android Keystore 支持的安全存储中（经由 `flutter_secure_storage`，键名为 `suicun.crypto.dbKey.v1`）。
   - 密钥**绝不**由用户低熵 PIN 派生，且绝不上载或托管（escrow）。
   - *代码依据*：[`lib/core/crypto/database_encryption_service.dart`](lib/core/crypto/database_encryption_service.dart)、[`lib/core/crypto/key_value_store.dart`](lib/core/crypto/key_value_store.dart)、[`pubspec.yaml`](pubspec.yaml)。

2. **加密备份（Argon2id + AES-256-GCM）**
   - 导出的加密备份为自包含 JSON 容器（`format: "suicun-encrypted-backup"`, `version: 1`）。
   - 基于用户密码的密钥派生使用 **Argon2id**（遵循 RFC 9106 首要推荐参数）：
     - 算法：`argon2id`（版本 19 / 0x13）
     - 内存大小：`65536` KiB（64 MiB）
     - 迭代次数：`3`
     - 并行度：`1`（保证低端手机平稳可用）
     - 盐值：16 字节密码学随机数（Base64 编码）
     - 派生哈希长度：32 字节（256 位）
   - 数据加密使用 **AES-256-GCM**，配合 12 字节随机 Nonce 与 16 字节身份认证标签（MAC）。
   - 备份密码从不落盘存储，也无第三方托管。
   - *代码依据*：[`lib/core/crypto/backup_crypto.dart`](lib/core/crypto/backup_crypto.dart)。

3. **证件照片加密（AES-256-GCM）**
   - 证件照片在写入应用私有文档目录 `id_photos/` 前使用 AES-256-GCM 加密。
   - 文件命名与后缀：`id_photos/{recordId}_{front|back}_{timestamp}.enc`。
   - 密文容器格式：4 字节魔数 `"SVF1"`（`0x53, 0x56, 0x46, 0x31`）+ 12 字节 Nonce + 密文 + 16 字节 MAC。
   - 独立的 256 位照片加密密钥在首次使用时随机生成，并保存在 Android Keystore（经由 `flutter_secure_storage`，键名为 `suicun.crypto.fileKey.v1`）。
   - 选择图片时的临时文件在加密完成后立即彻底删除；明文绝不持久化落盘，解密后的字节仅保留在内存中供 UI 渲染。
   - *代码依据*：[`lib/core/crypto/file_encryption_service.dart`](lib/core/crypto/file_encryption_service.dart)、[`lib/features/records/presentation/template_views/id_photo_storage.dart`](lib/features/records/presentation/template_views/id_photo_storage.dart)。

4. **WebDAV 同步（端到端加密与传输安全）**
   - **端到端加密（E2EE）**：同步数据在设备本地加密后再上传至 WebDAV，远程服务器仅存储加密信封（`suicun-vault-header`, `suicun-vault-key`, `suicun-revision`），无法获取明文笔记或配置。
   - 同步库密钥派生支持 Argon2id（64 MiB 内存、3 次迭代、并行度 1、16 字节盐、32 字节哈希）或 SHA-256 包装的 256 位恢复密钥；变更对象（Revision）采用 AES-256-GCM 加密，并结合 AAD 绑定实体 ID 与版本。
   - **传输安全**：配置校验与底层 HTTP Client 均强制使用 HTTPS（`https://`），严格阻止降级到 HTTP 及向非 HTTPS 地址的重定向。
   - WebDAV 登录凭据保存在安全存储中，键名前缀为 `suicun.webdav.*`。
   - *代码依据*：[`lib/features/sync/vault_crypto.dart`](lib/features/sync/vault_crypto.dart)、[`lib/services/webdav_service.dart`](lib/services/webdav_service.dart)、[`lib/features/sync/webdav_sync_provider.dart`](lib/features/sync/webdav_sync_provider.dart)。

5. **Android 系统备份与数据提取防护**
   - 在 `AndroidManifest.xml` 中明确声明 `android:allowBackup="false"` 与 `android:fullBackupContent="false"`，彻底禁用系统备份。
   - 配置 `data_extraction_rules.xml`，对 `<cloud-backup>` 和 `<device-transfer>` 排除所有存储域（`root`, `file`, `database`, `sharedpref`, `external`），防止未加密照片泄露或因 Keystore 密钥无法跨机迁移导致数据库损坏无法启动。
   - *代码依据*：[`android/app/src/main/AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml)、[`android/app/src/main/res/xml/data_extraction_rules.xml`](android/app/src/main/res/xml/data_extraction_rules.xml)。

6. **零跟踪、无服务器、无第三方 SDK**
   - 随存无用户账号体系、无自建中心化后端服务器、不收集任何数据统计或遥测上报。
   - 项目不依赖任何广告、统计或行为追踪第三方 SDK。
   - *代码依据*：[`pubspec.yaml`](pubspec.yaml)。

7. **已知限制与安全边界假设**
   - **备份密码遗忘**：由于采用 Argon2id + AES-256-GCM 且无后门设计，密码遗忘后在数学上不可解密恢复。
   - **本地数据库密钥丢失**：若用户清除应用数据或设备恢复出厂且未留有加密备份，本地数据库将永久无法恢复（256 位随机密钥仅存在于 Keystore 中，不托管）。
   - **应用锁边界**：应用锁 PIN 使用 Argon2id（16 MiB 内存、2 次迭代、并行度 1，存储于 `suicun.applock.pinHash.v2`）哈希存储，连续 5 次失败锁定 30 秒。但应用锁本质仅为 UI 屏障，且依赖系统级生物识别/设备密码回退（`local_auth`）。在已 Root 或已解锁物理机被接管场景下无法抵抗内存取证或 UI 绕过（本地数据库加密仍独立有效）。
   - **闪存磨损均衡残留**：早期明文库通过 `sqlcipher_export` 迁移至加密库后，原明文文件虽已删除，但受闪存磨损均衡机制影响底层物理块无法保证即时擦除（详见 `docs/key-recovery.md`）。
   - **系统备份关闭**：换机迁移必须依赖导出加密备份或 WebDAV 同步。
   - *代码 / 文档依据*：[`docs/key-recovery.md`](docs/key-recovery.md)、[`lib/features/security/data/app_lock_service.dart`](lib/features/security/data/app_lock_service.dart)。

---

### 历史安全公告

- 暂无。后续修复安全问题时在此追加链接。
