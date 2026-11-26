class FarmTask {
  const FarmTask({
    required this.id,
    required this.eleveurId,
    required this.title,
    required this.status,
    required this.createdAt,
    this.taskType = 'custom',
    this.plan = '',
    this.alertId,
    this.completionNote,
    this.completedWeightKg,
    this.previousWeightKg,
    this.eleveurName,
    this.description,
    this.cowId,
    this.dueAt,
    this.completedAt,
    this.completedBy,
    this.completedByName,
  });

  final String id;
  final String eleveurId;
  final String? eleveurName;
  final String title;
  final String? description;
  final String? cowId;
  final DateTime? dueAt;
  final String status;
  final DateTime createdAt;
  final String taskType;
  final String plan;
  final String? alertId;
  final String? completionNote;
  final double? completedWeightKg;
  final double? previousWeightKg;
  final DateTime? completedAt;
  final String? completedBy;
  final String? completedByName;

  factory FarmTask.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final eleveurId = json['eleveur_id'];
    final title = json['title'];
    final status = json['status'];
    final createdAt = _date(json['created_at'], 'created_at');
    if (id is! String ||
        eleveurId is! String ||
        title is! String ||
        status is! String ||
        (status != 'pending' && status != 'done') ||
        createdAt == null) {
      throw const FormatException('Invalid task response.');
    }

    return FarmTask(
      id: id,
      eleveurId: eleveurId,
      eleveurName: _optionalString(json['eleveur_name'], 'eleveur_name'),
      title: title,
      description: _optionalString(json['description'], 'description'),
      cowId: _optionalString(json['cow_id'], 'cow_id'),
      dueAt: _date(json['due_at'], 'due_at'),
      status: status,
      createdAt: createdAt,
      taskType: _optionalString(json['task_type'], 'task_type') ?? 'custom',
      plan: _optionalString(json['plan'], 'plan') ?? '',
      alertId: _optionalString(json['alert_id'], 'alert_id'),
      completionNote:
          _optionalString(json['completion_note'], 'completion_note'),
      completedWeightKg: _optionalNumber(
        json['completed_weight_kg'],
        'completed_weight_kg',
      ),
      previousWeightKg: _optionalNumber(
        json['previous_weight_kg'],
        'previous_weight_kg',
      ),
      completedAt: _date(json['completed_at'], 'completed_at'),
      completedBy: _optionalString(json['completed_by'], 'completed_by'),
      completedByName:
          _optionalString(json['completed_by_name'], 'completed_by_name'),
    );
  }
}

String? _optionalString(Object? value, String field) {
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException('Invalid "$field" in task response.');
}

DateTime? _date(Object? value, String field) {
  if (value == null) return null;
  if (value is! String) {
    throw FormatException('Invalid "$field" in task response.');
  }

  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('Invalid "$field" in task response.');
  }
  return parsed;
}

double? _optionalNumber(Object? value, String field) {
  if (value == null) return null;
  if (value is num && value.isFinite) return value.toDouble();
  throw FormatException('Invalid "$field" in task response.');
}
