class EleveurUser {
  final String id;
  final String name;
  final String role;
  final String adminId;
  final String? email;

  const EleveurUser({
    required this.id,
    required this.name,
    required this.role,
    required this.adminId,
    this.email,
  });

  factory EleveurUser.fromJson(Map<String, dynamic> json) {
    final email = _optionalString(json['email']);
    return EleveurUser(
      id: _requiredIdentifier(json, 'id'),
      name: _optionalString(json['name']) ?? '',
      role: _requiredString(json, 'role'),
      adminId: _optionalIdentifier(json, 'admin_id') ?? '',
      email: email,
    );
  }

  String? get displayName {
    final value = name.trim();
    if (value.isNotEmpty) return value;
    final fallback = email?.trim();
    return fallback == null || fallback.isEmpty ? null : fallback;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'admin_id': adminId,
        if (email != null) 'email': email,
      };
}

String _requiredIdentifier(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  if (value is num) return value.toString();
  throw FormatException('Missing or invalid "$key" in user response.');
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('Missing or invalid "$key" in user response.');
}

String? _optionalIdentifier(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  if (value is num) return value.toString();
  return null;
}

String? _optionalString(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;
