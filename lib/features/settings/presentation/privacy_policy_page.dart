// lib/features/settings/presentation/privacy_policy_page.dart
//
// 隐私政策页：正文全部走 arb（中英跟随系统语言，不并列显示），
// 与 docs/privacy/index.html（中文）、docs/privacy/en.html（英文）内容保持一致。
// 「联系我们」的邮箱来自 arb 的 privacyContactEmail，点击用 url_launcher 打开 mailto:。

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      color: colorScheme.onSurface,
      fontWeight: FontWeight.bold,
    );
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurface,
      height: 1.8,
    );

    Widget section(String title, String body) {
      return Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: titleStyle),
            const SizedBox(height: 4),
            Text(body, style: bodyStyle),
          ],
        ),
      );
    }

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.privacyIntro, style: bodyStyle),
              section(l10n.privacyDataStorageTitle,
                  l10n.privacyDataStorageBody),
              section(l10n.privacySyncTitle, l10n.privacySyncBody),
              section(l10n.privacyBackupTitle, l10n.privacyBackupBody),
              section(
                  l10n.privacyPermissionsTitle, l10n.privacyPermissionsBody),
              section(l10n.privacyThirdPartiesTitle,
                  l10n.privacyThirdPartiesBody),
              section(l10n.privacyDeletionTitle, l10n.privacyDeletionBody),
              // 联系我们：开发者名 + 可点击邮箱（mailto:）。
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.privacyContactTitle, style: titleStyle),
                    const SizedBox(height: 4),
                    Text(l10n.privacyContactBody, style: bodyStyle),
                    InkWell(
                      onTap: () => launchUrl(
                        Uri.parse('mailto:${l10n.privacyContactEmail}'),
                      ),
                      child: Text(
                        l10n.privacyContactEmail,
                        style: bodyStyle?.copyWith(
                          color: colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
