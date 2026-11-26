import 'package:eleveur_app/models/farm_task.dart';
import 'package:eleveur_app/native/action_queue.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeNativeActionChannel implements NativeActionChannel {
  Map<String, dynamic>? initial;
  ValueChanged<Map<String, dynamic>>? listener;

  @override
  Future<Map<String, dynamic>?> actionInitiale() async => initial;

  @override
  Future<void> startListening(
    ValueChanged<Map<String, dynamic>> onAction,
  ) async {
    listener = onAction;
  }
}

void main() {
  test('cold-start target is retained while logged out', () async {
    final channel = _FakeNativeActionChannel()
      ..initial = {'action': 'voir', 'task_id': 'task-1'};
    final target = PendingNotificationTarget(channel);
    await target.initialize();

    expect(target.take(), isNull);
    expect(target.pendingAction?['task_id'], 'task-1');

    target.setReadiness(
      sessionRestored: true,
      loggedIn: true,
      navigatorReady: true,
      shellReady: true,
    );
    expect(target.take()?['task_id'], 'task-1');
  });

  test('cold-start check-weight target opens its existing weight flow',
      () async {
    final channel = _FakeNativeActionChannel()
      ..initial = {
        'action': 'voir',
        'type': 'check_weight',
        'task_id': 'task-1',
        'cow_id': 'cow-1',
      };
    final target = PendingNotificationTarget(channel);
    await target.initialize();
    target.setReadiness(
      sessionRestored: true,
      loggedIn: true,
      navigatorReady: true,
      shellReady: true,
    );
    final task = FarmTask(
      id: 'task-1',
      title: 'Peser',
      taskType: 'check_weight',
      cowId: 'cow-1',
      createdAt: DateTime.utc(2025),
    );
    FarmTask? openedWeightTask;
    var openedTasks = false;

    final decision = await const TaskNotificationRouter().route(
      target.take()!,
      pendingTasks: [task],
      openWeightTask: (value) async {
        openedWeightTask = value;
      },
      openTasks: () => openedTasks = true,
    );

    expect(openedWeightTask, same(task));
    expect(openedTasks, isFalse);
    expect(decision, TaskNotificationDecision.openedWeightTask);
  });

  test('unknown or completed task opens tasks and reports missing target',
      () async {
    final target = PendingNotificationTarget(_FakeNativeActionChannel()
      ..initial = {
        'action': 'voir',
        'type': 'check_weight',
        'task_id': 'completed-task',
      });
    await target.initialize();
    target.setReadiness(
      sessionRestored: true,
      loggedIn: true,
      navigatorReady: true,
      shellReady: true,
    );
    var openedTasks = false;

    final decision = await const TaskNotificationRouter().route(
      target.take()!,
      pendingTasks: const [],
      openWeightTask: (_) async {},
      openTasks: () => openedTasks = true,
    );

    expect(openedTasks, isTrue);
    expect(decision, TaskNotificationDecision.taskNotFound);
  });

  test('warm action is held until the shell is ready', () async {
    final channel = _FakeNativeActionChannel();
    final target = PendingNotificationTarget(channel);
    await target.initialize();
    channel.listener!({
      'action': 'voir',
      'type': 'custom',
      'task_id': 'task-2',
    });

    expect(target.take(), isNull);
    target.setReadiness(
      sessionRestored: true,
      loggedIn: true,
      navigatorReady: true,
      shellReady: true,
    );
    expect(target.take()?['task_id'], 'task-2');
    expect(target.take(), isNull);
  });
}
