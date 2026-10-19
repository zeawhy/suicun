# Play Upload Key（正式签名密钥）生成与配置指南

> **谁生成密钥**：由用户本人在自己的电脑上生成。密钥是这个 App 的"身份证"，
> **不要把 keystore 文件或密码发给任何人**（包括 Muse、合作开发者、客服），
> 也不要上传到网盘、Git 仓库、邮件或聊天记录里。

## 1. 生成 keystore

在你自己的电脑上（Mac / Linux / Windows 均可，需装 JDK）打开终端，运行：

```bash
keytool -genkeypair -v \
  -storetype JKS \
  -keystore upload-keystore.jks \
  -alias upload \
  -keyalg RSA \
  -keysize 2048 \
  -validity 9125 \
  -storepass <你的keystore密码> \
  -keypass <你的密钥密码>
```

参数说明：

| 参数 | 说明 |
| --- | --- |
| `-keystore upload-keystore.jks` | keystore 文件名，可自己取名，放在安全目录（建议和代码分开，例如 `~/keys/`） |
| `-alias upload` | 密钥别名，后续 `key.properties` 的 `keyAlias` 必须和它一致 |
| `-keyalg RSA -keysize 2048` | Play 要求的签名算法与密钥长度 |
| `-validity 9125` | 有效期 25 年（9125 天）。**Play 要求 upload key 有效期至少到 2033 年之后**，25 年留足余量 |
| `-storepass` | keystore 密码，至少 6 位，建议 16 位以上随机密码 |
| `-keypass` | 密钥密码，可以和 keystore 密码相同或不同（Play 文档习惯用同一份密码） |
| `-storetype JKS` | keystore 格式 |

运行后 `keytool` 会要求填写姓名/组织/城市/省份/国家代码等证书信息（C=CN），
按实际情况填即可；最后确认 `Is ... correct? [no]:` 输入 `yes`。

完成后你会得到一个 `upload-keystore.jks` 文件——**这就是核心资产**，见第 4 节备份要求。

## 2. 写 `android/key.properties`

在仓库的 `android/` 目录下新建 `key.properties`（**不要提交到 Git，已在 `.gitignore` 中排除**）：

```properties
storePassword=<你的keystore密码>
keyPassword=<你的密钥密码>
keyAlias=upload
storeFile=upload-keystore.jks
```

说明：

- `storeFile` 填 keystore 文件名即可（相对路径，解析基准是 `android/app/` 目录，
  所以 keystore 放到 `android/app/` 下或写绝对路径都行；推荐放 `android/app/` 下，构建完可删除）。
- 也可以写绝对路径：`storeFile=/Users/你的名字/keys/upload-keystore.jks`。
- 有了这个文件，`flutter build apk --release` / `flutter build appbundle --release`
  就会用正式密钥签名；没有这个文件则自动回落到 debug 签名（本地调试不受影响）。

## 3. 把密钥存进 GitHub Secrets（CI 正式签名用）

CI 构建时从 Secrets 还原 keystore，四个 Secret 全部配齐才走正式签名，
缺任何一个都会安静地回落到 debug 签名（构建不挂）：

1. 把 keystore 转成 base64（**注意**：不要把输出贴到聊天记录里，直接复制到 GitHub 页面）：

   ```bash
   # macOS
   base64 -i upload-keystore.jks | pbcopy
   # Linux
   base64 -w0 upload-keystore.jks | xclip -selection clipboard
   # Windows (PowerShell)
   [Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks")) | Set-Clipboard
   ```

2. 在 GitHub 仓库页 → Settings → Secrets and variables → Actions → New repository secret，
   依次创建：

   | Secret 名 | 值 |
   | --- | --- |
   | `UPLOAD_KEYSTORE_BASE64` | 上一步 base64 输出的全部内容（一整行，不要换行） |
   | `KEY_ALIAS` | 密钥别名，如 `upload` |
   | `KEY_PASSWORD` | 密钥密码（同 `-keypass`） |
   | `STORE_PASSWORD` | keystore 密码（同 `-storepass`） |

3. 配好后触发 `build-apk.yml` workflow（Actions → Build release (APK + AAB) → Run workflow），
   构建日志里会看到 `Play upload keystore prepared: release build will be signed with the upload key.`，
   产出的 AAB 就是正式签名包，可直接上传 Play Console。

## 4. ⚠️ 密钥备份警告（必读）

- **密钥丢了 = 这个 App 永远无法再更新。**
  Google Play 要求同一个应用的所有版本都用同一个 upload key 签名。
  一旦 keystore 文件或密码丢失，就只能用**新的包名**重新上架，
  老用户收不到更新、评分和下载量全部清零。
- 备份方案（至少两份离线备份）：
  1. keystore 文件 + 密码存到密码管理器（如 1Password / Bitwarden 的安全备注）；
  2. 再拷一份到离线 U 盘或移动硬盘，锁好；
  3. 密码也可以手抄一份放保险箱。
- 不要只备份在正在用的电脑上（硬盘坏了就没了），不要备份在云盘/邮箱草稿里。

## 5. 常见问题

- **本地构建还是 debug 签名？** 检查 `android/key.properties` 是否存在、
  `keyAlias` 是否与生成时的 `-alias` 一致、密码是否正确。构建失败日志里
  `Keystore was tampered with, or password was incorrect` 就是密码错了。
- **换电脑开发？** 把 keystore 文件和密码用安全方式（加密 U 盘）拷过去，
  重新写一份 `key.properties` 即可，不用重新生成。
- **密钥泄露了怎么办？** 立即在 Play Console（设置 → 应用完整性）申请重置 upload key，
  用新密钥重新生成并更新 GitHub Secrets；同时旧包已发布的不受影响，
  但务必确认新密钥已生效再发版。
