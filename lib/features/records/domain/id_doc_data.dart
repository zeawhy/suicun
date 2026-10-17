// lib/features/records/domain/id_doc_data.dart
// Structured data model for ID documents (Round 4 §1).
// Immutable value object with JSON serialization for storage.

/// Structured data for an ID document record.
///
/// The [type] is one of the 11 canonical keys:
/// 'passport' | 'driver_license' | 'national_id' | 'residence_permit' |
/// 'social_security' | 'health_insurance' | 'student_id' |
/// 'cn_resident_id' | 'hk_mo_permit' | 'tw_permit' | 'other'
class IdDocData {
  const IdDocData({
    required this.type,
    this.name,
    this.number,
    this.issuingCountry,
    this.issueDate,
    this.expiryDate,
    this.noExpiry = false,
    this.photoFront,
    this.photoBack,
    this.note,
    this.schemaVersion = 2,
  });

  final String type;
  final String? name;
  final String? number;

  /// ISO 3166-1 alpha-2 country code, e.g. 'US', 'CN'.
  final String? issuingCountry;
  final DateTime? issueDate;
  final DateTime? expiryDate;

  /// True when the document has no expiry date.
  final bool noExpiry;

  /// Relative path in the app's private directory.
  final String? photoFront;

  /// Relative path in the app's private directory.
  final String? photoBack;
  final String? note;

  /// Schema version for forward compatibility. Current: 2.
  final int schemaVersion;

  IdDocData copyWith({
    String? type,
    String? name,
    String? number,
    String? issuingCountry,
    DateTime? issueDate,
    DateTime? expiryDate,
    bool? noExpiry,
    String? photoFront,
    String? photoBack,
    String? note,
    int? schemaVersion,
  }) {
    return IdDocData(
      type: type ?? this.type,
      name: name ?? this.name,
      number: number ?? this.number,
      issuingCountry: issuingCountry ?? this.issuingCountry,
      issueDate: issueDate ?? this.issueDate,
      expiryDate: expiryDate ?? this.expiryDate,
      noExpiry: noExpiry ?? this.noExpiry,
      photoFront: photoFront ?? this.photoFront,
      photoBack: photoBack ?? this.photoBack,
      note: note ?? this.note,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }

  factory IdDocData.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return IdDocData(
      type: json['type'] as String? ?? 'other',
      name: json['name'] as String?,
      number: json['number'] as String?,
      issuingCountry: json['issuingCountry'] as String?,
      issueDate: parseDate(json['issueDate']),
      expiryDate: parseDate(json['expiryDate']),
      noExpiry: json['noExpiry'] as bool? ?? false,
      photoFront: json['photoFront'] as String?,
      photoBack: json['photoBack'] as String?,
      note: json['note'] as String?,
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 2,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      if (name != null) 'name': name,
      if (number != null) 'number': number,
      if (issuingCountry != null) 'issuingCountry': issuingCountry,
      if (issueDate != null) 'issueDate': issueDate!.toIso8601String(),
      if (expiryDate != null) 'expiryDate': expiryDate!.toIso8601String(),
      'noExpiry': noExpiry,
      if (photoFront != null) 'photoFront': photoFront,
      if (photoBack != null) 'photoBack': photoBack,
      if (note != null) 'note': note,
      'schemaVersion': schemaVersion,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IdDocData &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          name == other.name &&
          number == other.number &&
          issuingCountry == other.issuingCountry &&
          issueDate == other.issueDate &&
          expiryDate == other.expiryDate &&
          noExpiry == other.noExpiry &&
          photoFront == other.photoFront &&
          photoBack == other.photoBack &&
          note == other.note &&
          schemaVersion == other.schemaVersion;

  @override
  int get hashCode => Object.hash(
        type,
        name,
        number,
        issuingCountry,
        issueDate,
        expiryDate,
        noExpiry,
        photoFront,
        photoBack,
        note,
        schemaVersion,
      );

  @override
  String toString() => 'IdDocData(type: $type, name: $name, '
      'number: ${number != null ? "***" : null})';
}
