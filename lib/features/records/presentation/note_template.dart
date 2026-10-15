// lib/features/records/presentation/note_template.dart
// Pre-defined note templates for creating records with boilerplate content.

import 'package:flutter/material.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';

/// Predefined template for creating a note with prefilled body text.
class NoteTemplate {
  const NoteTemplate({
    required this.id,
    required this.icon,
    required this.bodyZh,
    required this.bodyEn,
  });

  final String id;
  final IconData icon;
  final String bodyZh;
  final String bodyEn;

  /// Returns localized body according to [languageCode] (e.g. 'zh' or 'en').
  String getBody(String? languageCode) {
    if (languageCode?.toLowerCase().startsWith('en') == true) {
      return bodyEn;
    }
    return bodyZh;
  }

  /// Returns localized template name.
  String getTitle(AppLocalizations l10n) {
    switch (id) {
      case 'blank':
        return l10n.templateBlank;
      case 'password':
        return l10n.templatePassword;
      case 'idea':
        return l10n.templateIdea;
      case 'todo':
        return l10n.templateTodo;
      case 'contact':
        return l10n.templateContact;
      case 'id_document':
        return l10n.templateIdDocument;
      default:
        return id;
    }
  }

  /// Returns localized template one-line description.
  String getDescription(AppLocalizations l10n) {
    switch (id) {
      case 'blank':
        return l10n.templateBlankDesc;
      case 'password':
        return l10n.templatePasswordDesc;
      case 'idea':
        return l10n.templateIdeaDesc;
      case 'todo':
        return l10n.templateTodoDesc;
      case 'contact':
        return l10n.templateContactDesc;
      case 'id_document':
        return l10n.templateIdDocumentDesc;
      default:
        return '';
    }
  }

  /// All supported note templates.
  static const List<NoteTemplate> all = [
    NoteTemplate(
      id: 'blank',
      icon: Icons.edit_note_outlined,
      bodyZh: '',
      bodyEn: '',
    ),
    NoteTemplate(
      id: 'password',
      icon: Icons.lock_outline,
      bodyZh: '网站/应用：\n用户名：\n密码：\n备注：',
      bodyEn: 'Website/App:\nUsername:\nPassword:\nNotes:',
    ),
    NoteTemplate(
      id: 'idea',
      icon: Icons.lightbulb_outline,
      bodyZh: '灵感：\n来源：\n下一步行动：',
      bodyEn: 'Idea:\nSource:\nNext action:',
    ),
    NoteTemplate(
      id: 'todo',
      icon: Icons.check_box_outlined,
      bodyZh: '☐ 事项一\n☐ 事项二\n☐ 事项三',
      bodyEn: '☐ Task one\n☐ Task two\n☐ Task three',
    ),
    NoteTemplate(
      id: 'contact',
      icon: Icons.person_outline,
      bodyZh: '姓名：\n电话：\n邮箱：\n地址：\n备注：',
      bodyEn: 'Name:\nPhone:\nEmail:\nAddress:\nNotes:',
    ),
    NoteTemplate(
      id: 'id_document',
      icon: Icons.badge_outlined,
      bodyZh: '证件类型：\n姓名：\n证件号码：\n有效期至：\n证件照片正面：\n证件照片反面：\n备注：',
      bodyEn: 'Document type:\nName:\nDocument number:\nValid until:\nID photo front:\nID photo back:\nNotes:',
    ),
  ];

  /// Finds a template by its [id].
  static NoteTemplate? byId(String? id) {
    if (id == null) return null;
    if (id == 'address') {
      return byId('contact');
    }
    for (final template in all) {
      if (template.id == id) return template;
    }
    return null;
  }
}
