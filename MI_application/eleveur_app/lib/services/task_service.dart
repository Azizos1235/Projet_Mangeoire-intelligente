import '../models/farm_task.dart';
import 'api_client.dart';

abstract interface class TaskServiceApi {
  Future<List<FarmTask>> listMyPendingTasks();

  Future<void> markDone(
    String taskId, {
    double? completedWeightKg,
    double? previousWeightKg,
    String? completionNote,
  });
}

class TaskService implements TaskServiceApi {
  TaskService._();

  static final TaskService instance = TaskService._();

  @override
  Future<List<FarmTask>> listMyPendingTasks() async {
    final response = await ApiClient.instance.get('/tasks/mine');
    if (response is! List) {
      throw const FormatException('Invalid task list response.');
    }
    final tasks = response.map((item) {
      if (item is! Map) {
        throw const FormatException('Invalid task list response.');
      }
      return FarmTask.fromJson(Map<String, dynamic>.from(item));
    }).toList();
    return sortPendingTasks(tasks, now: DateTime.now());
  }

  static List<FarmTask> sortPendingTasks(
    List<FarmTask> tasks, {
    required DateTime now,
  }) {
    final sortedTasks = List<FarmTask>.of(tasks);
    final nowUtc = now.toUtc();
    sortedTasks.sort((first, second) {
      final firstDueAt = first.dueAt;
      final secondDueAt = second.dueAt;
      final firstOverdue =
          firstDueAt != null && firstDueAt.toUtc().isBefore(nowUtc);
      final secondOverdue =
          secondDueAt != null && secondDueAt.toUtc().isBefore(nowUtc);
      if (firstOverdue != secondOverdue) {
        return firstOverdue ? -1 : 1;
      }
      if (firstDueAt != null && secondDueAt != null) {
        final byDueDate =
            firstDueAt.toUtc().compareTo(secondDueAt.toUtc());
        if (byDueDate != 0) return byDueDate;
      } else if (firstDueAt != null) {
        return -1;
      } else if (secondDueAt != null) {
        return 1;
      }
      return second.createdAt.toUtc().compareTo(first.createdAt.toUtc());
    });
    return sortedTasks;
  }

  @override
  Future<void> markDone(
    String taskId, {
    double? completedWeightKg,
    double? previousWeightKg,
    String? completionNote,
  }) async {
    await ApiClient.instance.post(
      '/tasks/${Uri.encodeComponent(taskId)}/done',
      {
        if (completedWeightKg != null) 'completed_weight_kg': completedWeightKg,
        if (previousWeightKg != null) 'previous_weight_kg': previousWeightKg,
        if (completionNote != null && completionNote.trim().isNotEmpty)
          'completion_note': completionNote.trim(),
      },
    );
  }
}
