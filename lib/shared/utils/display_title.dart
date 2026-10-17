// lib/shared/utils/display_title.dart
// Formats an intelligent display title for records based on template data.

import 'package:flutter/widgets.dart';
import 'package:suicun/features/records/domain/id_doc_codec.dart';
import 'package:suicun/features/records/domain/id_doc_data.dart';
import 'package:suicun/features/records/domain/record_model.dart';
import 'package:suicun/features/records/presentation/id_doc_types.dart';
import 'package:suicun/features/records/presentation/template_views/template_detector.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';

/// Formats a display title for [RecordDetail].
///
/// Rules:
/// 1. If [r.title] is non-empty, returns [r.title].
/// 2. If [r.body] is an ID document body (new or legacy format), returns
///    `"${docType}${name != null ? ' · $name' : ''}"`, where docType is the
///    localized type name via [IdDocType.localizedName] when [context] is
///    given (falls back to the storage key / [defaultDocType] without one).
///    The JSON body itself is never shown.
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

  if (isIdDocBody(body)) {
    final IdDocData? data = decodeIdDocBody(body);
    if (data != null) {
      final type = IdDocTypeStorage.fromStorageKey(data.type);
      final String effectiveDocType;
      if (context != null) {
        effectiveDocType = type.localizedName(AppLocalizations.of(context));
      } else {
        effectiveDocType = defaultDocType ?? data.type;
      }
      final name = data.name?.trim() ?? '';
      final namePart = name.isNotEmpty ? ' · $name' : '';
      return '$effectiveDocType$namePart';
    }
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
