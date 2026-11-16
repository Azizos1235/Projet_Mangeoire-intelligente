import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

class CowReference {
  final String internalId;
  final String cowId;

  const CowReference({required this.internalId, required this.cowId});

  bool get hasPublicId {
    final publicId = cowId.trim();
    return publicId.isNotEmpty &&
        (publicId != internalId || _isCowCode(publicId));
  }

  String get displayId {
    if (hasPublicId) return cowId.trim();
    final id = internalId.trim();
    return _isCowCode(id) ? id : '—';
  }

  factory CowReference.fromJson(
    Map<String, dynamic> json, {
    int? debugItem,
  }) {
    final logItem =
        debugItem != null && (debugItem <= 20 || debugItem % 100 == 0);
    if (kDebugMode && logItem) {
      debugPrint('[DBG] CowReference.fromJson item=$debugItem start');
    }
    final cowId = json['cow_id'];
    final internalId = json['internal_id'] ?? cowId;
    if (internalId is! String || internalId.trim().isEmpty) {
      throw const FormatException(
          'Missing internal cow identifier in API response.');
    }
    final cow = CowReference(
      internalId: internalId,
      cowId: cowId is String ? cowId : '',
    );
    if (kDebugMode && logItem) {
      debugPrint('[DBG] CowReference.fromJson item=$debugItem complete');
    }
    return cow;
  }
}

bool _isCowCode(String value) =>
    RegExp(r'^COW[-_]?\d+$', caseSensitive: false).hasMatch(value.trim());

class CowProfile {
  final String internalId;
  final String cowId;
  final String adminId;
  final String breed;
  final String type;
  final double weightKg;
  final DateTime birthDate;
  final double ageMonths;
  final String? nfcUid;

  const CowProfile({
    required this.internalId,
    required this.cowId,
    required this.adminId,
    required this.breed,
    required this.type,
    required this.weightKg,
    required this.birthDate,
    required this.ageMonths,
    required this.nfcUid,
  });

  factory CowProfile.fromJson(Map<String, dynamic> json) => CowProfile(
        cowId: _requiredIdentifier(json, 'cow_id'),
        internalId: _optionalIdentifier(json, 'internal_id') ??
            _requiredIdentifier(json, 'cow_id'),
        adminId: _requiredIdentifier(json, 'admin_id'),
        breed: _requiredString(json, 'breed'),
        type: _requiredString(json, 'type'),
        weightKg: _requiredNumber(json, 'weight_kg'),
        birthDate: DateTime.parse(_requiredString(json, 'birth_date')),
        ageMonths: _requiredNumber(json, 'age_months'),
        nfcUid: _optionalString(json, 'nfc_uid'),
      );

  CowReference get reference =>
      CowReference(internalId: internalId, cowId: cowId);
}

String? _optionalIdentifier(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String && value.isNotEmpty) return value;
  if (value is num) return value.toString();
  throw FormatException('Invalid "$key" in profile response.');
}

String _requiredIdentifier(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  if (value is num) return value.toString();
  throw FormatException('Missing or invalid "$key" in profile response.');
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('Missing or invalid "$key" in profile response.');
}

double _requiredNumber(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num && value.isFinite) return value.toDouble();
  throw FormatException('Missing or invalid "$key" in profile response.');
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null || value is String) return value as String?;
  throw FormatException('Invalid "$key" in profile response.');
}
