// lib/features/records/presentation/template_views/id_doc_type.dart
// Shared ID document type definitions for the ID document template.
//
// Holds the [IdDocTypeKey] enum, the Chinese/English label tables (data used
// for parsing stored bodies — never shown verbatim; see [localizedDocType]),
// the card gradient/icon tables, and the [parseDocTypeKey]/[localizedDocType]
// helpers shared by the template view, the card view and display titles.

import 'package:flutter/material.dart';

enum IdDocTypeKey {
  idCard,
  driverLicense,
  vehicleLicense,
  passport,
  hmtPermit,
  socialCard,
  propertyCert,
  other,
}

/// Chinese labels per document type (data table for parsing/display).
const Map<IdDocTypeKey, String> kDocTypeChineseLabels = {
  IdDocTypeKey.idCard: '身份证',
  IdDocTypeKey.driverLicense: '驾驶证',
  IdDocTypeKey.vehicleLicense: '行驶证',
  IdDocTypeKey.passport: '护照',
  IdDocTypeKey.hmtPermit: '港澳通行证',
  IdDocTypeKey.socialCard: '社保卡',
  IdDocTypeKey.propertyCert: '房产证',
  IdDocTypeKey.other: '其他',
};

/// English labels per document type (data table for parsing/display).
const Map<IdDocTypeKey, String> kDocTypeEnglishLabels = {
  IdDocTypeKey.idCard: 'ID Card',
  IdDocTypeKey.driverLicense: 'Driver License',
  IdDocTypeKey.vehicleLicense: 'Vehicle License',
  IdDocTypeKey.passport: 'Passport',
  IdDocTypeKey.hmtPermit: 'Exit-Entry Permit (HK/Macau)',
  IdDocTypeKey.socialCard: 'Social Security Card',
  IdDocTypeKey.propertyCert: 'Property Certificate',
  IdDocTypeKey.other: 'Other',
};

/// Parses a stored document type string into an [IdDocTypeKey].
///
/// Unknown or empty values fall back to [IdDocTypeKey.idCard] (legacy
/// behavior: every stored ID record is assumed to be an ID card).
IdDocTypeKey parseDocTypeKey(String? docType) {
  if (docType == null || docType.trim().isEmpty) {
    return IdDocTypeKey.idCard;
  }
  final dt = docType.trim();
  final lower = dt.toLowerCase();
  if (dt == '身份证' || lower == 'id card') return IdDocTypeKey.idCard;
  if (dt == '驾驶证' || lower == 'driver license') {
    return IdDocTypeKey.driverLicense;
  }
  if (dt == '行驶证' || lower == 'vehicle license') {
    return IdDocTypeKey.vehicleLicense;
  }
  if (dt == '护照' || lower == 'passport') return IdDocTypeKey.passport;
  if (dt == '港澳通行证' || lower.contains('exit-entry') || lower.contains('hmt')) {
    return IdDocTypeKey.hmtPermit;
  }
  if (dt == '社保卡' || lower == 'social security card') {
    return IdDocTypeKey.socialCard;
  }
  if (dt == '房产证' || lower == 'property certificate') {
    return IdDocTypeKey.propertyCert;
  }
  return IdDocTypeKey.other;
}

/// Returns the document type name in the current UI language.
///
/// Rules (spec §2.8):
/// - A custom "other" type name typed by the user is shown as-is.
/// - Otherwise the label table matching the current locale is used.
/// - Stored bodies are never rewritten here (avoids sync conflicts).
String localizedDocType(
  BuildContext context,
  IdDocTypeKey key,
  String? raw,
) {
  if (key == IdDocTypeKey.other &&
      raw != null &&
      raw.isNotEmpty &&
      raw != '其他' &&
      raw.toLowerCase() != 'other') {
    return raw;
  }
  final isZh = Localizations.localeOf(context).languageCode == 'zh';
  return isZh ? kDocTypeChineseLabels[key]! : kDocTypeEnglishLabels[key]!;
}

/// Card gradient colors per document type: [start, middle, end].
const Map<IdDocTypeKey, List<Color>> kDocTypeGradients = {
  IdDocTypeKey.idCard: [
    Color(0xFF46668C),
    Color(0xFF2B4363),
    Color(0xFF1F3149),
  ],
  IdDocTypeKey.driverLicense: [
    Color(0xFF3F7D62),
    Color(0xFF2F6A52),
    Color(0xFF24533F),
  ],
  IdDocTypeKey.vehicleLicense: [
    Color(0xFF2F6F7A),
    Color(0xFF265C66),
    Color(0xFF1C4A52),
  ],
  IdDocTypeKey.passport: [
    Color(0xFF8E3B46),
    Color(0xFF76303C),
    Color(0xFF5C2230),
  ],
  IdDocTypeKey.hmtPermit: [
    Color(0xFF5B4B8A),
    Color(0xFF4A3D73),
    Color(0xFF3A2F5E),
  ],
  IdDocTypeKey.socialCard: [
    Color(0xFFC9773A),
    Color(0xFFAD612C),
    Color(0xFF8F4A1E),
  ],
  IdDocTypeKey.propertyCert: [
    Color(0xFF7A5C3E),
    Color(0xFF654B32),
    Color(0xFF4E3A27),
  ],
  IdDocTypeKey.other: [
    Color(0xFF5B6573),
    Color(0xFF48515D),
    Color(0xFF353D48),
  ],
};

/// Card type icon per document type.
const Map<IdDocTypeKey, IconData> kDocTypeIcons = {
  IdDocTypeKey.idCard: Icons.badge_outlined,
  IdDocTypeKey.driverLicense: Icons.directions_car_outlined,
  IdDocTypeKey.vehicleLicense: Icons.description_outlined,
  IdDocTypeKey.passport: Icons.flight_takeoff_outlined,
  IdDocTypeKey.hmtPermit: Icons.card_travel_outlined,
  IdDocTypeKey.socialCard: Icons.health_and_safety_outlined,
  IdDocTypeKey.propertyCert: Icons.home_work_outlined,
  IdDocTypeKey.other: Icons.credit_card_outlined,
};
