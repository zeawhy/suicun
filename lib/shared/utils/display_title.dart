// lib/shared/utils/display_title.dart
// Formats an intelligent display title for records based on template data.

import 'package:flutter/widgets.dart';
import 'package:suicun/features/records/domain/record_model.dart';
import 'package:suicun/features/records/presentation/template_views/id_doc_type.dart';
import 'package:suicun/features/records/presentation/template_views/template_detector.dart';

/// Formats a display title for [RecordDetail].
///
/// Rules:
/// 1. If [r.title] is non-empty, returns [r.title].
/// 2. If [r.body] matches ID document template, returns
///    `"${docType}${name != null ? ' · $name' : ''}"`, where docType is
///    localized via [localizedDocType] when [context] is given (falls back to
///    the raw stored type name / [defaultDocType] without a context).
/// 3. If [r.body] matches password template and website/app is non-empty, returns website/app.
/// 4. If [r.body] matches contact template and name is non-empty, returns contact name.
/// 5. Otherwise returns [untitled].
String displayTitleFor(
  RecordDetail r, {
  required String untitled,
  String? defaultDocType,
  BuildContext? context,
}) {
  return displayTitleFrom(
    title: r.title,
    body: r.body,
    untitled: untitled,
    defaultDocType: defaultDocType,
    context: context,
  );
}

/// Helper that computes the display title from raw [title] and [body] strings.
String displayTitleFrom({
  required String title,
  required String body,
  required String untitled,
  String? defaultDocType,
  BuildContext? context,
}) {
  if (title.trim().isNotEmpty) {
    return title;
  }

  if (isIdDocumentTemplate(body)) {
    final data = parseIdDocumentTemplate(body);
    final docType = data?.docType?.trim();
    final name = data?.name?.trim();
    final String effectiveDocType;
    if (context != null) {
      effectiveDocType = localizedDocType(
        context,
        parseDocTypeKey(docType),
        (docType != null && docType.isNotEmpty) ? docType : null,
      );
    } else {
      effectiveDocType = (docType != null && docType.isNotEmpty)
          ? docType
          : (defaultDocType ?? '证件');
    }
    final namePart = (name != null && name.isNotEmpty) ? ' · $name' : '';
    return '$effectiveDocType$namePart';
  }

  if (isPasswordTemplate(body)) {
    final data = parsePasswordTemplate(body);
    final website = data?.website?.trim();
    if (website != null && website.isNotEmpty) {
      return website;
    }
  }

  if (isContactTemplate(body)) {
    final data = parseContactTemplate(body);
    final contactName = data?.name?.trim();
    if (contactName != null && contactName.isNotEmpty) {
      return contactName;
    }
  }

  return untitled;
}
