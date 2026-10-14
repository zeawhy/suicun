// lib/features/settings/presentation/privacy_policy_page.dart

import 'package:flutter/material.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';

const String _privacyPolicyZh = '''随存是一款本地优先的隐私笔记应用。

数据存储：您的所有记录、照片均仅存储在您的设备本地，不上传到任何服务器。我们没有用户账号系统，不收集、不存储您的任何个人信息。

同步：如您自行配置 WebDAV 同步，数据仅在您的设备与您自己的服务器之间直接传输，我们无法访问。同步配置信息仅保存在本地。

权限使用：相机仅用于拍摄证件照片（保存到应用私有目录）；相册仅用于选择证件照片；指纹/面容仅用于应用锁解锁（生物信息由系统管理）；网络仅在您启用 WebDAV 同步时使用。

第三方：应用内无广告、无第三方 SDK、无数据统计上报。

数据删除：您可随时在「设置 → 清除全部数据」中彻底删除本地所有数据。''';

const String _privacyPolicyEn = '''SuiVault is a local-first privacy note-taking application.

Data Storage: All your records and photos are stored strictly locally on your device and are never uploaded to any server. We have no user account system and do not collect or store any of your personal information.

Sync: If you configure WebDAV sync, data is transferred directly between your device and your own server, and we cannot access it. Sync configuration information is stored locally only.

Permissions: Camera is used only to capture ID document photos (saved to the app's private directory); photo gallery is used only to select ID document photos; fingerprint/face recognition is used only to unlock the app lock (biometric information is managed by the operating system); network is used only when you enable WebDAV sync.

Third Parties: There are no ads, no third-party SDKs, and no analytics tracking or telemetry in the app.

Data Deletion: You can completely delete all local data at any time under "Settings → Clear all data".''';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    final content = isZh ? _privacyPolicyZh : _privacyPolicyEn;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.privacyPolicy),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
              height: 1.8,
            ),
          ),
        ),
      ),
    );
  }
}
