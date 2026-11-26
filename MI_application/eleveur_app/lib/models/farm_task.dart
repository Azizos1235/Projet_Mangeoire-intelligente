class FarmTask {
  const FarmTask({
    required this.id,
    required this.title,
    required this.createdAt,
    this.taskType = 'custom',
    this.plan = '',
    this.description,
    this.cowId,
    this.dueAt,
  });

  final String id;
  final String title;
  final String? description;
  final String? cowId;
  final DateTime? dueAt;
  final DateTime createdAt;
  final String taskType;
  final String plan;

  factory FarmTask.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final createdAt = _parseDate(json['created_at'], 'created_at');
    if (id is! String || title is! String || createdAt == null) {
      throw const FormatException('Invalid task response.');
    }

    return FarmTask(
      id: id,
      title: title,
      taskType: _optionalString(json['task_type'], 'task_type') ?? 'custom',
      plan: _optionalString(json['plan'], 'plan') ?? '',
      description: _optionalString(json['description'], 'description'),
      cowId: _optionalString(json['cow_id'], 'cow_id'),
      dueAt: _parseDate(json['due_at'], 'due_at'),
      createdAt: createdAt,
    );
  }
}

String? _optionalString(Object? value, String field) {
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException('Invalid "$field" in task response.');
}

DateTime? _parseDate(Object? value, String field) {
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
