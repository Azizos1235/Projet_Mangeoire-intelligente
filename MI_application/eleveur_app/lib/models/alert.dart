import 'package:flutter/material.dart';
import '../core/theme.dart';

enum AlertSeverity { info, warning, critical }

extension AlertSeverityX on AlertSeverity {
  Color get color => switch (this) {
        AlertSeverity.info => AppTheme.alertInfo,
        AlertSeverity.warning => AppTheme.alertWarning,
        AlertSeverity.critical => AppTheme.alertCritical,
      };
}

/// An alert returned by the alerts API.
class Alert {
  final String id;
  final String message;
  final AlertSeverity severity;
  final String? cowId;
  final String adminId;
  final String? action;
  final String type;
  final String? appetiteClass;
  final Map<String, double>? appetitePct;
  final String status;
  final DateTime createdAt;
  final DateTime? readAt;

  const Alert({
    required this.id,
    required this.message,
    required this.severity,
    required this.cowId,
    required this.adminId,
    required this.action,
    required this.type,
    required this.appetiteClass,
    required this.appetitePct,
    required this.status,
    required this.createdAt,
    required this.readAt,
  });

  bool get isRead => status == 'read';

  factory Alert.fromJson(Map<String, dynamic> json) {
    final severityName = _requiredString(json, 'severity');
    final severity = switch (severityName) {
      'warning' => AlertSeverity.warning,
      'critical' => AlertSeverity.critical,
      'info' => AlertSeverity.info,
      _ => AlertSeverity.info,
    };
    final action = _optionalString(json, 'action');
    if (action != null && !{'sell', 'vet', 'butcher'}.contains(action)) {
      throw FormatException('Unknown alert action: $action');
    }

    final status = _requiredString(json, 'status');
    if (status != 'unread' && status != 'read') {
      throw FormatException('Unknown alert status: $status');
    }

    return Alert(
      id: _requiredString(json, 'id'),
      message: _requiredString(json, 'message'),
      severity: severity,
      cowId: _optionalString(json, 'cow_id'),
      adminId: _requiredString(json, 'admin_id'),
      action: action,
      type: _requiredString(json, 'type'),
      appetiteClass: _optionalString(json, 'appetite_class'),
      appetitePct: _optionalNumberMap(json, 'appetite_pct'),
      status: status,
      createdAt: DateTime.parse(_requiredString(json, 'created_at')),
      readAt: _optionalDateTime(json, 'read_at'),
    );
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('Missing or invalid "$key" in API response.');
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null || value is String) return value as String?;
  throw FormatException('Invalid "$key" in API response.');
}

Map<String, double>? _optionalNumberMap(
  Map<String, dynamic> json,
  String key,
) {
  final value = json[key];
  if (value == null) return null;
  if (value is! Map) {
    throw FormatException('Invalid "$key" in API response.');
  }

  final result = <String, double>{};
  for (final entry in value.entries) {
    if (entry.key is! String || entry.value is! num) {
      throw FormatException('Invalid "$key" in API response.');
    }
    result[entry.key as String] = (entry.value as num).toDouble();
  }
  return Map.unmodifiable(result);
}

DateTime? _optionalDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String && value.isNotEmpty) return DateTime.parse(value);
  throw FormatException('Invalid "$key" in API response.');
}
