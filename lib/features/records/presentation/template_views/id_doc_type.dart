// lib/features/records/presentation/template_views/id_doc_type.dart
// Card styling per ID document type (Round 5 §1.4).
//
// The legacy IdDocTypeKey / label tables / parseDocTypeKey / localizedDocType
// were removed: display names now come from IdDocType.localizedName (l10n),
// and type identity is the IdDocType storage key. This file only holds the
// card gradient colors keyed by [IdDocType].

import 'package:flutter/material.dart';
import 'package:suicun/features/records/presentation/id_doc_types.dart';

/// Card gradient colors per document type: [start, middle, end].
const Map<IdDocType, List<Color>> kDocTypeGradients = {
  IdDocType.cnResidentId: [
    Color(0xFF46668C),
    Color(0xFF2B4363),
    Color(0xFF1F3149),
  ],
  IdDocType.nationalId: [
    Color(0xFF46668C),
    Color(0xFF2B4363),
    Color(0xFF1F3149),
  ],
  IdDocType.driverLicense: [
    Color(0xFF3F7D62),
    Color(0xFF2F6A52),
    Color(0xFF24533F),
  ],
  IdDocType.passport: [
    Color(0xFF8E3B46),
    Color(0xFF76303C),
    Color(0xFF5C2230),
  ],
  IdDocType.hkMoPermit: [
    Color(0xFF5B4B8A),
    Color(0xFF4A3D73),
    Color(0xFF3A2F5E),
  ],
  IdDocType.twPermit: [
    Color(0xFF5B4B8A),
    Color(0xFF4A3D73),
    Color(0xFF3A2F5E),
  ],
  IdDocType.residencePermit: [
    Color(0xFF5B4B8A),
    Color(0xFF4A3D73),
    Color(0xFF3A2F5E),
  ],
  IdDocType.socialSecurity: [
    Color(0xFFC9773A),
    Color(0xFFAD612C),
    Color(0xFF8F4A1E),
  ],
  IdDocType.healthInsurance: [
    Color(0xFF2F6F7A),
    Color(0xFF265C66),
    Color(0xFF1C4A52),
  ],
  IdDocType.studentId: [
    Color(0xFF7A5C3E),
    Color(0xFF654B32),
    Color(0xFF4E3A27),
  ],
  IdDocType.other: [
    Color(0xFF5B6573),
    Color(0xFF48515D),
    Color(0xFF353D48),
  ],
};
