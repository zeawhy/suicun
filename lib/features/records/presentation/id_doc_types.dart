// lib/features/records/presentation/id_doc_types.dart
// Round 4 §2: ID document type system.
//
// Defines the 11 document types with storage keys, Material icons, and
// region-aware sorting. Display names come from l10n (idTypePassport etc.),
// never hardcoded here.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';

/// The 11 ID document types (Round 4 §2). Stored as [storageKey] strings.
enum IdDocType {
  passport,
  driverLicense,
  nationalId,
  residencePermit,
  socialSecurity,
  healthInsurance,
  studentId,
  cnResidentId,
  hkMoPermit,
  twPermit,
  other,
}

/// Storage key for each type (persisted in IdDocData.type).
extension IdDocTypeStorage on IdDocType {
  String get storageKey {
    switch (this) {
      case IdDocType.passport:
        return 'passport';
      case IdDocType.driverLicense:
        return 'driver_license';
      case IdDocType.nationalId:
        return 'national_id';
      case IdDocType.residencePermit:
        return 'residence_permit';
      case IdDocType.socialSecurity:
        return 'social_security';
      case IdDocType.healthInsurance:
        return 'health_insurance';
      case IdDocType.studentId:
        return 'student_id';
      case IdDocType.cnResidentId:
        return 'cn_resident_id';
      case IdDocType.hkMoPermit:
        return 'hk_mo_permit';
      case IdDocType.twPermit:
        return 'tw_permit';
      case IdDocType.other:
        return 'other';
    }
  }

  static IdDocType fromStorageKey(String? key) {
    switch (key) {
      case 'passport':
        return IdDocType.passport;
      case 'driver_license':
        return IdDocType.driverLicense;
      case 'national_id':
        return IdDocType.nationalId;
      case 'residence_permit':
        return IdDocType.residencePermit;
      case 'social_security':
        return IdDocType.socialSecurity;
      case 'health_insurance':
        return IdDocType.healthInsurance;
      case 'student_id':
        return IdDocType.studentId;
      case 'cn_resident_id':
        return IdDocType.cnResidentId;
      case 'hk_mo_permit':
        return IdDocType.hkMoPermit;
      case 'tw_permit':
        return IdDocType.twPermit;
      default:
        return IdDocType.other;
    }
  }
}

extension IdDocTypeIcon on IdDocType {
  IconData get icon {
    switch (this) {
      case IdDocType.passport:
        return Icons.flight_takeoff_outlined;
      case IdDocType.driverLicense:
        return Icons.directions_car_outlined;
      case IdDocType.nationalId:
        return Icons.badge_outlined;
      case IdDocType.residencePermit:
        return Icons.home_work_outlined;
      case IdDocType.socialSecurity:
        return Icons.health_and_safety_outlined;
      case IdDocType.healthInsurance:
        return Icons.medical_services_outlined;
      case IdDocType.studentId:
        return Icons.school_outlined;
      case IdDocType.cnResidentId:
        return Icons.credit_card_outlined;
      case IdDocType.hkMoPermit:
        return Icons.card_travel_outlined;
      case IdDocType.twPermit:
        return Icons.luggage_outlined;
      case IdDocType.other:
        return Icons.description_outlined;
    }
  }
}

extension IdDocTypeL10n on IdDocType {
  String localizedName(AppLocalizations l10n) {
    switch (this) {
      case IdDocType.passport:
        return l10n.idTypePassport;
      case IdDocType.driverLicense:
        return l10n.idTypeDriverLicense;
      case IdDocType.nationalId:
        return l10n.idTypeNationalId;
      case IdDocType.residencePermit:
        return l10n.idTypeResidencePermit;
      case IdDocType.socialSecurity:
        return l10n.idTypeSocialSecurity;
      case IdDocType.healthInsurance:
        return l10n.idTypeHealthInsurance;
      case IdDocType.studentId:
        return l10n.idTypeStudentId;
      case IdDocType.cnResidentId:
        return l10n.idTypeCnResidentId;
      case IdDocType.hkMoPermit:
        return l10n.idTypeHkMoPermit;
      case IdDocType.twPermit:
        return l10n.idTypeTwPermit;
      case IdDocType.other:
        return l10n.idTypeOther;
    }
  }
}

const String _kRecentTypesKey = 'id_doc_recent_types';
const int _kMaxRecentTypes = 2;

Future<void> recordRecentDocType(IdDocType type) async {
  final prefs = await SharedPreferences.getInstance();
  final recent = prefs.getStringList(_kRecentTypesKey) ?? <String>[];
  recent.remove(type.storageKey);
  recent.insert(0, type.storageKey);
  if (recent.length > _kMaxRecentTypes) {
    recent.removeRange(_kMaxRecentTypes, recent.length);
  }
  await prefs.setStringList(_kRecentTypesKey, recent);
}

Future<List<IdDocType>> getRecentDocTypes() async {
  final prefs = await SharedPreferences.getInstance();
  final keys = prefs.getStringList(_kRecentTypesKey) ?? <String>[];
  return keys
      .map(IdDocTypeStorage.fromStorageKey)
      .where((t) => t != IdDocType.other || keys.contains('other'))
      .take(_kMaxRecentTypes)
      .toList();
}

const List<IdDocType> _kCnOrder = [
  IdDocType.cnResidentId,
  IdDocType.passport,
  IdDocType.driverLicense,
  IdDocType.socialSecurity,
  IdDocType.healthInsurance,
  IdDocType.hkMoPermit,
  IdDocType.twPermit,
  IdDocType.residencePermit,
  IdDocType.studentId,
  IdDocType.other,
];

const List<IdDocType> _kOtherOrder = [
  IdDocType.passport,
  IdDocType.driverLicense,
  IdDocType.nationalId,
  IdDocType.residencePermit,
  IdDocType.socialSecurity,
  IdDocType.healthInsurance,
  IdDocType.studentId,
  IdDocType.other,
];

const List<IdDocType> kChinaDocGroup = [
  IdDocType.cnResidentId,
  IdDocType.hkMoPermit,
  IdDocType.twPermit,
];

Future<List<IdDocType>> getOrderedDocTypes(String? countryCode) async {
  final isCn = countryCode?.toUpperCase() == 'CN';
  final base = isCn
      ? List<IdDocType>.from(_kCnOrder)
      : [..._kOtherOrder, ...kChinaDocGroup];

  final recent = await getRecentDocTypes();
  for (final t in recent.reversed) {
    base.remove(t);
    base.insert(0, t);
  }
  return base;
}

bool docTypeShowsIssuingCountry(IdDocType type) {
  return type == IdDocType.passport ||
      type == IdDocType.driverLicense ||
      type == IdDocType.nationalId ||
      type == IdDocType.residencePermit;
}

String generateIdDocTitle(
  AppLocalizations l10n,
  IdDocType type,
  String? name,
) {
  final typeName = type.localizedName(l10n);
  final trimmedName = name?.trim() ?? '';
  if (trimmedName.isEmpty) return typeName;
  return '$typeName · $trimmedName';
}
