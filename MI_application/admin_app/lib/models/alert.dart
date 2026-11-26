import 'package:flutter/material.dart';

import '../core/theme.dart';

enum AlertSeverity { info, warning, critical }

extension AlertSeverityX on AlertSeverity {
  Color get color => switch (this) {
        AlertSeverity.info => const Color(0xFF1E88E5),
        AlertSeverity.warning => AppTheme.amber,
        AlertSeverity.critical => AppTheme.warn,
      };
}

class Alert {
  const Alert({
    required this.id,
    required this.source,
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
    required this.taskId,
    required this.handled,
    required this.completionNote,
    required this.completedWeightKg,
    this.previousWeightKg,
  });

  final String id;
  final String source;
  final String message;
  final AlertSeverity severity;
  final String? cowId;
  final String? adminId;
  final String? action;
  final String type;
  final String? appetiteClass;
  final Map<String, double>? appetitePct;
  final String status;
  final DateTime createdAt;
  final DateTime? readAt;
  final String? taskId;
  final bool handled;
  final String? completionNote;
  final double? completedWeightKg;
  final double? previousWeightKg;

  bool get isRead => status == 'read';
  bool get isAppetite => type == 'appetite_high' || type == 'appetite_low';
  bool get isTaskCompleted => type == 'task_completed';

  factory Alert.fromJson(Map<String, dynamic> json) {
    final severityName = json['severity'];
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
      source: _optionalString(json, 'source') ?? 'system',
      message: _requiredString(json, 'message'),
      severity: severity,
      cowId: _optionalString(json, 'cow_id'),
      adminId: _optionalString(json, 'admin_id'),
      action: action,
      type: _requiredString(json, 'type'),
      appetiteClass: _optionalString(json, 'appetite_class'),
      appetitePct: _optionalNumberMap(json, 'appetite_pct'),
      status: status,
      createdAt: DateTime.parse(_requiredString(json, 'created_at')),
      readAt: _optionalDateTime(json, 'read_at'),
      taskId: _optionalString(json, 'task_id'),
      handled: _optionalBool(json, 'handled') ?? false,
      completionNote: _optionalString(json, 'completion_note'),
      completedWeightKg: _optionalNumber(json, 'completed_weight_kg'),
      previousWeightKg: _optionalNumber(json, 'previous_weight_kg'),
    );
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('Missing or invalid "$key" in alert response.');
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null || value is String) return value;
  throw FormatException('Invalid "$key" in alert response.');
}

Map<String, double>? _optionalNumberMap(
  Map<String, dynamic> json,
  String key,
) {
  final value = json[key];
  if (value == null) return null;
  if (value is! Map) {
    throw FormatException('Invalid "$key" in alert response.');
  }

  final result = <String, double>{};
  for (final entry in value.entries) {
    if (entry.key is! String || entry.value is! num) {
      throw FormatException('Invalid "$key" in alert response.');
    }
    result[entry.key as String] = (entry.value as num).toDouble();
  }
  return Map.unmodifiable(result);
}

DateTime? _optionalDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String && value.isNotEmpty) return DateTime.parse(value);
  throw FormatException('Invalid "$key" in alert response.');
}

bool? _optionalBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null || value is bool) return value as bool?;
  throw FormatException('Invalid "$key" in alert response.');
}

double? _optionalNumber(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is num && value.isFinite) return value.toDouble();
  throw FormatException('Invalid "$key" in alert response.');
}
