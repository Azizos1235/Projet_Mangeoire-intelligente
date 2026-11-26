import '../models/farm_task.dart';
import 'api_client.dart';

class TaskService {
  TaskService._();

  static final TaskService instance = TaskService._();

  Future<List<FarmTask>> listTasks({
    String? eleveurId,
    String? status,
    int limit = 500,
    int skip = 0,
  }) async {
    final query = <String, String>{
      'limit': '$limit',
      'skip': '$skip',
      if (eleveurId != null) 'eleveur_id': eleveurId,
      if (status != null) 'status': status,
    };
    final path = Uri(path: '/tasks', queryParameters: query);
    final response =
        await ApiClient.instance.get<List<dynamic>>(path.toString());
    return response.map((item) {
      if (item is! Map) {
        throw const FormatException('Invalid task list response.');
      }
      return FarmTask.fromJson(Map<String, dynamic>.from(item));
    }).toList(growable: false);
  }

  Future<void> createTask({
    required String eleveurId,
    required String title,
    String? description,
    String? cowId,
    DateTime? dueAt,
    String taskType = 'custom',
    String? plan,
    String? alertId,
  }) async {
    await ApiClient.instance.post<Map<String, dynamic>>(
      '/tasks',
      body: {
        'eleveur_id': eleveurId,
        'title': title,
        'task_type': taskType,
        if (plan != null) 'plan': plan,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (cowId != null) 'cow_id': cowId,
        if (alertId != null) 'alert_id': alertId,
        if (dueAt != null) 'due_at': dueAt.toUtc().toIso8601String(),
      },
    );
  }

  Future<void> deleteTask(String id) async {
    await ApiClient.instance
        .delete<Object?>('/tasks/${Uri.encodeComponent(id)}');
  }
}
